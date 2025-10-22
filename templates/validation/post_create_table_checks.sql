-- ==================================================================
-- POST-CREATE TABLE CHECKS
-- ==================================================================
-- Usage: @validation/post_create_table_checks.sql <owner> <table_name> <parallel_degree>
-- ==================================================================
-- Accepts: &1 = owner, &2 = table_name, &3 = parallel_degree
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE owner = '&1'
DEFINE table_name = '&2'
DEFINE parallel_degree = '&3'

PROMPT =============================================================
PROMPT Verifying table structure for &owner..&table_name
PROMPT =============================================================

-- Table structure
SELECT 
    table_name,
    tablespace_name,
    partitioned,
    status,
    num_rows,
    blocks
FROM 
    all_tables
WHERE 
    owner = UPPER('&owner')
    AND table_name = UPPER('&table_name');

-- Partitioning configuration
SELECT 
    table_name,
    partitioning_type,
    subpartitioning_type,
    partition_count,
    def_subpartition_count,
    interval,
    CASE WHEN interval IS NOT NULL THEN 'YES' ELSE 'NO' END as is_interval
FROM 
    all_part_tables
WHERE 
    owner = UPPER('&owner')
    AND table_name = UPPER('&table_name');

-- Partition key columns
SELECT 
    column_name,
    column_position,
    object_type
FROM 
    all_part_key_columns
WHERE 
    owner = UPPER('&owner')
    AND name = UPPER('&table_name')
ORDER BY 
    column_position;

-- LOB columns configuration
SELECT 
    column_name,
    segment_name,
    tablespace_name,
    securefile,
    compression,
    deduplication,
    in_row,
    chunk,
    cache
FROM 
    all_lobs
WHERE 
    owner = UPPER('&owner')
    AND table_name = UPPER('&table_name')
ORDER BY 
    column_name;

-- Gather initial statistics
PROMPT Gathering initial statistics...
DECLARE
    v_start_time TIMESTAMP := SYSTIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL DAY TO SECOND;
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => UPPER('&owner'),
        tabname => UPPER('&table_name'),
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        method_opt => 'FOR ALL COLUMNS SIZE AUTO',
        degree => TO_NUMBER('&parallel_degree'),
        cascade => FALSE
    );
    v_end_time := SYSTIMESTAMP;
    v_duration := v_end_time - v_start_time;
    DBMS_OUTPUT.PUT_LINE('✓ Statistics gathered successfully');
    DBMS_OUTPUT.PUT_LINE('  Duration: ' || TO_CHAR(EXTRACT(SECOND FROM v_duration), '999.99') || ' seconds');
END;
/

PROMPT =============================================================
PROMPT Table verification and statistics complete
PROMPT =============================================================
