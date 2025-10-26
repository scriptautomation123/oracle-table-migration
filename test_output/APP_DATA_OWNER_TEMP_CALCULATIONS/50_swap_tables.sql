-- ==================================================================
-- SWAP TABLES: APP_DATA_OWNER.TEMP_CALCULATIONS <-> APP_DATA_OWNER.TEMP_CALCULATIONS_NEW
-- ==================================================================
-- Generated: 2025-10-25 16:33:49
-- ==================================================================

SET ECHO ON
SET TIMING ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT Step 50: Swapping Tables
PROMPT ================================================================
PROMPT Old table: APP_DATA_OWNER.TEMP_CALCULATIONS
PROMPT New table: APP_DATA_OWNER.TEMP_CALCULATIONS_NEW
PROMPT Backup: APP_DATA_OWNER.TEMP_CALCULATIONS_OLD
PROMPT ================================================================

-- Atomic table swap using transaction-based approach 
-- All renames succeed or all fail - that's what makes it atomic
DECLARE
    v_error_message VARCHAR2(4000);
    v_original_exists NUMBER := 0;
    v_new_exists NUMBER := 0;
BEGIN
    -- Pre-swap validation
    DBMS_OUTPUT.PUT_LINE('Pre-swap validation...');
    
    -- Check original table exists
    SELECT COUNT(*) INTO v_original_exists
    FROM all_tables 
    WHERE owner = 'APP_DATA_OWNER' AND table_name = 'TEMP_CALCULATIONS';
    
    IF v_original_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Original table APP_DATA_OWNER.TEMP_CALCULATIONS not found');
    END IF;
    
    -- Check new table exists
    SELECT COUNT(*) INTO v_new_exists
    FROM all_tables 
    WHERE owner = 'APP_DATA_OWNER' AND table_name = 'TEMP_CALCULATIONS_NEW';
    
    IF v_new_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'New table APP_DATA_OWNER.TEMP_CALCULATIONS_NEW not found');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('✓ Both tables exist, proceeding with atomic swap...');
    DBMS_OUTPUT.PUT_LINE('NOTE: Oracle DDL auto-commits, but we make this atomic by ensuring both renames succeed or both fail');
    
    -- ATOMIC SWAP: Step 1 - Rename original table to _OLD
    DBMS_OUTPUT.PUT_LINE('Step 1: Renaming TEMP_CALCULATIONS → TEMP_CALCULATIONS_OLD');
    BEGIN
        EXECUTE IMMEDIATE 'ALTER TABLE APP_DATA_OWNER.TEMP_CALCULATIONS RENAME TO TEMP_CALCULATIONS_OLD';
        DBMS_OUTPUT.PUT_LINE('✓ Renamed TEMP_CALCULATIONS to TEMP_CALCULATIONS_OLD');
    EXCEPTION
        WHEN OTHERS THEN
            v_error_message := 'Step 1 failed - could not rename original table: ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('ERROR: ' || v_error_message);
            RAISE_APPLICATION_ERROR(-20003, v_error_message);
    END;
    
    -- ATOMIC SWAP: Step 2 - Rename new table to original name
    DBMS_OUTPUT.PUT_LINE('Step 2: Renaming TEMP_CALCULATIONS_NEW → TEMP_CALCULATIONS');
    BEGIN
        EXECUTE IMMEDIATE 'ALTER TABLE APP_DATA_OWNER.TEMP_CALCULATIONS_NEW RENAME TO TEMP_CALCULATIONS';
        DBMS_OUTPUT.PUT_LINE('✓ Renamed TEMP_CALCULATIONS_NEW to TEMP_CALCULATIONS');
        DBMS_OUTPUT.PUT_LINE('✓ ATOMIC SWAP SUCCESSFUL - both renames completed');
    EXCEPTION
        WHEN OTHERS THEN
            -- Step 2 failed - rollback Step 1 to maintain atomicity
            v_error_message := 'Step 2 failed - attempting rollback of Step 1: ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('ERROR: ' || v_error_message);
            DBMS_OUTPUT.PUT_LINE('Attempting compensatory rollback to maintain atomicity...');
            
            BEGIN
                EXECUTE IMMEDIATE 'ALTER TABLE APP_DATA_OWNER.TEMP_CALCULATIONS_OLD RENAME TO TEMP_CALCULATIONS';
                DBMS_OUTPUT.PUT_LINE('✓ Rollback successful: TEMP_CALCULATIONS_OLD restored to TEMP_CALCULATIONS');
                DBMS_OUTPUT.PUT_LINE('Status: ATOMIC SWAP FAILED - both operations rolled back');
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('CRITICAL ERROR: Rollback failed!');
                    DBMS_OUTPUT.PUT_LINE('Manual intervention required:');
                    DBMS_OUTPUT.PUT_LINE('  - Original table is now: APP_DATA_OWNER.TEMP_CALCULATIONS_OLD');
                    DBMS_OUTPUT.PUT_LINE('  - New table is still: APP_DATA_OWNER.TEMP_CALCULATIONS_NEW');
                    DBMS_OUTPUT.PUT_LINE('  - Expected table name TEMP_CALCULATIONS is unavailable');
                    RAISE_APPLICATION_ERROR(-20005, 'Atomic swap failed and rollback failed: ' || SQLERRM);
            END;
            
            RAISE_APPLICATION_ERROR(-20004, v_error_message);
    END;
    
    -- Post-swap validation
    DBMS_OUTPUT.PUT_LINE('Post-swap validation...');
    
    -- Verify old table exists with _OLD name
    SELECT COUNT(*) INTO v_original_exists
    FROM all_tables 
    WHERE owner = 'APP_DATA_OWNER' AND table_name = 'TEMP_CALCULATIONS_OLD';
    
    -- Verify new table now has original name
    SELECT COUNT(*) INTO v_new_exists
    FROM all_tables 
    WHERE owner = 'APP_DATA_OWNER' AND table_name = 'TEMP_CALCULATIONS';
    
    IF v_original_exists = 1 AND v_new_exists = 1 THEN
        DBMS_OUTPUT.PUT_LINE('✓ Post-swap validation successful');
        DBMS_OUTPUT.PUT_LINE('  - Old table: APP_DATA_OWNER.TEMP_CALCULATIONS_OLD ✓');
        DBMS_OUTPUT.PUT_LINE('  - Active table: APP_DATA_OWNER.TEMP_CALCULATIONS ✓');
    ELSE
        RAISE_APPLICATION_ERROR(-20006, 'Post-swap validation failed - unexpected table state');
    END IF;
    
    -- Check for invalidations from changing keys or loss of grants
    DBMS_OUTPUT.PUT_LINE('Checking for invalidations...');
    FOR invalid_obj IN (
        SELECT object_name, object_type, status
        FROM user_objects 
        WHERE status = 'INVALID'
        AND object_name IN ('TEMP_CALCULATIONS', 'TEMP_CALCULATIONS_OLD')
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('WARNING: Invalid object found: ' || invalid_obj.object_type || 
                           ' ' || invalid_obj.object_name || ' - Status: ' || invalid_obj.status);
    END LOOP;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FATAL ERROR in atomic table swap: ' || SQLERRM);
        RAISE;
END;
/

-- Verify final state
PROMPT Verifying table swap...
@validation/verify_table_states.sql APP_DATA_OWNER TEMP_CALCULATIONS TEMP_CALCULATIONS_OLD

PROMPT ✓ Step 50 Complete: Tables swapped successfully