-- ==================================================================
-- PRE-OPERATION VALIDATION CHECKS
-- ==================================================================
-- Usage: @validation/pre_operation_checks.sql <owner> <table_name1> [table_name2] [table_name3]
-- ==================================================================
-- This script performs comprehensive pre-operation validation including:
-- 1. Active session checks
-- 2. Table existence validation
-- 3. Constraint state validation
-- 4. Permission checks
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE owner = '&1'
DEFINE table_name1 = '&2'
DEFINE table_name2 = '&3'
DEFINE table_name3 = '&4'

PROMPT =============================================================
PROMPT PRE-OPERATION VALIDATION CHECKS
PROMPT =============================================================
PROMPT Owner: &owner
PROMPT Tables: &table_name1 &table_name2 &table_name3
PROMPT =============================================================

DECLARE
    v_validation_passed BOOLEAN := TRUE;
    v_error_count NUMBER := 0;
    v_table_exists NUMBER;
    v_constraint_count NUMBER;
    v_disabled_constraints NUMBER;
    v_permission_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting comprehensive pre-operation validation...');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- 1. Check for active sessions
    DBMS_OUTPUT.PUT_LINE('1. Checking for active sessions...');
    BEGIN
        @validation/check_active_sessions.sql &owner &table_name1 &table_name2 &table_name3
        DBMS_OUTPUT.PUT_LINE('   ✓ Active session check passed');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Active session check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- 2. Check table existence
    DBMS_OUTPUT.PUT_LINE('2. Checking table existence...');
    BEGIN
        SELECT COUNT(*) INTO v_table_exists
        FROM all_tables
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&table_name1');
        
        IF v_table_exists = 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Table &owner..&table_name1 does not exist');
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ✓ Table &owner..&table_name1 exists');
        END IF;
        
        -- Check additional tables if specified
        IF '&table_name2' IS NOT NULL AND '&table_name2' != '' THEN
            SELECT COUNT(*) INTO v_table_exists
            FROM all_tables
            WHERE owner = UPPER('&owner')
              AND table_name = UPPER('&table_name2');
            
            IF v_table_exists = 0 THEN
                DBMS_OUTPUT.PUT_LINE('   ✗ Table &owner..&table_name2 does not exist');
                v_validation_passed := FALSE;
                v_error_count := v_error_count + 1;
            ELSE
                DBMS_OUTPUT.PUT_LINE('   ✓ Table &owner..&table_name2 exists');
            END IF;
        END IF;
        
        IF '&table_name3' IS NOT NULL AND '&table_name3' != '' THEN
            SELECT COUNT(*) INTO v_table_exists
            FROM all_tables
            WHERE owner = UPPER('&owner')
              AND table_name = UPPER('&table_name3');
            
            IF v_table_exists = 0 THEN
                DBMS_OUTPUT.PUT_LINE('   ✗ Table &owner..&table_name3 does not exist');
                v_validation_passed := FALSE;
                v_error_count := v_error_count + 1;
            ELSE
                DBMS_OUTPUT.PUT_LINE('   ✓ Table &owner..&table_name3 exists');
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Table existence check failed: ' || SQLERRM);
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
          AND table_name = UPPER('&table_name1')
          AND constraint_type IN ('U', 'P', 'R', 'C');
        
        SELECT COUNT(*) INTO v_disabled_constraints
        FROM all_constraints
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&table_name1')
          AND constraint_type IN ('U', 'P', 'R', 'C')
          AND status = 'DISABLED';
        
        DBMS_OUTPUT.PUT_LINE('   Table &owner..&table_name1 constraints:');
        DBMS_OUTPUT.PUT_LINE('     Total: ' || v_constraint_count);
        DBMS_OUTPUT.PUT_LINE('     Disabled: ' || v_disabled_constraints);
        DBMS_OUTPUT.PUT_LINE('     Enabled: ' || (v_constraint_count - v_disabled_constraints));
        
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
    
    -- 4. Check permissions
    DBMS_OUTPUT.PUT_LINE('4. Checking permissions...');
    BEGIN
        SELECT COUNT(*) INTO v_permission_count
        FROM all_tab_privs
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&table_name1')
          AND grantee = USER;
        
        IF v_permission_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ✓ User has ' || v_permission_count || ' permission(s) on &owner..&table_name1');
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ⚠ Warning: No explicit permissions found (may be owner or have system privileges)');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Permission check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=============================================================');
    
    -- Final validation result
    IF v_validation_passed THEN
        DBMS_OUTPUT.PUT_LINE('✓ ALL VALIDATION CHECKS PASSED');
        DBMS_OUTPUT.PUT_LINE('✓ Safe to proceed with operation');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ VALIDATION FAILED');
        DBMS_OUTPUT.PUT_LINE('✗ Found ' || v_error_count || ' error(s) - operation not safe');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Please resolve the issues above before proceeding.');
        RAISE_APPLICATION_ERROR(-20001, 'Pre-operation validation failed with ' || v_error_count || ' error(s)');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('=============================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FATAL ERROR in validation: ' || SQLERRM);
        RAISE;
END;
/

PROMPT =============================================================
PROMPT Pre-operation validation complete
PROMPT =============================================================
