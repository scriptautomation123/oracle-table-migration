
-- ==================================================================
-- CREATE TABLE: APP_DATA_OWNER.APP_CACHE_NEW
-- ==================================================================
-- Generated: 2025-10-25 21:07:53
-- Migration Action: add_interval_hash_partitioning
-- Source Table: APP_DATA_OWNER.APP_CACHE
-- Current: Non-partitioned table
-- Target Partitioning: PartitionType.INTERVAL
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON
SET TIMING ON
SET FEEDBACK ON

PROMPT ================================================================
PROMPT Step 10: Creating New Partitioned Table
PROMPT ================================================================
PROMPT Table: APP_DATA_OWNER.APP_CACHE_NEW
PROMPT Partitioning: PartitionType.INTERVAL
PROMPT Partition Column: EXPIRY_TIME
PROMPT Subpartitioning: NONE
PROMPT Hash Subpartitions: 
PROMPT Tablespace: USERS

PROMPT LOB Columns: 2

PROMPT ================================================================

-- Check if table already exists (generic)
@validation/check_table_exists.sql APP_DATA_OWNER APP_CACHE_NEW

-- Create new table with partitioning
PROMPT

PROMPT Creating table APP_DATA_OWNER.APP_CACHE_NEW...
PROMPT Estimated time: < 1 minute



CREATE TABLE "APP_DATA_OWNER"."APP_CACHE_NEW"
(
    CACHE_KEY VARCHAR2(200) NOT NULL,
    CACHE_VALUE BLOB,
    CACHE_METADATA BLOB,
    EXPIRY_TIME TIMESTAMP(6)
)
TABLESPACE USERS
PCTFREE 10
INITRANS 1
MAXTRANS 255
STORAGE (
    INITIAL 65536
    NEXT 1048576
    BUFFER_POOL DEFAULT
)
ENABLE ROW MOVEMENT;

PROMPT ✓ Table APP_DATA_OWNER.APP_CACHE_NEW created successfully


-- Post-create table checks (structure, partitioning, LOBs, stats)
@validation/post_create_table_checks.sql APP_DATA_OWNER APP_CACHE_NEW 4

PROMPT
PROMPT ================================================================
PROMPT Step 10 Complete: Table Structure Created
PROMPT ================================================================
PROMPT Status: SUCCESS
PROMPT Table: APP_DATA_OWNER.APP_CACHE_NEW
PROMPT
PROMPT Next Steps:
PROMPT   1. Review table structure above
PROMPT   2. Run 20_data_load.sql to load data (est. < 1 minute)
PROMPT   3. Monitor space and performance
PROMPT ================================================================
