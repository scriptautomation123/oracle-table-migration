-- ===================================================================
-- Table Migration Writable View Framework
-- ===================================================================
-- Purpose: Create writable views for table migration scenarios
-- Scenario: table_old + table_new -> writable view named 'table'
--          - Reads from both table_old and table_new
--          - Writes only to table_new
--          - Handles referential integrity
-- ===================================================================

SET ECHO ON
SET SERVEROUTPUT ON

-- ===================================================================
-- 1. TABLE MIGRATION WRITABLE VIEW FUNCTION
-- ===================================================================

CREATE OR REPLACE FUNCTION create_migration_writable_view(
    p_table_name IN VARCHAR2,
    p_table_owner IN VARCHAR2 DEFAULT USER,
    p_old_table_suffix IN VARCHAR2 DEFAULT '_OLD',
    p_new_table_suffix IN VARCHAR2 DEFAULT '_NEW',
    p_enforce_referential_integrity IN BOOLEAN DEFAULT TRUE
) RETURN VARCHAR2
IS
    v_sql VARCHAR2(4000);
    v_trigger_name VARCHAR2(128);
    v_view_name VARCHAR2(128);
    v_old_table_name VARCHAR2(128);
    v_new_table_name VARCHAR2(128);
    v_view_columns VARCHAR2(4000);
    v_new_table_columns VARCHAR2(4000);
    v_column_list VARCHAR2(4000);
    v_column_values VARCHAR2(4000);
    v_column_updates VARCHAR2(4000);
    v_where_clause VARCHAR2(4000);
    v_referential_checks VARCHAR2(4000);
    v_view_definition VARCHAR2(4000);
    
    -- Cursor for table columns
    CURSOR c_table_columns IS
        SELECT column_name, data_type, nullable
        FROM all_tab_columns
        WHERE owner = p_table_owner
        AND table_name = p_table_name
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
        WHERE c.owner = p_table_owner
        AND c.table_name = p_table_name
        AND c.constraint_type = 'R';
    
BEGIN
    -- Set table names
    v_view_name := p_table_name;
    v_old_table_name := p_table_name || p_old_table_suffix;
    v_new_table_name := p_table_name || p_new_table_suffix;
    
    -- Build column lists
    FOR rec IN c_table_columns LOOP
        IF v_view_columns IS NULL THEN
            v_view_columns := rec.column_name;
            v_column_list := rec.column_name;
            v_column_values := ':NEW.' || rec.column_name;
            v_column_updates := rec.column_name || ' = :NEW.' || rec.column_name;
            v_new_table_columns := rec.column_name;
        ELSE
            v_view_columns := v_view_columns || ', ' || rec.column_name;
            v_column_list := v_column_list || ', ' || rec.column_name;
            v_column_values := v_column_values || ', :NEW.' || rec.column_name;
            v_column_updates := v_column_updates || ', ' || rec.column_name || ' = :NEW.' || rec.column_name;
            v_new_table_columns := v_new_table_columns || ', ' || rec.column_name;
        END IF;
    END LOOP;
    
    -- Build WHERE clause for UPDATE/DELETE
    FOR rec IN c_table_columns LOOP
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
    
    -- Create view definition (UNION of old and new tables)
    v_view_definition := '
CREATE OR REPLACE VIEW ' || p_table_owner || '.' || v_view_name || ' AS
SELECT ' || v_view_columns || '
FROM ' || p_table_owner || '.' || v_old_table_name || '
UNION ALL
SELECT ' || v_view_columns || '
FROM ' || p_table_owner || '.' || v_new_table_name;
';
    
    -- Create the view
    EXECUTE IMMEDIATE v_view_definition;
    
    -- Create trigger name
    v_trigger_name := 'TRG_' || v_view_name || '_MIGRATION_WRITABLE';
    
    -- Build migration writable trigger SQL
    v_sql := '
CREATE OR REPLACE TRIGGER ' || v_trigger_name || '
INSTEAD OF INSERT OR UPDATE OR DELETE ON ' || p_table_owner || '.' || v_view_name || '
FOR EACH ROW
DECLARE
    v_count NUMBER;
    v_error_msg VARCHAR2(4000);
    v_record_exists_old NUMBER;
    v_record_exists_new NUMBER;
BEGIN
    -- Begin transaction
    SAVEPOINT sp_' || v_view_name || '_migration;
    
    BEGIN
        IF INSERTING THEN
            ' || v_referential_checks || '
            
            -- Insert only into NEW table
            INSERT INTO ' || p_table_owner || '.' || v_new_table_name || ' (' || v_column_list || ')
            VALUES (' || v_column_values || ');
            
        ELSIF UPDATING THEN
            ' || v_referential_checks || '
            
            -- Check if record exists in OLD table
            SELECT COUNT(*) INTO v_record_exists_old 
            FROM ' || p_table_owner || '.' || v_old_table_name || '
            WHERE ' || v_where_clause || ';
            
            -- Check if record exists in NEW table
            SELECT COUNT(*) INTO v_record_exists_new 
            FROM ' || p_table_owner || '.' || v_new_table_name || '
            WHERE ' || v_where_clause || ';
            
            IF v_record_exists_new > 0 THEN
                -- Update record in NEW table
                UPDATE ' || p_table_owner || '.' || v_new_table_name || '
                SET ' || v_column_updates || '
                WHERE ' || v_where_clause || ';
            ELSIF v_record_exists_old > 0 THEN
                -- Move record from OLD to NEW table
                INSERT INTO ' || p_table_owner || '.' || v_new_table_name || ' (' || v_column_list || ')
                VALUES (' || v_column_values || ');
            ELSE
                RAISE_APPLICATION_ERROR(-20003, ''Record not found for update'');
            END IF;
            
        ELSIF DELETING THEN
            -- Check if record exists in OLD table
            SELECT COUNT(*) INTO v_record_exists_old 
            FROM ' || p_table_owner || '.' || v_old_table_name || '
            WHERE ' || v_where_clause || ';
            
            -- Check if record exists in NEW table
            SELECT COUNT(*) INTO v_record_exists_new 
            FROM ' || p_table_owner || '.' || v_new_table_name || '
            WHERE ' || v_where_clause || ';
            
            IF v_record_exists_new > 0 THEN
                -- Delete from NEW table
                DELETE FROM ' || p_table_owner || '.' || v_new_table_name || '
                WHERE ' || v_where_clause || ';
            ELSIF v_record_exists_old > 0 THEN
                -- Mark as deleted in OLD table (or delete if appropriate)
                -- For migration scenarios, you might want to keep OLD records
                -- DELETE FROM ' || p_table_owner || '.' || v_old_table_name || '
                -- WHERE ' || v_where_clause || ';
                RAISE_APPLICATION_ERROR(-20004, ''Cannot delete from OLD table during migration'');
            ELSE
                RAISE_APPLICATION_ERROR(-20005, ''Record not found for deletion'');
            END IF;
        END IF;
        
        -- Commit the transaction
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Rollback to savepoint
            ROLLBACK TO sp_' || v_view_name || '_migration;
            -- Re-raise the exception
            RAISE;
    END;
END;';
    
    -- Execute the trigger creation
    EXECUTE IMMEDIATE v_sql;
    
    RETURN 'SUCCESS: Created migration writable view ' || v_view_name || ' with trigger ' || v_trigger_name;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END;
/

-- ===================================================================
-- 2. BATCH TABLE MIGRATION WRITABLE VIEWS
-- ===================================================================

CREATE OR REPLACE PROCEDURE create_all_migration_writable_views(
    p_schema_name IN VARCHAR2 DEFAULT USER,
    p_table_suffix IN VARCHAR2 DEFAULT '_OLD',
    p_new_table_suffix IN VARCHAR2 DEFAULT '_NEW',
    p_enforce_referential_integrity IN BOOLEAN DEFAULT TRUE
)
IS
    -- Cursor to get all tables with OLD suffix
    CURSOR c_old_tables IS
        SELECT table_name
        FROM all_tables
        WHERE owner = p_schema_name
        AND table_name LIKE '%' || p_table_suffix;
    
    v_base_table_name VARCHAR2(128);
    v_result VARCHAR2(4000);
BEGIN
    FOR rec IN c_old_tables LOOP
        -- Extract base table name
        v_base_table_name := SUBSTR(rec.table_name, 1, LENGTH(rec.table_name) - LENGTH(p_table_suffix));
        
        -- Check if corresponding NEW table exists
        IF table_exists(p_schema_name, v_base_table_name || p_new_table_suffix) THEN
            DBMS_OUTPUT.PUT_LINE('Processing table: ' || v_base_table_name);
            v_result := create_migration_writable_view(
                v_base_table_name, 
                p_schema_name, 
                p_table_suffix, 
                p_new_table_suffix, 
                p_enforce_referential_integrity
            );
            DBMS_OUTPUT.PUT_LINE(v_result);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skipping ' || v_base_table_name || ': NEW table does not exist');
        END IF;
    END LOOP;
END;
/

-- ===================================================================
-- 3. HELPER FUNCTION TO CHECK TABLE EXISTS
-- ===================================================================

CREATE OR REPLACE FUNCTION table_exists(
    p_schema_name IN VARCHAR2,
    p_table_name IN VARCHAR2
) RETURN BOOLEAN
IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM all_tables
    WHERE owner = p_schema_name
    AND table_name = p_table_name;
    
    RETURN v_count > 0;
END;
/

-- ===================================================================
-- 4. MIGRATION STATUS CHECK
-- ===================================================================

CREATE OR REPLACE PROCEDURE check_migration_status(
    p_schema_name IN VARCHAR2 DEFAULT USER,
    p_table_suffix IN VARCHAR2 DEFAULT '_OLD',
    p_new_table_suffix IN VARCHAR2 DEFAULT '_NEW'
)
IS
    -- Cursor to check migration status
    CURSOR c_migration_status IS
        SELECT 
            t.table_name as base_table,
            CASE WHEN ot.table_name IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END as old_table_status,
            CASE WHEN nt.table_name IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END as new_table_status,
            CASE WHEN v.view_name IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END as view_status,
            CASE WHEN tr.trigger_name IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END as trigger_status
        FROM all_tables t
        LEFT JOIN all_tables ot ON t.owner = ot.owner AND ot.table_name = t.table_name || p_table_suffix
        LEFT JOIN all_tables nt ON t.owner = nt.owner AND nt.table_name = t.table_name || p_new_table_suffix
        LEFT JOIN all_views v ON t.owner = v.owner AND v.view_name = t.table_name
        LEFT JOIN all_triggers tr ON t.owner = tr.owner AND tr.trigger_name = 'TRG_' || t.table_name || '_MIGRATION_WRITABLE'
        WHERE t.owner = p_schema_name
        AND (ot.table_name IS NOT NULL OR nt.table_name IS NOT NULL)
        ORDER BY t.table_name;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('Migration Status for Schema: ' || p_schema_name);
    DBMS_OUTPUT.PUT_LINE('================================================');
    DBMS_OUTPUT.PUT_LINE('Base Table | OLD Table | NEW Table | View | Trigger');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------');
    
    FOR rec IN c_migration_status LOOP
        DBMS_OUTPUT.PUT_LINE(RPAD(rec.base_table, 12) || '| ' || 
                           RPAD(rec.old_table_status, 9) || '| ' || 
                           RPAD(rec.new_table_status, 9) || '| ' || 
                           RPAD(rec.view_status, 5) || '| ' || 
                           rec.trigger_status);
    END LOOP;
END;
/

-- ===================================================================
-- 5. CLEANUP MIGRATION VIEWS
-- ===================================================================

CREATE OR REPLACE PROCEDURE cleanup_migration_views(
    p_schema_name IN VARCHAR2 DEFAULT USER,
    p_table_suffix IN VARCHAR2 DEFAULT '_OLD',
    p_new_table_suffix IN VARCHAR2 DEFAULT '_NEW'
)
IS
    -- Cursor to get migration triggers
    CURSOR c_migration_triggers IS
        SELECT trigger_name
        FROM all_triggers
        WHERE owner = p_schema_name
        AND trigger_name LIKE 'TRG_%_MIGRATION_WRITABLE';
    
    -- Cursor to get migration views
    CURSOR c_migration_views IS
        SELECT view_name
        FROM all_views
        WHERE owner = p_schema_name
        AND view_name IN (
            SELECT SUBSTR(table_name, 1, LENGTH(table_name) - LENGTH(p_table_suffix))
            FROM all_tables
            WHERE owner = p_schema_name
            AND table_name LIKE '%' || p_table_suffix
        );
    
BEGIN
    -- Drop migration triggers
    FOR rec IN c_migration_triggers LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TRIGGER ' || p_schema_name || '.' || rec.trigger_name;
            DBMS_OUTPUT.PUT_LINE('Dropped trigger: ' || rec.trigger_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error dropping trigger ' || rec.trigger_name || ': ' || SQLERRM);
        END;
    END LOOP;
    
    -- Drop migration views
    FOR rec IN c_migration_views LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP VIEW ' || p_schema_name || '.' || rec.view_name;
            DBMS_OUTPUT.PUT_LINE('Dropped view: ' || rec.view_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error dropping view ' || rec.view_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- ===================================================================
-- 6. USAGE EXAMPLES
-- ===================================================================

/*
-- Example 1: Create migration writable view for single table
BEGIN
    DBMS_OUTPUT.PUT_LINE(create_migration_writable_view('EMPLOYEES', 'HR', '_OLD', '_NEW', TRUE));
END;
/

-- Example 2: Create all migration writable views
BEGIN
    create_all_migration_writable_views('HR', '_OLD', '_NEW', TRUE);
END;
/

-- Example 3: Check migration status
BEGIN
    check_migration_status('HR', '_OLD', '_NEW');
END;
/

-- Example 4: Cleanup migration views
BEGIN
    cleanup_migration_views('HR', '_OLD', '_NEW');
END;
/
*/

-- ===================================================================
-- 7. QUICK START INSTRUCTIONS
-- ===================================================================

PROMPT ===================================================================
PROMPT TABLE MIGRATION WRITABLE VIEW FRAMEWORK INSTALLED
PROMPT ===================================================================
PROMPT
PROMPT Usage Examples:
PROMPT 1. Create migration writable view for single table:
PROMPT    BEGIN DBMS_OUTPUT.PUT_LINE(create_migration_writable_view('TABLE_NAME', 'SCHEMA', '_OLD', '_NEW', TRUE)); END; /
PROMPT
PROMPT 2. Create all migration writable views:
PROMPT    BEGIN create_all_migration_writable_views('SCHEMA', '_OLD', '_NEW', TRUE); END; /
PROMPT
PROMPT 3. Check migration status:
PROMPT    BEGIN check_migration_status('SCHEMA', '_OLD', '_NEW'); END; /
PROMPT
PROMPT 4. Cleanup migration views:
PROMPT    BEGIN cleanup_migration_views('SCHEMA', '_OLD', '_NEW'); END; /
PROMPT
PROMPT ===================================================================

-- ===================================================================
-- END OF SCRIPT
-- ===================================================================
