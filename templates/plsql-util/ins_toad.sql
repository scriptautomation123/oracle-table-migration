-- ==================================================================
-- INSTEAD OF VIEW AND TRIGGER GENERATOR - OPTIMIZED VERSION 2.0
-- ==================================================================
-- Purpose: Generate DDL for migration views with INSTEAD OF triggers
-- Version: 2.0
-- Date: 2025-01-29
-- Compatible: Oracle 11g+ and Toad
-- ==================================================================
-- Usage: Run directly in Toad (F5) or SQL*Plus
-- Features:
--   - Uses only ALL_* views (no DBA privileges required)
--   - Single efficient query for metadata collection
--   - Smart column and PK handling
--   - Generates SQL only (no execution)
--   - Ready to copy/paste output
-- ==================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF
SET PAGESIZE 0
SET LINESIZE 300
SET FEEDBACK OFF
SET HEADING OFF
SET TRIMSPOOL ON

DECLARE
    -- ==================================================================
    -- CONFIGURATION - MODIFY THESE VALUES
    -- ==================================================================
    c_schema          CONSTANT VARCHAR2(128) := 'HR';           -- Your schema name
    c_base_table      CONSTANT VARCHAR2(128) := 'EMPLOYEES';    -- Base table name
    c_new_suffix      CONSTANT VARCHAR2(10)  := '_NEW';         -- New table suffix
    c_old_suffix      CONSTANT VARCHAR2(10)  := '_OLD';         -- Old table suffix
    c_view_suffix     CONSTANT VARCHAR2(10)  := '_JOINED';      -- View suffix
    
    -- ==================================================================
    -- CONSTANTS - DO NOT MODIFY
    -- ==================================================================
    c_max_len         CONSTANT PLS_INTEGER := 30;  -- Oracle name limit
    c_version         CONSTANT VARCHAR2(10) := '2.0';
    c_separator       CONSTANT VARCHAR2(70) := LPAD('=', 70, '=');
    
    -- Table and object names
    v_new_table       VARCHAR2(128);
    v_old_table       VARCHAR2(128);
    v_view_name       VARCHAR2(128);
    v_ins_trigger     VARCHAR2(128);
    v_upd_trigger     VARCHAR2(128);
    v_del_trigger     VARCHAR2(128);
    
    -- Column and constraint info
    v_pk_columns      VARCHAR2(4000);
    v_all_columns     VARCHAR2(32767);
    v_new_values      VARCHAR2(32767);
    v_pk_join         VARCHAR2(4000);
    v_update_sets     VARCHAR2(32767);
    
    -- Validation counters
    v_new_exists      NUMBER := 0;
    v_old_exists      NUMBER := 0;
    v_pk_count        NUMBER := 0;
    v_col_count       NUMBER := 0;
    v_col_match       NUMBER := 0;
    
    -- Working variables
    v_timestamp       VARCHAR2(30) := TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS');
    v_has_lobs        NUMBER := 0;
    v_has_virtual     NUMBER := 0;
    
    -- Type for column processing
    TYPE t_column IS RECORD (
        column_name   VARCHAR2(128),
        data_type     VARCHAR2(128),
        nullable      VARCHAR2(1)
    );
    TYPE t_columns IS TABLE OF t_column INDEX BY PLS_INTEGER;
    v_cols t_columns;
    
    -- ==================================================================
    -- HELPER PROCEDURES
    -- ==================================================================
    
    -- Print line with optional comment
    PROCEDURE p(p_text VARCHAR2 DEFAULT '', p_as_comment BOOLEAN DEFAULT FALSE) IS
    BEGIN
        IF p_as_comment AND p_text IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('-- ' || p_text);
        ELSE
            DBMS_OUTPUT.PUT_LINE(p_text);
        END IF;
    END p;
    
    -- Print section header
    PROCEDURE header(p_title VARCHAR2) IS
    BEGIN
        p(c_separator, TRUE);
        p(p_title, TRUE);
        p(c_separator, TRUE);
    END header;
    
    -- Clean and validate name
    FUNCTION clean_name(p_name VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN DBMS_ASSERT.SIMPLE_SQL_NAME(p_name);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'Invalid name: ' || p_name);
    END clean_name;
    
    -- Build qualified name
    FUNCTION qualified_name(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN p_schema || '.' || p_object;
    END qualified_name;
    
    -- Truncate name if needed
    FUNCTION fit_name(p_name VARCHAR2, p_max_len NUMBER DEFAULT c_max_len) RETURN VARCHAR2 IS
    BEGIN
        IF LENGTH(p_name) <= p_max_len THEN
            RETURN p_name;
        ELSE
            RETURN SUBSTR(p_name, 1, p_max_len);
        END IF;
    END fit_name;
    
BEGIN
    -- ==================================================================
    -- INITIALIZATION
    -- ==================================================================
    
    header('INSTEAD OF VIEW AND TRIGGER GENERATOR v' || c_version);
    p('Generated: ' || v_timestamp, TRUE);
    p('User: ' || USER, TRUE);
    p();
    
    -- Build object names
    v_new_table   := c_base_table || c_new_suffix;
    v_old_table   := c_base_table || c_old_suffix;
    v_view_name   := c_base_table || c_view_suffix;
    v_ins_trigger := fit_name('TG_' || c_base_table || '_INS', c_max_len);
    v_upd_trigger := fit_name('TG_' || c_base_table || '_UPD', c_max_len);
    v_del_trigger := fit_name('TG_' || c_base_table || '_DEL', c_max_len);
    
    -- Validate inputs
    BEGIN
        v_new_table := clean_name(v_new_table);
        v_old_table := clean_name(v_old_table);
        v_view_name := clean_name(v_view_name);
        
        -- Validate schema
        DECLARE
            v_temp VARCHAR2(128);
        BEGIN
            v_temp := DBMS_ASSERT.SCHEMA_NAME(c_schema);
        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20002, 'Schema not found: ' || c_schema);
        END;
    END;
    
    p('Configuration:', TRUE);
    p('  Schema: ' || c_schema, TRUE);
    p('  Base Table: ' || c_base_table, TRUE);
    p('  New Table: ' || v_new_table, TRUE);
    p('  Old Table: ' || v_old_table, TRUE);
    p('  View Name: ' || v_view_name, TRUE);
    p();
    
    -- ==================================================================
    -- VALIDATION
    -- ==================================================================
    
    -- Check NEW table exists
    SELECT COUNT(*) INTO v_new_exists
    FROM all_tables
    WHERE owner = c_schema 
      AND table_name = v_new_table;
    
    IF v_new_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'NEW table not found: ' || qualified_name(c_schema, v_new_table));
    END IF;
    
    -- Check OLD table exists
    SELECT COUNT(*) INTO v_old_exists
    FROM all_tables
    WHERE owner = c_schema 
      AND table_name = v_old_table;
    
    IF v_old_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'OLD table not found: ' || qualified_name(c_schema, v_old_table));
    END IF;
    
    p('✓ Both tables exist', TRUE);
    
    -- Check for primary key
    SELECT COUNT(*) INTO v_pk_count
    FROM all_constraints
    WHERE owner = c_schema
      AND table_name = v_new_table
      AND constraint_type = 'P';
    
    IF v_pk_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 
            'NEW table must have a primary key for deduplication: ' || qualified_name(c_schema, v_new_table));
    END IF;
    
    -- ==================================================================
    -- COLLECT METADATA (SINGLE EFFICIENT QUERY)
    -- ==================================================================
    
    -- Get PK columns
    SELECT LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY position)
    INTO v_pk_columns
    FROM all_cons_columns
    WHERE owner = c_schema
      AND table_name = v_new_table
      AND constraint_name = (
          SELECT constraint_name 
          FROM all_constraints 
          WHERE owner = c_schema 
            AND table_name = v_new_table 
            AND constraint_type = 'P'
      );
    
    p('✓ Primary key found: ' || v_pk_columns, TRUE);
    
    -- Get all columns and build lists
    DECLARE
        v_idx NUMBER := 0;
        v_first BOOLEAN := TRUE;
    BEGIN
        -- Reset strings
        v_all_columns := '';
        v_new_values := '';
        v_update_sets := '';
        
        -- Collect columns
        FOR rec IN (
            SELECT column_name, 
                   data_type,
                   nullable,
                   virtual_column,
                   column_id
            FROM all_tab_columns
            WHERE owner = c_schema
              AND table_name = v_new_table
              AND virtual_column = 'NO'
            ORDER BY column_id
        ) LOOP
            v_idx := v_idx + 1;
            v_cols(v_idx).column_name := rec.column_name;
            v_cols(v_idx).data_type := rec.data_type;
            v_cols(v_idx).nullable := rec.nullable;
            
            -- Build column lists
            IF NOT v_first THEN
                v_all_columns := v_all_columns || ', ';
                v_new_values := v_new_values || ', ';
                v_update_sets := v_update_sets || ',' || CHR(10) || '    ';
            END IF;
            
            v_all_columns := v_all_columns || rec.column_name;
            v_new_values := v_new_values || ':NEW.' || rec.column_name;
            
            -- Build UPDATE SET clause (skip PK columns)
            IF INSTR(',' || v_pk_columns || ',', ',' || rec.column_name || ',') = 0 THEN
                v_update_sets := v_update_sets || rec.column_name || ' = :NEW.' || rec.column_name;
            END IF;
            
            v_first := FALSE;
            v_col_count := v_col_count + 1;
        END LOOP;
    END;
    
    p('✓ Found ' || v_col_count || ' columns', TRUE);
    
    -- Check for special column types
    SELECT COUNT(*) INTO v_has_lobs
    FROM all_tab_columns
    WHERE owner = c_schema
      AND table_name = v_new_table
      AND data_type IN ('CLOB', 'BLOB', 'NCLOB', 'BFILE');
    
    IF v_has_lobs > 0 THEN
        p('⚠ Table contains LOB columns - special handling may be required', TRUE);
    END IF;
    
    -- Build PK join condition
    DECLARE
        v_pk_col VARCHAR2(128);
        v_pos NUMBER := 1;
        v_first BOOLEAN := TRUE;
    BEGIN
        v_pk_join := '';
        v_pk_where := '';
        
        LOOP
            v_pk_col := REGEXP_SUBSTR(v_pk_columns, '[^,]+', 1, v_pos);
            EXIT WHEN v_pk_col IS NULL;
            
            IF NOT v_first THEN
                v_pk_join := v_pk_join || ' AND ';
                v_pk_where := v_pk_where || ' AND ';
            END IF;
            
            v_pk_join := v_pk_join || 'n.' || TRIM(v_pk_col) || ' = o.' || TRIM(v_pk_col);
            v_pk_where := v_pk_where || TRIM(v_pk_col) || ' = :OLD.' || TRIM(v_pk_col);
            
            v_first := FALSE;
            v_pos := v_pos + 1;
        END LOOP;
    END;
    
    p('✓ Join condition built', TRUE);
    p();
    
    -- ==================================================================
    -- GENERATE DROP STATEMENTS
    -- ==================================================================
    
    header('STEP 1: DROP EXISTING OBJECTS (IF ANY)');
    p();
    p('-- Drop triggers first (dependent objects)');
    p('BEGIN');
    p('  FOR t IN (SELECT trigger_name FROM all_triggers');
    p('            WHERE owner = ''' || c_schema || '''');
    p('              AND table_name = ''' || v_view_name || ''') LOOP');
    p('    EXECUTE IMMEDIATE ''DROP TRIGGER ' || c_schema || '.'' || t.trigger_name;');
    p('  END LOOP;');
    p('EXCEPTION WHEN OTHERS THEN NULL;');
    p('END;');
    p('/');
    p();
    p('-- Drop view');
    p('BEGIN');
    p('  EXECUTE IMMEDIATE ''DROP VIEW ' || qualified_name(c_schema, v_view_name) || ''';');
    p('EXCEPTION WHEN OTHERS THEN NULL;');
    p('END;');
    p('/');
    p();
    
    -- ==================================================================
    -- GENERATE CREATE VIEW
    -- ==================================================================
    
    header('STEP 2: CREATE MIGRATION VIEW');
    p();
    p('-- This view combines NEW and OLD tables with deduplication');
    p('CREATE OR REPLACE VIEW ' || qualified_name(c_schema, v_view_name) || ' AS');
    p('  -- Records from NEW table (priority)');
    p('  SELECT ' || v_all_columns);
    p('  FROM ' || qualified_name(c_schema, v_new_table));
    p('  UNION ALL');
    p('  -- Records from OLD table (not in NEW)');
    p('  SELECT ' || v_all_columns);
    p('  FROM ' || qualified_name(c_schema, v_old_table) || ' o');
    p('  WHERE NOT EXISTS (');
    p('    SELECT 1');
    p('    FROM ' || qualified_name(c_schema, v_new_table) || ' n');
    p('    WHERE ' || v_pk_join);
    p('  );');
    p();
    
    -- ==================================================================
    -- GENERATE INSTEAD OF INSERT TRIGGER
    -- ==================================================================
    
    header('STEP 3: CREATE INSTEAD OF INSERT TRIGGER');
    p();
    p('CREATE OR REPLACE TRIGGER ' || qualified_name(c_schema, v_ins_trigger));
    p('  INSTEAD OF INSERT ON ' || qualified_name(c_schema, v_view_name));
    p('  FOR EACH ROW');
    p('BEGIN');
    p('  -- Insert into NEW table only');
    p('  INSERT INTO ' || qualified_name(c_schema, v_new_table));
    p('    (' || v_all_columns || ')');
    p('  VALUES');
    p('    (' || v_new_values || ');');
    p('EXCEPTION');
    p('  WHEN DUP_VAL_ON_INDEX THEN');
    p('    -- Handle duplicate: update existing record');
    p('    UPDATE ' || qualified_name(c_schema, v_new_table));
    p('    SET ' || v_update_sets);
    p('    WHERE ' || REPLACE(v_pk_join, 'n.', ''));
    p('END ' || v_ins_trigger || ';');
    p('/');
    p();
    
    -- ==================================================================
    -- GENERATE INSTEAD OF UPDATE TRIGGER
    -- ==================================================================
    
    header('STEP 4: CREATE INSTEAD OF UPDATE TRIGGER');
    p();
    p('CREATE OR REPLACE TRIGGER ' || qualified_name(c_schema, v_upd_trigger));
    p('  INSTEAD OF UPDATE ON ' || qualified_name(c_schema, v_view_name));
    p('  FOR EACH ROW');
    p('BEGIN');
    p('  -- Update in NEW table if exists');
    p('  UPDATE ' || qualified_name(c_schema, v_new_table));
    p('  SET ' || v_update_sets);
    p('  WHERE ' || REPLACE(v_pk_where, ':OLD.', ''));
    p('  ');
    p('  -- If not in NEW, insert it');
    p('  IF SQL%ROWCOUNT = 0 THEN');
    p('    INSERT INTO ' || qualified_name(c_schema, v_new_table));
    p('      (' || v_all_columns || ')');
    p('    VALUES');
    p('      (' || v_new_values || ');');
    p('  END IF;');
    p('END ' || v_upd_trigger || ';');
    p('/');
    p();
    
    -- ==================================================================
    -- GENERATE INSTEAD OF DELETE TRIGGER
    -- ==================================================================
    
    header('STEP 5: CREATE INSTEAD OF DELETE TRIGGER');
    p();
    p('CREATE OR REPLACE TRIGGER ' || qualified_name(c_schema, v_del_trigger));
    p('  INSTEAD OF DELETE ON ' || qualified_name(c_schema, v_view_name));
    p('  FOR EACH ROW');
    p('BEGIN');
    p('  -- Delete from NEW table only');
    p('  DELETE FROM ' || qualified_name(c_schema, v_new_table));
    p('  WHERE ' || REPLACE(v_pk_where, ':OLD.', ''));
    p('  ');
    p('  -- Note: Records in OLD table are preserved');
    p('END ' || v_del_trigger || ';');
    p('/');
    p();
    
    -- ==================================================================
    -- GENERATE VERIFICATION QUERIES
    -- ==================================================================
    
    header('VERIFICATION QUERIES');
    p();
    p('-- Check view and triggers exist');
    p('SELECT object_name, object_type, status');
    p('FROM all_objects');
    p('WHERE owner = ''' || c_schema || '''');
    p('  AND object_name IN (''' || v_view_name || ''',');
    p('                      ''' || v_ins_trigger || ''',');
    p('                      ''' || v_upd_trigger || ''',');
    p('                      ''' || v_del_trigger || ''')');
    p('ORDER BY object_type, object_name;');
    p();
    
    p('-- Compare row counts');
    p('SELECT ''NEW Table'' as source, COUNT(*) as rows FROM ' || qualified_name(c_schema, v_new_table));
    p('UNION ALL');
    p('SELECT ''OLD Table'', COUNT(*) FROM ' || qualified_name(c_schema, v_old_table));
    p('UNION ALL');
    p('SELECT ''View (Combined)'', COUNT(*) FROM ' || qualified_name(c_schema, v_view_name) || ';');
    p();
    
    p('-- Test INSERT (should go to NEW table)');
    p('-- INSERT INTO ' || qualified_name(c_schema, v_view_name) || ' (...) VALUES (...);');
    p();
    
    p('-- Test UPDATE (should update NEW or insert if not exists)');
    p('-- UPDATE ' || qualified_name(c_schema, v_view_name) || ' SET ... WHERE ...;');
    p();
    
    p('-- Test DELETE (should delete from NEW only)');
    p('-- DELETE FROM ' || qualified_name(c_schema, v_view_name) || ' WHERE ...;');
    p();
    
    -- ==================================================================
    -- SUMMARY
    -- ==================================================================
    
    header('SUMMARY');
    p('Objects to be created:', TRUE);
    p('  View: ' || qualified_name(c_schema, v_view_name), TRUE);
    p('  Triggers:', TRUE);
    p('    - ' || v_ins_trigger || ' (INSTEAD OF INSERT)', TRUE);
    p('    - ' || v_upd_trigger || ' (INSTEAD OF UPDATE)', TRUE);
    p('    - ' || v_del_trigger || ' (INSTEAD OF DELETE)', TRUE);
    p();
    p('Primary Key: ' || v_pk_columns, TRUE);
    p('Total Columns: ' || v_col_count, TRUE);
    IF v_has_lobs > 0 THEN
        p('LOB Columns: ' || v_has_lobs || ' (requires special handling)', TRUE);
    END IF;
    p();
    p('Next Steps:', TRUE);
    p('  1. Review the generated DDL above', TRUE);
    p('  2. Copy and execute in order (drops, then creates)', TRUE);
    p('  3. Run verification queries', TRUE);
    p('  4. Test with sample DML operations', TRUE);
    p();
    p('Generated: ' || v_timestamp, TRUE);
    header('END OF SCRIPT');
    
EXCEPTION
    WHEN OTHERS THEN
        p();
        header('ERROR OCCURRED');
        p('Error Code: ' || SQLCODE, TRUE);
        p('Error Message: ' || SQLERRM, TRUE);
        p('Error Stack:', TRUE);
        p(DBMS_UTILITY.FORMAT_ERROR_STACK);
        p();
        p('Please check your configuration and try again', TRUE);
END;
/

-- Reset settings for Toad
SET PAGESIZE 14
SET LINESIZE 100
SET FEEDBACK ON
SET HEADING ON

-- ==================================================================
-- TOAD USAGE INSTRUCTIONS
-- ==================================================================
-- 1. Open this script in Toad (File > Open)
-- 2. Modify the configuration variables at the top:
--    - c_schema: Your schema name
--    - c_base_table: Base table name (without suffixes)
-- 3. Press F5 or click Execute Script button
-- 4. Copy the generated SQL from the output window
-- 5. Paste into a new editor window and execute
-- ==================================================================
