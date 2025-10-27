
-- ==================================================================
-- DELTA LOAD: APP_DATA_OWNER.TEMP_CALCULATIONS_NEW
-- ==================================================================
-- Generated: 2025-10-25 21:07:54
-- Captures changes since initial load: 2025-10-25 21:07:54
-- ==================================================================

SET ECHO ON
SET TIMING ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT Step 40: Delta Load (Incremental Changes)
PROMPT ================================================================
PROMPT Source: APP_DATA_OWNER.TEMP_CALCULATIONS
PROMPT Target: APP_DATA_OWNER.TEMP_CALCULATIONS_NEW
PROMPT Captures changes since: 2025-10-25 21:07:54
PROMPT ================================================================

-- Variables for timing and counts
VARIABLE v_start_time VARCHAR2(30)
VARIABLE v_end_time VARCHAR2(30)
VARIABLE v_delta_count NUMBER
VARIABLE v_insert_count NUMBER
VARIABLE v_update_count NUMBER

-- Record start time
BEGIN
    SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') INTO :v_start_time FROM dual;
    DBMS_OUTPUT.PUT_LINE('Delta load started at: ' || :v_start_time);
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- Configurable delta load based on partition key and interval
PROMPT Calculating delta cutoff based on interval: last_day
DECLARE
    v_partition_column VARCHAR2(128) := 'CALC_TIMESTAMP';
    v_delta_interval VARCHAR2(20) := 'last_day';
    v_cutoff_timestamp DATE;
    v_table_name VARCHAR2(128) := 'APP_DATA_OWNER.TEMP_CALCULATIONS';
    v_sql VARCHAR2(4000);
BEGIN
    -- Calculate cutoff timestamp based on configured interval
    CASE v_delta_interval
        WHEN 'last_hour' THEN
            v_cutoff_timestamp := SYSDATE - INTERVAL '1' HOUR;
        WHEN 'last_day' THEN  
            v_cutoff_timestamp := SYSDATE - INTERVAL '1' DAY;
        WHEN 'last_week' THEN
            v_cutoff_timestamp := SYSDATE - INTERVAL '7' DAY;
        ELSE
            -- Default to last day if interval not recognized
            v_cutoff_timestamp := SYSDATE - INTERVAL '1' DAY;
    END CASE;
    
    DBMS_OUTPUT.PUT_LINE('Delta load configuration:');
    DBMS_OUTPUT.PUT_LINE('  Interval: ' || v_delta_interval);  
    DBMS_OUTPUT.PUT_LINE('  Cutoff timestamp: ' || TO_CHAR(v_cutoff_timestamp, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('  Partition column: ' || v_partition_column);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Build safe SQL with proper escaping
    v_sql := 'SELECT COUNT(*) FROM ' || v_table_name || ' WHERE ' || v_partition_column || ' > :1';
    
    DBMS_OUTPUT.PUT_LINE('Counting delta rows...');
    DBMS_OUTPUT.PUT_LINE('Executing: ' || v_sql);
    
    EXECUTE IMMEDIATE v_sql INTO :v_delta_count USING v_cutoff_timestamp;
    
    DBMS_OUTPUT.PUT_LINE('Delta rows to process: ' || TO_CHAR(:v_delta_count, '999,999,999,999'));
    DBMS_OUTPUT.PUT_LINE('');
    
    IF :v_delta_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No delta changes found for interval ' || v_delta_interval || ' - skipping delta load');
        RETURN;
    END IF;
    
    -- Store cutoff for use in subsequent operations
    SELECT TO_CHAR(v_cutoff_timestamp, 'YYYY-MM-DD HH24:MI:SS') INTO :v_start_time FROM dual;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR counting delta rows: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('SQL attempted: ' || v_sql);
        RAISE;
END;
/


-- Delta load with MERGE (tables with primary keys)
PROMPT Processing delta changes with MERGE...

MERGE /*+ PARALLEL(4) */ INTO APP_DATA_OWNER.TEMP_CALCULATIONS_NEW tgt
USING (
    SELECT CALC_TIMESTAMP, CALC_ID, INPUT_VALUE, OUTPUT_VALUE, CALC_NAME
    FROM APP_DATA_OWNER.TEMP_CALCULATIONS
    WHERE CALC_TIMESTAMP > 
    (CASE 'last_day'
        WHEN 'last_hour' THEN SYSDATE - INTERVAL '1' HOUR
        WHEN 'last_day' THEN SYSDATE - INTERVAL '1' DAY  
        WHEN 'last_week' THEN SYSDATE - INTERVAL '7' DAY
        ELSE SYSDATE - INTERVAL '1' DAY
    END)
) src
ON (tgt.CALC_TIMESTAMP = src.CALC_TIMESTAMP)
WHEN MATCHED THEN
    UPDATE SET 
WHEN NOT MATCHED THEN
    INSERT (CALC_TIMESTAMP, CALC_ID, INPUT_VALUE, OUTPUT_VALUE, CALC_NAME)
    VALUES (CALC_TIMESTAMP, CALC_ID, INPUT_VALUE, OUTPUT_VALUE, CALC_NAME);

-- Get merge statistics
BEGIN
    :v_insert_count := SQL%ROWCOUNT;
    DBMS_OUTPUT.PUT_LINE('Delta load completed: ' || TO_CHAR(:v_insert_count, '999,999,999,999') || ' rows processed');
END;
/



COMMIT;

-- Record end time
BEGIN
    SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') INTO :v_end_time FROM dual;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Delta load finished at: ' || :v_end_time);
END;
/

PROMPT ✓ Step 40 Complete: Delta load finished
