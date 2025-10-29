-- ==================================================================
-- GRANT GENERATOR - Generate GRANT statements from ALL_* views
-- ==================================================================
-- Usage: Run directly in Toad - modify the variables below as needed
-- ==================================================================
-- This script generates GRANT statements for tables, views, procedures,
-- functions, packages, and sequences based on existing grants found
-- in the ALL_* views.
-- ==================================================================
-- Supported Objects:
--   - Tables (TABLE)
--   - Views (VIEW)
--   - Procedures (PROCEDURE)
--   - Functions (FUNCTION)
--   - Packages (PACKAGE)
--   - Sequences (SEQUENCE)
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
    v_owner VARCHAR2(128) := 'HR';                    -- Schema owner
    v_object_name VARCHAR2(128) := 'EMPLOYEES';      -- Specific object name (NULL for all objects)
    v_object_type VARCHAR2(20) := 'TABLE';           -- Object type: TABLE, VIEW, PROCEDURE, FUNCTION, PACKAGE, SEQUENCE, or NULL for all
    v_grantee_filter VARCHAR2(128) := NULL;           -- Filter by grantee (NULL for all grantees)
    v_privilege_filter VARCHAR2(50) := NULL;          -- Filter by privilege (NULL for all privileges)
    
    -- *** END CONFIGURATION SECTION ***
    
    v_total_grants NUMBER := 0;
    v_grant_count NUMBER := 0;
    v_object_count NUMBER := 0;
    
    -- Object information
    TYPE object_rec IS RECORD (
        object_name VARCHAR2(128),
        object_type VARCHAR2(20),
        grantee VARCHAR2(128),
        privilege VARCHAR2(50),
        grantable VARCHAR2(3),
        hierarchy VARCHAR2(3)
    );
    
    TYPE object_table IS TABLE OF object_rec;
    v_objects object_table := object_table();
    
BEGIN
    -- ================================================================
    -- STEP 1: Input Validation and Setup
    -- ================================================================
    
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('-- GRANT GENERATOR - TOAD VERSION');
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('-- Configuration:');
    DBMS_OUTPUT.PUT_LINE('--   Owner: ' || v_owner);
    DBMS_OUTPUT.PUT_LINE('--   Object Name: ' || NVL(v_object_name, 'ALL OBJECTS'));
    DBMS_OUTPUT.PUT_LINE('--   Object Type: ' || NVL(v_object_type, 'ALL TYPES'));
    DBMS_OUTPUT.PUT_LINE('--   Grantee Filter: ' || NVL(v_grantee_filter, 'ALL GRANTEES'));
    DBMS_OUTPUT.PUT_LINE('--   Privilege Filter: ' || NVL(v_privilege_filter, 'ALL PRIVILEGES'));
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Validate owner name using DBMS_ASSERT
    BEGIN
        v_owner := DBMS_ASSERT.SIMPLE_SQL_NAME(v_owner);
        IF v_object_name IS NOT NULL THEN
            v_object_name := DBMS_ASSERT.SIMPLE_SQL_NAME(v_object_name);
        END IF;
        IF v_object_type IS NOT NULL THEN
            v_object_type := UPPER(v_object_type);
        END IF;
        IF v_grantee_filter IS NOT NULL THEN
            v_grantee_filter := DBMS_ASSERT.SIMPLE_SQL_NAME(v_grantee_filter);
        END IF;
        IF v_privilege_filter IS NOT NULL THEN
            v_privilege_filter := UPPER(v_privilege_filter);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Invalid input parameters. Only alphanumeric and underscore allowed. ' ||
                'Error: ' || SQLERRM);
    END;
    
    -- ================================================================
    -- STEP 2: Collect Grant Information
    -- ================================================================
    
    DBMS_OUTPUT.PUT_LINE('-- Collecting grant information...');
    
    -- Count total grants
    SELECT COUNT(*) INTO v_total_grants
    FROM all_tab_privs
    WHERE owner = v_owner
      AND (v_object_name IS NULL OR table_name = v_object_name)
      AND (v_object_type IS NULL OR 
           (v_object_type = 'TABLE' AND table_name NOT LIKE '%_VIEW') OR
           (v_object_type = 'VIEW' AND table_name LIKE '%_VIEW') OR
           (v_object_type IN ('PROCEDURE', 'FUNCTION', 'PACKAGE') AND table_name LIKE '%_' || v_object_type))
      AND (v_grantee_filter IS NULL OR grantee = v_grantee_filter)
      AND (v_privilege_filter IS NULL OR privilege = v_privilege_filter);
    
    IF v_total_grants = 0 THEN
        DBMS_OUTPUT.PUT_LINE('-- No grants found matching the criteria');
        DBMS_OUTPUT.PUT_LINE('-- Please check your configuration parameters');
        RETURN;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('-- Found ' || v_total_grants || ' grants');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Collect grant details
    v_objects.EXTEND(v_total_grants);
    
    DECLARE
        v_idx NUMBER := 1;
    BEGIN
        FOR g IN (
            SELECT table_name, grantee, privilege, grantable, hierarchy
            FROM all_tab_privs
            WHERE owner = v_owner
              AND (v_object_name IS NULL OR table_name = v_object_name)
              AND (v_object_type IS NULL OR 
                   (v_object_type = 'TABLE' AND table_name NOT LIKE '%_VIEW') OR
                   (v_object_type = 'VIEW' AND table_name LIKE '%_VIEW') OR
                   (v_object_type IN ('PROCEDURE', 'FUNCTION', 'PACKAGE') AND table_name LIKE '%_' || v_object_type))
              AND (v_grantee_filter IS NULL OR grantee = v_grantee_filter)
              AND (v_privilege_filter IS NULL OR privilege = v_privilege_filter)
            ORDER BY table_name, grantee, privilege
        ) LOOP
            v_objects(v_idx).object_name := g.table_name;
            v_objects(v_idx).object_type := v_object_type;
            v_objects(v_idx).grantee := g.grantee;
            v_objects(v_idx).privilege := g.privilege;
            v_objects(v_idx).grantable := g.grantable;
            v_objects(v_idx).hierarchy := g.hierarchy;
            
            v_idx := v_idx + 1;
        END LOOP;
    END;
    
    -- ================================================================
    -- STEP 3: Generate GRANT Statements
    -- ================================================================
    
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('-- GRANT STATEMENTS GENERATED');
    DBMS_OUTPUT.PUT_LINE('-- Owner: ' || v_owner);
    DBMS_OUTPUT.PUT_LINE('-- Generated: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Generate GRANT statements
    FOR i IN 1..v_objects.COUNT LOOP
        DECLARE
            v_grant_sql VARCHAR2(1000);
            v_grantable_clause VARCHAR2(50) := '';
        BEGIN
            -- Build grantable clause
            IF v_objects(i).grantable = 'YES' THEN
                v_grantable_clause := ' WITH GRANT OPTION';
            ELSIF v_objects(i).hierarchy = 'YES' THEN
                v_grantable_clause := ' WITH HIERARCHY OPTION';
            END IF;
            
            -- Generate GRANT statement
            v_grant_sql := 'GRANT ' || v_objects(i).privilege || ' ON ' ||
                          DBMS_ASSERT.ENQUOTE_NAME(v_owner) || '.' ||
                          DBMS_ASSERT.ENQUOTE_NAME(v_objects(i).object_name) ||
                          ' TO ' || DBMS_ASSERT.ENQUOTE_NAME(v_objects(i).grantee) ||
                          v_grantable_clause || ';';
            
            DBMS_OUTPUT.PUT_LINE('-- Grant: ' || v_objects(i).privilege || ' on ' || 
                               v_objects(i).object_name || ' to ' || v_objects(i).grantee);
            DBMS_OUTPUT.PUT_LINE(v_grant_sql);
            DBMS_OUTPUT.PUT_LINE('');
            
            v_grant_count := v_grant_count + 1;
        END;
    END LOOP;
    
    -- ================================================================
    -- STEP 4: Generate Verification Queries
    -- ================================================================
    
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('-- VERIFICATION QUERIES');
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    DBMS_OUTPUT.PUT_LINE('-- Query 1: Check all grants for the owner');
    DBMS_OUTPUT.PUT_LINE('SELECT table_name, grantee, privilege, grantable, hierarchy');
    DBMS_OUTPUT.PUT_LINE('FROM all_tab_privs');
    DBMS_OUTPUT.PUT_LINE('WHERE owner = ''' || v_owner || '''');
    IF v_object_name IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('  AND table_name = ''' || v_object_name || '''');
    END IF;
    DBMS_OUTPUT.PUT_LINE('ORDER BY table_name, grantee, privilege;');
    DBMS_OUTPUT.PUT_LINE('');
    
    DBMS_OUTPUT.PUT_LINE('-- Query 2: Check grants by grantee');
    DBMS_OUTPUT.PUT_LINE('SELECT grantee, COUNT(*) as grant_count');
    DBMS_OUTPUT.PUT_LINE('FROM all_tab_privs');
    DBMS_OUTPUT.PUT_LINE('WHERE owner = ''' || v_owner || '''');
    IF v_object_name IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('  AND table_name = ''' || v_object_name || '''');
    END IF;
    DBMS_OUTPUT.PUT_LINE('GROUP BY grantee');
    DBMS_OUTPUT.PUT_LINE('ORDER BY grantee;');
    DBMS_OUTPUT.PUT_LINE('');
    
    DBMS_OUTPUT.PUT_LINE('-- Query 3: Check grants by privilege');
    DBMS_OUTPUT.PUT_LINE('SELECT privilege, COUNT(*) as privilege_count');
    DBMS_OUTPUT.PUT_LINE('FROM all_tab_privs');
    DBMS_OUTPUT.PUT_LINE('WHERE owner = ''' || v_owner || '''');
    IF v_object_name IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('  AND table_name = ''' || v_object_name || '''');
    END IF;
    DBMS_OUTPUT.PUT_LINE('GROUP BY privilege');
    DBMS_OUTPUT.PUT_LINE('ORDER BY privilege;');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ================================================================
    -- STEP 5: Generate Summary Information
    -- ================================================================
    
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('-- SUMMARY');
    DBMS_OUTPUT.PUT_LINE('-- ==================================================================');
    DBMS_OUTPUT.PUT_LINE('-- Total grants found: ' || v_total_grants);
    DBMS_OUTPUT.PUT_LINE('-- Grants generated: ' || v_grant_count);
    DBMS_OUTPUT.PUT_LINE('--');
    
    -- Count unique objects
    DECLARE
        v_unique_objects NUMBER := 0;
    BEGIN
        SELECT COUNT(DISTINCT object_name) INTO v_unique_objects
        FROM (
            SELECT object_name FROM TABLE(v_objects)
        );
        DBMS_OUTPUT.PUT_LINE('-- Unique objects: ' || v_unique_objects);
    END;
    
    -- Count unique grantees
    DECLARE
        v_unique_grantees NUMBER := 0;
    BEGIN
        SELECT COUNT(DISTINCT grantee) INTO v_unique_grantees
        FROM (
            SELECT grantee FROM TABLE(v_objects)
        );
        DBMS_OUTPUT.PUT_LINE('-- Unique grantees: ' || v_unique_grantees);
    END;
    
    DBMS_OUTPUT.PUT_LINE('--');
    DBMS_OUTPUT.PUT_LINE('-- Instructions:');
    DBMS_OUTPUT.PUT_LINE('-- 1. Review the generated GRANT statements above');
    DBMS_OUTPUT.PUT_LINE('-- 2. Copy and execute them as needed');
    DBMS_OUTPUT.PUT_LINE('-- 3. Run the verification queries to confirm grants');
    DBMS_OUTPUT.PUT_LINE('-- 4. Note: This script only shows table/view grants from all_tab_privs');
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
--    - v_owner: Schema owner to check grants for
--    - v_object_name: Specific object name (NULL for all objects)
--    - v_object_type: Object type filter (NULL for all types)
--    - v_grantee_filter: Filter by specific grantee (NULL for all)
--    - v_privilege_filter: Filter by specific privilege (NULL for all)
-- 3. Execute the script (F5 or Execute button)
-- 4. Review the generated GRANT statements in the output
-- 5. Copy and execute the GRANT statements as needed
-- 6. Run the verification queries to confirm grants
-- ==================================================================
