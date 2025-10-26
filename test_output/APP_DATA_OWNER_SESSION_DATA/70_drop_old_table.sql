-- ==================================================================
-- DROP OLD TABLE: APP_DATA_OWNER.SESSION_DATA_OLD
-- ==================================================================
-- Generated: 2025-10-25 16:33:49
-- WARNING: This is IRREVERSIBLE!
-- 
-- IMPORTANT: This script is NOT part of master1.sql
-- Execute manually only after validating migration success
-- Recommended retention period: 7 days
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT STANDALONE DROP SCRIPT - Execute manually after validation
PROMPT ================================================================
PROMPT Table to drop: APP_DATA_OWNER.SESSION_DATA_OLD
PROMPT Migration date: 2025-10-25 16:33:49
PROMPT Retention period: 7 days
PROMPT ================================================================

-- Pre-drop validation
DECLARE
    v_table_exists NUMBER := 0;
    v_migration_table_exists NUMBER := 0;
    v_old_row_count NUMBER := 0;
    v_new_row_count NUMBER := 0;
BEGIN
    -- Check if old table exists
    SELECT COUNT(*) INTO v_table_exists
    FROM all_tables
    WHERE owner = 'APP_DATA_OWNER' AND table_name = 'SESSION_DATA_OLD';
    
    IF v_table_exists = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Table APP_DATA_OWNER.SESSION_DATA_OLD does not exist - nothing to drop');
        RETURN;
    END IF;
    
    -- Check if migrated table exists and is active
    SELECT COUNT(*) INTO v_migration_table_exists
    FROM all_tables
    WHERE owner = 'APP_DATA_OWNER' AND table_name = 'SESSION_DATA';
    
    IF v_migration_table_exists = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Migrated table APP_DATA_OWNER.SESSION_DATA not found!');
        DBMS_OUTPUT.PUT_LINE('DO NOT drop old table - migration may have failed');
        RAISE_APPLICATION_ERROR(-20001, 'Migration table not found - aborting drop');
    END IF;
    
    -- Compare row counts as final safety check
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM APP_DATA_OWNER.SESSION_DATA_OLD' INTO v_old_row_count;
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM APP_DATA_OWNER.SESSION_DATA' INTO v_new_row_count;
    
    DBMS_OUTPUT.PUT_LINE('Pre-drop validation:');
    DBMS_OUTPUT.PUT_LINE('  Old table rows: ' || TO_CHAR(v_old_row_count, '999,999,999,999'));
    DBMS_OUTPUT.PUT_LINE('  New table rows: ' || TO_CHAR(v_new_row_count, '999,999,999,999'));
    
    IF v_new_row_count < v_old_row_count THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: New table has fewer rows than old table!');
        DBMS_OUTPUT.PUT_LINE('Difference: ' || (v_old_row_count - v_new_row_count) || ' rows');
        DBMS_OUTPUT.PUT_LINE('Verify migration was successful before dropping old table');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('✓ Pre-drop validation completed');
END;
/

-- Drop the old table with purge (no recycle bin)
PROMPT Dropping table APP_DATA_OWNER.SESSION_DATA_OLD...
DROP TABLE APP_DATA_OWNER.SESSION_DATA_OLD PURGE;

PROMPT ✓ Table APP_DATA_OWNER.SESSION_DATA_OLD dropped successfully

-- Post-drop verification
PROMPT Verifying table removal...
DECLARE
    v_table_count NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_table_count
    FROM all_tables
    WHERE owner = 'APP_DATA_OWNER' AND table_name = 'SESSION_DATA_OLD';
    
    IF v_table_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('✓ Confirmed: Table APP_DATA_OWNER.SESSION_DATA_OLD successfully removed');
    ELSE
        DBMS_OUTPUT.PUT_LINE('ERROR: Table still exists after DROP command');
    END IF;
END;
/

PROMPT ================================================================
PROMPT ✓ DROP OPERATION COMPLETE
PROMPT ================================================================
PROMPT Dropped: APP_DATA_OWNER.SESSION_DATA_OLD
PROMPT Active table: APP_DATA_OWNER.SESSION_DATA
PROMPT Date: 2025-10-25 16:33:49
PROMPT ================================================================