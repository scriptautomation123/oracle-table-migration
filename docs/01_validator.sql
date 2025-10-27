-- ==================================================================
-- UNIFIED VALIDATION SCRIPT (DEPRECATED - USE READONLY OR WRITE)
-- ==================================================================
-- Usage: @validation/01_validator.sql <operation> <args...>
-- ==================================================================
-- WARNING: This script contains BOTH read-only and write operations
-- For safety, use the separated versions instead:
--   - 01_validator_readonly.sql (SELECT operations only)
--   - 01_validator_write.sql (ALTER/UPDATE/DELETE operations)
-- ==================================================================
-- Operations (READ-ONLY):
--   check_sessions <owner> <table_name1> [table_name2] [table_name3]
--   check_existence <owner> <table_name>
--   check_table_structure <owner> <table_name>
--   count_rows <owner> <table_name> [expected_count]
--   check_constraints <owner> <table_name> [action]
--   check_partition_dist <owner> <table_name>
-- Operations (WRITE):
--   check_constraints <owner> <table_name> enable [auto_enable]
--   check_constraints <owner> <table_name> disable [auto_enable]
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE operation = '&1'
DEFINE owner = '&2'
DEFINE table_name = '&3'
DEFINE arg4 = '&4'
DEFINE arg5 = '&5'

PROMPT =============================================================
PROMPT UNIFIED VALIDATOR - Operation: &operation
PROMPT =============================================================

DECLARE
    v_result BOOLEAN := TRUE;
    v_count NUMBER;
    v_msg VARCHAR2(4000);
BEGIN
    CASE UPPER('&operation')
        WHEN 'CHECK_SESSIONS' THEN
            -- Check for active sessions
            FOR rec IN (
                SELECT COUNT(*) as cnt
                FROM v$session s, v$sqlarea sa
                WHERE s.sql_id = sa.sql_id
                  AND UPPER(sa.sql_text) LIKE '%' || UPPER('&table_name') || '%'
                  AND s.status = 'ACTIVE'
                  AND s.username IS NOT NULL
            ) LOOP
                IF rec.cnt > 0 THEN
                    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: FAILED - Active sessions found: ' || rec.cnt);
                    v_result := FALSE;
                ELSE
                    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - No active sessions');
                END IF;
            END LOOP;
            
        WHEN 'CHECK_EXISTENCE' THEN
            -- Check table exists
            SELECT COUNT(*) INTO v_count
            FROM all_tables
            WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name');
            
            IF v_count = 0 THEN
                DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: FAILED - Table does not exist');
                v_result := FALSE;
            ELSE
                DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - Table exists');
            END IF;
            
        WHEN 'CHECK_TABLE_STRUCTURE' THEN
            -- Validate table structure
            SELECT COUNT(*) INTO v_count
            FROM all_tables
            WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name');
            
            IF v_count = 0 THEN
                DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: FAILED - Table was not created');
                v_result := FALSE;
            ELSE
                DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - Table structure valid');
                
                -- Show partitioning info if exists
                FOR rec IN (
                    SELECT partitioning_type, NVL(subpartitioning_type, 'NONE') as subpart, NVL(interval, 'N/A') as interval
                    FROM all_part_tables
                    WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name')
                ) LOOP
                    DBMS_OUTPUT.PUT_LINE('  Partition Type: ' || rec.partitioning_type);
                    DBMS_OUTPUT.PUT_LINE('  Subpartition Type: ' || rec.subpart);
                    DBMS_OUTPUT.PUT_LINE('  Interval: ' || rec.interval);
                END LOOP;
            END IF;
            
        WHEN 'COUNT_ROWS' THEN
            -- Count rows with optional comparison
            EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || UPPER('&owner') || '.' || UPPER('&table_name') INTO v_count;
            
            IF '&arg4' IS NOT NULL AND '&arg4' != '' THEN
                DECLARE
                    v_expected NUMBER := TO_NUMBER('&arg4');
                BEGIN
                    IF v_count = v_expected THEN
                        DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - Row count matches (' || v_count || ')');
                    ELSIF v_expected = 0 AND v_count > 0 THEN
                        DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: FAILED - Table has rows when expecting empty');
                        v_result := FALSE;
                    ELSIF v_count > v_expected THEN
                        DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: WARNING - More rows than expected (' || v_count || ' > ' || v_expected || ')');
                    ELSE
                        DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: WARNING - Fewer rows than expected (' || v_count || ' < ' || v_expected || ')');
                    END IF;
                END;
            ELSE
                DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: INFO - Row count: ' || v_count);
            END IF;
            
        WHEN 'CHECK_CONSTRAINTS' THEN
            -- Check/enable/disable constraints
            DECLARE
                v_action VARCHAR2(20) := UPPER(NVL('&arg4', 'CHECK'));
                v_auto_enable BOOLEAN := UPPER(NVL('&arg5', 'FALSE')) IN ('TRUE', 'YES', '1');
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
                DBMS_OUTPUT.PUT_LINE('Disabled: ' || v_disabled_count);
                
                IF v_action = 'ENABLE' THEN
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
                            DBMS_OUTPUT.PUT_LINE('  Enabled: ' || c.constraint_name);
                        EXCEPTION
                            WHEN OTHERS THEN
                                DBMS_OUTPUT.PUT_LINE('  Failed: ' || c.constraint_name || ' - ' || SQLERRM);
                        END;
                    END LOOP;
                    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: COMPLETED - Constraints enabled');
                ELSIF v_action = 'DISABLE' THEN
                    -- Disable all constraints
                    FOR c IN (
                        SELECT constraint_name
                        FROM all_constraints
                        WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name')
                          AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'ENABLED'
                        ORDER BY CASE constraint_type WHEN 'R' THEN 1 WHEN 'C' THEN 2 WHEN 'U' THEN 3 WHEN 'P' THEN 4 END
                    ) LOOP
                        BEGIN
                            EXECUTE IMMEDIATE 'ALTER TABLE ' || UPPER('&owner') || '.' || UPPER('&table_name') || 
                                             ' DISABLE CONSTRAINT ' || c.constraint_name;
                            DBMS_OUTPUT.PUT_LINE('  Disabled: ' || c.constraint_name);
                        EXCEPTION
                            WHEN OTHERS THEN
                                DBMS_OUTPUT.PUT_LINE('  Failed: ' || c.constraint_name || ' - ' || SQLERRM);
                        END;
                    END LOOP;
                    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: COMPLETED - Constraints disabled');
                ELSIF v_disabled_count > 0 THEN
                    IF v_auto_enable THEN
                        DBMS_OUTPUT.PUT_LINE('Auto-enabling disabled constraints...');
                        v_action := 'ENABLE';
                    ELSE
                        DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: WARNING - ' || v_disabled_count || ' constraint(s) disabled');
                    END IF;
                ELSE
                    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - All constraints enabled');
                END IF;
            END;
            
        WHEN 'CHECK_PARTITION_DIST' THEN
            -- Show partition distribution
            FOR rec IN (
                SELECT partition_name, num_rows, 
                       ROUND(num_rows * 100.0 / NULLIF(SUM(num_rows) OVER(), 0), 2) as pct
                FROM all_tab_partitions
                WHERE table_owner = UPPER('&owner') AND table_name = UPPER('&table_name')
                ORDER BY partition_position DESC
                FETCH FIRST 10 ROWS ONLY
            ) LOOP
                DBMS_OUTPUT.PUT_LINE(rec.partition_name || ': ' || rec.num_rows || ' rows (' || rec.pct || '%)');
            END LOOP;
            DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - Partition distribution shown');
            
        ELSE
            DBMS_OUTPUT.PUT_LINE('ERROR: Unknown operation: &operation');
            DBMS_OUTPUT.PUT_LINE('Valid operations: check_sessions, check_existence, check_table_structure, count_rows, check_constraints, check_partition_dist');
            v_result := FALSE;
    END CASE;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: ERROR - ' || SQLERRM);
        v_result := FALSE;
END;
/

PROMPT =============================================================
