-- ==================================================================
-- POST-DATA LOAD VALIDATION
-- ==================================================================
-- Usage: @validation/post_data_load_checks.sql <owner> <table_name> <source_table> <source_row_count> <parallel_degree>
-- ==================================================================
-- Accepts: &1 = owner, &2 = target table, &3 = source table, &4 = source row count, &5 = parallel degree
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE owner = '&1'
DEFINE target_table = '&2'
DEFINE source_table = '&3'
DEFINE source_row_count = '&4'
DEFINE parallel_degree = '&5'

PROMPT =============================================================
PROMPT Post-Data Load Validation for &owner..&target_table
PROMPT =============================================================

-- Verify target table is not empty
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM &owner..&target_table;
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('✗ ERROR: Target table is empty after load!');
        RAISE_APPLICATION_ERROR(-20001, 'Target table is empty');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ Target table row count: ' || v_count);
    END IF;
END;
/

-- Compare source and target row counts
DECLARE
    v_source_count NUMBER := TO_NUMBER('&source_row_count');
    v_target_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_target_count FROM &owner..&target_table;
    DBMS_OUTPUT.PUT_LINE('Source Rows: ' || v_source_count);
    DBMS_OUTPUT.PUT_LINE('Target Rows: ' || v_target_count);
    IF v_source_count = v_target_count THEN
        DBMS_OUTPUT.PUT_LINE('✓✓✓ Row count MATCH - Data load SUCCESSFUL! ✓✓✓');
    ELSIF v_target_count > v_source_count THEN
        DBMS_OUTPUT.PUT_LINE('✗✗✗ ERROR: Target has MORE rows than source! ✗✗✗');
        RAISE_APPLICATION_ERROR(-20002, 'Target row count exceeds source');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗✗✗ WARNING: Row count MISMATCH - ' || (v_source_count - v_target_count) || ' rows missing! ✗✗✗');
        RAISE_APPLICATION_ERROR(-20001, 'Row count mismatch detected');
    END IF;
END;
/

-- Gather statistics on loaded table
PROMPT Gathering statistics on target table...
DECLARE
    v_stats_start TIMESTAMP := SYSTIMESTAMP;
    v_stats_end TIMESTAMP;
    v_stats_duration NUMBER;
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => '&owner',
        tabname => '&target_table',
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        method_opt => 'FOR ALL COLUMNS SIZE AUTO',
        degree => TO_NUMBER('&parallel_degree'),
        cascade => FALSE,
        granularity => 'AUTO',
        no_invalidate => FALSE
    );
    v_stats_end := SYSTIMESTAMP;
    v_stats_duration := EXTRACT(SECOND FROM (v_stats_end - v_stats_start));
    DBMS_OUTPUT.PUT_LINE('✓ Statistics gathered successfully');
    DBMS_OUTPUT.PUT_LINE('  Duration: ' || ROUND(v_stats_duration, 2) || ' seconds');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: Statistics gathering failed: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('         You may need to gather stats manually later');
END;
/

PROMPT =============================================================
PROMPT Data load validation complete
PROMPT =============================================================
