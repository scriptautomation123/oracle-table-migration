-- ==================================================================
-- SWAP CONSTRAINT VALIDATION
-- ==================================================================
-- Usage: @validation/swap_constraint_validation.sql <owner> <table_name> <auto_enable>
-- ==================================================================
-- This script handles constraint validation specifically for table swap operations:
-- 1. Checks for disabled constraints
-- 2. Optionally auto-enables constraints
-- 3. Provides detailed constraint status
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE owner = '&1'
DEFINE table_name = '&2'
DEFINE auto_enable = '&3'

PROMPT =============================================================
PROMPT SWAP CONSTRAINT VALIDATION
PROMPT =============================================================
PROMPT Owner: &owner
PROMPT Table: &table_name
PROMPT Auto-enable: &auto_enable
PROMPT =============================================================

DECLARE
    v_disabled_constraints NUMBER := 0;
    v_enabled_constraints NUMBER := 0;
    v_total_constraints NUMBER := 0;
    v_constraint_enabled_count NUMBER := 0;
    v_constraint_failed_count NUMBER := 0;
    v_auto_enable_flag BOOLEAN;
BEGIN
    -- Parse auto-enable flag
    v_auto_enable_flag := UPPER('&auto_enable') = 'TRUE' OR UPPER('&auto_enable') = 'YES' OR UPPER('&auto_enable') = '1';
    
    DBMS_OUTPUT.PUT_LINE('Checking constraint states for table &owner..&table_name...');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Count total constraints
    SELECT COUNT(*) INTO v_total_constraints
    FROM all_constraints
    WHERE owner = UPPER('&owner')
      AND table_name = UPPER('&table_name')
      AND constraint_type IN ('U', 'P', 'R', 'C');
    
    -- Count disabled constraints
    SELECT COUNT(*) INTO v_disabled_constraints
    FROM all_constraints
    WHERE owner = UPPER('&owner')
      AND table_name = UPPER('&table_name')
      AND constraint_type IN ('U', 'P', 'R', 'C')
      AND status = 'DISABLED';
    
    -- Count enabled constraints
    SELECT COUNT(*) INTO v_enabled_constraints
    FROM all_constraints
    WHERE owner = UPPER('&owner')
      AND table_name = UPPER('&table_name')
      AND constraint_type IN ('U', 'P', 'R', 'C')
      AND status = 'ENABLED';
    
    DBMS_OUTPUT.PUT_LINE('Constraint Summary:');
    DBMS_OUTPUT.PUT_LINE('  Total constraints: ' || v_total_constraints);
    DBMS_OUTPUT.PUT_LINE('  Enabled: ' || v_enabled_constraints);
    DBMS_OUTPUT.PUT_LINE('  Disabled: ' || v_disabled_constraints);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Handle disabled constraints
    IF v_disabled_constraints > 0 THEN
        DBMS_OUTPUT.PUT_LINE('⚠ Found ' || v_disabled_constraints || ' disabled constraint(s)');
        
        IF v_auto_enable_flag THEN
            DBMS_OUTPUT.PUT_LINE('Auto-enabling constraints before swap...');
            DBMS_OUTPUT.PUT_LINE('');
            
            -- Enable constraints in proper order
            FOR c IN (
                SELECT constraint_name, constraint_type
                FROM all_constraints
                WHERE owner = UPPER('&owner')
                  AND table_name = UPPER('&table_name')
                  AND constraint_type IN ('U', 'P', 'R', 'C')
                  AND status = 'DISABLED'
                ORDER BY 
                    CASE constraint_type
                        WHEN 'P' THEN 1  -- Primary key first
                        WHEN 'U' THEN 2  -- Unique
                        WHEN 'C' THEN 3  -- Check
                        WHEN 'R' THEN 4  -- Foreign keys last
                    END
            ) LOOP
                BEGIN
                    EXECUTE IMMEDIATE 'ALTER TABLE &owner.&table_name ENABLE NOVALIDATE CONSTRAINT ' || c.constraint_name;
                    v_constraint_enabled_count := v_constraint_enabled_count + 1;
                    DBMS_OUTPUT.PUT_LINE('  ✓ Enabled ' || 
                        CASE c.constraint_type
                            WHEN 'P' THEN 'PRIMARY KEY'
                            WHEN 'U' THEN 'UNIQUE'
                            WHEN 'R' THEN 'FOREIGN KEY'
                            WHEN 'C' THEN 'CHECK'
                        END || ': ' || c.constraint_name);
                EXCEPTION
                    WHEN OTHERS THEN
                        v_constraint_failed_count := v_constraint_failed_count + 1;
                        DBMS_OUTPUT.PUT_LINE('  ✗ Failed to enable ' || c.constraint_name || ': ' || SQLERRM);
                END;
            END LOOP;
            
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Constraint enabling results:');
            DBMS_OUTPUT.PUT_LINE('  Successfully enabled: ' || v_constraint_enabled_count);
            IF v_constraint_failed_count > 0 THEN
                DBMS_OUTPUT.PUT_LINE('  Failed to enable: ' || v_constraint_failed_count);
                DBMS_OUTPUT.PUT_LINE('  ⚠ Manual intervention may be required for failed constraints');
            END IF;
            
        ELSE
            DBMS_OUTPUT.PUT_LINE('⚠ Auto-enable is disabled');
            DBMS_OUTPUT.PUT_LINE('Cannot proceed with swap: ' || v_disabled_constraints || 
                ' constraint(s) are disabled.');
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('RECOMMENDATIONS:');
            DBMS_OUTPUT.PUT_LINE('1. Enable constraints manually before swap:');
            DBMS_OUTPUT.PUT_LINE('   @validation/enable_constraints.sql &owner &table_name');
            DBMS_OUTPUT.PUT_LINE('2. Or set auto_enable_constraints=true in migration settings');
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: FAILED - Disabled constraints found, auto-enable disabled');
            -- Don't raise exception - let caller handle the failure
        END IF;
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ All constraints are enabled - safe to proceed');
        DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - All constraints enabled');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=============================================================');
    DBMS_OUTPUT.PUT_LINE('✓ Constraint validation completed');
    DBMS_OUTPUT.PUT_LINE('=============================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FATAL ERROR in constraint validation: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: ERROR - ' || SQLERRM);
        -- Don't re-raise - let caller handle the error
END;
/

PROMPT =============================================================
PROMPT Swap constraint validation complete
PROMPT =============================================================
