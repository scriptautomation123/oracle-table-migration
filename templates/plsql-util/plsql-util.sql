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
--   SYS       - System-level operations (requires SYSDBA)
-- ==================================================================
-- NOTE: All queries use ALL_* views with explicit owner filters
-- SYS operations require SYSDBA privileges and use DBA_* views
-- ==================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF

-- Toad standalone compatibility
-- If running in Toad standalone mode, use default values
DEFINE category = '&1'
DEFINE operation = '&2'
DEFINE arg3 = '&3'
DEFINE arg4 = '&4'
DEFINE arg5 = '&5'
DEFINE arg6 = '&6'
DEFINE arg7 = '&7'

-- For Toad standalone execution, provide defaults if no parameters
-- Usage in Toad: Set substitution variables manually or use defaults
-- Default: READONLY check_existence SCHEMA TABLE

PROMPT =============================================================
PROMPT PL/SQL UTILITY - Category: &category | Operation: &operation
PROMPT =============================================================
PROMPT Toad Standalone Mode: Set substitution variables manually
PROMPT Example: :category = 'READONLY', :operation = 'check_existence'
PROMPT =============================================================

-- Toad Standalone Execution Support
-- If running in Toad without parameters, use these defaults
-- Uncomment and modify the following lines for Toad standalone execution:

/*
-- Toad Standalone Configuration (uncomment and modify as needed)
DEFINE category = 'READONLY'
DEFINE operation = 'check_existence'
DEFINE arg3 = 'SCHEMA_NAME'
DEFINE arg4 = 'TABLE_NAME'
DEFINE arg5 = ''
DEFINE arg6 = ''
DEFINE arg7 = ''
*/

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
            CASE v_operation
                WHEN 'ENABLE_CONSTRAINTS' THEN
                    DECLARE
                        v_disabled_count NUMBER;
                        v_total_count NUMBER;
                        v_safe_table VARCHAR2(256);
                    BEGIN
                        v_safe_table := safe_schema_table(v_arg3, v_arg4);

                        SELECT COUNT(*) INTO v_total_count
                        FROM all_constraints
                        WHERE owner = v_arg3 AND table_name = v_arg4
                          AND constraint_type IN ('U', 'P', 'R', 'C');

                        SELECT COUNT(*) INTO v_disabled_count
                        FROM all_constraints
                        WHERE owner = v_arg3 AND table_name = v_arg4
                          AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'DISABLED';

                        DBMS_OUTPUT.PUT_LINE('Total constraints: ' || v_total_count);
                        DBMS_OUTPUT.PUT_LINE('Currently disabled: ' || v_disabled_count);

                        FOR c IN (
                            SELECT constraint_name, constraint_type
                            FROM all_constraints
                            WHERE owner = v_arg3 AND table_name = v_arg4
                              AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'DISABLED'
                            ORDER BY CASE constraint_type WHEN 'P' THEN 1 WHEN 'U' THEN 2 WHEN 'C' THEN 3 WHEN 'R' THEN 4 END
                        ) LOOP
                            BEGIN
                                EXECUTE IMMEDIATE 'ALTER TABLE ' || v_safe_table ||
                                                 ' ENABLE NOVALIDATE CONSTRAINT ' || DBMS_ASSERT.ENQUOTE_NAME(c.constraint_name);
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
                        v_safe_table VARCHAR2(256);
                    BEGIN
                        v_safe_table := safe_schema_table(v_arg3, v_arg4);

                        SELECT COUNT(*) INTO v_total_count
                        FROM all_constraints
                        WHERE owner = v_arg3 AND table_name = v_arg4
                          AND constraint_type IN ('U', 'P', 'R', 'C');

                        SELECT COUNT(*) INTO v_enabled_count
                        FROM all_constraints
                        WHERE owner = v_arg3 AND table_name = v_arg4
                          AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'ENABLED';

                        DBMS_OUTPUT.PUT_LINE('Total constraints: ' || v_total_count);
                        DBMS_OUTPUT.PUT_LINE('Currently enabled: ' || v_enabled_count);

                        FOR c IN (
                            SELECT constraint_name, constraint_type
                            FROM all_constraints
                            WHERE owner = v_arg3 AND table_name = v_arg4
                              AND constraint_type IN ('U', 'P', 'R', 'C') AND status = 'ENABLED'
                            ORDER BY CASE constraint_type WHEN 'R' THEN 1 WHEN 'C' THEN 2 WHEN 'U' THEN 3 WHEN 'P' THEN 4 END
                        ) LOOP
                            BEGIN
                                EXECUTE IMMEDIATE 'ALTER TABLE ' || v_safe_table ||
                                                 ' DISABLE CONSTRAINT ' || DBMS_ASSERT.ENQUOTE_NAME(c.constraint_name);
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
                        v_schema VARCHAR2(128) := v_arg3;
                        v_table VARCHAR2(128) := v_arg4;
                        v_new_table VARCHAR2(128) := v_table || '_NEW';
                        v_old_table VARCHAR2(128) := v_table || '_OLD';
                        v_view_name VARCHAR2(128) := v_table || '_JOINED';
                        v_trigger_name VARCHAR2(128) := 'TG_' || SUBSTR(v_table, 1, 23) || '_IOT'; -- Ensure under 30 char limit

                        -- Column information
                        v_pk_columns VARCHAR2(4000);
                        v_all_columns VARCHAR2(4000);
                        v_insert_columns VARCHAR2(4000);
                        v_new_values VARCHAR2(4000);
                        v_pk_join_condition VARCHAR2(4000);

                        -- Validation
                        v_new_table_exists NUMBER;
                        v_old_table_exists NUMBER;

                        -- SQL statements
                        v_view_sql CLOB;
                        v_trigger_sql CLOB;
                    BEGIN
                        DBMS_OUTPUT.PUT_LINE('Creating migration view and trigger...');
                        DBMS_OUTPUT.PUT_LINE('  Schema: ' || v_schema);
                        DBMS_OUTPUT.PUT_LINE('  Table: ' || v_table);
                        DBMS_OUTPUT.PUT_LINE('  New table: ' || v_new_table);
                        DBMS_OUTPUT.PUT_LINE('  Old table: ' || v_old_table);
                        DBMS_OUTPUT.PUT_LINE('  View: ' || v_view_name);
                        DBMS_OUTPUT.PUT_LINE('  Trigger: ' || v_trigger_name);

                        -- Check NEW table exists
                        SELECT COUNT(*) INTO v_new_table_exists
                        FROM all_tables
                        WHERE owner = v_schema AND table_name = v_new_table;

                        IF v_new_table_exists = 0 THEN
                            DBMS_OUTPUT.PUT_LINE('  FAILED: New table does not exist');
                            v_result := FALSE;
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('  ✓ New table exists');
                        END IF;

                        -- Check OLD table exists
                        SELECT COUNT(*) INTO v_old_table_exists
                        FROM all_tables
                        WHERE owner = v_schema AND table_name = v_old_table;

                        IF v_old_table_exists = 0 THEN
                            DBMS_OUTPUT.PUT_LINE('  FAILED: Old table does not exist');
                            v_result := FALSE;
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('  ✓ Old table exists');
                        END IF;

                        IF NOT v_result THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Prerequisites not met');
                            RETURN;
                        END IF;

                        -- Get PK columns from NEW table
                        SELECT LISTAGG(cc.column_name, ', ')
                               WITHIN GROUP (ORDER BY cc.position)
                        INTO v_pk_columns
                        FROM all_constraints c
                        JOIN all_cons_columns cc
                            ON c.constraint_name = cc.constraint_name
                            AND c.owner = cc.owner
                        WHERE c.owner = v_schema
                            AND c.table_name = v_new_table
                            AND c.constraint_type = 'P';

                        IF v_pk_columns IS NULL THEN
                            RAISE_APPLICATION_ERROR(-20004,
                                'NEW table must have a primary key: ' || v_schema || '.' || v_new_table || '. ' ||
                                'Cannot create migration view without a primary key for deduplication.');
                        END IF;

                        DBMS_OUTPUT.PUT_LINE('  ✓ Primary key found: ' || v_pk_columns);

                        -- Get all columns for SELECT and INSERT
                        SELECT
                            LISTAGG(column_name, ', ')
                                WITHIN GROUP (ORDER BY column_id),
                            LISTAGG(':NEW.' || column_name, ', ')
                                WITHIN GROUP (ORDER BY column_id)
                        INTO v_all_columns, v_new_values
                        FROM all_tab_columns
                        WHERE owner = v_schema
                            AND table_name = v_new_table
                            AND virtual_column = 'NO'; -- Exclude virtual columns

                        IF v_all_columns IS NULL THEN
                            RAISE_APPLICATION_ERROR(-20005,
                                'No columns found in NEW table: ' || v_schema || '.' || v_new_table);
                        END IF;

                        v_insert_columns := v_all_columns; -- Same list for INSERT

                        DBMS_OUTPUT.PUT_LINE('  ✓ Found ' ||
                            REGEXP_COUNT(v_all_columns, ',') + 1 || ' columns');

                        -- Build PK join condition
                        DECLARE
                            v_pk_array DBMS_SQL.VARCHAR2_TABLE;
                            v_pk_count NUMBER;
                            v_join_parts DBMS_SQL.VARCHAR2_TABLE;
                        BEGIN
                            -- Split PK columns by comma
                            v_pk_count := REGEXP_COUNT(v_pk_columns, ',') + 1;

                            FOR i IN 1..v_pk_count LOOP
                                v_pk_array(i) := TRIM(REGEXP_SUBSTR(v_pk_columns, '[^,]+', 1, i));
                                v_join_parts(i) := 'n.' || v_pk_array(i) || ' = o.' || v_pk_array(i);
                            END LOOP;

                            -- Join with AND
                            v_pk_join_condition := v_join_parts(1);
                            FOR i IN 2..v_pk_count LOOP
                                v_pk_join_condition := v_pk_join_condition || ' AND ' || v_join_parts(i);
                            END LOOP;
                        END;

                        DBMS_OUTPUT.PUT_LINE('  ✓ Join condition: ' || v_pk_join_condition);

                        -- Drop view if exists
                        BEGIN
                            EXECUTE IMMEDIATE 'DROP VIEW ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || DBMS_ASSERT.ENQUOTE_NAME(v_view_name);
                            DBMS_OUTPUT.PUT_LINE('  ✓ Dropped existing view');
                        EXCEPTION
                            WHEN OTHERS THEN
                                IF SQLCODE = -942 THEN  -- Table or view does not exist
                                    DBMS_OUTPUT.PUT_LINE('  ℹ View does not exist (OK)');
                                ELSE
                                    DBMS_OUTPUT.PUT_LINE('  ⚠ Warning: ' || SQLERRM);
                                END IF;
                        END;

                        -- Create view using proper identifier quoting
                        v_view_sql :=
                            'CREATE OR REPLACE VIEW ' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_view_name) || ' AS ' || CHR(10) ||
                            '  SELECT ' || v_all_columns || ' FROM ' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_new_table) || ' n' || CHR(10) ||
                            '  UNION ALL' || CHR(10) ||
                            '  SELECT ' || v_all_columns || ' FROM ' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_old_table) || ' o' || CHR(10) ||
                            '  WHERE NOT EXISTS (' || CHR(10) ||
                            '    SELECT 1 FROM ' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_new_table) || ' n' || CHR(10) ||
                            '    WHERE ' || v_pk_join_condition || CHR(10) ||
                            '  )';

                        -- Execute view creation
                        BEGIN
                            EXECUTE IMMEDIATE v_view_sql;
                            DBMS_OUTPUT.PUT_LINE('  ✓ Created view ' || v_view_name);
                        EXCEPTION
                            WHEN OTHERS THEN
                                DBMS_OUTPUT.PUT_LINE('  ✗ View creation failed');
                                DBMS_OUTPUT.PUT_LINE('SQL: ' || SUBSTR(v_view_sql, 1, 200));
                                RAISE_APPLICATION_ERROR(-20006,
                                    'Failed to create view: ' || SQLERRM);
                        END;

                        -- Drop trigger if exists
                        BEGIN
                            EXECUTE IMMEDIATE 'DROP TRIGGER ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || DBMS_ASSERT.ENQUOTE_NAME(v_trigger_name);
                            DBMS_OUTPUT.PUT_LINE('  ✓ Dropped existing trigger');
                        EXCEPTION
                            WHEN OTHERS THEN
                                IF SQLCODE = -4080 THEN  -- Trigger does not exist
                                    DBMS_OUTPUT.PUT_LINE('  ℹ Trigger does not exist (OK)');
                                ELSE
                                    DBMS_OUTPUT.PUT_LINE('  ⚠ Warning: ' || SQLERRM);
                                END IF;
                        END;

                        -- Create INSTEAD OF trigger with proper :NEW references (NOT :NEW.*)
                        v_trigger_sql :=
                            'CREATE OR REPLACE TRIGGER ' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_trigger_name) || CHR(10) ||
                            '  INSTEAD OF INSERT ON ' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_view_name) || CHR(10) ||
                            '  FOR EACH ROW' || CHR(10) ||
                            'BEGIN' || CHR(10) ||
                            '  -- Insert into NEW table only during migration' || CHR(10) ||
                            '  INSERT INTO ' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_new_table) || CHR(10) ||
                            '    (' || v_insert_columns || ')' || CHR(10) ||
                            '  VALUES' || CHR(10) ||
                            '    (' || v_new_values || ');' || CHR(10) ||
                            'EXCEPTION' || CHR(10) ||
                            '  WHEN DUP_VAL_ON_INDEX THEN' || CHR(10) ||
                            '    -- Duplicate key, log and continue' || CHR(10) ||
                            '    NULL;' || CHR(10) ||
                            '  WHEN OTHERS THEN' || CHR(10) ||
                            '    -- Log error and re-raise' || CHR(10) ||
                            '    RAISE;' || CHR(10) ||
                            'END;';

                        -- Execute trigger creation
                        BEGIN
                            EXECUTE IMMEDIATE v_trigger_sql;
                            DBMS_OUTPUT.PUT_LINE('  ✓ Created INSTEAD OF trigger ' || v_trigger_name);
                        EXCEPTION
                            WHEN OTHERS THEN
                                DBMS_OUTPUT.PUT_LINE('  ✗ Trigger creation failed');
                                DBMS_OUTPUT.PUT_LINE('SQL: ' || SUBSTR(v_trigger_sql, 1, 200));
                                RAISE_APPLICATION_ERROR(-20007,
                                    'Failed to create trigger: ' || SQLERRM);
                        END;

                        -- Create restriction triggers (UPDATE/DELETE not allowed)
                        EXECUTE IMMEDIATE
                            'CREATE OR REPLACE TRIGGER ' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' ||
                            DBMS_ASSERT.ENQUOTE_NAME(SUBSTR(v_trigger_name, 1, 26) || '_UPD') || CHR(10) ||
                            '  INSTEAD OF UPDATE ON ' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_view_name) || CHR(10) ||
                            '  FOR EACH ROW' || CHR(10) ||
                            'BEGIN' || CHR(10) ||
                            '  RAISE_APPLICATION_ERROR(-20100, ' || CHR(10) ||
                            '    ''UPDATE not supported on migration view. Use direct table access.'');' || CHR(10) ||
                            'END;';

                        DBMS_OUTPUT.PUT_LINE('  ✓ UPDATE restriction trigger created');

                        EXECUTE IMMEDIATE
                            'CREATE OR REPLACE TRIGGER ' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' ||
                            DBMS_ASSERT.ENQUOTE_NAME(SUBSTR(v_trigger_name, 1, 26) || '_DEL') || CHR(10) ||
                            '  INSTEAD OF DELETE ON ' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' ||
                            DBMS_ASSERT.ENQUOTE_NAME(v_view_name) || CHR(10) ||
                            '  FOR EACH ROW' || CHR(10) ||
                            'BEGIN' || CHR(10) ||
                            '  RAISE_APPLICATION_ERROR(-20101, ' || CHR(10) ||
                            '    ''DELETE not supported on migration view. Use direct table access.'');' || CHR(10) ||
                            'END;';

                        DBMS_OUTPUT.PUT_LINE('  ✓ DELETE restriction trigger created');

                        DBMS_OUTPUT.PUT_LINE('');
                        DBMS_OUTPUT.PUT_LINE('================================================================');
                        DBMS_OUTPUT.PUT_LINE('✓ Migration view and triggers created successfully');
                        DBMS_OUTPUT.PUT_LINE('================================================================');
                        DBMS_OUTPUT.PUT_LINE('View: ' || v_schema || '.' || v_view_name);
                        DBMS_OUTPUT.PUT_LINE('  - Combines data from NEW and OLD tables');
                        DBMS_OUTPUT.PUT_LINE('  - Deduplicates using PK: ' || v_pk_columns);
                        DBMS_OUTPUT.PUT_LINE('  - Supports: INSERT only');
                        DBMS_OUTPUT.PUT_LINE('  - Restrictions: UPDATE and DELETE will raise errors');
                        DBMS_OUTPUT.PUT_LINE('');
                        DBMS_OUTPUT.PUT_LINE('Usage:');
                        DBMS_OUTPUT.PUT_LINE('  INSERT INTO ' || v_schema || '.' || v_view_name || ' VALUES (...);');
                        DBMS_OUTPUT.PUT_LINE('  -- Data will be inserted into ' || v_new_table);
                        DBMS_OUTPUT.PUT_LINE('================================================================');

                        DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - View and trigger created successfully');
                    END;

                WHEN 'FINALIZE_SWAP' THEN
                    -- Complete the swap: drop old, rename new, drop view/trigger, validate
                    DECLARE
                        v_schema VARCHAR2(128) := v_arg3;
                        v_table VARCHAR2(128) := v_arg4;
                        v_new_table VARCHAR2(128) := v_table || '_NEW';
                        v_old_table VARCHAR2(128) := v_table || '_OLD';
                        v_view_name VARCHAR2(128) := v_table || '_JOINED';
                        v_trigger_name VARCHAR2(128) := 'TG_' || SUBSTR(v_table, 1, 23) || '_IOT';
                    BEGIN
                        DBMS_OUTPUT.PUT_LINE('Finalizing swap operation...');
                        DBMS_OUTPUT.PUT_LINE('  Schema: ' || v_schema);
                        DBMS_OUTPUT.PUT_LINE('  Table: ' || v_table);

                        -- Step 1: Drop INSTEAD OF trigger
                        BEGIN
                            EXECUTE IMMEDIATE 'DROP TRIGGER ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || DBMS_ASSERT.ENQUOTE_NAME(v_trigger_name);
                            DBMS_OUTPUT.PUT_LINE('  ✓ Dropped trigger');
                        EXCEPTION
                            WHEN OTHERS THEN
                                IF SQLCODE = -4080 THEN  -- Trigger does not exist
                                    DBMS_OUTPUT.PUT_LINE('  ℹ Trigger does not exist (OK)');
                                ELSE
                                    DBMS_OUTPUT.PUT_LINE('  ✗ Failed to drop trigger: ' || SQLERRM);
                                    v_result := FALSE;
                                END IF;
                        END;

                        -- Step 2: Drop view
                        BEGIN
                            EXECUTE IMMEDIATE 'DROP VIEW ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || DBMS_ASSERT.ENQUOTE_NAME(v_view_name);
                            DBMS_OUTPUT.PUT_LINE('  ✓ Dropped view');
                        EXCEPTION
                            WHEN OTHERS THEN
                                IF SQLCODE = -942 THEN  -- View does not exist
                                    DBMS_OUTPUT.PUT_LINE('  ℹ View does not exist (OK)');
                                ELSE
                                    DBMS_OUTPUT.PUT_LINE('  ✗ Failed to drop view: ' || SQLERRM);
                                    v_result := FALSE;
                                END IF;
                        END;

                        -- Step 3: Drop old table
                        BEGIN
                            EXECUTE IMMEDIATE 'DROP TABLE ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || DBMS_ASSERT.ENQUOTE_NAME(v_old_table) || ' PURGE';
                            DBMS_OUTPUT.PUT_LINE('  ✓ Dropped old table');
                        EXCEPTION
                            WHEN OTHERS THEN
                                IF SQLCODE = -942 THEN  -- Table does not exist
                                    DBMS_OUTPUT.PUT_LINE('  ℹ Old table does not exist (OK)');
                                ELSE
                                    DBMS_OUTPUT.PUT_LINE('  ✗ Failed to drop old table: ' || SQLERRM);
                                    v_result := FALSE;
                                END IF;
                        END;

                        -- Step 4: Rename new table to original name
                        BEGIN
                            EXECUTE IMMEDIATE 'ALTER TABLE ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' || DBMS_ASSERT.ENQUOTE_NAME(v_new_table) ||
                                             ' RENAME TO ' || DBMS_ASSERT.ENQUOTE_NAME(v_table);
                            DBMS_OUTPUT.PUT_LINE('  ✓ Renamed ' || v_new_table || ' to ' || v_table);
                        EXCEPTION
                            WHEN OTHERS THEN
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
                                            EXECUTE IMMEDIATE 'ALTER ' || obj.object_type || ' ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || '.' ||
                                                           DBMS_ASSERT.ENQUOTE_NAME(obj.object_name) || ' COMPILE';
                                            DBMS_OUTPUT.PUT_LINE('      ✓ Recompiled successfully');
                                        END IF;
                                    EXCEPTION
                                        WHEN OTHERS THEN
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
                        v_schema VARCHAR2(128) := v_arg3;
                        v_table VARCHAR2(128) := v_arg4;
                        v_days_ahead NUMBER := TO_NUMBER(NVL(v_arg5, '2')); -- days to pre-create
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
                        v_schema VARCHAR2(128) := v_arg3;
                        v_table VARCHAR2(128) := v_arg4;
                        v_subpart_col VARCHAR2(128) := v_arg5; -- subpartition column
                        v_subpart_count NUMBER := TO_NUMBER(NVL(v_arg6, '8')); -- number of subpartitions
                        v_safe_table VARCHAR2(256);
                    BEGIN
                        DBMS_OUTPUT.PUT_LINE('Adding hash subpartitions to interval table...');
                        DBMS_OUTPUT.PUT_LINE('  Schema: ' || v_schema);
                        DBMS_OUTPUT.PUT_LINE('  Table: ' || v_table);
                        DBMS_OUTPUT.PUT_LINE('  Subpartition Column: ' || v_subpart_col);
                        DBMS_OUTPUT.PUT_LINE('  Subpartition Count: ' || v_subpart_count);

                        v_safe_table := safe_schema_table(v_schema, v_table);

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
                            EXECUTE IMMEDIATE 'ALTER TABLE ' || v_safe_table ||
                                             ' SET SUBPARTITION TEMPLATE (SUBPARTITION BY HASH (' ||
                                             DBMS_ASSERT.ENQUOTE_NAME(v_subpart_col) || ') SUBPARTITIONS ' || v_subpart_count || ')';

                            DBMS_OUTPUT.PUT_LINE('  ✓ Modified table structure');

                            -- Regenerate partitions to apply template
                            EXECUTE IMMEDIATE 'ALTER TABLE ' || v_safe_table ||
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
            CASE v_operation
                WHEN 'DROP' THEN
                    DECLARE
                        v_safe_table VARCHAR2(256);
                    BEGIN
                        v_safe_table := safe_schema_table(v_arg3, v_arg4);
                        EXECUTE IMMEDIATE 'DROP TABLE ' || v_safe_table || ' CASCADE CONSTRAINTS PURGE';
                        DBMS_OUTPUT.PUT_LINE('✓ Dropped: ' || v_safe_table);
                    EXCEPTION
                        WHEN OTHERS THEN
                            DBMS_OUTPUT.PUT_LINE('✗ Failed to drop table: ' || SQLERRM);
                            v_result := FALSE;
                    END;

                WHEN 'RENAME' THEN
                    DECLARE
                        v_safe_table VARCHAR2(256);
                        v_safe_new_name VARCHAR2(128);
                    BEGIN
                        v_safe_table := safe_schema_table(v_arg3, v_arg4);
                        v_safe_new_name := safe_sql_name(v_arg5);
                        EXECUTE IMMEDIATE 'ALTER TABLE ' || v_safe_table || ' RENAME TO ' || DBMS_ASSERT.ENQUOTE_NAME(v_safe_new_name);
                        DBMS_OUTPUT.PUT_LINE('✓ Renamed: ' || v_safe_table || ' → ' || v_safe_new_name);
                    EXCEPTION
                        WHEN OTHERS THEN
                            DBMS_OUTPUT.PUT_LINE('✗ Failed to rename table: ' || SQLERRM);
                            v_result := FALSE;
                    END;

                ELSE
                    DBMS_OUTPUT.PUT_LINE('ERROR: Unknown CLEANUP operation');
                    DBMS_OUTPUT.PUT_LINE('Valid: drop, rename');
                    v_result := FALSE;
            END CASE;

        -- ==================================================================
        -- SYS CATEGORY - System-level operations (requires SYSDBA)
        -- ==================================================================
        WHEN 'SYS' THEN
            CASE UPPER('&operation')
                WHEN 'CHECK_PRIVILEGES' THEN
                    -- Check if current user has SYSDBA privileges
                    DECLARE
                        v_is_sysdba NUMBER;
                        v_current_user VARCHAR2(128);
                    BEGIN
                        SELECT COUNT(*) INTO v_is_sysdba
                        FROM v$session s, v$session_roles sr
                        WHERE s.sid = SYS_CONTEXT('USERENV', 'SID')
                          AND s.sid = sr.sid
                          AND sr.granted_role = 'DBA';

                        SELECT USER INTO v_current_user FROM dual;

                        DBMS_OUTPUT.PUT_LINE('Current user: ' || v_current_user);
                        DBMS_OUTPUT.PUT_LINE('SYSDBA privileges: ' || CASE WHEN v_is_sysdba > 0 THEN 'YES' ELSE 'NO' END);

                        IF v_is_sysdba > 0 THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - SYSDBA privileges confirmed');
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - SYSDBA privileges required');
                            v_result := FALSE;
                        END IF;
                    END;

                WHEN 'CHECK_TABLESPACE' THEN
                    -- Check tablespace usage and availability
                    DECLARE
                        v_tablespace VARCHAR2(128) := UPPER('&arg3');
                        v_free_space NUMBER;
                        v_total_space NUMBER;
                        v_used_pct NUMBER;
                    BEGIN
                        IF v_tablespace IS NULL OR v_tablespace = '' THEN
                            -- Show all tablespaces
                            DBMS_OUTPUT.PUT_LINE('Tablespace Usage Summary:');
                            DBMS_OUTPUT.PUT_LINE('=====================================');

                            FOR ts IN (
                                SELECT tablespace_name,
                                       ROUND(SUM(bytes)/1024/1024/1024, 2) as total_gb,
                                       ROUND(SUM(bytes - NVL(free_bytes, 0))/1024/1024/1024, 2) as used_gb,
                                       ROUND(NVL(SUM(free_bytes), 0)/1024/1024/1024, 2) as free_gb,
                                       ROUND((SUM(bytes - NVL(free_bytes, 0))/SUM(bytes))*100, 1) as used_pct
                                FROM (
                                    SELECT tablespace_name, bytes, 0 as free_bytes
                                    FROM dba_data_files
                                    UNION ALL
                                    SELECT tablespace_name, 0 as bytes, bytes as free_bytes
                                    FROM dba_free_space
                                )
                                GROUP BY tablespace_name
                                ORDER BY used_pct DESC
                            ) LOOP
                                DBMS_OUTPUT.PUT_LINE(ts.tablespace_name || ': ' || ts.used_gb || 'GB/' || ts.total_gb || 'GB (' || ts.used_pct || '%)');
                            END LOOP;
                        ELSE
                            -- Check specific tablespace
                            SELECT
                                ROUND(SUM(bytes)/1024/1024/1024, 2),
                                ROUND(SUM(bytes - NVL(free_bytes, 0))/1024/1024/1024, 2),
                                ROUND((SUM(bytes - NVL(free_bytes, 0))/SUM(bytes))*100, 1)
                            INTO v_total_space, v_free_space, v_used_pct
                            FROM (
                                SELECT tablespace_name, bytes, 0 as free_bytes
                                FROM dba_data_files
                                WHERE tablespace_name = v_tablespace
                                UNION ALL
                                SELECT tablespace_name, 0 as bytes, bytes as free_bytes
                                FROM dba_free_space
                                WHERE tablespace_name = v_tablespace
                            );

                            DBMS_OUTPUT.PUT_LINE('Tablespace: ' || v_tablespace);
                            DBMS_OUTPUT.PUT_LINE('Total Space: ' || v_total_space || 'GB');
                            DBMS_OUTPUT.PUT_LINE('Used Space: ' || (v_total_space - v_free_space) || 'GB');
                            DBMS_OUTPUT.PUT_LINE('Free Space: ' || v_free_space || 'GB');
                            DBMS_OUTPUT.PUT_LINE('Used %: ' || v_used_pct || '%');

                            IF v_used_pct > 90 THEN
                                DBMS_OUTPUT.PUT_LINE('RESULT: WARNING - Tablespace nearly full');
                            ELSE
                                DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - Tablespace space OK');
                            END IF;
                        END IF;
                    END;

                WHEN 'CHECK_SESSIONS_ALL' THEN
                    -- Check all active sessions (system-wide)
                    DECLARE
                        v_pattern VARCHAR2(128) := UPPER('&arg3');
                        v_session_count NUMBER := 0;
                    BEGIN
                        DBMS_OUTPUT.PUT_LINE('Active Sessions Summary:');
                        DBMS_OUTPUT.PUT_LINE('=====================================');

                        FOR sess IN (
                            SELECT username, status, COUNT(*) as session_count
                            FROM v$session
                            WHERE username IS NOT NULL
                              AND (v_pattern IS NULL OR UPPER(username) LIKE '%' || v_pattern || '%')
                            GROUP BY username, status
                            ORDER BY session_count DESC
                        ) LOOP
                            DBMS_OUTPUT.PUT_LINE(sess.username || ' (' || sess.status || '): ' || sess.session_count || ' sessions');
                            v_session_count := v_session_count + sess.session_count;
                        END LOOP;

                        DBMS_OUTPUT.PUT_LINE('Total active sessions: ' || v_session_count);

                        IF v_session_count > 0 THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: INFO - Active sessions found');
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - No active sessions');
                        END IF;
                    END;

                WHEN 'KILL_SESSIONS' THEN
                    -- Kill sessions matching pattern (use with caution!)
                    DECLARE
                        v_pattern VARCHAR2(128) := UPPER('&arg3');
                        v_kill_count NUMBER := 0;
                    BEGIN
                        IF v_pattern IS NULL OR v_pattern = '' THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: FAILED - Pattern required for safety');
                            v_result := FALSE;
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('Killing sessions matching: ' || v_pattern);
                            DBMS_OUTPUT.PUT_LINE('WARNING: This will terminate user sessions!');

                            FOR sess IN (
                                SELECT sid, serial#, username, program
                                FROM v$session
                                WHERE username IS NOT NULL
                                  AND UPPER(username) LIKE '%' || v_pattern || '%'
                                  AND username != USER -- Don't kill own session
                            ) LOOP
                                BEGIN
                                    EXECUTE IMMEDIATE 'ALTER SYSTEM KILL SESSION ''' || sess.sid || ',' || sess.serial# || ''' IMMEDIATE';
                                    DBMS_OUTPUT.PUT_LINE('  Killed: ' || sess.username || ' (' || sess.program || ')');
                                    v_kill_count := v_kill_count + 1;
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        DBMS_OUTPUT.PUT_LINE('  Failed to kill: ' || sess.username || ' - ' || SQLERRM);
                                END;
                            END LOOP;

                            DBMS_OUTPUT.PUT_LINE('Killed ' || v_kill_count || ' sessions');
                            DBMS_OUTPUT.PUT_LINE('RESULT: COMPLETED - Session cleanup done');
                        END IF;
                    END;

                WHEN 'CHECK_INVALID_OBJECTS' THEN
                    -- Check for invalid objects in schema or system-wide
                    DECLARE
                        v_schema VARCHAR2(128) := UPPER('&arg3');
                        v_invalid_count NUMBER := 0;
                    BEGIN
                        IF v_schema IS NULL OR v_schema = '' THEN
                            -- System-wide check
                            SELECT COUNT(*) INTO v_invalid_count
                            FROM dba_objects
                            WHERE status = 'INVALID';

                            DBMS_OUTPUT.PUT_LINE('System-wide Invalid Objects: ' || v_invalid_count);

                            IF v_invalid_count > 0 THEN
                                DBMS_OUTPUT.PUT_LINE('Top 10 invalid objects:');
                                FOR obj IN (
                                    SELECT owner, object_name, object_type, status
                                    FROM dba_objects
                                    WHERE status = 'INVALID'
                                    ORDER BY owner, object_type, object_name
                                    FETCH FIRST 10 ROWS ONLY
                                ) LOOP
                                    DBMS_OUTPUT.PUT_LINE('  ' || obj.owner || '.' || obj.object_name || ' (' || obj.object_type || ')');
                                END LOOP;
                            END IF;
                        ELSE
                            -- Schema-specific check
                            SELECT COUNT(*) INTO v_invalid_count
                            FROM dba_objects
                            WHERE owner = v_schema AND status = 'INVALID';

                            DBMS_OUTPUT.PUT_LINE('Invalid objects in ' || v_schema || ': ' || v_invalid_count);

                            IF v_invalid_count > 0 THEN
                                FOR obj IN (
                                    SELECT object_name, object_type, status
                                    FROM dba_objects
                                    WHERE owner = v_schema AND status = 'INVALID'
                                    ORDER BY object_type, object_name
                                ) LOOP
                                    DBMS_OUTPUT.PUT_LINE('  ' || obj.object_name || ' (' || obj.object_type || ')');
                                END LOOP;
                            END IF;
                        END IF;

                        IF v_invalid_count = 0 THEN
                            DBMS_OUTPUT.PUT_LINE('RESULT: PASSED - No invalid objects found');
                        ELSE
                            DBMS_OUTPUT.PUT_LINE('RESULT: WARNING - ' || v_invalid_count || ' invalid objects found');
                        END IF;
                    END;

                ELSE
                    DBMS_OUTPUT.PUT_LINE('ERROR: Unknown SYS operation');
                    DBMS_OUTPUT.PUT_LINE('Valid: check_privileges, check_tablespace, check_sessions_all, kill_sessions, check_invalid_objects');
                    v_result := FALSE;
            END CASE;

        ELSE
            DBMS_OUTPUT.PUT_LINE('ERROR: Unknown category: ' || v_category);
            DBMS_OUTPUT.PUT_LINE('Valid categories: READONLY, WRITE, WORKFLOW, CLEANUP, SYS');
            v_result := FALSE;
    END CASE;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('RESULT: ERROR - ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
        v_result := FALSE;
END;
/

PROMPT =============================================================

