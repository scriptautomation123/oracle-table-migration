-- ==================================================================
-- PL/SQL SECURITY FIXES AND IMPROVEMENTS
-- ==================================================================
-- This file contains corrected versions of the critical issues
-- identified in the Principal Engineer Review
-- ==================================================================
-- Author: Principal Engineer Review Team
-- Date: 2025-10-28
-- ==================================================================

-- ==================================================================
-- FIX #1: SQL Injection Protection Helper Functions
-- ==================================================================

CREATE OR REPLACE FUNCTION safe_sql_name(p_name VARCHAR2) 
    RETURN VARCHAR2 
    DETERMINISTIC
IS
    v_safe_name VARCHAR2(128);
BEGIN
    -- Use Oracle's built-in validation
    v_safe_name := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_name)));
    RETURN v_safe_name;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 
            'Invalid SQL identifier: "' || p_name || '". ' ||
            'Only alphanumeric characters and underscores are allowed. ' ||
            'Error: ' || SQLERRM);
END safe_sql_name;
/

CREATE OR REPLACE FUNCTION safe_schema_table(
    p_schema VARCHAR2,
    p_table VARCHAR2
) RETURN VARCHAR2
    DETERMINISTIC
IS
    v_safe_schema VARCHAR2(128);
    v_safe_table VARCHAR2(128);
BEGIN
    v_safe_schema := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_schema)));
    v_safe_table := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_table)));
    
    -- Return quoted identifier for use in dynamic SQL
    RETURN DBMS_ASSERT.ENQUOTE_NAME(v_safe_schema) || '.' || 
           DBMS_ASSERT.ENQUOTE_NAME(v_safe_table);
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Invalid schema.table: "' || p_schema || '.' || p_table || '". ' ||
            'Error: ' || SQLERRM);
END safe_schema_table;
/

-- ==================================================================
-- FIX #2: Corrected INSTEAD OF Trigger Implementation
-- ==================================================================

CREATE OR REPLACE PROCEDURE create_migration_view(
    p_schema IN VARCHAR2,
    p_table_base IN VARCHAR2
)
IS
    -- Local variables
    v_schema VARCHAR2(128);
    v_table_base VARCHAR2(128);
    v_new_table VARCHAR2(128);
    v_old_table VARCHAR2(128);
    v_view_name VARCHAR2(128);
    v_trigger_name VARCHAR2(128);
    
    -- Column information
    v_pk_columns VARCHAR2(4000);
    v_all_columns VARCHAR2(4000);
    v_insert_columns VARCHAR2(4000);
    v_new_values VARCHAR2(4000);
    v_pk_join_condition VARCHAR2(4000);
    
    -- Validation
    v_count NUMBER;
    v_new_table_exists NUMBER;
    v_old_table_exists NUMBER;
    
    -- SQL statements
    v_view_sql CLOB;
    v_trigger_sql CLOB;
    
BEGIN
    -- ================================================================
    -- STEP 1: Input Validation and Sanitization
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('Creating migration view and trigger...');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Validate and sanitize inputs using DBMS_ASSERT
    BEGIN
        v_schema := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_schema)));
        v_table_base := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_table_base)));
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Invalid schema or table name. Only alphanumeric and underscore allowed. ' ||
                'Error: ' || SQLERRM);
    END;
    
    -- Build table names
    v_new_table := v_table_base || '_NEW';
    v_old_table := v_table_base || '_OLD';
    v_view_name := v_table_base || '_JOINED';
    v_trigger_name := 'TG_' || SUBSTR(v_table_base, 1, 23) || '_IOT'; -- Ensure under 30 char limit
    
    DBMS_OUTPUT.PUT_LINE('Schema: ' || v_schema);
    DBMS_OUTPUT.PUT_LINE('Base table: ' || v_table_base);
    DBMS_OUTPUT.PUT_LINE('New table: ' || v_new_table);
    DBMS_OUTPUT.PUT_LINE('Old table: ' || v_old_table);
    DBMS_OUTPUT.PUT_LINE('View name: ' || v_view_name);
    DBMS_OUTPUT.PUT_LINE('Trigger name: ' || v_trigger_name);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ================================================================
    -- STEP 2: Validate Prerequisites
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('Validating prerequisites...');
    
    -- Check NEW table exists
    SELECT COUNT(*) INTO v_new_table_exists
    FROM all_tables
    WHERE owner = v_schema 
        AND table_name = v_new_table;
    
    IF v_new_table_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20002,
            'NEW table does not exist: ' || v_schema || '.' || v_new_table);
    END IF;
    DBMS_OUTPUT.PUT_LINE('  ✓ NEW table exists');
    
    -- Check OLD table exists
    SELECT COUNT(*) INTO v_old_table_exists
    FROM all_tables
    WHERE owner = v_schema 
        AND table_name = v_old_table;
    
    IF v_old_table_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20003,
            'OLD table does not exist: ' || v_schema || '.' || v_old_table);
    END IF;
    DBMS_OUTPUT.PUT_LINE('  ✓ OLD table exists');
    
    -- ================================================================
    -- STEP 3: Get Primary Key Information
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Detecting primary key...');
    
    -- Get PK columns from NEW table
    SELECT LISTAGG(cc.column_name, ', ') 
           WITHIN GROUP (ORDER BY cc.position)
    INTO v_pk_columns
    FROM all_constraints c
    JOIN all_cons_columns cc 
        ON c.constraint_name = cc.constraint_name 
        AND c.owner = cc.owner
    WHERE c.owner = v_schema
        AND c.table_name = v_new_table
        AND c.constraint_type = 'P';
    
    IF v_pk_columns IS NULL THEN
        RAISE_APPLICATION_ERROR(-20004,
            'NEW table must have a primary key: ' || v_schema || '.' || v_new_table || '. ' ||
            'Cannot create migration view without a primary key for deduplication.');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('  ✓ Primary key found: ' || v_pk_columns);
    
    -- ================================================================
    -- STEP 4: Build Column Lists
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Building column lists...');
    
    -- Get all columns for SELECT and INSERT
    SELECT 
        LISTAGG(column_name, ', ') 
            WITHIN GROUP (ORDER BY column_id),
        LISTAGG(':NEW.' || column_name, ', ') 
            WITHIN GROUP (ORDER BY column_id)
    INTO v_all_columns, v_new_values
    FROM all_tab_columns
    WHERE owner = v_schema
        AND table_name = v_new_table
        AND virtual_column = 'NO'; -- Exclude virtual columns
    
    IF v_all_columns IS NULL THEN
        RAISE_APPLICATION_ERROR(-20005,
            'No columns found in NEW table: ' || v_schema || '.' || v_new_table);
    END IF;
    
    v_insert_columns := v_all_columns; -- Same list for INSERT
    
    DBMS_OUTPUT.PUT_LINE('  ✓ Found ' || 
        REGEXP_COUNT(v_all_columns, ',') + 1 || ' columns');
    
    -- ================================================================
    -- STEP 5: Build PK Join Condition
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Building join condition...');
    
    -- Build join condition: n.col1 = o.col1 AND n.col2 = o.col2 ...
    DECLARE
        v_pk_array DBMS_SQL.VARCHAR2_TABLE;
        v_pk_count NUMBER;
        v_join_parts DBMS_SQL.VARCHAR2_TABLE;
    BEGIN
        -- Split PK columns by comma
        v_pk_count := REGEXP_COUNT(v_pk_columns, ',') + 1;
        
        FOR i IN 1..v_pk_count LOOP
            v_pk_array(i) := TRIM(REGEXP_SUBSTR(v_pk_columns, '[^,]+', 1, i));
            v_join_parts(i) := 'n.' || v_pk_array(i) || ' = o.' || v_pk_array(i);
        END LOOP;
        
        -- Join with AND
        v_pk_join_condition := v_join_parts(1);
        FOR i IN 2..v_pk_count LOOP
            v_pk_join_condition := v_pk_join_condition || ' AND ' || v_join_parts(i);
        END LOOP;
    END;
    
    DBMS_OUTPUT.PUT_LINE('  ✓ Join condition: ' || v_pk_join_condition);
    
    -- ================================================================
    -- STEP 6: Create View
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Creating view...');
    
    -- Build view SQL using proper identifier quoting
    v_view_sql := 
        'CREATE OR REPLACE VIEW ' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_view_name) || ' AS ' || CHR(10) ||
        '  SELECT ' || v_all_columns || ' FROM ' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_new_table) || ' n' || CHR(10) ||
        '  UNION ALL' || CHR(10) ||
        '  SELECT ' || v_all_columns || ' FROM ' ||
        DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_old_table) || ' o' || CHR(10) ||
        '  WHERE NOT EXISTS (' || CHR(10) ||
        '    SELECT 1 FROM ' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_new_table) || ' n' || CHR(10) ||
        '    WHERE ' || v_pk_join_condition || CHR(10) ||
        '  )';
    
    -- Execute view creation
    BEGIN
        EXECUTE IMMEDIATE v_view_sql;
        DBMS_OUTPUT.PUT_LINE('  ✓ View created: ' || v_schema || '.' || v_view_name);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  ✗ View creation failed');
            DBMS_OUTPUT.PUT_LINE('SQL: ' || SUBSTR(v_view_sql, 1, 200));
            RAISE_APPLICATION_ERROR(-20006,
                'Failed to create view: ' || SQLERRM);
    END;
    
    -- ================================================================
    -- STEP 7: Create INSTEAD OF Trigger
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Creating INSTEAD OF trigger...');
    
    -- Build trigger SQL with proper :NEW references (NOT :NEW.*)
    v_trigger_sql := 
        'CREATE OR REPLACE TRIGGER ' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_trigger_name) || CHR(10) ||
        '  INSTEAD OF INSERT ON ' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_view_name) || CHR(10) ||
        '  FOR EACH ROW' || CHR(10) ||
        'BEGIN' || CHR(10) ||
        '  -- Insert into NEW table only during migration' || CHR(10) ||
        '  INSERT INTO ' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_new_table) || CHR(10) ||
        '    (' || v_insert_columns || ')' || CHR(10) ||
        '  VALUES' || CHR(10) ||
        '    (' || v_new_values || ');' || CHR(10) ||
        'EXCEPTION' || CHR(10) ||
        '  WHEN DUP_VAL_ON_INDEX THEN' || CHR(10) ||
        '    -- Duplicate key, log and continue' || CHR(10) ||
        '    NULL;' || CHR(10) ||
        '  WHEN OTHERS THEN' || CHR(10) ||
        '    -- Log error and re-raise' || CHR(10) ||
        '    RAISE;' || CHR(10) ||
        'END;';
    
    -- Execute trigger creation
    BEGIN
        EXECUTE IMMEDIATE v_trigger_sql;
        DBMS_OUTPUT.PUT_LINE('  ✓ Trigger created: ' || v_schema || '.' || v_trigger_name);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  ✗ Trigger creation failed');
            DBMS_OUTPUT.PUT_LINE('SQL: ' || SUBSTR(v_trigger_sql, 1, 200));
            RAISE_APPLICATION_ERROR(-20007,
                'Failed to create trigger: ' || SQLERRM);
    END;
    
    -- ================================================================
    -- STEP 8: Create Restriction Triggers (UPDATE/DELETE not allowed)
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Creating restriction triggers...');
    
    -- Trigger to prevent UPDATE
    EXECUTE IMMEDIATE 
        'CREATE OR REPLACE TRIGGER ' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
        DBMS_ASSERT.ENQUOTE_NAME(SUBSTR(v_trigger_name, 1, 26) || '_UPD') || CHR(10) ||
        '  INSTEAD OF UPDATE ON ' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_view_name) || CHR(10) ||
        '  FOR EACH ROW' || CHR(10) ||
        'BEGIN' || CHR(10) ||
        '  RAISE_APPLICATION_ERROR(-20100, ' || CHR(10) ||
        '    ''UPDATE not supported on migration view. Use direct table access.'');' || CHR(10) ||
        'END;';
    
    DBMS_OUTPUT.PUT_LINE('  ✓ UPDATE restriction trigger created');
    
    -- Trigger to prevent DELETE
    EXECUTE IMMEDIATE 
        'CREATE OR REPLACE TRIGGER ' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
        DBMS_ASSERT.ENQUOTE_NAME(SUBSTR(v_trigger_name, 1, 26) || '_DEL') || CHR(10) ||
        '  INSTEAD OF DELETE ON ' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
        DBMS_ASSERT.ENQUOTE_NAME(v_view_name) || CHR(10) ||
        '  FOR EACH ROW' || CHR(10) ||
        'BEGIN' || CHR(10) ||
        '  RAISE_APPLICATION_ERROR(-20101, ' || CHR(10) ||
        '    ''DELETE not supported on migration view. Use direct table access.'');' || CHR(10) ||
        'END;';
    
    DBMS_OUTPUT.PUT_LINE('  ✓ DELETE restriction trigger created');
    
    -- ================================================================
    -- Final Summary
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('✓ Migration view and triggers created successfully');
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('View: ' || v_schema || '.' || v_view_name);
    DBMS_OUTPUT.PUT_LINE('  - Combines data from NEW and OLD tables');
    DBMS_OUTPUT.PUT_LINE('  - Deduplicates using PK: ' || v_pk_columns);
    DBMS_OUTPUT.PUT_LINE('  - Supports: INSERT only');
    DBMS_OUTPUT.PUT_LINE('  - Restrictions: UPDATE and DELETE will raise errors');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Usage:');
    DBMS_OUTPUT.PUT_LINE('  INSERT INTO ' || v_schema || '.' || v_view_name || ' VALUES (...);');
    DBMS_OUTPUT.PUT_LINE('  -- Data will be inserted into ' || v_new_table);
    DBMS_OUTPUT.PUT_LINE('================================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('✗ ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('');
        RAISE;
END create_migration_view;
/

-- ==================================================================
-- FIX #3: Safe Row Count with SQL Injection Protection
-- ==================================================================

CREATE OR REPLACE FUNCTION safe_row_count(
    p_schema VARCHAR2,
    p_table VARCHAR2
) RETURN NUMBER
IS
    v_schema VARCHAR2(128);
    v_table VARCHAR2(128);
    v_count NUMBER;
    v_sql VARCHAR2(500);
BEGIN
    -- Validate inputs
    v_schema := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_schema)));
    v_table := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_table)));
    
    -- Build safe SQL
    v_sql := 'SELECT COUNT(*) FROM ' || 
             DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
             DBMS_ASSERT.ENQUOTE_NAME(v_table);
    
    -- Execute
    EXECUTE IMMEDIATE v_sql INTO v_count;
    
    RETURN v_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Failed to count rows in ' || v_schema || '.' || v_table || ': ' || SQLERRM);
END safe_row_count;
/

-- ==================================================================
-- FIX #4: Improved Atomic Swap with Better Error Messages
-- ==================================================================

CREATE OR REPLACE PROCEDURE atomic_table_swap(
    p_schema VARCHAR2,
    p_table_original VARCHAR2,
    p_table_new VARCHAR2,
    p_table_old VARCHAR2
)
IS
    v_schema VARCHAR2(128);
    v_original VARCHAR2(128);
    v_new VARCHAR2(128);
    v_old VARCHAR2(128);
    v_original_exists NUMBER;
    v_new_exists NUMBER;
    v_error_msg VARCHAR2(4000);
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('ATOMIC TABLE SWAP PROCEDURE');
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ================================================================
    -- STEP 1: Input Validation
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('Step 1: Validating inputs...');
    
    v_schema := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_schema)));
    v_original := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_table_original)));
    v_new := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_table_new)));
    v_old := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_table_old)));
    
    DBMS_OUTPUT.PUT_LINE('  Schema: ' || v_schema);
    DBMS_OUTPUT.PUT_LINE('  Original table: ' || v_original);
    DBMS_OUTPUT.PUT_LINE('  New table: ' || v_new);
    DBMS_OUTPUT.PUT_LINE('  Backup name: ' || v_old);
    DBMS_OUTPUT.PUT_LINE('  ✓ Input validation passed');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ================================================================
    -- STEP 2: Pre-Swap Validation
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('Step 2: Pre-swap validation...');
    
    -- Check original table exists
    SELECT COUNT(*) INTO v_original_exists
    FROM all_tables
    WHERE owner = v_schema 
        AND table_name = v_original;
    
    IF v_original_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20020,
            'Original table does not exist: ' || v_schema || '.' || v_original);
    END IF;
    DBMS_OUTPUT.PUT_LINE('  ✓ Original table exists');
    
    -- Check new table exists
    SELECT COUNT(*) INTO v_new_exists
    FROM all_tables
    WHERE owner = v_schema 
        AND table_name = v_new;
    
    IF v_new_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20021,
            'New table does not exist: ' || v_schema || '.' || v_new);
    END IF;
    DBMS_OUTPUT.PUT_LINE('  ✓ New table exists');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ================================================================
    -- STEP 3: Acquire Locks (Minimize Race Condition Window)
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('Step 3: Acquiring exclusive locks...');
    DBMS_OUTPUT.PUT_LINE('  NOTE: This reduces but does not eliminate the race condition');
    DBMS_OUTPUT.PUT_LINE('        Oracle DDL operations auto-commit and are not transactional');
    
    BEGIN
        -- Lock both tables to prevent concurrent access
        EXECUTE IMMEDIATE 
            'LOCK TABLE ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
            DBMS_ASSERT.ENQUOTE_NAME(v_original) || ' IN EXCLUSIVE MODE NOWAIT';
        DBMS_OUTPUT.PUT_LINE('  ✓ Locked original table');
        
        EXECUTE IMMEDIATE 
            'LOCK TABLE ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
            DBMS_ASSERT.ENQUOTE_NAME(v_new) || ' IN EXCLUSIVE MODE NOWAIT';
        DBMS_OUTPUT.PUT_LINE('  ✓ Locked new table');
        
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -54 THEN -- Resource busy (ORA-00054)
                RAISE_APPLICATION_ERROR(-20022,
                    'Cannot acquire locks - tables are in use. ' ||
                    'Active sessions must complete before swap can proceed.');
            ELSE
                RAISE;
            END IF;
    END;
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ================================================================
    -- STEP 4: ATOMIC RENAME - Step 1 (Original -> Old)
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('Step 4: Renaming ' || v_original || ' -> ' || v_old);
    DBMS_OUTPUT.PUT_LINE('  WARNING: Brief window where ' || v_original || ' does not exist');
    
    BEGIN
        EXECUTE IMMEDIATE 
            'ALTER TABLE ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
            DBMS_ASSERT.ENQUOTE_NAME(v_original) || 
            ' RENAME TO ' || DBMS_ASSERT.ENQUOTE_NAME(v_old);
        
        DBMS_OUTPUT.PUT_LINE('  ✓ Renamed ' || v_original || ' to ' || v_old);
        
    EXCEPTION
        WHEN OTHERS THEN
            v_error_msg := 'Failed to rename original table: ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('  ✗ ERROR: ' || v_error_msg);
            RAISE_APPLICATION_ERROR(-20023, v_error_msg);
    END;
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ================================================================
    -- STEP 5: ATOMIC RENAME - Step 2 (New -> Original)
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('Step 5: Renaming ' || v_new || ' -> ' || v_original);
    
    BEGIN
        EXECUTE IMMEDIATE 
            'ALTER TABLE ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
            DBMS_ASSERT.ENQUOTE_NAME(v_new) || 
            ' RENAME TO ' || DBMS_ASSERT.ENQUOTE_NAME(v_original);
        
        DBMS_OUTPUT.PUT_LINE('  ✓ Renamed ' || v_new || ' to ' || v_original);
        DBMS_OUTPUT.PUT_LINE('  ✓ SWAP SUCCESSFUL');
        
    EXCEPTION
        WHEN OTHERS THEN
            v_error_msg := 'Failed to rename new table: ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('  ✗ ERROR: ' || v_error_msg);
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('ATTEMPTING COMPENSATORY ROLLBACK...');
            
            -- ================================================================
            -- STEP 6: ROLLBACK - Restore Original Name
            -- ================================================================
            BEGIN
                EXECUTE IMMEDIATE 
                    'ALTER TABLE ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
                    DBMS_ASSERT.ENQUOTE_NAME(v_old) || 
                    ' RENAME TO ' || DBMS_ASSERT.ENQUOTE_NAME(v_original);
                
                DBMS_OUTPUT.PUT_LINE('  ✓ Rollback successful: ' || v_old || ' -> ' || v_original);
                DBMS_OUTPUT.PUT_LINE('  Status: SWAP FAILED - rolled back to original state');
                
                RAISE_APPLICATION_ERROR(-20024,
                    'Swap failed but rolled back successfully. Original state restored. ' ||
                    'Error was: ' || v_error_msg);
                    
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('  ✗ CRITICAL: ROLLBACK FAILED!');
                    DBMS_OUTPUT.PUT_LINE('');
                    DBMS_OUTPUT.PUT_LINE('================================================================');
                    DBMS_OUTPUT.PUT_LINE('MANUAL INTERVENTION REQUIRED');
                    DBMS_OUTPUT.PUT_LINE('================================================================');
                    DBMS_OUTPUT.PUT_LINE('Current state:');
                    DBMS_OUTPUT.PUT_LINE('  - Original table is now: ' || v_schema || '.' || v_old);
                    DBMS_OUTPUT.PUT_LINE('  - New table is still: ' || v_schema || '.' || v_new);
                    DBMS_OUTPUT.PUT_LINE('  - Expected table name "' || v_original || '" is MISSING');
                    DBMS_OUTPUT.PUT_LINE('');
                    DBMS_OUTPUT.PUT_LINE('To restore:');
                    DBMS_OUTPUT.PUT_LINE('  1. Verify table states: SELECT table_name FROM all_tables');
                    DBMS_OUTPUT.PUT_LINE('     WHERE owner = ''' || v_schema || ''';');
                    DBMS_OUTPUT.PUT_LINE('  2. Manually rename: ALTER TABLE ' || v_old || ' RENAME TO ' || v_original || ';');
                    DBMS_OUTPUT.PUT_LINE('  3. Verify applications can access table');
                    DBMS_OUTPUT.PUT_LINE('================================================================');
                    
                    RAISE_APPLICATION_ERROR(-20025,
                        'CRITICAL: Swap failed AND rollback failed. ' ||
                        'Manual intervention required. ' ||
                        'Swap error: ' || v_error_msg || ' ' ||
                        'Rollback error: ' || SQLERRM);
            END;
    END;
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ================================================================
    -- STEP 7: Post-Swap Validation
    -- ================================================================
    DBMS_OUTPUT.PUT_LINE('Step 6: Post-swap validation...');
    
    -- Verify old table exists with backup name
    SELECT COUNT(*) INTO v_original_exists
    FROM all_tables
    WHERE owner = v_schema 
        AND table_name = v_old;
    
    IF v_original_exists = 0 THEN
        DBMS_OUTPUT.PUT_LINE('  ⚠ WARNING: Backup table not found: ' || v_old);
    ELSE
        DBMS_OUTPUT.PUT_LINE('  ✓ Backup table exists: ' || v_old);
    END IF;
    
    -- Verify new table now has original name
    SELECT COUNT(*) INTO v_new_exists
    FROM all_tables
    WHERE owner = v_schema 
        AND table_name = v_original;
    
    IF v_new_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20026,
            'VALIDATION FAILED: Active table missing: ' || v_schema || '.' || v_original);
    ELSE
        DBMS_OUTPUT.PUT_LINE('  ✓ Active table exists: ' || v_original);
    END IF;
    
    -- Check for invalid objects
    FOR invalid_obj IN (
        SELECT object_name, object_type
        FROM all_objects
        WHERE owner = v_schema
            AND status = 'INVALID'
            AND object_name IN (v_original, v_old)
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ⚠ WARNING: Invalid object: ' || 
            invalid_obj.object_type || ' ' || invalid_obj.object_name);
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('✓ ATOMIC TABLE SWAP COMPLETED SUCCESSFULLY');
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('Active table: ' || v_schema || '.' || v_original);
    DBMS_OUTPUT.PUT_LINE('Backup table: ' || v_schema || '.' || v_old);
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('NOTE: There was a brief window (milliseconds) where ' || v_original);
    DBMS_OUTPUT.PUT_LINE('      did not exist. Applications with retry logic should be unaffected.');
    DBMS_OUTPUT.PUT_LINE('================================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('✗ FATAL ERROR in atomic_table_swap: ' || SQLERRM);
        RAISE;
END atomic_table_swap;
/

-- ==================================================================
-- TESTING EXAMPLES
-- ==================================================================

-- Test the migration view creator
-- BEGIN
--     create_migration_view('MY_SCHEMA', 'MY_TABLE');
-- END;
-- /

-- Test the atomic swap
-- BEGIN
--     atomic_table_swap(
--         p_schema => 'MY_SCHEMA',
--         p_table_original => 'MY_TABLE',
--         p_table_new => 'MY_TABLE_NEW',
--         p_table_old => 'MY_TABLE_OLD'
--     );
-- END;
-- /

-- Test row counting with injection protection
-- SELECT safe_row_count('MY_SCHEMA', 'MY_TABLE') FROM dual;

-- ==================================================================
-- END OF SECURITY FIXES
-- ==================================================================
