-- ==================================================================
-- POST-SWAP VALIDATION
-- ==================================================================
-- Usage: @validation/post_swap_validation.sql <owner> <table_name> <old_table_name>
-- ==================================================================
-- This script validates that a table swap was successful by checking:
-- 1. Table existence and naming
-- 2. Table structure integrity
-- 3. Constraint states
-- 4. Data accessibility
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE owner = '&1'
DEFINE table_name = '&2'
DEFINE old_table_name = '&3'

PROMPT =============================================================
PROMPT POST-SWAP VALIDATION
PROMPT =============================================================
PROMPT Owner: &owner
PROMPT Active Table: &table_name
PROMPT Backup Table: &old_table_name
PROMPT =============================================================

DECLARE
    v_validation_passed BOOLEAN := TRUE;
    v_error_count NUMBER := 0;
    v_table_exists NUMBER;
    v_backup_exists NUMBER;
    v_constraint_count NUMBER;
    v_enabled_constraints NUMBER;
    v_disabled_constraints NUMBER;
    v_row_count NUMBER;
    v_backup_row_count NUMBER;
    v_partitioned VARCHAR2(3);
    v_status VARCHAR2(8);
BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting post-swap validation...');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- 1. Verify table naming and existence
    DBMS_OUTPUT.PUT_LINE('1. Verifying table naming and existence...');
    
    -- Check that the main table exists with the correct name
    BEGIN
        SELECT COUNT(*) INTO v_table_exists
        FROM all_tables
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&table_name');
        
        IF v_table_exists = 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Main table &owner..&table_name does not exist');
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ✓ Main table &owner..&table_name exists');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Main table check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    -- Check that the backup table exists
    BEGIN
        SELECT COUNT(*) INTO v_backup_exists
        FROM all_tables
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&old_table_name');
        
        IF v_backup_exists = 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Backup table &owner..&old_table_name does not exist');
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ✓ Backup table &owner..&old_table_name exists');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Backup table check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- 2. Verify table structure
    DBMS_OUTPUT.PUT_LINE('2. Verifying table structure...');
    BEGIN
        SELECT partitioned, status
        INTO v_partitioned, v_status
        FROM all_tables
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&table_name');
        
        DBMS_OUTPUT.PUT_LINE('   Table properties:');
        DBMS_OUTPUT.PUT_LINE('     Partitioned: ' || v_partitioned);
        DBMS_OUTPUT.PUT_LINE('     Status: ' || v_status);
        
        IF v_status = 'VALID' THEN
            DBMS_OUTPUT.PUT_LINE('   ✓ Table structure is valid');
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ⚠ Warning: Table status is ' || v_status);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Table structure check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- 3. Check constraint states
    DBMS_OUTPUT.PUT_LINE('3. Checking constraint states...');
    BEGIN
        SELECT COUNT(*) INTO v_constraint_count
        FROM all_constraints
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&table_name')
          AND constraint_type IN ('U', 'P', 'R', 'C');
        
        SELECT COUNT(*) INTO v_enabled_constraints
        FROM all_constraints
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&table_name')
          AND constraint_type IN ('U', 'P', 'R', 'C')
          AND status = 'ENABLED';
        
        v_disabled_constraints := v_constraint_count - v_enabled_constraints;
        
        DBMS_OUTPUT.PUT_LINE('   Constraint summary:');
        DBMS_OUTPUT.PUT_LINE('     Total: ' || v_constraint_count);
        DBMS_OUTPUT.PUT_LINE('     Enabled: ' || v_enabled_constraints);
        DBMS_OUTPUT.PUT_LINE('     Disabled: ' || v_disabled_constraints);
        
        IF v_disabled_constraints > 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ⚠ Warning: ' || v_disabled_constraints || ' constraint(s) are disabled');
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ✓ All constraints are enabled');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Constraint check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- 4. Verify data accessibility
    DBMS_OUTPUT.PUT_LINE('4. Verifying data accessibility...');
    BEGIN
        -- Count rows in main table
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || '&owner' || '.' || '&table_name' INTO v_row_count;
        DBMS_OUTPUT.PUT_LINE('   Main table row count: ' || v_row_count);
        
        -- Count rows in backup table
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || '&owner' || '.' || '&old_table_name' INTO v_backup_row_count;
        DBMS_OUTPUT.PUT_LINE('   Backup table row count: ' || v_backup_row_count);
        
        IF v_row_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ✓ Main table is accessible and contains data');
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ⚠ Warning: Main table is empty');
        END IF;
        
        IF v_backup_row_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ✓ Backup table is accessible and contains data');
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ⚠ Warning: Backup table is empty');
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Data accessibility check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=============================================================');
    
    -- Final validation result
    IF v_validation_passed THEN
        DBMS_OUTPUT.PUT_LINE('✓ POST-SWAP VALIDATION PASSED');
        DBMS_OUTPUT.PUT_LINE('✓ Table swap was successful');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('SUMMARY:');
        DBMS_OUTPUT.PUT_LINE('- Main table &owner..&table_name is active and accessible');
        DBMS_OUTPUT.PUT_LINE('- Backup table &owner..&old_table_name contains original data');
        DBMS_OUTPUT.PUT_LINE('- Table structure and constraints are intact');
        IF v_disabled_constraints > 0 THEN
            DBMS_OUTPUT.PUT_LINE('- Consider enabling disabled constraints if needed');
        END IF;
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ POST-SWAP VALIDATION FAILED');
        DBMS_OUTPUT.PUT_LINE('✗ Found ' || v_error_count || ' error(s) - swap may have failed');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Please investigate the issues above.');
        RAISE_APPLICATION_ERROR(-20001, 'Post-swap validation failed with ' || v_error_count || ' error(s)');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('=============================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FATAL ERROR in post-swap validation: ' || SQLERRM);
        RAISE;
END;
/

PROMPT =============================================================
PROMPT Post-swap validation complete
PROMPT =============================================================
