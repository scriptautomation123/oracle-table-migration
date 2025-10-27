-- ==================================================================
-- PARTITION DISTRIBUTION SUMMARY
-- ==================================================================
-- Usage: @validation/partition_distribution_summary.sql <owner> <table_name> <subpartition_type>
-- ==================================================================
-- Accepts: &1 = owner, &2 = table_name, &3 = subpartition_type (optional)
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE owner = '&1'
DEFINE table_name = '&2'
DEFINE subpartition_type = '&3'

PROMPT =============================================================
PROMPT Partition Distribution Summary for &owner..&table_name
PROMPT =============================================================

SELECT 
    partition_name,
    CASE WHEN UPPER('&subpartition_type') = 'HASH' THEN subpartition_count END AS subpartition_count,
    num_rows,
    blocks,
    ROUND(num_rows * 100.0 / NULLIF(SUM(num_rows) OVER (), 0), 2) AS pct_of_total,
    high_value
FROM 
    all_tab_partitions
WHERE 
    table_owner = UPPER('&owner')
    AND table_name = UPPER('&table_name')
ORDER BY 
    partition_position DESC
FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT (Showing last 10 partitions - newest first)
PROMPT =============================================================
