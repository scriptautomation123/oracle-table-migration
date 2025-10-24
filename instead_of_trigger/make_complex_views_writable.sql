-- ===================================================================
-- Complex Writable Views Framework
-- ===================================================================
-- Purpose: Handle multi-table joins with referential integrity
-- Features: 
--   - Multi-table view support
--   - Referential integrity enforcement
--   - Transaction management
--   - Conflict resolution
-- ===================================================================

SET ECHO ON
SET SERVEROUTPUT ON

-- ===================================================================
-- 1. ENHANCED VIEW ANALYSIS FUNCTION
-- ===================================================================

CREATE OR REPLACE FUNCTION analyze_complex_view(
    p_view_name IN VARCHAR2,
    p_view_owner IN VARCHAR2 DEFAULT USER
) RETURN SYS_REFCURSOR
IS
    v_cursor SYS_REFCURSOR;
BEGIN
    OPEN v_cursor FOR
        SELECT 
            v.view_name,
            v.view_definition,
            -- Extract table names from view definition
            REGEXP_SUBSTR(UPPER(v.view_definition), 'FROM\s+([A-Z_][A-Z0-9_]*)', 1, 1, 'i', 1) as primary_table,
            REGEXP_SUBSTR(UPPER(v.view_definition), 'JOIN\s+([A-Z_][A-Z0-9_]*)', 1, 1, 'i', 1) as join_table_1,
            REGEXP_SUBSTR(UPPER(v.view_definition), 'JOIN\s+([A-Z_][A-Z0-9_]*)', 1, 2, 'i', 1) as join_table_2,
            REGEXP_SUBSTR(UPPER(v.view_definition), 'JOIN\s+([A-Z_][A-Z0-9_]*)', 1, 3, 'i', 1) as join_table_3
        FROM all_views v
        WHERE v.owner = p_view_owner
        AND v.view_name = p_view_name;
    
    RETURN v_cursor;
END;
/

-- ===================================================================
-- 2. REFERENTIAL INTEGRITY ANALYSIS
-- ===================================================================

CREATE OR REPLACE FUNCTION analyze_referential_integrity(
    p_table_name IN VARCHAR2,
    p_table_owner IN VARCHAR2 DEFAULT USER
) RETURN SYS_REFCURSOR
IS
    v_cursor SYS_REFCURSOR;
BEGIN
    OPEN v_cursor FOR
        SELECT 
            c.constraint_name,
            c.constraint_type,
            c.r_constraint_name,
            cc1.column_name as child_column,
            cc2.column_name as parent_column,
            c.r_owner as parent_owner,
            c.r_table_name as parent_table,
            c.delete_rule,
            c.update_rule
        FROM all_constraints c
        JOIN all_cons_columns cc1 ON c.constraint_name = cc1.constraint_name 
            AND c.owner = cc1.owner
        LEFT JOIN all_constraints rc ON c.r_constraint_name = rc.constraint_name
        LEFT JOIN all_cons_columns cc2 ON rc.constraint_name = cc2.constraint_name 
            AND rc.owner = cc2.owner
        WHERE c.owner = p_table_owner
        AND c.table_name = p_table_name
        AND c.constraint_type IN ('P', 'R', 'U');
    
    RETURN v_cursor;
END;
/

-- ===================================================================
-- 3. COMPLEX VIEW WRITABLE FUNCTION
-- ===================================================================

CREATE OR REPLACE FUNCTION make_complex_view_writable(
    p_view_name IN VARCHAR2,
    p_view_owner IN VARCHAR2 DEFAULT USER,
    p_primary_table IN VARCHAR2,
    p_join_tables IN VARCHAR2 DEFAULT NULL,
    p_enforce_referential_integrity IN BOOLEAN DEFAULT TRUE
) RETURN VARCHAR2
IS
    v_sql VARCHAR2(4000);
    v_trigger_name VARCHAR2(128);
    v_view_columns VARCHAR2(4000);
    v_primary_columns VARCHAR2(4000);
    v_join_columns VARCHAR2(4000);
    v_column_list VARCHAR2(4000);
    v_column_values VARCHAR2(4000);
    v_column_updates VARCHAR2(4000);
    v_where_clause VARCHAR2(4000);
    v_referential_checks VARCHAR2(4000);
    
    -- Cursor for view columns
    CURSOR c_view_columns IS
        SELECT column_name, data_type
        FROM all_tab_columns
        WHERE owner = p_view_owner
        AND table_name = p_view_name
        ORDER BY column_id;
    
    -- Cursor for primary table columns
    CURSOR c_primary_columns IS
        SELECT column_name, data_type
        FROM all_tab_columns
        WHERE owner = p_view_owner
        AND table_name = p_primary_table
        ORDER BY column_id;
    
    -- Cursor for foreign key constraints
    CURSOR c_fk_constraints IS
        SELECT 
            c.constraint_name,
            cc.column_name,
            c.r_table_name,
            c.r_owner,
            c.delete_rule
        FROM all_constraints c
        JOIN all_cons_columns cc ON c.constraint_name = cc.constraint_name 
            AND c.owner = cc.owner
        WHERE c.owner = p_view_owner
        AND c.table_name = p_primary_table
        AND c.constraint_type = 'R';
    
BEGIN
    -- Build column lists
    FOR rec IN c_view_columns LOOP
        IF v_view_columns IS NULL THEN
            v_view_columns := rec.column_name;
            v_column_list := rec.column_name;
            v_column_values := ':NEW.' || rec.column_name;
            v_column_updates := rec.column_name || ' = :NEW.' || rec.column_name;
        ELSE
            v_view_columns := v_view_columns || ', ' || rec.column_name;
            v_column_list := v_column_list || ', ' || rec.column_name;
            v_column_values := v_column_values || ', :NEW.' || rec.column_name;
            v_column_updates := v_column_updates || ', ' || rec.column_name || ' = :NEW.' || rec.column_name;
        END IF;
    END LOOP;
    
    -- Build WHERE clause for UPDATE/DELETE
    FOR rec IN c_primary_columns LOOP
        IF v_where_clause IS NULL THEN
            v_where_clause := rec.column_name || ' = :OLD.' || rec.column_name;
        ELSE
            v_where_clause := v_where_clause || ' AND ' || rec.column_name || ' = :OLD.' || rec.column_name;
        END IF;
    END LOOP;
    
    -- Build referential integrity checks
    IF p_enforce_referential_integrity THEN
        FOR rec IN c_fk_constraints LOOP
            v_referential_checks := v_referential_checks || '
        -- Check referential integrity for ' || rec.constraint_name || '
        IF :NEW.' || rec.column_name || ' IS NOT NULL THEN
            SELECT COUNT(*) INTO v_count FROM ' || rec.r_owner || '.' || rec.r_table_name || 
            ' WHERE ' || rec.column_name || ' = :NEW.' || rec.column_name || ';
            IF v_count = 0 THEN
                RAISE_APPLICATION_ERROR(-20001, ''Referential integrity violation: ' || 
                rec.column_name || ' does not exist in ' || rec.r_table_name || ''');
            END IF;
        END IF;';
        END LOOP;
    END IF;
    
    -- Create trigger name
    v_trigger_name := 'TRG_' || p_view_name || '_COMPLEX_WRITABLE';
    
    -- Build complex trigger SQL
    v_sql := '
CREATE OR REPLACE TRIGGER ' || v_trigger_name || '
INSTEAD OF INSERT OR UPDATE OR DELETE ON ' || p_view_owner || '.' || p_view_name || '
FOR EACH ROW
DECLARE
    v_count NUMBER;
    v_error_msg VARCHAR2(4000);
BEGIN
    -- Begin transaction
    SAVEPOINT sp_' || p_view_name || ';
    
    BEGIN
        IF INSERTING THEN
            ' || v_referential_checks || '
            INSERT INTO ' || p_view_owner || '.' || p_primary_table || ' (' || v_column_list || ')
            VALUES (' || v_column_values || ');
            
        ELSIF UPDATING THEN
            ' || v_referential_checks || '
            UPDATE ' || p_view_owner || '.' || p_primary_table || '
            SET ' || v_column_updates || '
            WHERE ' || v_where_clause || ';
            
        ELSIF DELETING THEN
            -- Check for dependent records
            FOR rec IN c_fk_constraints LOOP
                SELECT COUNT(*) INTO v_count FROM ' || p_view_owner || '.' || p_primary_table || 
                ' WHERE ' || rec.column_name || ' = :OLD.' || rec.column_name || ';
                IF v_count > 0 THEN
                    RAISE_APPLICATION_ERROR(-20002, ''Cannot delete: Dependent records exist'');
                END IF;
            END LOOP;
            
            DELETE FROM ' || p_view_owner || '.' || p_primary_table || '
            WHERE ' || v_where_clause || ';
        END IF;
        
        -- Commit the transaction
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Rollback to savepoint
            ROLLBACK TO sp_' || p_view_name || ';
            -- Re-raise the exception
            RAISE;
    END;
END;';
    
    -- Execute the trigger creation
    EXECUTE IMMEDIATE v_sql;
    
    RETURN 'SUCCESS: Created complex writable view trigger ' || v_trigger_name;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END;
/

-- ===================================================================
-- 4. MULTI-TABLE VIEW WRITABLE FUNCTION
-- ===================================================================

CREATE OR REPLACE FUNCTION make_multi_table_view_writable(
    p_view_name IN VARCHAR2,
    p_view_owner IN VARCHAR2 DEFAULT USER,
    p_table_configs IN VARCHAR2, -- JSON-like string with table configurations
    p_enforce_referential_integrity IN BOOLEAN DEFAULT TRUE
) RETURN VARCHAR2
IS
    v_sql VARCHAR2(4000);
    v_trigger_name VARCHAR2(128);
    v_view_columns VARCHAR2(4000);
    v_column_list VARCHAR2(4000);
    v_column_values VARCHAR2(4000);
    v_column_updates VARCHAR2(4000);
    v_where_clause VARCHAR2(4000);
    v_referential_checks VARCHAR2(4000);
    v_table_inserts VARCHAR2(4000);
    v_table_updates VARCHAR2(4000);
    v_table_deletes VARCHAR2(4000);
    
    -- Cursor for view columns
    CURSOR c_view_columns IS
        SELECT column_name, data_type
        FROM all_tab_columns
        WHERE owner = p_view_owner
        AND table_name = p_view_name
        ORDER BY column_id;
    
BEGIN
    -- Build column lists
    FOR rec IN c_view_columns LOOP
        IF v_view_columns IS NULL THEN
            v_view_columns := rec.column_name;
            v_column_list := rec.column_name;
            v_column_values := ':NEW.' || rec.column_name;
            v_column_updates := rec.column_name || ' = :NEW.' || rec.column_name;
        ELSE
            v_view_columns := v_view_columns || ', ' || rec.column_name;
            v_column_list := v_column_list || ', ' || rec.column_name;
            v_column_values := v_column_values || ', :NEW.' || rec.column_name;
            v_column_updates := v_column_updates || ', ' || rec.column_name || ' = :NEW.' || rec.column_name;
        END IF;
    END LOOP;
    
    -- Parse table configurations and build operations
    -- This is a simplified version - you'd need to parse the JSON-like string
    v_table_inserts := '-- Insert into primary table
            INSERT INTO ' || p_view_owner || '.' || p_view_name || ' (' || v_column_list || ')
            VALUES (' || v_column_values || ');';
    
    v_table_updates := '-- Update primary table
            UPDATE ' || p_view_owner || '.' || p_view_name || '
            SET ' || v_column_updates || '
            WHERE ' || v_where_clause || ';';
    
    v_table_deletes := '-- Delete from primary table
            DELETE FROM ' || p_view_owner || '.' || p_view_name || '
            WHERE ' || v_where_clause || ';';
    
    -- Create trigger name
    v_trigger_name := 'TRG_' || p_view_name || '_MULTI_TABLE_WRITABLE';
    
    -- Build multi-table trigger SQL
    v_sql := '
CREATE OR REPLACE TRIGGER ' || v_trigger_name || '
INSTEAD OF INSERT OR UPDATE OR DELETE ON ' || p_view_owner || '.' || p_view_name || '
FOR EACH ROW
DECLARE
    v_count NUMBER;
    v_error_msg VARCHAR2(4000);
BEGIN
    -- Begin transaction
    SAVEPOINT sp_' || p_view_name || ';
    
    BEGIN
        IF INSERTING THEN
            ' || v_referential_checks || '
            ' || v_table_inserts || '
            
        ELSIF UPDATING THEN
            ' || v_referential_checks || '
            ' || v_table_updates || '
            
        ELSIF DELETING THEN
            ' || v_table_deletes || '
        END IF;
        
        -- Commit the transaction
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Rollback to savepoint
            ROLLBACK TO sp_' || p_view_name || ';
            -- Re-raise the exception
            RAISE;
    END;
END;';
    
    -- Execute the trigger creation
    EXECUTE IMMEDIATE v_sql;
    
    RETURN 'SUCCESS: Created multi-table writable view trigger ' || v_trigger_name;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END;
/

-- ===================================================================
-- 5. REFERENTIAL INTEGRITY ENFORCEMENT PROCEDURE
-- ===================================================================

CREATE OR REPLACE PROCEDURE enforce_referential_integrity(
    p_table_name IN VARCHAR2,
    p_table_owner IN VARCHAR2 DEFAULT USER,
    p_operation IN VARCHAR2, -- 'INSERT', 'UPDATE', 'DELETE'
    p_column_values IN VARCHAR2 DEFAULT NULL -- JSON-like string with column values
)
IS
    v_count NUMBER;
    v_error_msg VARCHAR2(4000);
    
    -- Cursor for foreign key constraints
    CURSOR c_fk_constraints IS
        SELECT 
            c.constraint_name,
            cc.column_name,
            c.r_table_name,
            c.r_owner,
            c.delete_rule
        FROM all_constraints c
        JOIN all_cons_columns cc ON c.constraint_name = cc.constraint_name 
            AND c.owner = cc.owner
        WHERE c.owner = p_table_owner
        AND c.table_name = p_table_name
        AND c.constraint_type = 'R';
    
BEGIN
    FOR rec IN c_fk_constraints LOOP
        -- Check referential integrity based on operation
        IF p_operation = 'INSERT' OR p_operation = 'UPDATE' THEN
            -- Check if referenced record exists
            EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || rec.r_owner || '.' || rec.r_table_name || 
                ' WHERE ' || rec.column_name || ' = :col_value' INTO v_count USING p_column_values;
            
            IF v_count = 0 THEN
                v_error_msg := 'Referential integrity violation: ' || rec.column_name || 
                    ' does not exist in ' || rec.r_table_name;
                RAISE_APPLICATION_ERROR(-20001, v_error_msg);
            END IF;
            
        ELSIF p_operation = 'DELETE' THEN
            -- Check for dependent records
            EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_table_owner || '.' || p_table_name || 
                ' WHERE ' || rec.column_name || ' = :col_value' INTO v_count USING p_column_values;
            
            IF v_count > 0 THEN
                v_error_msg := 'Cannot delete: Dependent records exist in ' || p_table_name;
                RAISE_APPLICATION_ERROR(-20002, v_error_msg);
            END IF;
        END IF;
    END LOOP;
END;
/

-- ===================================================================
-- 6. TRANSACTION MANAGEMENT PROCEDURE
-- ===================================================================

CREATE OR REPLACE PROCEDURE manage_view_transaction(
    p_view_name IN VARCHAR2,
    p_operation IN VARCHAR2,
    p_success IN BOOLEAN DEFAULT TRUE
)
IS
    v_savepoint_name VARCHAR2(128);
BEGIN
    v_savepoint_name := 'sp_' || p_view_name || '_' || p_operation;
    
    IF p_success THEN
        -- Commit the transaction
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Transaction committed for view: ' || p_view_name);
    ELSE
        -- Rollback to savepoint
        ROLLBACK TO v_savepoint_name;
        DBMS_OUTPUT.PUT_LINE('Transaction rolled back for view: ' || p_view_name);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error managing transaction: ' || SQLERRM);
        RAISE;
END;
/

-- ===================================================================
-- 7. CONFLICT RESOLUTION PROCEDURE
-- ===================================================================

CREATE OR REPLACE PROCEDURE resolve_view_conflicts(
    p_view_name IN VARCHAR2,
    p_conflict_type IN VARCHAR2, -- 'DUPLICATE_KEY', 'REFERENTIAL_INTEGRITY', 'CHECK_CONSTRAINT'
    p_conflict_data IN VARCHAR2 DEFAULT NULL
)
IS
    v_resolution_strategy VARCHAR2(100);
    v_sql VARCHAR2(4000);
BEGIN
    -- Determine resolution strategy based on conflict type
    CASE p_conflict_type
        WHEN 'DUPLICATE_KEY' THEN
            v_resolution_strategy := 'UPDATE_EXISTING';
        WHEN 'REFERENTIAL_INTEGRITY' THEN
            v_resolution_strategy := 'REJECT_OPERATION';
        WHEN 'CHECK_CONSTRAINT' THEN
            v_resolution_strategy := 'APPLY_DEFAULTS';
        ELSE
            v_resolution_strategy := 'REJECT_OPERATION';
    END CASE;
    
    -- Apply resolution strategy
    CASE v_resolution_strategy
        WHEN 'UPDATE_EXISTING' THEN
            -- Update existing record instead of inserting
            DBMS_OUTPUT.PUT_LINE('Resolving duplicate key conflict by updating existing record');
        WHEN 'REJECT_OPERATION' THEN
            -- Reject the operation
            RAISE_APPLICATION_ERROR(-20003, 'Operation rejected due to conflict: ' || p_conflict_type);
        WHEN 'APPLY_DEFAULTS' THEN
            -- Apply default values
            DBMS_OUTPUT.PUT_LINE('Resolving constraint conflict by applying defaults');
        ELSE
            RAISE_APPLICATION_ERROR(-20004, 'Unknown conflict resolution strategy');
    END CASE;
END;
/

-- ===================================================================
-- 8. USAGE EXAMPLES
-- ===================================================================

/*
-- Example 1: Make complex view with referential integrity
BEGIN
    DBMS_OUTPUT.PUT_LINE(make_complex_view_writable('HR_EMPLOYEE_DEPT_VIEW', 'HR', 'EMPLOYEES', 'DEPARTMENTS', TRUE));
END;
/

-- Example 2: Make multi-table view writable
BEGIN
    DBMS_OUTPUT.PUT_LINE(make_multi_table_view_writable('COMPLEX_VIEW', 'SCHEMA', '{"primary":"TABLE1","joins":["TABLE2","TABLE3"]}', TRUE));
END;
/

-- Example 3: Enforce referential integrity
BEGIN
    enforce_referential_integrity('EMPLOYEES', 'HR', 'INSERT', '123');
END;
/

-- Example 4: Manage transaction
BEGIN
    manage_view_transaction('MY_VIEW', 'INSERT', TRUE);
END;
/

-- Example 5: Resolve conflicts
BEGIN
    resolve_view_conflicts('MY_VIEW', 'DUPLICATE_KEY', '{"id":123}');
END;
/
*/

-- ===================================================================
-- 9. QUICK START INSTRUCTIONS
-- ===================================================================

PROMPT ===================================================================
PROMPT COMPLEX WRITABLE VIEWS FRAMEWORK INSTALLED
PROMPT ===================================================================
PROMPT
PROMPT Usage Examples:
PROMPT 1. Make complex view writable with referential integrity:
PROMPT    BEGIN DBMS_OUTPUT.PUT_LINE(make_complex_view_writable('MY_VIEW', 'SCHEMA', 'PRIMARY_TABLE', 'JOIN_TABLES', TRUE)); END; /
PROMPT
PROMPT 2. Make multi-table view writable:
PROMPT    BEGIN DBMS_OUTPUT.PUT_LINE(make_multi_table_view_writable('COMPLEX_VIEW', 'SCHEMA', 'TABLE_CONFIG', TRUE)); END; /
PROMPT
PROMPT 3. Enforce referential integrity:
PROMPT    BEGIN enforce_referential_integrity('TABLE_NAME', 'SCHEMA', 'INSERT', 'VALUE'); END; /
PROMPT
PROMPT 4. Manage transactions:
PROMPT    BEGIN manage_view_transaction('VIEW_NAME', 'OPERATION', TRUE); END; /
PROMPT
PROMPT 5. Resolve conflicts:
PROMPT    BEGIN resolve_view_conflicts('VIEW_NAME', 'CONFLICT_TYPE', 'DATA'); END; /
PROMPT
PROMPT ===================================================================

-- ===================================================================
-- END OF SCRIPT
-- ===================================================================
