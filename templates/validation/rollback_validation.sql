-- ==================================================================
-- ROLLBACK VALIDATION
-- ==================================================================
-- Usage: @validation/rollback_validation.sql <owner> <table_name> <old_table_name> <new_table_name>
-- ==================================================================
-- This script validates the state after a failed table swap and provides
-- rollback recommendations by checking:
-- 1. Current table states
-- 2. Data integrity
-- 3. Rollback options
-- 4. Recovery recommendations
-- ==================================================================
SET SERVEROUTPUT ON
SET VERVERIFY OFF

DEFINE owner = '&1'
DEFINE table_name = '&2'
DEFINE old_table_name = '&3'
DEFINE new_table_name = '&4'

PROMPT =============================================================
PROMPT ROLLBACK VALIDATION
PROMPT =============================================================
PROMPT Owner: &owner
PROMPT Target Table: &table_name
PROMPT Backup Table: &old_table_name
PROMPT New Table: &new_table_name
PROMPT =============================================================

DECLARE
    v_validation_passed BOOLEAN := TRUE;
    v_error_count NUMBER := 0;
    v_table_exists NUMBER;
    v_backup_exists NUMBER;
    v_new_exists NUMBER;
    v_row_count NUMBER;
    v_backup_row_count NUMBER;
    v_new_row_count NUMBER;
    v_rollback_possible BOOLEAN := FALSE;
    v_rollback_recommended BOOLEAN := FALSE;
    v_current_state VARCHAR2(100);
BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting rollback validation...');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- 1. Check current table states
    DBMS_OUTPUT.PUT_LINE('1. Checking current table states...');
    
    -- Check target table
    BEGIN
        SELECT COUNT(*) INTO v_table_exists
        FROM all_tables
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&table_name');
        
        IF v_table_exists > 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ✓ Target table &owner..&table_name exists');
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ✗ Target table &owner..&table_name does not exist');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Target table check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    -- Check backup table
    BEGIN
        SELECT COUNT(*) INTO v_backup_exists
        FROM all_tables
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&old_table_name');
        
        IF v_backup_exists > 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ✓ Backup table &owner..&old_table_name exists');
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ✗ Backup table &owner..&old_table_name does not exist');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Backup table check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    -- Check new table
    BEGIN
        SELECT COUNT(*) INTO v_new_exists
        FROM all_tables
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&new_table_name');
        
        IF v_new_exists > 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ✓ New table &owner..&new_table_name exists');
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ✗ New table &owner..&new_table_name does not exist');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ New table check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- 2. Determine current state
    DBMS_OUTPUT.PUT_LINE('2. Determining current state...');
    
    IF v_table_exists > 0 AND v_backup_exists > 0 AND v_new_exists > 0 THEN
        v_current_state := 'ALL_TABLES_EXIST';
        DBMS_OUTPUT.PUT_LINE('   State: All tables exist (swap may have failed)');
        v_rollback_recommended := TRUE;
    ELSIF v_table_exists = 0 AND v_backup_exists > 0 AND v_new_exists > 0 THEN
        v_current_state := 'SWAP_INCOMPLETE';
        DBMS_OUTPUT.PUT_LINE('   State: Swap incomplete (target table missing)');
        v_rollback_recommended := TRUE;
        v_rollback_possible := TRUE;
    ELSIF v_table_exists > 0 AND v_backup_exists = 0 AND v_new_exists > 0 THEN
        v_current_state := 'PARTIAL_SWAP';
        DBMS_OUTPUT.PUT_LINE('   State: Partial swap (backup table missing)');
        v_rollback_recommended := TRUE;
    ELSIF v_table_exists > 0 AND v_backup_exists > 0 AND v_new_exists = 0 THEN
        v_current_state := 'SWAP_SUCCESS';
        DBMS_OUTPUT.PUT_LINE('   State: Swap appears successful');
        v_rollback_recommended := FALSE;
    ELSE
        v_current_state := 'UNKNOWN';
        DBMS_OUTPUT.PUT_LINE('   State: Unknown (unexpected table configuration)');
        v_rollback_recommended := TRUE;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- 3. Check data integrity
    DBMS_OUTPUT.PUT_LINE('3. Checking data integrity...');
    
    -- Count rows in each table
    BEGIN
        IF v_table_exists > 0 THEN
            EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || '&owner' || '.' || '&table_name' INTO v_row_count;
            DBMS_OUTPUT.PUT_LINE('   Target table row count: ' || v_row_count);
        END IF;
        
        IF v_backup_exists > 0 THEN
            EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || '&owner' || '.' || '&old_table_name' INTO v_backup_row_count;
            DBMS_OUTPUT.PUT_LINE('   Backup table row count: ' || v_backup_row_count);
        END IF;
        
        IF v_new_exists > 0 THEN
            EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || '&owner' || '.' || '&new_table_name' INTO v_new_row_count;
            DBMS_OUTPUT.PUT_LINE('   New table row count: ' || v_new_row_count);
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Data integrity check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=============================================================');
    
    -- 4. Provide rollback recommendations
    DBMS_OUTPUT.PUT_LINE('4. ROLLBACK RECOMMENDATIONS:');
    DBMS_OUTPUT.PUT_LINE('');
    
    IF v_current_state = 'SWAP_INCOMPLETE' THEN
        DBMS_OUTPUT.PUT_LINE('RECOMMENDED ACTION: Complete the rollback');
        DBMS_OUTPUT.PUT_LINE('  ALTER TABLE &owner..&old_table_name RENAME TO &table_name;');
        DBMS_OUTPUT.PUT_LINE('  DROP TABLE &owner..&new_table_name;');
        v_rollback_possible := TRUE;
    ELSIF v_current_state = 'ALL_TABLES_EXIST' THEN
        DBMS_OUTPUT.PUT_LINE('RECOMMENDED ACTION: Clean up and retry');
        DBMS_OUTPUT.PUT_LINE('  DROP TABLE &owner..&new_table_name;');
        DBMS_OUTPUT.PUT_LINE('  ALTER TABLE &owner..&old_table_name RENAME TO &table_name;');
        v_rollback_possible := TRUE;
    ELSIF v_current_state = 'PARTIAL_SWAP' THEN
        DBMS_OUTPUT.PUT_LINE('RECOMMENDED ACTION: Investigate and restore from backup');
        DBMS_OUTPUT.PUT_LINE('  Check if backup table contains original data');
        DBMS_OUTPUT.PUT_LINE('  Consider restoring from database backup if needed');
    ELSIF v_current_state = 'SWAP_SUCCESS' THEN
        DBMS_OUTPUT.PUT_LINE('RECOMMENDED ACTION: No rollback needed');
        DBMS_OUTPUT.PUT_LINE('  Swap appears to have completed successfully');
        DBMS_OUTPUT.PUT_LINE('  Backup table &owner..&old_table_name can be dropped if no longer needed');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RECOMMENDED ACTION: Manual investigation required');
        DBMS_OUTPUT.PUT_LINE('  Current state is unexpected - manual intervention needed');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=============================================================');
    
    -- Final validation result
    IF v_validation_passed THEN
        DBMS_OUTPUT.PUT_LINE('✓ ROLLBACK VALIDATION COMPLETED');
        DBMS_OUTPUT.PUT_LINE('Current state: ' || v_current_state);
        
        IF v_rollback_recommended THEN
            DBMS_OUTPUT.PUT_LINE('⚠ Rollback is recommended');
        ELSE
            DBMS_OUTPUT.PUT_LINE('✓ No rollback needed');
        END IF;
        
        IF v_rollback_possible THEN
            DBMS_OUTPUT.PUT_LINE('✓ Rollback is possible');
        ELSE
            DBMS_OUTPUT.PUT_LINE('⚠ Rollback may not be possible - manual intervention required');
        END IF;
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ ROLLBACK VALIDATION FAILED');
        DBMS_OUTPUT.PUT_LINE('✗ Found ' || v_error_count || ' error(s)');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Manual investigation required.');
        RAISE_APPLICATION_ERROR(-20001, 'Rollback validation failed with ' || v_error_count || ' error(s)');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('=============================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FATAL ERROR in rollback validation: ' || SQLERRM);
        RAISE;
END;
/

PROMPT =============================================================
PROMPT Rollback validation complete
PROMPT =============================================================
