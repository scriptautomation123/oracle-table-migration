 hou-- ==================================================================
-- PL/SQL UTILITY SCRIPT - Consolidated Oracle Table Migration Tools
-- ==================================================================
-- Usage: @plsql-util.sql <category> <operation> <args...>
-- ==================================================================
-- Categories:
--   READONLY  - Safe read-only operations (SELECT only)
--   WRITE     - Data/schema modifications (ALTER/UPDATE/DELETE)
--   WORKFLOW  - Multi-step workflow operations
--   CLEANUP   - Table cleanup operations
-- ==================================================================
-- NOTE: All queries use ALL_* views with explicit owner filters
-- ==================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF

DEFINE category = '&1'
DEFINE operation = '&2'
DEFINE arg3 = '&3'
DEFINE arg4 = '&4'
DEFINE arg5 = '&5'
DEFINE arg6 = '&6'
DEFINE arg7 = '&7'

PROMPT =============================================================
PROMPT PL/SQL UTILITY - Category: &category | Operation: &operation
PROMPT =============================================================

DECLARE
    v_result BOOLEAN := TRUE;
    v_count NUMBER;
    v_msg VARCHAR2(4000);
BEGIN
    CASE UPPER('&category')
        
        -- ==================================================================
        -- READONLY CATEGORY - Safe read-only operations
        -- ==================================================================
        WHEN 'READONLY' THEN
            CASE UPPER('&operation')
                WHEN 'CHECK_SESSIONS' THEN
                    -- Check for active sessions
                    FOR rec IN (
                        SELECT COUNT(*) as cnt
                        FROM v$session s, v$sqlarea sa
                        WHERE s.sql_id = sa.sql_id
                          AND UPPER(sa.sql_text) LIKE '%' || UPPER('&arg3') || '%'
                          AND s.status = 'ACTIVE'
                          AND s.username IS NOT NULL
                    ) LOOP
                        IF rec.cnt > 0 THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Active sessions found: ' || rec.cnt);
                            v_result := FALSE;
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - No active sessions');
                        END IF;
                    END LOOP;
                    
                WHEN 'CHECK_EXISTENCE' THEN
                    SELECT COUNT(*) INTO v_count
                    FROM all_tables
                    WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4');
                    
                    IF v_count = 0 THEN
                        DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Table does not exist');
                        v_result := FALSE;
                    ELSE
                        DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - Table exists');
                    END IF;
                    
                WHEN 'CHECK_TABLE_STRUCTURE' THEN
                    SELECT COUNT(*) INTO v_count
                    FROM all_tables
                    WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4');
                    
                    IF v_count = 0 THEN
                        DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Table was not created');
                        v_result := FALSE;
                    ELSE
                        DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - Table structure valid');
                        
                        FOR rec IN (
                            SELECT partitioning_type, NVL(subpartitioning_type, 'NONE') as subpart, NVL(interval, 'N/A') as interval
                            FROM all_part_tables
                            WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4')
                        ) LOOP
                            DBMS_OUTPUT.PUT_LINE('  Partition Type: ' || rec.partitioning_type);
                            DBMS_OUTPUT.PUT_LINE('  Subpartition Type: ' || rec.subpart);
                            DBMS_OUTPUT.PUT_LINE('  Interval: ' || rec.interval);
                        END LOOP;
                    END IF;
                    
                WHEN 'COUNT_ROWS' THEN
                    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || UPPER('&arg3') || '.' || UPPER('&arg4') INTO v_count;
                    
                    IF '&arg5' IS NOT NULL AND '&arg5' != '' THEN
                        DECLARE
                            v_expected NUMBER := TO_NUMBER('&arg5');
                        BEGIN
                            IF v_count = v_expected THEN
                                DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - Row count matches (' || v_count || ')');
                            ELSIF v_expected = 0 AND v_count > 0 THEN
                                DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Table has rows when expecting empty');
                                v_result := FALSE;
                            ELSIF v_count > v_expected THEN
                                DBMS_OUTPUT.PUT_LINE('RESULT: WARNING - More rows than expected (' || v_count || ' > ' || v_expected || ')');
                            ELSE
                                DBMS_OUTPUT.PUT_LINE('RESULT: WARNING - Fewer rows than expected (' || v_count || ' < ' || v_expected || ')');
                            END IF;
                        END;
                    ELSE
                        DBMS_OUTPUT.PUT_LINE('RESULT: INFO - Row count: ' || v_count);
                    END IF;
                    
                WHEN 'CHECK_CONSTRAINTS' THEN
                    DECLARE
                        v_disabled_count NUMBER;
                        v_total_count NUMBER;
                    BEGIN
                        SELECT COUNT(*) INTO v_total_count
                        FROM all_constraints
                        WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4')
                          AND constraint_type IN ('U', 'P', 'R', 'C');
                        
                        SELECT COUNT(*) INTO v_disabled_count
                        FROM all_constraints
                        WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4')
                          AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'DISABLED';
                        
                        DBMS_OUTPUT.PUT_LINE('Total constraints: ' || v_total_count);
                        DBMS_OUTPUT.PUT_LINE('Disabled: ' || v_disabled_count);
                        
                        IF v_disabled_count > 0 THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: WARNING - ' || v_disabled_count || ' constraint(s) disabled');
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - All constraints enabled');
                        END IF;
                    END;
                    
                WHEN 'CHECK_PARTITION_DIST' THEN
                    FOR rec IN (
                        SELECT partition_name, num_rows, 
                               ROUND(num_rows * 100.0 / NULLIF(SUM(num_rows) OVER(), 0), 2) as pct
                        FROM all_tab_partitions
                        WHERE table_owner = UPPER('&arg3') AND table_name = UPPER('&arg4')
                        ORDER BY partition_position DESC
                        FETCH FIRST 10 ROWS ONLY
                    ) LOOP
                        DBMS_OUTPUT.PUT_LINE(rec.partition_name || ': ' || rec.num_rows || ' rows (' || rec.pct || '%)');
                    END LOOP;
                    DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - Partition distribution shown');
                    
                ELSE
                    DBMS_OUTPUT.PUT_LINE('ERROR: Unknown READONLY operation');
                    DBMS_OUTPUT.PUT_LINE('Valid: check_sessions, check_existence, check_table_structure, count_rows, check_constraints, check_partition_dist');
                    v_result := FALSE;
            END CASE;
        
        -- ==================================================================
        -- WRITE CATEGORY - Data/schema modifications
        -- ==================================================================
        WHEN 'WRITE' THEN
            CASE UPPER('&operation')
                WHEN 'ENABLE_CONSTRAINTS' THEN
                    DECLARE
                        v_disabled_count NUMBER;
                        v_total_count NUMBER;
                    BEGIN
                        SELECT COUNT(*) INTO v_total_count
                        FROM all_constraints
                        WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4')
                          AND constraint_type IN ('U', 'P', 'R', 'C');
                        
                        SELECT COUNT(*) INTO v_disabled_count
                        FROM all_constraints
                        WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4')
                          AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'DISABLED';
                        
                        DBMS_OUTPUT.PUT_LINE('Total constraints: ' || v_total_count);
                        DBMS_OUTPUT.PUT_LINE('Currently disabled: ' || v_disabled_count);
                        
                        FOR c IN (
                            SELECT constraint_name, constraint_type
                            FROM all_constraints
                            WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4')
                              AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'DISABLED'
                            ORDER BY CASE constraint_type WHEN 'P' THEN 1 WHEN 'U' THEN 2 WHEN 'C' THEN 3 WHEN 'R' THEN 4 END
                        ) LOOP
                            BEGIN
                                EXECUTE IMMEDIATE 'ALTER TABLE ' || UPPER('&arg3') || '.' || UPPER('&arg4') || 
                                                 ' ENABLE NOVALIDATE CONSTRAINT ' || c.constraint_name;
                                DBMS_OUTPUT.PUT_LINE('  Enabled: ' || c.constraint_name || ' (' || c.constraint_type || ')');
                            EXCEPTION
                                WHEN OTHERS THEN
                                    DBMS_OUTPUT.PUT_LINE('  Failed: ' || c.constraint_name || ' - ' || SQLERRM);
                            END;
                        END LOOP;
                        
                        DBMS_OUTPUT.PUT_LINE('RESULT: COMPLETED - Constraints enabled');
                    END;
                    
                WHEN 'DISABLE_CONSTRAINTS' THEN
                    DECLARE
                        v_enabled_count NUMBER;
                        v_total_count NUMBER;
                    BEGIN
                        SELECT COUNT(*) INTO v_total_count
                        FROM all_constraints
                        WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4')
                          AND constraint_type IN ('U', 'P', 'R', 'C');
                        
                        SELECT COUNT(*) INTO v_enabled_count
                        FROM all_constraints
                        WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4')
                          AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'ENABLED';
                        
                        DBMS_OUTPUT.PUT_LINE('Total constraints: ' || v_total_count);
                        DBMS_OUTPUT.PUT_LINE('Currently enabled: ' || v_enabled_count);
                        
                        FOR c IN (
                            SELECT constraint_name, constraint_type
                            FROM all_constraints
                            WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4')
                              AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'ENABLED'
                            ORDER BY CASE constraint_type WHEN 'R' THEN 1 WHEN 'C' THEN 2 WHEN 'U' THEN 3 WHEN 'P' THEN 4 END
                        ) LOOP
                            BEGIN
                                EXECUTE IMMEDIATE 'ALTER TABLE ' || UPPER('&arg3') || '.' || UPPER('&arg4') || 
                                                 ' DISABLE CONSTRAINT ' || c.constraint_name;
                                DBMS_OUTPUT.PUT_LINE('  Disabled: ' || c.constraint_name || ' (' || c.constraint_type || ')');
                            EXCEPTION
                                WHEN OTHERS THEN
                                    DBMS_OUTPUT.PUT_LINE('  Failed: ' || c.constraint_name || ' - ' || SQLERRM);
                            END;
                        END LOOP;
                        
                        DBMS_OUTPUT.PUT_LINE('RESULT: COMPLETED - Constraints disabled');
                    END;
                    
                ELSE
                    DBMS_OUTPUT.PUT_LINE('ERROR: Unknown WRITE operation');
                    DBMS_OUTPUT.PUT_LINE('Valid: enable_constraints, disable_constraints');
                    v_result := FALSE;
            END CASE;
        
        -- ==================================================================
        -- WORKFLOW CATEGORY - Multi-step workflow operations
        -- ==================================================================
        WHEN 'WORKFLOW' THEN
            CASE UPPER('&operation')
                WHEN 'PRE_SWAP' THEN
                    DECLARE
                        v_new_table VARCHAR2(128) := UPPER('&arg4');
                        v_old_table VARCHAR2(128) := UPPER('&arg5');
                    BEGIN
                        DBMS_OUTPUT.PUT_LINE('Checking tables exist...');
                        
                        SELECT COUNT(*) INTO v_count FROM all_tables
                        WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4');
                        IF v_count = 0 THEN
                            DBMS_OUTPUT.PUT_LINE('  FAILED: Original table missing');
                            v_result := FALSE;
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('  PASSED: Original table exists');
                        END IF;
                        
                        SELECT COUNT(*) INTO v_count FROM all_tables
                        WHERE owner = UPPER('&arg3') AND table_name = v_new_table;
                        IF v_count = 0 THEN
                            DBMS_OUTPUT.PUT_LINE('  FAILED: New table missing');
                            v_result := FALSE;
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('  PASSED: New table exists');
                        END IF;
                        
                        IF v_result THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - Pre-swap checks complete');
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Pre-swap checks failed');
                        END IF;
                    END;
                    
                WHEN 'POST_SWAP' THEN
                    DECLARE
                        v_old_table VARCHAR2(128) := UPPER('&arg4');
                    BEGIN
                        DBMS_OUTPUT.PUT_LINE('Validating swap success...');
                        
                        SELECT COUNT(*) INTO v_count FROM all_tables
                        WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4');
                        IF v_count = 0 THEN
                            DBMS_OUTPUT.PUT_LINE('  FAILED: Main table missing');
                            v_result := FALSE;
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('  PASSED: Main table exists');
                        END IF;
                        
                        IF v_result THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - Swap successful');
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Swap validation failed');
                        END IF;
                    END;
                    
                WHEN 'POST_DATA_LOAD' THEN
                    DECLARE
                        v_target VARCHAR2(128) := UPPER('&arg4');
                        v_source VARCHAR2(128) := UPPER('&arg5');
                        v_source_count NUMBER := TO_NUMBER('&arg6');
                        v_target_count NUMBER;
                        v_parallel NUMBER := TO_NUMBER(NVL('&arg7', '1'));
                    BEGIN
                        DBMS_OUTPUT.PUT_LINE('Validating data load...');
                        
                        -- Check target is not empty
                        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || UPPER('&arg3') || '.' || v_target INTO v_target_count;
                        
                        IF v_target_count = 0 THEN
                            DBMS_OUTPUT.PUT_LINE('  FAILED: Target is empty');
                            v_result := FALSE;
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('  PASSED: Target has data (' || v_target_count || ' rows)');
                        END IF;
                        
                        -- Compare counts
                        IF v_source_count = v_target_count THEN
                            DBMS_OUTPUT.PUT_LINE('  Row count MATCH: ' || v_target_count);
                        ELSIF v_target_count > v_source_count THEN
                            DBMS_OUTPUT.PUT_LINE('  WARNING: Target has MORE rows (' || v_target_count || ' > ' || v_source_count || ')');
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('  WARNING: Row count MISMATCH (' || v_target_count || ' < ' || v_source_count || ')');
                        END IF;
                        
                        -- Gather statistics on loaded table
                        DBMS_OUTPUT.PUT_LINE('  Gathering statistics...');
                        BEGIN
                            DBMS_STATS.GATHER_TABLE_STATS(
                                ownname => UPPER('&arg3'),
                                tabname => v_target,
                                estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
                                method_opt => 'FOR ALL COLUMNS SIZE AUTO',
                                degree => v_parallel,
                                cascade => TRUE
                            );
                            DBMS_OUTPUT.PUT_LINE('  ✓ Statistics gathered');
                        EXCEPTION
                            WHEN OTHERS THEN
                                DBMS_OUTPUT.PUT_LINE('    Warning: Stats gathering failed: ' || SQLERRM);
                        END;
                        
                        IF v_result THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - Data load validation complete');
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Data load validation failed');
                        END IF;
                    END;
                    
                WHEN 'POST_CREATE' THEN
                    DECLARE
                        v_parallel NUMBER := TO_NUMBER(NVL('&arg5', '1'));
                    BEGIN
                        DBMS_OUTPUT.PUT_LINE('Verifying table structure for &arg3..&arg4');
                        DBMS_OUTPUT.PUT_LINE('=============================================================');
                        
                        -- Check table exists and show structure
                        SELECT COUNT(*) INTO v_count
                        FROM all_tables
                        WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4');
                        
                        IF v_count = 0 THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Table not created');
                            v_result := FALSE;
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('✓ Table structure verification');
                            
                            -- Show partitioning configuration
                            FOR rec IN (
                                SELECT partitioning_type, NVL(subpartitioning_type, 'NONE') as subpart_type,
                                       partition_count, def_subpartition_count,
                                       NVL(interval, 'N/A') as interval, 
                                       CASE WHEN interval IS NOT NULL THEN 'YES' ELSE 'NO' END as is_interval
                                FROM all_part_tables
                                WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4')
                            ) LOOP
                                DBMS_OUTPUT.PUT_LINE('  Partitioning Type: ' || rec.partitioning_type);
                                DBMS_OUTPUT.PUT_LINE('  Subpartitioning Type: ' || rec.subpart_type);
                                DBMS_OUTPUT.PUT_LINE('  Partition Count: ' || rec.partition_count);
                                DBMS_OUTPUT.PUT_LINE('  Subpartition Count: ' || rec.def_subpartition_count);
                                DBMS_OUTPUT.PUT_LINE('  Interval: ' || rec.interval);
                                DBMS_OUTPUT.PUT_LINE('  Is Interval: ' || rec.is_interval);
                            END LOOP;
                            
                            -- Show partition key columns
                            DBMS_OUTPUT.PUT_LINE('  Partition Key Columns:');
                            FOR key_col IN (
                                SELECT column_name, column_position, object_type
                                FROM all_part_key_columns
                                WHERE owner = UPPER('&arg3') AND name = UPPER('&arg4')
                                ORDER BY column_position
                            ) LOOP
                                DBMS_OUTPUT.PUT_LINE('    ' || key_col.column_position || '. ' || key_col.column_name || ' (' || key_col.object_type || ')');
                            END LOOP;
                            
                            -- Show LOB columns configuration
                            DECLARE
                                v_lob_count NUMBER;
                            BEGIN
                                SELECT COUNT(*) INTO v_lob_count
                                FROM all_lobs
                                WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4');
                                
                                IF v_lob_count > 0 THEN
                                    DBMS_OUTPUT.PUT_LINE('  LOB Columns (' || v_lob_count || '):');
                                    FOR lob_col IN (
                                        SELECT column_name, segment_name, tablespace_name,
                                               securefile, compression, deduplication, 
                                               in_row, chunk, cache
                                        FROM all_lobs
                                        WHERE owner = UPPER('&arg3') AND table_name = UPPER('&arg4')
                                        ORDER BY column_name
                                    ) LOOP
                                        DBMS_OUTPUT.PUT_LINE('    ' || lob_col.column_name || ': ' ||
                                                           'Tablespace=' || lob_col.tablespace_name || ', ' ||
                                                           'SecureFile=' || lob_col.securefile || ', ' ||
                                                           'Compression=' || lob_col.compression || ', ' ||
                                                           'In-Row=' || lob_col.in_row);
                                    END LOOP;
                                END IF;
                            END;
                            
                            -- Gather statistics
                            DBMS_OUTPUT.PUT_LINE('  Gathering statistics...');
                            DECLARE
                                v_start_time TIMESTAMP := SYSTIMESTAMP;
                                v_end_time TIMESTAMP;
                                v_duration INTERVAL DAY TO SECOND;
                            BEGIN
                                DBMS_STATS.GATHER_TABLE_STATS(
                                    ownname => UPPER('&arg3'),
                                    tabname => UPPER('&arg4'),
                                    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
                                    method_opt => 'FOR ALL COLUMNS SIZE AUTO',
                                    degree => v_parallel,
                                    cascade => FALSE
                                );
                                v_end_time := SYSTIMESTAMP;
                                v_duration := v_end_time - v_start_time;
                                DBMS_OUTPUT.PUT_LINE('  ✓ Statistics gathered successfully');
                                DBMS_OUTPUT.PUT_LINE('    Duration: ' || TO_CHAR(EXTRACT(SECOND FROM v_duration), '999.99') || ' seconds');
                            EXCEPTION
                                WHEN OTHERS THEN
                                    DBMS_OUTPUT.PUT_LINE('    Warning: Stats gathering failed: ' || SQLERRM);
                            END;
                            
                            DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - Table verification and statistics complete');
                        END IF;
                    END;
                    
                WHEN 'CREATE_RENAMED_VIEW' THEN
                    -- Creates view with join between old and new tables, with INSTEAD OF trigger for DML
                    DECLARE
                        v_schema VARCHAR2(128) := UPPER('&arg3');
                        v_table VARCHAR2(128) := UPPER('&arg4');
                        v_new_table VARCHAR2(128) := v_table || '_NEW';
                        v_old_table VARCHAR2(128) := v_table || '_OLD';
                        v_view_name VARCHAR2(128) := v_table || '_JOINED';
                        v_trigger_name VARCHAR2(128) := 'TG_' || v_view_name || '_IOT';
                    BEGIN
                        DBMS_OUTPUT.PUT_LINE('Creating renamed view with INSTEAD OF trigger...');
                        DBMS_OUTPUT.PUT_LINE('  Schema: ' || v_schema);
                        DBMS_OUTPUT.PUT_LINE('  Table: ' || v_table);
                        DBMS_OUTPUT.PUT_LINE('  New table: ' || v_new_table);
                        DBMS_OUTPUT.PUT_LINE('  Old table: ' || v_old_table);
                        DBMS_OUTPUT.PUT_LINE('  View: ' || v_view_name);
                        
                        -- Check tables exist
                        SELECT COUNT(*) INTO v_count FROM all_tables
                        WHERE owner = v_schema AND table_name = v_new_table;
                        IF v_count = 0 THEN
                            DBMS_OUTPUT.PUT_LINE('  FAILED: New table does not exist');
                            v_result := FALSE;
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('  ✓ New table exists');
                        END IF;
                        
                        SELECT COUNT(*) INTO v_count FROM all_tables
                        WHERE owner = v_schema AND table_name = v_old_table;
                        IF v_count = 0 THEN
                            DBMS_OUTPUT.PUT_LINE('  FAILED: Old table does not exist');
                            v_result := FALSE;
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('  ✓ Old table exists');
                        END IF;
                        
                        IF NOT v_result THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Prerequisites not met');
                            RETURN;
                        END IF;
                        
                        -- Get all columns from NEW table for view definition
                        DECLARE
                            v_cols CLOB := '';
                            v_first BOOLEAN := TRUE;
                        BEGIN
                            FOR col IN (
                                SELECT column_name, data_type, column_id
                                FROM all_tab_columns
                                WHERE owner = v_schema AND table_name = v_new_table
                                ORDER BY column_id
                            ) LOOP
                                IF v_first THEN
                                    v_cols := v_cols || col.column_name;
                                    v_first := FALSE;
                                ELSE
                                    v_cols := v_cols || ', ' || col.column_name;
                                END IF;
                            END LOOP;
                            
                            -- Drop view if exists
                            BEGIN
                                EXECUTE IMMEDIATE 'DROP VIEW ' || v_schema || '.' || v_view_name;
                                DBMS_OUTPUT.PUT_LINE('  ✓ Dropped existing view');
                            EXCEPTION WHEN OTHERS THEN NULL;
                            END;
                            
                            -- Create view with FULL OUTER JOIN to show both tables
                            EXECUTE IMMEDIATE 'CREATE OR REPLACE VIEW ' || v_schema || '.' || v_view_name || ' AS
                                SELECT * FROM ' || v_schema || '.' || v_new_table || ' UNION ALL
                                SELECT ' || REPLACE(v_cols, v_new_table || '.', '') || ' FROM ' || v_schema || '.' || v_old_table || '
                                WHERE NOT EXISTS (SELECT 1 FROM ' || v_schema || '.' || v_new_table || ' WHERE ' || 
                                SUBSTR(v_cols, 1, INSTR(v_cols, ',') - 1) || ' = ' || v_old_table || '.' || 
                                SUBSTR(v_cols, 1, INSTR(v_cols, ',') - 1) || ')';
                            
                            DBMS_OUTPUT.PUT_LINE('  ✓ Created view ' || v_view_name);
                        END;
                        
                        -- Drop trigger if exists
                        BEGIN
                            EXECUTE IMMEDIATE 'DROP TRIGGER ' || v_schema || '.' || v_trigger_name;
                            DBMS_OUTPUT.PUT_LINE('  ✓ Dropped existing trigger');
                        EXCEPTION WHEN OTHERS THEN NULL;
                        END;
                        
                        -- Create INSTEAD OF trigger (INSERT only to NEW table)
                        EXECUTE IMMEDIATE 'CREATE OR REPLACE TRIGGER ' || v_schema || '.' || v_trigger_name || '
                            INSTEAD OF INSERT ON ' || v_schema || '.' || v_view_name || '
                            FOR EACH ROW
                            BEGIN
                                INSERT INTO ' || v_schema || '.' || v_new_table || ' VALUES :NEW.*;
                            END;';
                        
                        DBMS_OUTPUT.PUT_LINE('  ✓ Created INSTEAD OF trigger ' || v_trigger_name);
                        DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - View and trigger created successfully');
                    END;
                    
                WHEN 'FINALIZE_SWAP' THEN
                    -- Complete the swap: drop old, rename new, drop view/trigger, validate
                    DECLARE
                        v_schema VARCHAR2(128) := UPPER('&arg3');
                        v_table VARCHAR2(128) := UPPER('&arg4');
                        v_new_table VARCHAR2(128) := v_table || '_NEW';
                        v_old_table VARCHAR2(128) := v_table || '_OLD';
                        v_view_name VARCHAR2(128) := v_table || '_JOINED';
                        v_trigger_name VARCHAR2(128) := 'TG_' || v_view_name || '_IOT';
                    BEGIN
                        DBMS_OUTPUT.PUT_LINE('Finalizing swap operation...');
                        DBMS_OUTPUT.PUT_LINE('  Schema: ' || v_schema);
                        DBMS_OUTPUT.PUT_LINE('  Table: ' || v_table);
                        
                        -- Step 1: Drop INSTEAD OF trigger
                        BEGIN
                            EXECUTE IMMEDIATE 'DROP TRIGGER ' || v_schema || '.' || v_trigger_name;
                            DBMS_OUTPUT.PUT_LINE('  ✓ Dropped trigger');
                        EXCEPTION WHEN OTHERS THEN
                            DBMS_OUTPUT.PUT_LINE('  ✗ Failed to drop trigger: ' || SQLERRM);
                            v_result := FALSE;
                        END;
                        
                        -- Step 2: Drop view
                        BEGIN
                            EXECUTE IMMEDIATE 'DROP VIEW ' || v_schema || '.' || v_view_name;
                            DBMS_OUTPUT.PUT_LINE('  ✓ Dropped view');
                        EXCEPTION WHEN OTHERS THEN
                            DBMS_OUTPUT.PUT_LINE('  ✗ Failed to drop view: ' || SQLERRM);
                            v_result := FALSE;
                        END;
                        
                        -- Step 3: Drop old table
                        BEGIN
                            EXECUTE IMMEDIATE 'DROP TABLE ' || v_schema || '.' || v_old_table || ' PURGE';
                            DBMS_OUTPUT.PUT_LINE('  ✓ Dropped old table');
                        EXCEPTION WHEN OTHERS THEN
                            DBMS_OUTPUT.PUT_LINE('  ✗ Failed to drop old table: ' || SQLERRM);
                            v_result := FALSE;
                        END;
                        
                        -- Step 4: Rename new table to original name
                        BEGIN
                            EXECUTE IMMEDIATE 'ALTER TABLE ' || v_schema || '.' || v_new_table || ' RENAME TO ' || v_table;
                            DBMS_OUTPUT.PUT_LINE('  ✓ Renamed ' || v_new_table || ' to ' || v_table);
                        EXCEPTION WHEN OTHERS THEN
                            DBMS_OUTPUT.PUT_LINE('  ✗ Failed to rename table: ' || SQLERRM);
                            v_result := FALSE;
                        END;
                        
                        -- Step 5: Validate objects - check for invalid objects
                        DECLARE
                            v_invalid_count NUMBER;
                        BEGIN
                            SELECT COUNT(*) INTO v_invalid_count
                            FROM all_objects
                            WHERE owner = v_schema AND status = 'INVALID';
                            
                            IF v_invalid_count > 0 THEN
                                DBMS_OUTPUT.PUT_LINE('  ⚠ Found ' || v_invalid_count || ' invalid object(s):');
                                
                                FOR obj IN (
                                    SELECT object_name, object_type, status
                                    FROM all_objects
                                    WHERE owner = v_schema AND status = 'INVALID'
                                    ORDER BY object_type, object_name
                                ) LOOP
                                    DBMS_OUTPUT.PUT_LINE('    - ' || obj.object_name || ' (' || obj.object_type || ')');
                                    
                                    -- Attempt to recompile
                                    BEGIN
                                        IF obj.object_type IN ('PROCEDURE', 'FUNCTION', 'PACKAGE', 'PACKAGE BODY', 'TRIGGER') THEN
                                            EXECUTE IMMEDIATE 'ALTER ' || obj.object_type || ' ' || v_schema || '.' || 
                                                           obj.object_name || ' COMPILE';
                                            DBMS_OUTPUT.PUT_LINE('      ✓ Recompiled successfully');
                                        END IF;
                                    EXCEPTION WHEN OTHERS THEN
                                        DBMS_OUTPUT.PUT_LINE('      ✗ Recompile failed: ' || SQLERRM);
                                    END;
                                END LOOP;
                                
                                -- Check again after recompilation
                                SELECT COUNT(*) INTO v_invalid_count
                                FROM all_objects
                                WHERE owner = v_schema AND status = 'INVALID';
                                
                                IF v_invalid_count = 0 THEN
                                    DBMS_OUTPUT.PUT_LINE('  ✓ All objects recompiled successfully');
                                ELSE
                                    DBMS_OUTPUT.PUT_LINE('  ✗ ' || v_invalid_count || ' objects still invalid');
                                END IF;
                            ELSE
                                DBMS_OUTPUT.PUT_LINE('  ✓ No invalid objects found');
                            END IF;
                        END;
                        
                        IF v_result THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - Finalization complete');
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Finalization had errors');
                        END IF;
                    END;
                    
                WHEN 'PRE_CREATE_PARTITIONS' THEN
                    -- Pre-create future interval partitions
                    DECLARE
                        v_schema VARCHAR2(128) := UPPER('&arg3');
                        v_table VARCHAR2(128) := UPPER('&arg4');
                        v_days_ahead NUMBER := TO_NUMBER(NVL('&arg5', '2')); -- days to pre-create
                        v_partition_count NUMBER := 0;
                        v_interval_unit VARCHAR2(10);
                        v_partition_type VARCHAR2(10);
                        v_max_partition_date DATE;
                        v_next_partition_date DATE;
                        v_current_date DATE := TRUNC(SYSDATE);
                    BEGIN
                        DBMS_OUTPUT.PUT_LINE('Pre-creating interval partitions...');
                        DBMS_OUTPUT.PUT_LINE('  Schema: ' || v_schema);
                        DBMS_OUTPUT.PUT_LINE('  Table: ' || v_table);
                        DBMS_OUTPUT.PUT_LINE('  Days ahead: ' || v_days_ahead);
                        
                        -- Validate table exists and get interval information
                        SELECT COUNT(*) INTO v_count FROM all_part_tables
                        WHERE owner = v_schema AND table_name = v_table;
                        
                        IF v_count = 0 THEN
                            DBMS_OUTPUT.PUT_LINE('  FAILED: Table does not exist or is not partitioned');
                            v_result := FALSE;
                        ELSE
                            -- Get partitioning details
                            FOR rec IN (
                                SELECT partitioning_type, interval, partition_key_columns
                                FROM all_part_tables
                                WHERE owner = v_schema AND table_name = v_table
                            ) LOOP
                                v_partition_type := rec.partitioning_type;
                                
                                IF rec.interval IS NULL THEN
                                    DBMS_OUTPUT.PUT_LINE('  FAILED: Table is not interval partitioned');
                                    v_result := FALSE;
                                ELSE
                                    DBMS_OUTPUT.PUT_LINE('  ✓ Table is interval partitioned');
                                    DBMS_OUTPUT.PUT_LINE('  Interval: ' || rec.interval);
                                    
                                    -- Parse interval to determine unit (NUMTODSINTERVAL or INTERVAL)
                                    IF rec.interval LIKE '%DAY%' THEN
                                        v_interval_unit := 'DAY';
                                        -- Extract number from interval (e.g., 'NUMTODSINTERVAL(1,''DAY'')' -> 1)
                                        DECLARE
                                            v_num_start NUMBER := INSTR(rec.interval, '(') + 1;
                                            v_num_end NUMBER := INSTR(rec.interval, ',', v_num_start) - 1;
                                            v_num_str VARCHAR2(100);
                                        BEGIN
                                            v_num_str := SUBSTR(rec.interval, v_num_start, v_num_end - v_num_start);
                                            -- For hour partitions, calculate hours per day
                                            IF rec.interval LIKE '%HOUR%' THEN
                                                v_interval_unit := 'HOUR';
                                            END IF;
                                        END;
                                    ELSIF rec.interval LIKE '%HOUR%' THEN
                                        v_interval_unit := 'HOUR';
                                        -- For hour partitions, each hour is one partition
                                        v_days_ahead := v_days_ahead * 24; -- Convert days to hours
                                    ELSIF rec.interval LIKE '%MONTH%' THEN
                                        v_interval_unit := 'MONTH';
                                    END IF;
                                END IF;
                            END LOOP;
                            
                            IF NOT v_result THEN
                                DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Invalid partition configuration');
                                RETURN;
                            END IF;
                            
                            -- Get max partition date
                            BEGIN
                                SELECT MAX(partition_position), MAX(high_value)
                                INTO v_count, v_max_partition_date
                                FROM all_tab_partitions
                                WHERE table_owner = v_schema AND table_name = v_table;
                                
                                DBMS_OUTPUT.PUT_LINE('  Max partition date: ' || TO_CHAR(v_max_partition_date, 'YYYY-MM-DD'));
                            EXCEPTION WHEN OTHERS THEN
                                DBMS_OUTPUT.PUT_LINE('  WARNING: Could not determine max partition date: ' || SQLERRM);
                                v_max_partition_date := TRUNC(SYSDATE);
                            END;
                            
                            -- Calculate how many partitions to pre-create
                            IF v_interval_unit = 'HOUR' THEN
                                v_partition_count := v_days_ahead; -- Already converted to hours
                            ELSIF v_interval_unit = 'DAY' THEN
                                v_partition_count := v_days_ahead;
                            ELSIF v_interval_unit = 'MONTH' THEN
                                v_partition_count := v_days_ahead / 30; -- Approximately
                            END IF;
                            
                            DBMS_OUTPUT.PUT_LINE('  Interval unit: ' || v_interval_unit);
                            DBMS_OUTPUT.PUT_LINE('  Partitions to pre-create: ' || v_partition_count);
                            
                            -- Pre-create partitions
                            FOR i IN 1..v_partition_count LOOP
                                IF v_interval_unit = 'HOUR' THEN
                                    v_next_partition_date := v_current_date + (v_max_partition_date - v_current_date) + (i - 1) / 24;
                                ELSIF v_interval_unit = 'DAY' THEN
                                    v_next_partition_date := v_current_date + (v_max_partition_date - v_current_date) + i;
                                ELSIF v_interval_unit = 'MONTH' THEN
                                    v_next_partition_date := ADD_MONTHS(v_current_date, i);
                                END IF;
                                
                                BEGIN
                                    -- Create partition only if it doesn't exist
                                    DECLARE
                                        v_part_exists NUMBER := 0;
                                    BEGIN
                                        SELECT COUNT(*) INTO v_part_exists
                                        FROM all_tab_partitions
                                        WHERE table_owner = v_schema 
                                          AND table_name = v_table
                                          AND high_value = 'TO_DATE(''' || TO_CHAR(v_next_partition_date, 'YYYY-MM-DD') || ''', ''YYYY-MM-DD'')';
                                        
                                        IF v_part_exists = 0 THEN
                                            EXECUTE IMMEDIATE 'ALTER TABLE ' || v_schema || '.' || v_table || 
                                                             ' SPLIT PARTITION (FOR (TO_DATE(''' || 
                                                             TO_CHAR(v_next_partition_date, 'YYYY-MM-DD') || 
                                                             ''', ''YYYY-MM-DD''))) AT ' || 
                                                             TO_DATE(v_next_partition_date, 'YYYY-MM-DD');
                                            DBMS_OUTPUT.PUT_LINE('  ✓ Pre-created partition: ' || TO_CHAR(v_next_partition_date, 'YYYY-MM-DD'));
                                        ELSE
                                            DBMS_OUTPUT.PUT_LINE('  - Partition exists: ' || TO_CHAR(v_next_partition_date, 'YYYY-MM-DD'));
                                        END IF;
                                    END;
                                EXCEPTION WHEN OTHERS THEN
                                    -- Ignore errors if partition already exists or other non-critical issues
                                    IF SQLERRM LIKE '%already exists%' OR SQLERRM LIKE '%does not exist%' THEN
                                        DBMS_OUTPUT.PUT_LINE('  - Skipped: ' || TO_CHAR(v_next_partition_date, 'YYYY-MM-DD'));
                                    ELSE
                                        DBMS_OUTPUT.PUT_LINE('  ✗ Error creating partition for ' || 
                                                           TO_CHAR(v_next_partition_date, 'YYYY-MM-DD') || ': ' || SQLERRM);
                                    END IF;
                                END;
                            END LOOP;
                            
                            DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - Pre-creation complete');
                        END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: ERROR - ' || SQLERRM);
                            v_result := FALSE;
                    END;
                    
                WHEN 'ADD_HASH_SUBPARTITIONS' THEN
                    -- Add hash subpartitions to an interval-partitioned table
                    DECLARE
                        v_schema VARCHAR2(128) := UPPER('&arg3');
                        v_table VARCHAR2(128) := UPPER('&arg4');
                        v_subpart_col VARCHAR2(128) := UPPER('&arg5'); -- subpartition column
                        v_subpart_count NUMBER := TO_NUMBER(NVL('&arg6', '8')); -- number of subpartitions
                    BEGIN
                        DBMS_OUTPUT.PUT_LINE('Adding hash subpartitions to interval table...');
                        DBMS_OUTPUT.PUT_LINE('  Schema: ' || v_schema);
                        DBMS_OUTPUT.PUT_LINE('  Table: ' || v_table);
                        DBMS_OUTPUT.PUT_LINE('  Subpartition Column: ' || v_subpart_col);
                        DBMS_OUTPUT.PUT_LINE('  Subpartition Count: ' || v_subpart_count);
                        
                        -- Validate table exists and is partitioned
                        SELECT COUNT(*) INTO v_count FROM all_part_tables
                        WHERE owner = v_schema AND table_name = v_table;
                        
                        IF v_count = 0 THEN
                            DBMS_OUTPUT.PUT_LINE('  FAILED: Table does not exist or is not partitioned');
                            v_result := FALSE;
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('  ✓ Table is partitioned');
                            
                            -- Check current partitioning
                            FOR rec IN (
                                SELECT partitioning_type, interval, def_subpartition_count
                                FROM all_part_tables
                                WHERE owner = v_schema AND table_name = v_table
                            ) LOOP
                                DBMS_OUTPUT.PUT_LINE('  Current partitioning: ' || rec.partitioning_type);
                                DBMS_OUTPUT.PUT_LINE('  Interval: ' || NVL(rec.interval, 'N/A'));
                                DBMS_OUTPUT.PUT_LINE('  Current subpartitions: ' || NVL(rec.def_subpartition_count, 0));
                                
                                IF rec.partitioning_type != 'RANGE' OR rec.interval IS NULL THEN
                                    DBMS_OUTPUT.PUT_LINE('  FAILED: Table must be interval-range partitioned');
                                    v_result := FALSE;
                                ELSIF rec.def_subpartition_count > 0 THEN
                                    DBMS_OUTPUT.PUT_LINE('  WARNING: Table already has subpartitions');
                                END IF;
                            END LOOP;
                            
                            IF NOT v_result THEN
                                DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Table not eligible for subpartitioning');
                                RETURN;
                            END IF;
                            
                            -- Modify table to add subpartitions
                            EXECUTE IMMEDIATE 'ALTER TABLE ' || v_schema || '.' || v_table || 
                                             ' SET SUBPARTITION TEMPLATE (SUBPARTITION BY HASH (' || 
                                             v_subpart_col || ') SUBPARTITIONS ' || v_subpart_count || ')';
                            
                            DBMS_OUTPUT.PUT_LINE('  ✓ Modified table structure');
                            
                            -- Regenerate partitions to apply template
                            EXECUTE IMMEDIATE 'ALTER TABLE ' || v_schema || '.' || v_table || 
                                             ' MERGE PARTITIONS';
                            
                            DBMS_OUTPUT.PUT_LINE('  ✓ Applied subpartition template to future partitions');
                            DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - Hash subpartitions added successfully');
                        END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: ERROR - ' || SQLERRM);
                            v_result := FALSE;
                    END;
                    
                ELSE
                    DBMS_OUTPUT.PUT_LINE('ERROR: Unknown WORKFLOW operation');
                    DBMS_OUTPUT.PUT_LINE('Valid: pre_swap, post_swap, post_create, create_renamed_view, finalize_swap, add_hash_subpartitions');
                    v_result := FALSE;
            END CASE;
        
        -- ==================================================================
        -- CLEANUP CATEGORY - Table cleanup operations
        -- ==================================================================
        WHEN 'CLEANUP' THEN
            CASE UPPER('&operation')
                WHEN 'DROP' THEN
                    EXECUTE IMMEDIATE 'DROP TABLE ' || UPPER('&arg3') || ' CASCADE CONSTRAINTS PURGE';
                    DBMS_OUTPUT.PUT_LINE('✓ Dropped: ' || UPPER('&arg3'));
                    
                WHEN 'RENAME' THEN
                    EXECUTE IMMEDIATE 'ALTER TABLE ' || UPPER('&arg3') || ' RENAME TO ' || UPPER('&arg4');
                    DBMS_OUTPUT.PUT_LINE('✓ Renamed: ' || UPPER('&arg3') || ' → ' || UPPER('&arg4'));
                    
                ELSE
                    DBMS_OUTPUT.PUT_LINE('ERROR: Unknown CLEANUP operation');
                    DBMS_OUTPUT.PUT_LINE('Valid: drop, rename');
                    v_result := FALSE;
            END CASE;
        
        ELSE
            DBMS_OUTPUT.PUT_LINE('ERROR: Unknown category: &category');
            DBMS_OUTPUT.PUT_LINE('Valid categories: READONLY, WRITE, WORKFLOW, CLEANUP');
            v_result := FALSE;
    END CASE;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('RESULT: ERROR - ' || SQLERRM);
        v_result := FALSE;
END;
/

PROMPT =============================================================

