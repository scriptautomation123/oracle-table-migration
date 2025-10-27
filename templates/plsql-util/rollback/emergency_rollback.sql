-- ==================================================================
-- Emergency Rollback
-- ==================================================================
-- Purpose: Fast emergency rollback when critical issues occur
-- Usage: @emergency_rollback.sql <OWNER> <TABLE_NAME>
-- Author: Migration Team
-- Date: 2025-10-22
-- ==================================================================
-- WARNING: This is for EMERGENCY USE ONLY
-- This script performs minimal validation for speed
-- ==================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 1000
SET VERIFY OFF
SET TIMING ON

ACCEPT p_owner PROMPT 'Enter table owner (or press Enter for current user): '
ACCEPT p_table_name PROMPT 'Enter table name: '
ACCEPT p_confirmation PROMPT 'Type EMERGENCY to confirm emergency rollback: '

DEFINE v_owner = '&p_owner'
DEFINE v_table_name = '&p_table_name'
DEFINE v_confirmation = '&p_confirmation'

-- If owner not provided, use current user
COLUMN current_owner NEW_VALUE v_owner NOPRINT
SELECT NVL('&v_owner', USER) AS current_owner FROM dual;

WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT
PROMPT ================================================================
PROMPT ⚠⚠⚠  EMERGENCY ROLLBACK PROCEDURE  ⚠⚠⚠
PROMPT ================================================================
PROMPT Table: &v_owner..&v_table_name
PROMPT Time: &_DATE
PROMPT ================================================================

DECLARE
    v_confirmation VARCHAR2(20) := UPPER('&v_confirmation');
    v_owner VARCHAR2(128) := UPPER('&v_owner');
    v_table_name VARCHAR2(128) := UPPER('&v_table_name');
    v_old_exists NUMBER;
    v_current_exists NUMBER;
    v_new_exists NUMBER;
    v_temp_name VARCHAR2(128);
    v_start_time TIMESTAMP := SYSTIMESTAMP;
    v_step NUMBER := 0;
    
    PROCEDURE log_step(p_message VARCHAR2) IS
    BEGIN
        v_step := v_step + 1;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('[STEP ' || v_step || '] ' || TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SS.FF3') || ' - ' || p_message);
    END;
    
    PROCEDURE log_info(p_message VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('        ' || p_message);
    END;
    
    PROCEDURE log_error(p_message VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('        ✗ ERROR: ' || p_message);
    END;
    
    PROCEDURE log_success(p_message VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('        ✓ ' || p_message);
    END;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Confirmation check
    IF v_confirmation != 'EMERGENCY' THEN
        log_error('Emergency rollback not confirmed');
        log_error('You must type EMERGENCY to proceed');
        RETURN;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('⚠ EMERGENCY ROLLBACK INITIATED');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ==================================================================
    -- STEP 1: Assess Current State
    -- ==================================================================
    log_step('ASSESSING CURRENT STATE');
    
    SELECT COUNT(*) INTO v_current_exists
    FROM all_tables
    WHERE owner = v_owner AND table_name = v_table_name;
    
    SELECT COUNT(*) INTO v_old_exists
    FROM all_tables
    WHERE owner = v_owner AND table_name = v_table_name || '_OLD';
    
    SELECT COUNT(*) INTO v_new_exists
    FROM all_tables
    WHERE owner = v_owner AND table_name = v_table_name || '_NEW';
    
    log_info('Current table exists: ' || CASE WHEN v_current_exists = 1 THEN 'YES' ELSE 'NO' END);
    log_info('OLD table exists: ' || CASE WHEN v_old_exists = 1 THEN 'YES' ELSE 'NO' END);
    log_info('NEW table exists: ' || CASE WHEN v_new_exists = 1 THEN 'YES' ELSE 'NO' END);
    
    -- ==================================================================
    -- STEP 2: Determine Rollback Strategy
    -- ==================================================================
    log_step('DETERMINING ROLLBACK STRATEGY');
    
    IF v_old_exists = 0 THEN
        log_error('No _OLD table found - cannot perform rollback');
        log_error('Original table may have been dropped already');
        log_error('MANUAL INTERVENTION REQUIRED');
        RAISE_APPLICATION_ERROR(-20001, 'Cannot rollback - no backup table found');
    END IF;
    
    IF v_current_exists = 1 AND v_old_exists = 1 THEN
        log_info('Strategy: Swap current table with OLD table');
    ELSIF v_current_exists = 0 AND v_old_exists = 1 THEN
        log_info('Strategy: Rename OLD table to restore original');
    ELSE
        log_error('Unexpected table state - manual intervention required');
        RAISE_APPLICATION_ERROR(-20002, 'Unexpected table state');
    END IF;
    
    -- ==================================================================
    -- STEP 3: Create Backup of Current State
    -- ==================================================================
    log_step('CREATING SAFETY BACKUP');
    
    IF v_current_exists = 1 THEN
        v_temp_name := v_table_name || '_EMERG_' || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS');
        
        log_info('Renaming current table to: ' || v_temp_name);
        
        EXECUTE IMMEDIATE 'ALTER TABLE ' || v_owner || '.' || v_table_name || 
                         ' RENAME TO ' || v_temp_name;
        
        log_success('Safety backup created: ' || v_temp_name);
    ELSE
        log_info('No current table to backup');
    END IF;
    
    -- ==================================================================
    -- STEP 4: Restore OLD Table
    -- ==================================================================
    log_step('RESTORING ORIGINAL TABLE');
    
    log_info('Renaming ' || v_table_name || '_OLD to ' || v_table_name);
    
    EXECUTE IMMEDIATE 'ALTER TABLE ' || v_owner || '.' || v_table_name || '_OLD' ||
                     ' RENAME TO ' || v_table_name;
    
    log_success('Original table restored to active name');
    
    -- ==================================================================
    -- STEP 5: Verify Rollback
    -- ==================================================================
    log_step('VERIFYING ROLLBACK');
    
    DECLARE
        v_row_count NUMBER;
        v_index_count NUMBER;
        v_invalid_indexes NUMBER := 0;
    BEGIN
        -- Check table access
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_owner || '.' || v_table_name || ' WHERE ROWNUM = 1'
        INTO v_row_count;
        
        log_success('Table is accessible');
        
        -- Check indexes
        SELECT COUNT(*), SUM(CASE WHEN status != 'VALID' THEN 1 ELSE 0 END)
        INTO v_index_count, v_invalid_indexes
        FROM all_indexes
        WHERE table_owner = v_owner
          AND table_name = v_table_name;
        
        log_info('Indexes: ' || v_index_count || ' total, ' || v_invalid_indexes || ' invalid');
        
        IF v_invalid_indexes > 0 THEN
            log_info('⚠ Some indexes may need rebuilding');
        END IF;
    END;
    
    -- ==================================================================
    -- STEP 6: Summary
    -- ==================================================================
    DECLARE
        v_elapsed_seconds NUMBER;
    BEGIN
        v_elapsed_seconds := EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)) +
                            EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_start_time)) * 60;
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('================================================================');
        DBMS_OUTPUT.PUT_LINE('✓ EMERGENCY ROLLBACK COMPLETE');
        DBMS_OUTPUT.PUT_LINE('================================================================');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Time Elapsed: ' || ROUND(v_elapsed_seconds, 2) || ' seconds');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Current State:');
        DBMS_OUTPUT.PUT_LINE('  ✓ ' || v_table_name || ' = Original table (RESTORED)');
        IF v_current_exists = 1 THEN
            DBMS_OUTPUT.PUT_LINE('  ⚠ ' || v_temp_name || ' = Migration table (kept as backup)');
        END IF;
        IF v_new_exists = 1 THEN
            DBMS_OUTPUT.PUT_LINE('  ⚠ ' || v_table_name || '_NEW = Incomplete migration (can be dropped)');
        END IF;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('IMMEDIATE ACTIONS REQUIRED:');
        DBMS_OUTPUT.PUT_LINE('  1. ✓ Verify application connectivity to ' || v_table_name);
        DBMS_OUTPUT.PUT_LINE('  2. ✓ Run smoke tests to ensure functionality');
        DBMS_OUTPUT.PUT_LINE('  3. ✓ Check for data consistency');
        DBMS_OUTPUT.PUT_LINE('  4. ⚠ Review why rollback was necessary');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('CLEANUP (after validation):');
        IF v_current_exists = 1 THEN
            DBMS_OUTPUT.PUT_LINE('  - DROP TABLE ' || v_owner || '.' || v_temp_name || ' CASCADE CONSTRAINTS PURGE;');
        END IF;
        IF v_new_exists = 1 THEN
            DBMS_OUTPUT.PUT_LINE('  - DROP TABLE ' || v_owner || '.' || v_table_name || '_NEW CASCADE CONSTRAINTS PURGE;');
        END IF;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('INVESTIGATION:');
        DBMS_OUTPUT.PUT_LINE('  - Document the reason for emergency rollback');
        DBMS_OUTPUT.PUT_LINE('  - Review alert logs for errors');
        DBMS_OUTPUT.PUT_LINE('  - Analyze what went wrong with the migration');
        DBMS_OUTPUT.PUT_LINE('================================================================');
    END;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('================================================================');
        DBMS_OUTPUT.PUT_LINE('✗ EMERGENCY ROLLBACK FAILED');
        DBMS_OUTPUT.PUT_LINE('================================================================');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('⚠⚠⚠ CRITICAL: MANUAL DBA INTERVENTION REQUIRED ⚠⚠⚠');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Current Table State:');
        DBMS_OUTPUT.PUT_LINE('  Query all_tables to determine current state');
        DBMS_OUTPUT.PUT_LINE('  Look for: ' || v_table_name || ', ' || v_table_name || '_OLD, ' || v_table_name || '_NEW');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Contact senior DBA immediately');
        DBMS_OUTPUT.PUT_LINE('================================================================');
        
        RAISE;
END;
/

UNDEFINE p_owner
UNDEFINE p_table_name
UNDEFINE p_confirmation
UNDEFINE v_owner
UNDEFINE v_table_name
UNDEFINE v_confirmation

PROMPT
PROMPT ================================================================
PROMPT Emergency rollback procedure complete
PROMPT ================================================================
PROMPT Review output above for next steps
PROMPT ================================================================
