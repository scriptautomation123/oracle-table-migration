-- ==================================================================
-- TABLE SWAP VALIDATION
-- ==================================================================
-- Usage: @validation/table_swap_validation.sql <owner> <table_name> <new_table_name> <old_table_name>
-- ==================================================================
-- This script performs comprehensive validation for table swap operations:
-- 1. Active session checks
-- 2. Table existence validation
-- 3. Constraint state validation
-- 4. Permission checks
-- 5. Pre-swap state verification
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE owner = '&1'
DEFINE table_name = '&2'
DEFINE new_table_name = '&3'
DEFINE old_table_name = '&4'

PROMPT =============================================================
PROMPT TABLE SWAP VALIDATION
PROMPT =============================================================
PROMPT Owner: &owner
PROMPT Original Table: &table_name
PROMPT New Table: &new_table_name
PROMPT Backup Table: &old_table_name
PROMPT =============================================================

DECLARE
    v_validation_passed BOOLEAN := TRUE;
    v_error_count NUMBER := 0;
    v_table_exists NUMBER;
    v_constraint_count NUMBER;
    v_disabled_constraints NUMBER;
    v_enabled_constraints NUMBER;
    v_permission_count NUMBER;
    v_active_sessions NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting comprehensive table swap validation...');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- 1. Check for active sessions using the tables
    DBMS_OUTPUT.PUT_LINE('1. Checking for active sessions...');
    BEGIN
        SELECT COUNT(*) INTO v_active_sessions
        FROM v$session s, v$sqlarea sa
        WHERE s.sql_id = sa.sql_id
          AND (
              UPPER(sa.sql_text) LIKE '%' || UPPER('&table_name') || '%'
              OR UPPER(sa.sql_text) LIKE '%' || UPPER('&new_table_name') || '%'
          )
          AND s.status = 'ACTIVE'
          AND s.username IS NOT NULL;
        
        IF v_active_sessions > 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Found ' || v_active_sessions || ' active session(s) using the tables');
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ✓ No active sessions found');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Active session check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- 2. Check table existence
    DBMS_OUTPUT.PUT_LINE('2. Checking table existence...');
    
    -- Check original table exists
    BEGIN
        SELECT COUNT(*) INTO v_table_exists
        FROM all_tables
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&table_name');
        
        IF v_table_exists = 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Original table &owner..&table_name does not exist');
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ✓ Original table &owner..&table_name exists');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Original table check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    -- Check new table exists
    BEGIN
        SELECT COUNT(*) INTO v_table_exists
        FROM all_tables
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&new_table_name');
        
        IF v_table_exists = 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ New table &owner..&new_table_name does not exist');
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ✓ New table &owner..&new_table_name exists');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ New table check failed: ' || SQLERRM);
            v_validation_passed := FALSE;
            v_error_count := v_error_count + 1;
    END;
    
    -- Check backup table doesn't exist (should be clean)
    BEGIN
        SELECT COUNT(*) INTO v_table_exists
        FROM all_tables
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&old_table_name');
        
        IF v_table_exists > 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ⚠ Warning: Backup table &owner..&old_table_name already exists');
            DBMS_OUTPUT.PUT_LINE('   This may indicate a previous failed swap operation');
        ELSE
            DBMS_OUTPUT.PUT_LINE('   ✓ Backup table name &owner..&old_table_name is available');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('   ✗ Backup table check failed: ' || SQLERRM);
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
        
        SELECT COUNT(*) INTO v_disabled_constraints
        FROM all_constraints
        WHERE owner = UPPER('&owner')
          AND table_name = UPPER('&table_name')
          AND constraint_type IN ('U', 'P', 'R', 'C')
          AND status = 'DISABLED';
        
        v_enabled_constraints := v_constraint_count - v_disabled_constraints;
        
        DBMS_OUTPUT.PUT_LINE('   Original table constraints:');
        DBMS_OUTPUT.PUT_LINE('     Total: ' || v_constraint_count);
        DBMS_OUTPUT.PUT_LINE('     Enabled: ' || v_enabled_constraints);
        DBMS_OUTPUT.PUT_LINE('     Disabled: ' || v_disabled_constraints);
        
        IF v_disabled_constraints > 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ⚠ Warning: ' || v_disabled_constraints || ' constraint(s) are disabled');
            DBMS_OUTPUT.PUT_LINE('   Consider enabling constraints before swap');
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
          AND table_name = UPPER('&table_name')
          AND grantee = USER;
        
        IF v_permission_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('   ✓ User has ' || v_permission_count || ' permission(s) on &owner..&table_name');
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
        DBMS_OUTPUT.PUT_LINE('✓ Safe to proceed with table swap');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('RECOMMENDATIONS:');
        IF v_disabled_constraints > 0 THEN
            DBMS_OUTPUT.PUT_LINE('- Consider enabling disabled constraints before swap');
        END IF;
        DBMS_OUTPUT.PUT_LINE('- Ensure you have a backup of critical data');
        DBMS_OUTPUT.PUT_LINE('- Test the swap in a non-production environment first');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ VALIDATION FAILED');
        DBMS_OUTPUT.PUT_LINE('✗ Found ' || v_error_count || ' error(s) - swap not safe');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Please resolve the issues above before proceeding.');
        RAISE_APPLICATION_ERROR(-20001, 'Table swap validation failed with ' || v_error_count || ' error(s)');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('=============================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FATAL ERROR in validation: ' || SQLERRM);
        RAISE;
END;
/

PROMPT =============================================================
PROMPT Table swap validation complete
PROMPT =============================================================
