
-- ==================================================================
-- DATA LOAD: APP_DATA_OWNER.SESSION_DATA -> APP_DATA_OWNER.SESSION_DATA_NEW
-- ==================================================================
-- Generated: 2025-10-25 21:07:54
-- Estimated rows: 30 rows
-- Estimated size: 0.01 GB
-- Estimated time: < 1 minute
-- Parallel degree: 4
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON
SET TIMING ON
SET FEEDBACK ON
SET VERIFY OFF

PROMPT ================================================================
PROMPT Step 20: Initial Data Load
PROMPT ================================================================
PROMPT Source: APP_DATA_OWNER.SESSION_DATA
PROMPT Target: APP_DATA_OWNER.SESSION_DATA_NEW
PROMPT Method: Parallel INSERT /*+ APPEND */
PROMPT Parallel Degree: 4
PROMPT Estimated Time: < 1 minute
PROMPT ================================================================

-- Variables for timing and counts
VARIABLE v_start_time VARCHAR2(30)
VARIABLE v_end_time VARCHAR2(30)
VARIABLE v_source_count NUMBER
VARIABLE v_target_count NUMBER
VARIABLE v_batch_size NUMBER

-- Record start time
BEGIN
    SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') INTO :v_start_time FROM dual;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Data load started at: ' || :v_start_time);
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- Get source row count using generic validation
@validation/count_table_rows.sql APP_DATA_OWNER SESSION_DATA 30

-- Verify target table is empty using generic validation
@validation/count_table_rows.sql APP_DATA_OWNER SESSION_DATA_NEW 0

-- Disable constraints on target (performance optimization)
@validation/disable_constraints.sql APP_DATA_OWNER SESSION_DATA_NEW

-- Enable parallel DML
ALTER SESSION ENABLE PARALLEL DML;
ALTER SESSION SET PARALLEL_DEGREE_POLICY = MANUAL;

PROMPT
PROMPT ================================================================
PROMPT Starting Data Load...
PROMPT ================================================================
PROMPT This may take < 1 minute depending on system load
PROMPT Progress will be shown after completion
PROMPT ================================================================

-- Main data load with append hint
INSERT /*+ APPEND PARALLEL(4) NOLOGGING */ 
INTO APP_DATA_OWNER.SESSION_DATA_NEW
(
    CREATED_AT, LAST_ACCESS, USER_ID, SESSION_ID
)
SELECT /*+ PARALLEL(4) */
    CREATED_AT, LAST_ACCESS, USER_ID, SESSION_ID
FROM 
    APP_DATA_OWNER.SESSION_DATA
ORDER BY 
    CREATED_AT  -- Order by partition key for efficient loading;

-- Record end time and commit
BEGIN
    SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') INTO :v_end_time FROM dual;
END;
/

COMMIT;

PROMPT
PROMPT ✓ Data load completed and committed


-- Post-data load validation and statistics
@validation/post_data_load_checks.sql APP_DATA_OWNER SESSION_DATA_NEW SESSION_DATA 30 4

-- Re-enable constraints
@validation/enable_constraints.sql APP_DATA_OWNER SESSION_DATA_NEW

-- Final summary
PROMPT
PROMPT ================================================================
PROMPT Step 20 Complete: Data Load SUCCESSFUL
PROMPT ================================================================
PROMPT Status: SUCCESS ✓
PROMPT Source Rows: :v_source_count (use PRINT v_source_count to see value)
PROMPT Target Rows: :v_target_count (use PRINT v_target_count to see value)
PROMPT Start Time: :v_start_time
PROMPT End Time: :v_end_time
PROMPT
PROMPT Next Steps:
PROMPT   1. Run 30_create_indexes.sql to rebuild indexes
PROMPT   2. Consider running 03_validation/data_comparison.sql
PROMPT   3. Monitor partition growth
PROMPT ================================================================
