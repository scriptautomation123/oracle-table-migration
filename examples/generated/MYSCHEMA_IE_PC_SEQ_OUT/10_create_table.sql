-- ==================================================================
-- CREATE TABLE: MYSCHEMA.IE_PC_SEQ_OUT_NEW
-- ==================================================================
-- Generated: 2025-10-22 01:30:55
-- Migration Action: convert_interval_to_interval_hash
-- Source Table: MYSCHEMA.IE_PC_SEQ_OUT-- Current Partitioning: RANGE (INTERVAL)-- Target Partitioning: INTERVAL-HASH-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON
SET TIMING ON
SET FEEDBACK ON

PROMPT ================================================================
PROMPT Step 10: Creating New Partitioned Table
PROMPT ================================================================
PROMPT Table: MYSCHEMA.IE_PC_SEQ_OUT_NEWPROMPT Partitioning: INTERVAL (DAY)PROMPT Partition Column: PROCESS_DATEPROMPT Subpartitioning: HASH on SEQ_ID
PROMPT Hash Subpartitions: 4PROMPT Tablespace: USERSPROMPT LOB Columns: 1PROMPT ================================================================

-- Drop table if exists (safety check)
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM all_tables
    WHERE owner = 'MYSCHEMA'
      AND table_name = 'IE_PC_SEQ_OUT_NEW';
    
    IF v_count > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE MYSCHEMA.IE_PC_SEQ_OUT_NEW PURGE';
        DBMS_OUTPUT.PUT_LINE('✓ Dropped existing table MYSCHEMA.IE_PC_SEQ_OUT_NEW');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ Table MYSCHEMA.IE_PC_SEQ_OUT_NEW does not exist - proceeding with creation');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/

-- Create new table with partitioning
PROMPT
PROMPT Creating table MYSCHEMA.IE_PC_SEQ_OUT_NEW...
PROMPT Estimated time: ~1.6 hours

CREATE TABLE MYSCHEMA.IE_PC_SEQ_OUT_NEW
(
-- Column definitions to be extracted from source table
)
TABLESPACE USERSPARTITION BY RANGE (PROCESS_DATE)INTERVAL (INTERVAL(NUMTODSINTERVAL(1, 'DAY')))SUBPARTITION BY HASH (SEQ_ID)
SUBPARTITIONS 4(
    PARTITION p_initial VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD'))
)ENABLE ROW MOVEMENTPARALLEL 2;

PROMPT ✓ Table MYSCHEMA.IE_PC_SEQ_OUT_NEW created successfully

-- Verify table creation
PROMPT
PROMPT Verifying table structure...

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
    owner = 'MYSCHEMA'
    AND table_name = 'IE_PC_SEQ_OUT_NEW';
-- Verify partitioning configuration
PROMPT
PROMPT Verifying partitioning configuration...

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
    owner = 'MYSCHEMA'
    AND table_name = 'IE_PC_SEQ_OUT_NEW';

-- Show partition key columns
PROMPT
PROMPT Partition key columns:

SELECT 
    column_name,
    column_position,
    object_type
FROM 
    all_part_key_columns
WHERE 
    owner = 'MYSCHEMA'
    AND name = 'IE_PC_SEQ_OUT_NEW'
ORDER BY 
    column_position;
-- Verify LOB columns configuration
PROMPT
PROMPT Verifying LOB column configuration...

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
    owner = 'MYSCHEMA'
    AND table_name = 'IE_PC_SEQ_OUT_NEW'
ORDER BY 
    column_name;
-- Gather initial statistics
PROMPT
PROMPT Gathering initial statistics...

DECLARE
    v_start_time TIMESTAMP := SYSTIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL DAY TO SECOND;
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => 'MYSCHEMA',
        tabname => 'IE_PC_SEQ_OUT_NEW',
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        method_opt => 'FOR ALL COLUMNS SIZE AUTO',
        degree => 2,
        cascade => FALSE
    );
    
    v_end_time := SYSTIMESTAMP;
    v_duration := v_end_time - v_start_time;
    
    DBMS_OUTPUT.PUT_LINE('✓ Statistics gathered successfully');
    DBMS_OUTPUT.PUT_LINE('  Duration: ' || TO_CHAR(EXTRACT(SECOND FROM v_duration), '999.99') || ' seconds');
END;
/

-- Display table info
PROMPT
PROMPT Table Information:
PROMPT ==================

DECLARE
    v_table_exists NUMBER;
    v_partitioned VARCHAR2(3);
    v_part_type VARCHAR2(30);
    v_subpart_type VARCHAR2(30);
    v_interval VARCHAR2(1000);
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM all_tables
    WHERE owner = 'MYSCHEMA' AND table_name = 'IE_PC_SEQ_OUT_NEW';
    
    IF v_table_exists = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Table was not created successfully!');
        RAISE_APPLICATION_ERROR(-20001, 'Table creation failed');
    END IF;
    
    SELECT partitioned INTO v_partitioned
    FROM all_tables
    WHERE owner = 'MYSCHEMA' AND table_name = 'IE_PC_SEQ_OUT_NEW';
    
    DBMS_OUTPUT.PUT_LINE('Table Name: MYSCHEMA.IE_PC_SEQ_OUT_NEW');
    DBMS_OUTPUT.PUT_LINE('Tablespace: USERS');
    DBMS_OUTPUT.PUT_LINE('Partitioned: ' || v_partitioned);
    
    IF v_partitioned = 'YES' THEN
        SELECT partitioning_type, subpartitioning_type, NVL(interval, 'N/A')
        INTO v_part_type, v_subpart_type, v_interval
        FROM all_part_tables
        WHERE owner = 'MYSCHEMA' AND table_name = 'IE_PC_SEQ_OUT_NEW';
        
        DBMS_OUTPUT.PUT_LINE('Partition Type: ' || v_part_type);
        DBMS_OUTPUT.PUT_LINE('Subpartition Type: ' || NVL(v_subpart_type, 'NONE'));
        DBMS_OUTPUT.PUT_LINE('Interval: ' || v_interval);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('✓ Table created and verified successfully!');
END;
/

PROMPT
PROMPT ================================================================
PROMPT Step 10 Complete: Table Structure Created
PROMPT ================================================================
PROMPT Status: SUCCESS
PROMPT Table: MYSCHEMA.IE_PC_SEQ_OUT_NEWPROMPT Partitioning: INTERVAL-HASHPROMPT
PROMPT Next Steps:
PROMPT   1. Review table structure above
PROMPT   2. Run 20_data_load.sql to load data (est. ~1.6 hours)
PROMPT   3. Monitor space and performance
PROMPT ================================================================
