-- ==================================================================
-- CONSTRAINT RENAME GENERATOR - TOAD COMPATIBLE VERSION
-- ==================================================================
-- Usage: Run directly in Toad - modify the variables below as needed
-- ==================================================================
-- This script generates SQL statements to rename constraints when 
-- renaming tables, but does NOT execute them. The generated SQL can
-- be reviewed and executed separately.
-- ==================================================================
-- Renameable Constraints:
--   - Primary Key constraints (P)
--   - Unique constraints (U) 
--   - Foreign Key constraints (R)
-- ==================================================================
-- Non-renameable Constraints (excluded):
--   - Check constraints (C) - Oracle doesn't support renaming
--   - NOT NULL constraints - System-generated names, not renamed
-- ==================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF
SET PAGESIZE 0
SET LINESIZE 200
SET FEEDBACK OFF
SET HEADING OFF

-- ==================================================================
-- CONFIGURATION SECTION - MODIFY THESE VALUES AS NEEDED
-- ==================================================================

DECLARE
    -- *** MODIFY THESE VALUES FOR YOUR USE CASE ***
    v_schema VARCHAR2(128) := 'HR';                    -- Schema name
    v_old_table VARCHAR2(128) := 'EMPLOYEES_OLD';     -- Old table name
    v_new_table VARCHAR2(128) := 'EMPLOYEES';         -- New table name
    v_prefix VARCHAR2(128) := 'EMPLOYEES';            -- Constraint prefix (defaults to new table name)
    
    -- *** END CONFIGURATION SECTION ***
    
    v_total_constraints NUMBER := 0;
    v_constraint_count NUMBER := 0;
    
    -- Validation flags
    v_old_table_exists NUMBER := 0;
    v_new_table_exists NUMBER := 0;
    
    -- Constraint information
    TYPE constraint_rec IS RECORD (
        constraint_name VARCHAR2(128),
        constraint_type VARCHAR2(1),
        new_constraint_name VARCHAR2(128),
        constraint_type_desc VARCHAR2(20)
    );
    
    TYPE constraint_table IS TABLE OF constraint_rec;
    v_constraints constraint_table := constraint_table();
    
BEGIN
    -- ================================================================
    -- STEP 1: Input Validation
    -- ================================================================
    
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('-- CONSTRAINT RENAME GENERATOR - TOAD VERSION');
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('-- Configuration:');
    DBMS_OUTPUT.PUT_LINE('--   Schema: ' || v_schema);
    DBMS_OUTPUT.PUT_LINE('--   Old Table: ' || v_old_table);
    DBMS_OUTPUT.PUT_LINE('--   New Table: ' || v_new_table);
    DBMS_OUTPUT.PUT_LINE('--   Constraint Prefix: ' || v_prefix);
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Validate schema and table names using DBMS_ASSERT
    BEGIN
        v_schema := DBMS_ASSERT.SIMPLE_SQL_NAME(v_schema);
        v_old_table := DBMS_ASSERT.SIMPLE_SQL_NAME(v_old_table);
        v_new_table := DBMS_ASSERT.SIMPLE_SQL_NAME(v_new_table);
        v_prefix := DBMS_ASSERT.SIMPLE_SQL_NAME(v_prefix);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Invalid schema or table name. Only alphanumeric and underscore allowed. ' ||
                'Error: ' || SQLERRM);
    END;
    
    -- Check if old table exists
    SELECT COUNT(*) INTO v_old_table_exists
    FROM all_tables
    WHERE owner = v_schema AND table_name = v_old_table;
    
    IF v_old_table_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Old table does not exist: ' || v_schema || '.' || v_old_table);
    END IF;
    
    -- Check if new table exists
    SELECT COUNT(*) INTO v_new_table_exists
    FROM all_tables
    WHERE owner = v_schema AND table_name = v_new_table;
    
    IF v_new_table_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20003,
            'New table does not exist: ' || v_schema || '.' || v_new_table);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('-- ✓ Validation passed - both tables exist');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ================================================================
    -- STEP 2: Collect Renameable Constraints
    -- ================================================================
    
    -- Count total constraints
    SELECT COUNT(*) INTO v_total_constraints
    FROM all_constraints
    WHERE owner = v_schema 
      AND table_name = v_old_table
      AND constraint_type IN ('P', 'U', 'R');
    
    IF v_total_constraints = 0 THEN
        DBMS_OUTPUT.PUT_LINE('-- No renameable constraints found for ' || v_schema || '.' || v_old_table);
        DBMS_OUTPUT.PUT_LINE('-- Note: Check constraints and NOT NULL constraints are not renameable');
        RETURN;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('-- Found ' || v_total_constraints || ' renameable constraints');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Collect constraint details
    v_constraints.EXTEND(v_total_constraints);
    
    DECLARE
        v_idx NUMBER := 1;
    BEGIN
        FOR c IN (
            SELECT constraint_name, constraint_type
            FROM all_constraints
            WHERE owner = v_schema 
              AND table_name = v_old_table
              AND constraint_type IN ('P', 'U', 'R')
            ORDER BY 
                CASE constraint_type 
                    WHEN 'P' THEN 1 
                    WHEN 'U' THEN 2 
                    WHEN 'R' THEN 3 
                END,
                constraint_name
        ) LOOP
            v_constraints(v_idx).constraint_name := c.constraint_name;
            v_constraints(v_idx).constraint_type := c.constraint_type;
            
            -- Generate new constraint name
            CASE c.constraint_type
                WHEN 'P' THEN
                    v_constraints(v_idx).new_constraint_name := v_prefix || '_PK';
                    v_constraints(v_idx).constraint_type_desc := 'Primary Key';
                WHEN 'U' THEN
                    v_constraints(v_idx).new_constraint_name := v_prefix || '_UK' || 
                        CASE WHEN LENGTH(c.constraint_name) > LENGTH(v_prefix) + 2 
                             THEN SUBSTR(c.constraint_name, LENGTH(v_prefix) + 3)
                             ELSE '_' || TO_CHAR(v_idx)
                        END;
                    v_constraints(v_idx).constraint_type_desc := 'Unique';
                WHEN 'R' THEN
                    v_constraints(v_idx).new_constraint_name := v_prefix || '_FK' || 
                        CASE WHEN LENGTH(c.constraint_name) > LENGTH(v_prefix) + 2 
                             THEN SUBSTR(c.constraint_name, LENGTH(v_prefix) + 3)
                             ELSE '_' || TO_CHAR(v_idx)
                        END;
                    v_constraints(v_idx).constraint_type_desc := 'Foreign Key';
            END CASE;
            
            -- Ensure new name doesn't exceed Oracle's 30-character limit
            IF LENGTH(v_constraints(v_idx).new_constraint_name) > 30 THEN
                v_constraints(v_idx).new_constraint_name := 
                    SUBSTR(v_prefix, 1, 26) || '_' || TO_CHAR(v_idx);
            END IF;
            
            v_idx := v_idx + 1;
        END LOOP;
    END;
    
    -- ================================================================
    -- STEP 3: Generate SQL Statements
    -- ================================================================
    
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('-- CONSTRAINT RENAME SQL GENERATED');
    DBMS_OUTPUT.PUT_LINE('-- Schema: ' || v_schema);
    DBMS_OUTPUT.PUT_LINE('-- Old Table: ' || v_old_table);
    DBMS_OUTPUT.PUT_LINE('-- New Table: ' || v_new_table);
    DBMS_OUTPUT.PUT_LINE('-- Constraint Prefix: ' || v_prefix);
    DBMS_OUTPUT.PUT_LINE('-- Generated: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Generate ALTER TABLE statements
    FOR i IN 1..v_constraints.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('-- Rename ' || v_constraints(i).constraint_type_desc || ' constraint');
        DBMS_OUTPUT.PUT_LINE('-- Old: ' || v_constraints(i).constraint_name);
        DBMS_OUTPUT.PUT_LINE('-- New: ' || v_constraints(i).new_constraint_name);
        DBMS_OUTPUT.PUT_LINE('ALTER TABLE ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || 
                             DBMS_ASSERT.ENQUOTE_NAME(v_new_table) ||
                             ' RENAME CONSTRAINT ' || 
                             DBMS_ASSERT.ENQUOTE_NAME(v_constraints(i).constraint_name) ||
                             ' TO ' || DBMS_ASSERT.ENQUOTE_NAME(v_constraints(i).new_constraint_name) || ';');
        DBMS_OUTPUT.PUT_LINE('');
        
        v_constraint_count := v_constraint_count + 1;
    END LOOP;
    
    -- ================================================================
    -- STEP 4: Generate Verification Queries
    -- ================================================================
    
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('-- VERIFICATION QUERIES');
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    DBMS_OUTPUT.PUT_LINE('-- Query 1: Check all constraints on the new table');
    DBMS_OUTPUT.PUT_LINE('SELECT constraint_name, constraint_type, status');
    DBMS_OUTPUT.PUT_LINE('FROM all_constraints');
    DBMS_OUTPUT.PUT_LINE('WHERE owner = ''' || v_schema || '''');
    DBMS_OUTPUT.PUT_LINE('  AND table_name = ''' || v_new_table || '''');
    DBMS_OUTPUT.PUT_LINE('ORDER BY constraint_type, constraint_name;');
    DBMS_OUTPUT.PUT_LINE('');
    
    DBMS_OUTPUT.PUT_LINE('-- Query 2: Check constraint details with columns');
    DBMS_OUTPUT.PUT_LINE('SELECT c.constraint_name, c.constraint_type, c.status,');
    DBMS_OUTPUT.PUT_LINE('       LISTAGG(cc.column_name, '', '') WITHIN GROUP (ORDER BY cc.position) as columns');
    DBMS_OUTPUT.PUT_LINE('FROM all_constraints c');
    DBMS_OUTPUT.PUT_LINE('JOIN all_cons_columns cc ON c.constraint_name = cc.constraint_name AND c.owner = cc.owner');
    DBMS_OUTPUT.PUT_LINE('WHERE c.owner = ''' || v_schema || '''');
    DBMS_OUTPUT.PUT_LINE('  AND c.table_name = ''' || v_new_table || '''');
    DBMS_OUTPUT.PUT_LINE('GROUP BY c.constraint_name, c.constraint_type, c.status');
    DBMS_OUTPUT.PUT_LINE('ORDER BY c.constraint_type, c.constraint_name;');
    DBMS_OUTPUT.PUT_LINE('');
    
    DBMS_OUTPUT.PUT_LINE('-- Query 3: Check foreign key references');
    DBMS_OUTPUT.PUT_LINE('SELECT c.constraint_name, c.constraint_type, c.status,');
    DBMS_OUTPUT.PUT_LINE('       c.r_owner, c.r_constraint_name');
    DBMS_OUTPUT.PUT_LINE('FROM all_constraints c');
    DBMS_OUTPUT.PUT_LINE('WHERE c.owner = ''' || v_schema || '''');
    DBMS_OUTPUT.PUT_LINE('  AND c.table_name = ''' || v_new_table || '''');
    DBMS_OUTPUT.PUT_LINE('  AND c.constraint_type = ''R''');
    DBMS_OUTPUT.PUT_LINE('ORDER BY c.constraint_name;');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ================================================================
    -- STEP 5: Generate Summary Information
    -- ================================================================
    
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('-- SUMMARY');
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('-- Total constraints to rename: ' || v_constraint_count);
    DBMS_OUTPUT.PUT_LINE('--');
    DBMS_OUTPUT.PUT_LINE('-- Constraint Types:');
    
    DECLARE
        v_pk_count NUMBER := 0;
        v_uk_count NUMBER := 0;
        v_fk_count NUMBER := 0;
    BEGIN
        FOR i IN 1..v_constraints.COUNT LOOP
            CASE v_constraints(i).constraint_type
                WHEN 'P' THEN v_pk_count := v_pk_count + 1;
                WHEN 'U' THEN v_uk_count := v_uk_count + 1;
                WHEN 'R' THEN v_fk_count := v_fk_count + 1;
            END CASE;
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('--   Primary Keys: ' || v_pk_count);
        DBMS_OUTPUT.PUT_LINE('--   Unique Constraints: ' || v_uk_count);
        DBMS_OUTPUT.PUT_LINE('--   Foreign Keys: ' || v_fk_count);
    END;
    
    DBMS_OUTPUT.PUT_LINE('--');
    DBMS_OUTPUT.PUT_LINE('-- Instructions:');
    DBMS_OUTPUT.PUT_LINE('-- 1. Review the generated ALTER TABLE statements above');
    DBMS_OUTPUT.PUT_LINE('-- 2. Copy and execute them one by one, or as a batch');
    DBMS_OUTPUT.PUT_LINE('-- 3. Run the verification queries to confirm success');
    DBMS_OUTPUT.PUT_LINE('-- 4. Note: Check constraints and NOT NULL constraints are not renamed');
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('-- ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('-- Error Code: ' || SQLCODE);
        DBMS_OUTPUT.PUT_LINE('-- Please check your configuration values and try again');
END;
/

-- Reset SQL*Plus settings for Toad
SET PAGESIZE 14
SET LINESIZE 80
SET FEEDBACK ON
SET HEADING ON

-- ==================================================================
-- TOAD USAGE INSTRUCTIONS
-- ==================================================================
-- 1. Open this script in Toad
-- 2. Modify the configuration variables in the DECLARE section:
--    - v_schema: Your schema name
--    - v_old_table: The old table name (source of constraints)
--    - v_new_table: The new table name (where constraints will be renamed)
--    - v_prefix: Prefix for new constraint names (defaults to new table name)
-- 3. Execute the script (F5 or Execute button)
-- 4. Review the generated SQL in the output
-- 5. Copy and execute the ALTER TABLE statements
-- 6. Run the verification queries to confirm success
-- ==================================================================
