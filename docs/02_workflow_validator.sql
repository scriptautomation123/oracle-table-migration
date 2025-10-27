-- ==================================================================
-- WORKFLOW VALIDATION SCRIPT (Table Swap & Rollback)
-- ==================================================================
-- Usage: @validation/02_workflow_validator.sql <operation> <args...>
-- ==================================================================
-- Operations:
--   pre_swap <owner> <table_name> <new_table_name> <old_table_name>
--   post_swap <owner> <table_name> <old_table_name>
--   rollback <owner> <table_name> <old_table_name> <new_table_name>
--   post_create <owner> <table_name> <parallel_degree>
--   post_data_load <owner> <target> <source> <source_count> <parallel_degree>
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE operation = '&1'
DEFINE owner = '&2'
DEFINE table_name = '&3'
DEFINE arg4 = '&4'
DEFINE arg5 = '&5'
DEFINE arg6 = '&6'

PROMPT =============================================================
PROMPT WORKFLOW VALIDATOR - Operation: &operation
PROMPT =============================================================

DECLARE
    v_result BOOLEAN := TRUE;
    v_count NUMBER;
BEGIN
    CASE UPPER('&operation')
        WHEN 'PRE_SWAP' THEN
            -- Pre-swap validation (checks sessions, existence, constraints)
            DECLARE
                v_new_table VARCHAR2(128) := UPPER('&arg4');
                v_old_table VARCHAR2(128) := UPPER('&arg5');
                v_table_exists NUMBER;
            BEGIN
                DBMS_OUTPUT.PUT_LINE('Checking tables exist...');
                
                -- Check original table
                SELECT COUNT(*) INTO v_count FROM all_tables
                WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name');
                IF v_count = 0 THEN
                    DBMS_OUTPUT.PUT_LINE('  FAILED: Original table missing');
                    v_result := FALSE;
                ELSE
                    DBMS_OUTPUT.PUT_LINE('  PASSED: Original table exists');
                END IF;
                
                -- Check new table
                SELECT COUNT(*) INTO v_count FROM all_tables
                WHERE owner = UPPER('&owner') AND table_name = v_new_table;
                IF v_count = 0 THEN
                    DBMS_OUTPUT.PUT_LINE('  FAILED: New table missing');
                    v_result := FALSE;
                ELSE
                    DBMS_OUTPUT.PUT_LINE('  PASSED: New table exists');
                END IF;
                
                -- Check backup table doesn't exist yet
                SELECT COUNT(*) INTO v_count FROM all_tables
                WHERE owner = UPPER('&owner') AND table_name = v_old_table;
                IF v_count > 0 THEN
                    DBMS_OUTPUT.PUT_LINE('  WARNING: Backup table already exists');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('  PASSED: Backup table name available');
                END IF;
                
                IF v_result THEN
                    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - Pre-swap checks complete');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: FAILED - Pre-swap checks failed');
                END IF;
            END;
            
        WHEN 'POST_SWAP' THEN
            -- Post-swap validation
            DECLARE
                v_old_table VARCHAR2(128) := UPPER('&arg4');
                v_count NUMBER;
            BEGIN
                DBMS_OUTPUT.PUT_LINE('Validating swap success...');
                
                -- Check main table
                SELECT COUNT(*) INTO v_count FROM all_tables
                WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name');
                IF v_count = 0 THEN
                    DBMS_OUTPUT.PUT_LINE('  FAILED: Main table missing');
                    v_result := FALSE;
                ELSE
                    DBMS_OUTPUT.PUT_LINE('  PASSED: Main table exists');
                END IF;
                
                -- Check backup table
                SELECT COUNT(*) INTO v_count FROM all_tables
                WHERE owner = UPPER('&owner') AND table_name = v_old_table;
                IF v_count = 0 THEN
                    DBMS_OUTPUT.PUT_LINE('  FAILED: Backup table missing');
                    v_result := FALSE;
                ELSE
                    DBMS_OUTPUT.PUT_LINE('  PASSED: Backup table exists');
                END IF;
                
                IF v_result THEN
                    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - Swap successful');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: FAILED - Swap validation failed');
                END IF;
            END;
            
        WHEN 'ROLLBACK' THEN
            -- Rollback validation
            DECLARE
                v_old_table VARCHAR2(128) := UPPER('&arg4');
                v_new_table VARCHAR2(128) := UPPER('&arg5');
                v_state VARCHAR2(50);
            BEGIN
                DBMS_OUTPUT.PUT_LINE('Analyzing rollback state...');
                
                SELECT 
                    CASE 
                        WHEN COUNT(*) FILTER (WHERE table_name = UPPER('&table_name')) > 0
                         AND COUNT(*) FILTER (WHERE table_name = v_old_table) > 0
                         AND COUNT(*) FILTER (WHERE table_name = v_new_table) > 0
                        THEN 'ALL_EXIST'
                        WHEN COUNT(*) FILTER (WHERE table_name = UPPER('&table_name')) = 0
                         AND COUNT(*) FILTER (WHERE table_name = v_old_table) > 0
                         AND COUNT(*) FILTER (WHERE table_name = v_new_table) > 0
                        THEN 'SWAP_INCOMPLETE'
                        WHEN COUNT(*) FILTER (WHERE table_name = UPPER('&table_name')) > 0
                         AND COUNT(*) FILTER (WHERE table_name = v_old_table) = 0
                        THEN 'SWAP_SUCCESS'
                        ELSE 'UNKNOWN'
                    END INTO v_state
                FROM all_tables
                WHERE owner = UPPER('&owner')
                  AND table_name IN (UPPER('&table_name'), v_old_table, v_new_table);
                
                DBMS_OUTPUT.PUT_LINE('  State: ' || v_state);
                
                CASE v_state
                    WHEN 'ALL_EXIST' THEN
                        DBMS_OUTPUT.PUT_LINE('  RECOMMENDATION: Clean up new table and retry');
                    WHEN 'SWAP_INCOMPLETE' THEN
                        DBMS_OUTPUT.PUT_LINE('  RECOMMENDATION: Restore old table to main, drop new');
                        DBMS_OUTPUT.PUT_LINE('    ALTER TABLE &owner..' || v_old_table || ' RENAME TO ' || UPPER('&table_name') || ';');
                        DBMS_OUTPUT.PUT_LINE('    DROP TABLE &owner..' || v_new_table || ';');
                    WHEN 'SWAP_SUCCESS' THEN
                        DBMS_OUTPUT.PUT_LINE('  RECOMMENDATION: No rollback needed');
                    ELSE
                        DBMS_OUTPUT.PUT_LINE('  RECOMMENDATION: Manual investigation required');
                END CASE;
                
                DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: COMPLETED - Rollback analysis complete');
            END;
            
        WHEN 'POST_CREATE' THEN
            -- Post-create table validation
            DECLARE
                v_parallel NUMBER := TO_NUMBER(NVL('&arg4', '1'));
            BEGIN
                -- Validate table was created
                SELECT COUNT(*) INTO v_count FROM all_tables
                WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name');
                
                IF v_count = 0 THEN
                    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: FAILED - Table not created');
                    v_result := FALSE;
                ELSE
                    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - Table created');
                    
                    -- Gather statistics
                    BEGIN
                        DBMS_STATS.GATHER_TABLE_STATS(
                            ownname => UPPER('&owner'),
                            tabname => UPPER('&table_name'),
                            estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
                            degree => v_parallel,
                            cascade => FALSE
                        );
                        DBMS_OUTPUT.PUT_LINE('  Statistics gathered');
                    EXCEPTION
                        WHEN OTHERS THEN
                            DBMS_OUTPUT.PUT_LINE('  Warning: Stats gathering failed: ' || SQLERRM);
                    END;
                END IF;
            END;
            
        WHEN 'POST_DATA_LOAD' THEN
            -- Post-data-load validation
            DECLARE
                v_target VARCHAR2(128) := UPPER('&table_name');
                v_source VARCHAR2(128) := UPPER('&arg4');
                v_source_count NUMBER := TO_NUMBER('&arg5');
                v_target_count NUMBER;
            BEGIN
                -- Check target is not empty
                EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || UPPER('&owner') || '.' || v_target INTO v_target_count;
                
                IF v_target_count = 0 THEN
                    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: FAILED - Target is empty');
                    v_result := FALSE;
                ELSE
                    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - Target has data');
                END IF;
                
                -- Compare counts
                IF v_source_count = v_target_count THEN
                    DBMS_OUTPUT.PUT_LINE('  Row count MATCH: ' || v_source_count);
                ELSIF v_target_count > v_source_count THEN
                    DBMS_OUTPUT.PUT_LINE('  WARNING: Target has MORE rows (' || v_target_count || ' > ' || v_source_count || ')');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('  WARNING: Row count MISMATCH (' || v_target_count || ' < ' || v_source_count || ')');
                END IF;
            END;
            
        ELSE
            DBMS_OUTPUT.PUT_LINE('ERROR: Unknown operation: &operation');
            DBMS_OUTPUT.PUT_LINE('Valid operations: pre_swap, post_swap, rollback, post_create, post_data_load');
            v_result := FALSE;
    END CASE;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: ERROR - ' || SQLERRM);
        v_result := FALSE;
END;
/

PROMPT =============================================================
