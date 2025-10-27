-- ==================================================================
-- UNIFIED VALIDATION SCRIPT - WRITE OPERATIONS
-- ==================================================================
-- Usage: @validation/01_validator_write.sql <operation> <args...>
-- ==================================================================
-- Operations (WRITE - MODIFIES DATA/SCHEMA):
--   enable_constraints <owner> <table_name>
--   disable_constraints <owner> <table_name>
-- ==================================================================
-- NOTE: This script MODIFIES schema and data
-- For read-only operations, use 01_validator_readonly.sql
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE operation = '&1'
DEFINE owner = '&2'
DEFINE table_name = '&3'
DEFINE arg4 = '&4'
DEFINE arg5 = '&5'

PROMPT =============================================================
PROMPT UNIFIED VALIDATOR (WRITE) - Operation: &operation
PROMPT WARNING: This operation will modify the database
PROMPT =============================================================

DECLARE
    v_result BOOLEAN := TRUE;
    v_count NUMBER;
    v_msg VARCHAR2(4000);
BEGIN
    CASE UPPER('&operation')
        WHEN 'ENABLE_CONSTRAINTS' THEN
            -- Enable all constraints (WRITE OPERATION)
            DECLARE
                v_disabled_count NUMBER;
                v_total_count NUMBER;
            BEGIN
                SELECT COUNT(*) INTO v_total_count
                FROM all_constraints
                WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name')
                  AND constraint_type IN ('U', 'P', 'R', 'C');
                
                SELECT COUNT(*) INTO v_disabled_count
                FROM all_constraints
                WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name')
                  AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'DISABLED';
                
                DBMS_OUTPUT.PUT_LINE('Total constraints: ' || v_total_count);
                DBMS_OUTPUT.PUT_LINE('Currently disabled: ' || v_disabled_count);
                
                -- Enable all disabled constraints
                FOR c IN (
                    SELECT constraint_name, constraint_type
                    FROM all_constraints
                    WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name')
                      AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'DISABLED'
                    ORDER BY CASE constraint_type WHEN 'P' THEN 1 WHEN 'U' THEN 2 WHEN 'C' THEN 3 WHEN 'R' THEN 4 END
                ) LOOP
                    BEGIN
                        EXECUTE IMMEDIATE 'ALTER TABLE ' || UPPER('&owner') || '.' || UPPER('&table_name') || 
                                         ' ENABLE NOVALIDATE CONSTRAINT ' || c.constraint_name;
                        DBMS_OUTPUT.PUT_LINE('  Enabled: ' || c.constraint_name || ' (' || c.constraint_type || ')');
                    EXCEPTION
                        WHEN OTHERS THEN
                            DBMS_OUTPUT.PUT_LINE('  Failed: ' || c.constraint_name || ' - ' || SQLERRM);
                    END;
                END LOOP;
                
                DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: COMPLETED - Constraints enabled');
            END;
            
        WHEN 'DISABLE_CONSTRAINTS' THEN
            -- Disable all constraints (WRITE OPERATION)
            DECLARE
                v_enabled_count NUMBER;
                v_total_count NUMBER;
            BEGIN
                SELECT COUNT(*) INTO v_total_count
                FROM all_constraints
                WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name')
                  AND constraint_type IN ('U', 'P', 'R', 'C');
                
                SELECT COUNT(*) INTO v_enabled_count
                FROM all_constraints
                WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name')
                  AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'ENABLED';
                
                DBMS_OUTPUT.PUT_LINE('Total constraints: ' || v_total_count);
                DBMS_OUTPUT.PUT_LINE('Currently enabled: ' || v_enabled_count);
                
                -- Disable all constraints
                FOR c IN (
                    SELECT constraint_name, constraint_type
                    FROM all_constraints
                    WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name')
                      AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'ENABLED'
                    ORDER BY CASE constraint_type WHEN 'R' THEN 1 WHEN 'C' THEN 2 WHEN 'U' THEN 3 WHEN 'P' THEN 4 END
                ) LOOP
                    BEGIN
                        EXECUTE IMMEDIATE 'ALTER TABLE ' || UPPER('&owner') || '.' || UPPER('&table_name') || 
                                         ' DISABLE CONSTRAINT ' || c.constraint_name;
                        DBMS_OUTPUT.PUT_LINE('  Disabled: ' || c.constraint_name || ' (' || c.constraint_type || ')');
                    EXCEPTION
                        WHEN OTHERS THEN
                            DBMS_OUTPUT.PUT_LINE('  Failed: ' || c.constraint_name || ' - ' || SQLERRM);
                    END;
                END LOOP;
                
                DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: COMPLETED - Constraints disabled');
            END;
            
        ELSE
            DBMS_OUTPUT.PUT_LINE('ERROR: Unknown operation: &operation');
            DBMS_OUTPUT.PUT_LINE('Valid operations: enable_constraints, disable_constraints');
            v_result := FALSE;
    END CASE;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: ERROR - ' || SQLERRM);
        v_result := FALSE;
END;
/

PROMPT =============================================================
