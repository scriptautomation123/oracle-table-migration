-- ==================================================================
-- CONSTRAINT RENAME GENERATOR - IMPROVED VERSION
-- ==================================================================
-- Purpose: Generates SQL statements to rename constraints when 
-- renaming tables. Does NOT execute - review and run separately.
-- ==================================================================
-- Improvements:
--   - Single query for better performance
--   - Cleaner code structure with better modularity
--   - Enhanced naming logic with proper sequencing
--   - Detailed constraint information in output
--   - Better error handling and validation
-- ==================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF
SET PAGESIZE 0
SET LINESIZE 300
SET FEEDBACK OFF
SET HEADING OFF

DECLARE
    -- ==================================================================
    -- CONFIGURATION - MODIFY THESE VALUES
    -- ==================================================================
    c_schema         CONSTANT VARCHAR2(128) := 'HR';              -- Schema name
    c_old_table      CONSTANT VARCHAR2(128) := 'EMPLOYEES_OLD';   -- Old table name  
    c_new_table      CONSTANT VARCHAR2(128) := 'EMPLOYEES';       -- New table name
    c_prefix         VARCHAR2(128)          := 'EMPLOYEES';       -- Constraint prefix
    
    -- ==================================================================
    -- CONSTANTS - DO NOT MODIFY
    -- ==================================================================
    c_max_name_len   CONSTANT NUMBER := 30;
    c_separator      CONSTANT VARCHAR2(70) := LPAD('=', 70, '=');
    c_timestamp      CONSTANT VARCHAR2(30) := TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS');
    
    -- Type definitions
    TYPE t_constraint IS RECORD (
        constraint_name     VARCHAR2(128),
        constraint_type     CHAR(1),
        new_name           VARCHAR2(128),
        columns            VARCHAR2(4000),
        r_owner            VARCHAR2(128),
        r_constraint_name  VARCHAR2(128),
        search_condition   VARCHAR2(4000)
    );
    
    TYPE t_constraint_list IS TABLE OF t_constraint INDEX BY PLS_INTEGER;
    v_constraints t_constraint_list;
    
    -- Counters
    v_pk_count      NUMBER := 0;
    v_uk_count      NUMBER := 0;
    v_fk_count      NUMBER := 0;
    v_total_count   NUMBER := 0;
    v_table_exists  NUMBER := 0;
    
    -- Variables
    v_idx           NUMBER := 0;
    v_uk_seq        NUMBER := 0;
    v_fk_seq        NUMBER := 0;
    
    -- ==================================================================
    -- LOCAL PROCEDURES
    -- ==================================================================
    
    PROCEDURE print_line(p_text VARCHAR2 DEFAULT '') IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE(p_text);
    END;
    
    PROCEDURE print_header(p_title VARCHAR2) IS
    BEGIN
        print_line('-- ' || c_separator);
        print_line('-- ' || p_title);
        print_line('-- ' || c_separator);
    END;
    
    PROCEDURE print_comment(p_text VARCHAR2) IS
    BEGIN
        print_line('-- ' || p_text);
    END;
    
    FUNCTION generate_constraint_name(
        p_prefix VARCHAR2,
        p_type   CHAR,
        p_seq    NUMBER DEFAULT NULL
    ) RETURN VARCHAR2 IS
        v_suffix VARCHAR2(10);
        v_name   VARCHAR2(128);
    BEGIN
        -- Generate appropriate suffix
        v_suffix := CASE p_type
            WHEN 'P' THEN '_PK'
            WHEN 'U' THEN '_UK' || NULLIF(TO_CHAR(p_seq), '1')
            WHEN 'R' THEN '_FK' || TO_CHAR(p_seq)
            ELSE '_' || p_type || NVL(TO_CHAR(p_seq), '')
        END;
        
        v_name := p_prefix || v_suffix;
        
        -- Ensure within Oracle limits
        IF LENGTH(v_name) > c_max_name_len THEN
            v_name := SUBSTR(p_prefix, 1, c_max_name_len - LENGTH(v_suffix)) || v_suffix;
        END IF;
        
        RETURN v_name;
    END;
    
    FUNCTION validate_identifier(p_name VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN DBMS_ASSERT.SIMPLE_SQL_NAME(p_name);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 
                'Invalid identifier "' || p_name || '": ' || SQLERRM);
    END;
    
BEGIN
    -- ==================================================================
    -- INITIALIZATION AND VALIDATION
    -- ==================================================================
    
    print_header('CONSTRAINT RENAME GENERATOR');
    print_comment('Generated: ' || c_timestamp);
    print_comment('User: ' || USER);
    print_line();
    
    -- Validate and sanitize inputs
    BEGIN
        c_prefix := NVL(c_prefix, c_new_table);
        
        -- Validate all identifiers
        c_prefix := validate_identifier(c_prefix);
        
        -- Validate schema exists (using DBMS_ASSERT for schema)
        DECLARE
            v_validated_schema VARCHAR2(128);
        BEGIN
            v_validated_schema := DBMS_ASSERT.SCHEMA_NAME(c_schema);
        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20002, 'Schema not found: ' || c_schema);
        END;
        
        -- Validate table names
        DECLARE
            v_validated_old VARCHAR2(128);
            v_validated_new VARCHAR2(128);
        BEGIN
            v_validated_old := validate_identifier(c_old_table);
            v_validated_new := validate_identifier(c_new_table);
        END;
        
    EXCEPTION
        WHEN OTHERS THEN
            print_comment('ERROR during validation: ' || SQLERRM);
            RAISE;
    END;
    
    -- Check table existence
    BEGIN
        SELECT COUNT(*) INTO v_table_exists
        FROM all_tables
        WHERE owner = c_schema 
          AND table_name = c_old_table;
        
        IF v_table_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 
                'Old table not found: ' || c_schema || '.' || c_old_table);
        END IF;
        
        SELECT COUNT(*) INTO v_table_exists
        FROM all_tables
        WHERE owner = c_schema 
          AND table_name = c_new_table;
        
        IF v_table_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 
                'New table not found: ' || c_schema || '.' || c_new_table);
        END IF;
    END;
    
    print_comment('Configuration:');
    print_comment('  Schema: ' || c_schema);
    print_comment('  Old Table: ' || c_old_table);
    print_comment('  New Table: ' || c_new_table);
    print_comment('  Constraint Prefix: ' || c_prefix);
    print_comment('✓ Validation passed - both tables exist');
    print_line();
    
    -- ==================================================================
    -- COLLECT CONSTRAINTS (SINGLE OPTIMIZED QUERY)
    -- ==================================================================
    
    FOR rec IN (
        SELECT 
            c.constraint_name,
            c.constraint_type,
            c.r_owner,
            c.r_constraint_name,
            c.search_condition,
            LISTAGG(cc.column_name, ', ') 
                WITHIN GROUP (ORDER BY cc.position) AS column_list
        FROM all_constraints c
        LEFT JOIN all_cons_columns cc
            ON c.owner = cc.owner
            AND c.constraint_name = cc.constraint_name
        WHERE c.owner = c_schema
          AND c.table_name = c_old_table
          AND c.constraint_type IN ('P', 'U', 'R')
        GROUP BY 
            c.constraint_name,
            c.constraint_type,
            c.r_owner,
            c.r_constraint_name,
            c.search_condition
        ORDER BY 
            DECODE(c.constraint_type, 'P', 1, 'U', 2, 'R', 3, 4),
            c.constraint_name
    ) LOOP
        v_idx := v_idx + 1;
        v_constraints(v_idx).constraint_name := rec.constraint_name;
        v_constraints(v_idx).constraint_type := rec.constraint_type;
        v_constraints(v_idx).columns := rec.column_list;
        v_constraints(v_idx).r_owner := rec.r_owner;
        v_constraints(v_idx).r_constraint_name := rec.r_constraint_name;
        v_constraints(v_idx).search_condition := rec.search_condition;
        
        -- Generate new name with proper sequencing
        CASE rec.constraint_type
            WHEN 'P' THEN
                v_pk_count := v_pk_count + 1;
                v_constraints(v_idx).new_name := generate_constraint_name(c_prefix, 'P');
            WHEN 'U' THEN
                v_uk_count := v_uk_count + 1;
                v_uk_seq := v_uk_seq + 1;
                v_constraints(v_idx).new_name := generate_constraint_name(c_prefix, 'U', v_uk_seq);
            WHEN 'R' THEN
                v_fk_count := v_fk_count + 1;
                v_fk_seq := v_fk_seq + 1;
                v_constraints(v_idx).new_name := generate_constraint_name(c_prefix, 'R', v_fk_seq);
        END CASE;
        
        v_total_count := v_total_count + 1;
    END LOOP;
    
    -- Check if any constraints found
    IF v_total_count = 0 THEN
        print_comment('No renameable constraints found for ' || c_schema || '.' || c_old_table);
        print_comment('Note: Check constraints (C) and NOT NULL constraints cannot be renamed in Oracle');
        RETURN;
    END IF;
    
    print_comment('Found ' || v_total_count || ' renameable constraint(s)');
    print_line();
    
    -- ==================================================================
    -- GENERATE ALTER STATEMENTS
    -- ==================================================================
    
    print_header('GENERATED ALTER STATEMENTS');
    print_line();
    
    FOR i IN 1..v_constraints.COUNT LOOP
        -- Print constraint details as comments
        print_comment('Constraint #' || i || ': ' || 
            CASE v_constraints(i).constraint_type
                WHEN 'P' THEN 'PRIMARY KEY'
                WHEN 'U' THEN 'UNIQUE'
                WHEN 'R' THEN 'FOREIGN KEY'
            END);
        print_comment('  Old Name: ' || v_constraints(i).constraint_name);
        print_comment('  New Name: ' || v_constraints(i).new_name);
        print_comment('  Columns: ' || v_constraints(i).columns);
        
        IF v_constraints(i).r_constraint_name IS NOT NULL THEN
            print_comment('  References: ' || v_constraints(i).r_owner || '.' || 
                         v_constraints(i).r_constraint_name);
        END IF;
        
        -- Generate ALTER statement
        print_line('ALTER TABLE ' || c_schema || '.' || c_new_table ||
                  ' RENAME CONSTRAINT ' || v_constraints(i).constraint_name ||
                  ' TO ' || v_constraints(i).new_name || ';');
        print_line();
    END LOOP;
    
    -- ==================================================================
    -- GENERATE ROLLBACK STATEMENTS
    -- ==================================================================
    
    print_header('ROLLBACK STATEMENTS (IF NEEDED)');
    print_line();
    
    FOR i IN 1..v_constraints.COUNT LOOP
        print_comment('Rollback constraint #' || i);
        print_line('ALTER TABLE ' || c_schema || '.' || c_new_table ||
                  ' RENAME CONSTRAINT ' || v_constraints(i).new_name ||
                  ' TO ' || v_constraints(i).constraint_name || ';');
    END LOOP;
    print_line();
    
    -- ==================================================================
    -- VERIFICATION QUERIES
    -- ==================================================================
    
    print_header('VERIFICATION QUERIES');
    print_line();
    
    print_comment('Query 1: Verify all constraints after rename');
    print_line('SELECT constraint_name, constraint_type, status');
    print_line('FROM all_constraints');
    print_line('WHERE owner = ''' || c_schema || '''');
    print_line('  AND table_name = ''' || c_new_table || '''');
    print_line('  AND constraint_name LIKE ''' || c_prefix || '%''');
    print_line('ORDER BY');
    print_line('  DECODE(constraint_type, ''P'', 1, ''U'', 2, ''R'', 3, 4),');
    print_line('  constraint_name;');
    print_line();
    
    print_comment('Query 2: Detailed constraint verification');
    print_line('SELECT ');
    print_line('  c.constraint_name,');
    print_line('  c.constraint_type,');
    print_line('  LISTAGG(cc.column_name, '', '') WITHIN GROUP (ORDER BY cc.position) AS columns,');
    print_line('  c.status,');
    print_line('  c.r_owner || ''.'' || r.table_name AS references_table,');
    print_line('  c.r_constraint_name AS references_constraint');
    print_line('FROM all_constraints c');
    print_line('LEFT JOIN all_cons_columns cc');
    print_line('  ON c.owner = cc.owner AND c.constraint_name = cc.constraint_name');
    print_line('LEFT JOIN all_constraints r');
    print_line('  ON c.r_owner = r.owner AND c.r_constraint_name = r.constraint_name');
    print_line('WHERE c.owner = ''' || c_schema || '''');
    print_line('  AND c.table_name = ''' || c_new_table || '''');
    print_line('GROUP BY ');
    print_line('  c.constraint_name, c.constraint_type, c.status,');
    print_line('  c.r_owner, r.table_name, c.r_constraint_name');
    print_line('ORDER BY');
    print_line('  DECODE(c.constraint_type, ''P'', 1, ''U'', 2, ''R'', 3, 4),');
    print_line('  c.constraint_name;');
    print_line();
    
    -- ==================================================================
    -- SUMMARY
    -- ==================================================================
    
    print_header('SUMMARY');
    print_comment('Total Constraints to Rename: ' || v_total_count);
    print_line();
    print_comment('Breakdown by Type:');
    print_comment('  Primary Keys: ' || v_pk_count);
    print_comment('  Unique Keys: ' || v_uk_count);
    print_comment('  Foreign Keys: ' || v_fk_count);
    print_line();
    print_comment('Next Steps:');
    print_comment('  1. Review the generated ALTER statements above');
    print_comment('  2. Save the rollback statements for safety');
    print_comment('  3. Execute the ALTER statements in a transaction');
    print_comment('  4. Run the verification queries to confirm success');
    print_comment('  5. Commit if successful, or run rollback statements if needed');
    print_line();
    print_comment('Note: Check constraints and NOT NULL constraints cannot be renamed');
    print_comment('      They must be dropped and recreated if name change is required');
    print_header('END OF GENERATED SCRIPT');
    
EXCEPTION
    WHEN OTHERS THEN
        print_line();
        print_header('ERROR OCCURRED');
        print_comment('Error Code: ' || SQLCODE);
        print_comment('Error Message: ' || SQLERRM);
        print_comment('Error Stack:');
        print_line(DBMS_UTILITY.FORMAT_ERROR_STACK);
        print_comment('Please check your configuration and try again');
        print_header('END OF ERROR REPORT');
END;
/

-- Reset settings
SET PAGESIZE 14
SET LINESIZE 80
SET FEEDBACK ON
SET HEADING ON

-- ==================================================================
-- USAGE INSTRUCTIONS
-- ==================================================================
-- 1. Open this script in Toad or SQL*Plus
-- 2. Modify the configuration constants at the top:
--    - c_schema: Your schema name
--    - c_old_table: The old table name (source of constraints)
--    - c_new_table: The new table name (target for renamed constraints)
--    - c_prefix: Prefix for new constraint names
-- 3. Execute the script (F5 in Toad or @scriptname in SQL*Plus)
-- 4. Review the generated ALTER statements
-- 5. Copy and execute the statements as needed
-- 6. Use the verification queries to confirm success
-- ==================================================================
