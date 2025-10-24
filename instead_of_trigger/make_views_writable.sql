-- ===================================================================
-- Generic View Writable Solution
-- ===================================================================
-- Purpose: Make Oracle views writable using INSTEAD OF triggers
-- Usage: Run this script to create a generic framework for writable views
-- ===================================================================

SET ECHO ON
SET SERVEROUTPUT ON

-- ===================================================================
-- 1. CREATE GENERIC WRITABLE VIEW FUNCTION
-- ===================================================================

CREATE OR REPLACE FUNCTION make_view_writable(
    p_view_name IN VARCHAR2,
    p_base_table IN VARCHAR2,
    p_view_owner IN VARCHAR2 DEFAULT USER,
    p_base_owner IN VARCHAR2 DEFAULT USER
) RETURN VARCHAR2
IS
    v_sql VARCHAR2(4000);
    v_trigger_name VARCHAR2(128);
    v_view_columns VARCHAR2(4000);
    v_base_columns VARCHAR2(4000);
    v_column_list VARCHAR2(4000);
    v_column_values VARCHAR2(4000);
    v_column_updates VARCHAR2(4000);
    v_where_clause VARCHAR2(4000);
    
    -- Cursor to get view columns
    CURSOR c_view_columns IS
        SELECT column_name, data_type
        FROM all_tab_columns
        WHERE owner = p_view_owner
        AND table_name = p_view_name
        ORDER BY column_id;
    
    -- Cursor to get base table columns
    CURSOR c_base_columns IS
        SELECT column_name, data_type
        FROM all_tab_columns
        WHERE owner = p_base_owner
        AND table_name = p_base_table
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
    
    -- Build WHERE clause for UPDATE/DELETE
    FOR rec IN c_base_columns LOOP
        IF v_where_clause IS NULL THEN
            v_where_clause := rec.column_name || ' = :OLD.' || rec.column_name;
        ELSE
            v_where_clause := v_where_clause || ' AND ' || rec.column_name || ' = :OLD.' || rec.column_name;
        END IF;
    END LOOP;
    
    -- Create trigger name
    v_trigger_name := 'TRG_' || p_view_name || '_WRITABLE';
    
    -- Build trigger SQL
    v_sql := '
CREATE OR REPLACE TRIGGER ' || v_trigger_name || '
INSTEAD OF INSERT OR UPDATE OR DELETE ON ' || p_view_owner || '.' || p_view_name || '
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO ' || p_base_owner || '.' || p_base_table || ' (' || v_column_list || ')
        VALUES (' || v_column_values || ');
    ELSIF UPDATING THEN
        UPDATE ' || p_base_owner || '.' || p_base_table || '
        SET ' || v_column_updates || '
        WHERE ' || v_where_clause || ';
    ELSIF DELETING THEN
        DELETE FROM ' || p_base_owner || '.' || p_base_table || '
        WHERE ' || v_where_clause || ';
    END IF;
END;';
    
    -- Execute the trigger creation
    EXECUTE IMMEDIATE v_sql;
    
    RETURN 'SUCCESS: Created writable view trigger ' || v_trigger_name;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END;
/

-- ===================================================================
-- 2. CREATE GENERIC WRITABLE VIEW PROCEDURE
-- ===================================================================

CREATE OR REPLACE PROCEDURE create_writable_view(
    p_view_name IN VARCHAR2,
    p_base_table IN VARCHAR2,
    p_view_owner IN VARCHAR2 DEFAULT USER,
    p_base_owner IN VARCHAR2 DEFAULT USER,
    p_drop_existing IN BOOLEAN DEFAULT TRUE
)
IS
    v_result VARCHAR2(4000);
    v_trigger_name VARCHAR2(128);
BEGIN
    -- Drop existing trigger if requested
    IF p_drop_existing THEN
        v_trigger_name := 'TRG_' || p_view_name || '_WRITABLE';
        BEGIN
            EXECUTE IMMEDIATE 'DROP TRIGGER ' || v_trigger_name;
            DBMS_OUTPUT.PUT_LINE('Dropped existing trigger: ' || v_trigger_name);
        EXCEPTION
            WHEN OTHERS THEN
                NULL; -- Trigger doesn't exist, continue
        END;
    END IF;
    
    -- Create writable view
    v_result := make_view_writable(p_view_name, p_base_table, p_view_owner, p_base_owner);
    DBMS_OUTPUT.PUT_LINE(v_result);
    
END;
/

-- ===================================================================
-- 3. CREATE BATCH WRITABLE VIEWS PROCEDURE
-- ===================================================================

CREATE OR REPLACE PROCEDURE make_all_views_writable(
    p_schema_name IN VARCHAR2 DEFAULT USER,
    p_base_table_prefix IN VARCHAR2 DEFAULT NULL
)
IS
    -- Cursor to get all views in schema
    CURSOR c_views IS
        SELECT view_name, view_definition
        FROM all_views
        WHERE owner = p_schema_name
        AND (p_base_table_prefix IS NULL OR view_name LIKE p_base_table_prefix || '%');
    
    v_result VARCHAR2(4000);
    v_base_table VARCHAR2(128);
BEGIN
    FOR rec IN c_views LOOP
        -- Extract base table name from view definition
        -- This is a simple extraction - you may need to enhance based on your view patterns
        v_base_table := extract_base_table(rec.view_definition);
        
        IF v_base_table IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('Processing view: ' || rec.view_name);
            v_result := make_view_writable(rec.view_name, v_base_table, p_schema_name, p_schema_name);
            DBMS_OUTPUT.PUT_LINE(v_result);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Could not determine base table for view: ' || rec.view_name);
        END IF;
    END LOOP;
END;
/

-- ===================================================================
-- 4. HELPER FUNCTION TO EXTRACT BASE TABLE NAME
-- ===================================================================

CREATE OR REPLACE FUNCTION extract_base_table(p_view_definition IN CLOB)
RETURN VARCHAR2
IS
    v_definition VARCHAR2(4000);
    v_base_table VARCHAR2(128);
    v_start_pos NUMBER;
    v_end_pos NUMBER;
BEGIN
    -- Convert CLOB to VARCHAR2 (first 4000 chars)
    v_definition := SUBSTR(p_view_definition, 1, 4000);
    
    -- Convert to uppercase for parsing
    v_definition := UPPER(v_definition);
    
    -- Look for FROM clause
    v_start_pos := INSTR(v_definition, 'FROM ');
    IF v_start_pos > 0 THEN
        v_start_pos := v_start_pos + 5; -- Skip 'FROM '
        
        -- Find end of table name (space, comma, or WHERE)
        v_end_pos := v_start_pos;
        WHILE v_end_pos <= LENGTH(v_definition) AND 
              SUBSTR(v_definition, v_end_pos, 1) NOT IN (' ', ',', 'W', 'J', 'U', 'G', 'H', 'O') LOOP
            v_end_pos := v_end_pos + 1;
        END LOOP;
        
        -- Extract table name
        v_base_table := SUBSTR(v_definition, v_start_pos, v_end_pos - v_start_pos);
        
        -- Remove any schema prefix
        IF INSTR(v_base_table, '.') > 0 THEN
            v_base_table := SUBSTR(v_base_table, INSTR(v_base_table, '.') + 1);
        END IF;
        
        RETURN v_base_table;
    END IF;
    
    RETURN NULL;
END;
/

-- ===================================================================
-- 5. USAGE EXAMPLES
-- ===================================================================

/*
-- Example 1: Make a single view writable
BEGIN
    create_writable_view('MY_VIEW', 'MY_TABLE');
END;
/

-- Example 2: Make a view writable with specific owners
BEGIN
    create_writable_view('HR_VIEW', 'HR_TABLE', 'HR_SCHEMA', 'HR_SCHEMA');
END;
/

-- Example 3: Make all views in a schema writable
BEGIN
    make_all_views_writable('HR_SCHEMA');
END;
/

-- Example 4: Make views with specific prefix writable
BEGIN
    make_all_views_writable('HR_SCHEMA', 'V_');
END;
/
*/

-- ===================================================================
-- 6. CLEANUP PROCEDURE
-- ===================================================================

CREATE OR REPLACE PROCEDURE drop_writable_triggers(
    p_schema_name IN VARCHAR2 DEFAULT USER,
    p_trigger_prefix IN VARCHAR2 DEFAULT 'TRG_'
)
IS
    -- Cursor to get all writable triggers
    CURSOR c_triggers IS
        SELECT trigger_name
        FROM all_triggers
        WHERE owner = p_schema_name
        AND trigger_name LIKE p_trigger_prefix || '%_WRITABLE';
    
BEGIN
    FOR rec IN c_triggers LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TRIGGER ' || p_schema_name || '.' || rec.trigger_name;
            DBMS_OUTPUT.PUT_LINE('Dropped trigger: ' || rec.trigger_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error dropping trigger ' || rec.trigger_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- ===================================================================
-- 7. STATUS CHECK PROCEDURE
-- ===================================================================

CREATE OR REPLACE PROCEDURE check_writable_views_status(
    p_schema_name IN VARCHAR2 DEFAULT USER
)
IS
    -- Cursor to check writable view status
    CURSOR c_views IS
        SELECT v.view_name, t.trigger_name
        FROM all_views v
        LEFT JOIN all_triggers t ON v.view_name = SUBSTR(t.trigger_name, 5, LENGTH(t.trigger_name) - 14)
        WHERE v.owner = p_schema_name
        AND (t.trigger_name IS NULL OR t.trigger_name LIKE 'TRG_' || v.view_name || '_WRITABLE');
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('Writable Views Status for Schema: ' || p_schema_name);
    DBMS_OUTPUT.PUT_LINE('================================================');
    
    FOR rec IN c_views LOOP
        IF rec.trigger_name IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('✓ ' || rec.view_name || ' - WRITABLE');
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ ' || rec.view_name || ' - READ-ONLY');
        END IF;
    END LOOP;
END;
/

-- ===================================================================
-- 8. QUICK START INSTRUCTIONS
-- ===================================================================

PROMPT ===================================================================
PROMPT WRITABLE VIEWS FRAMEWORK INSTALLED
PROMPT ===================================================================
PROMPT
PROMPT Usage Examples:
PROMPT 1. Make single view writable:
PROMPT    BEGIN create_writable_view('MY_VIEW', 'MY_TABLE'); END; /
PROMPT
PROMPT 2. Make all views writable:
PROMPT    BEGIN make_all_views_writable('SCHEMA_NAME'); END; /
PROMPT
PROMPT 3. Check status:
PROMPT    BEGIN check_writable_views_status('SCHEMA_NAME'); END; /
PROMPT
PROMPT 4. Cleanup triggers:
PROMPT    BEGIN drop_writable_triggers('SCHEMA_NAME'); END; /
PROMPT
PROMPT ===================================================================

-- ===================================================================
-- END OF SCRIPT
-- ===================================================================
