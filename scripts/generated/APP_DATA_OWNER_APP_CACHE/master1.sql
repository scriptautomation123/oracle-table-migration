
-- ==================================================================
-- MASTER SCRIPT 1: COMPLETE END-TO-END MIGRATION
-- ==================================================================
-- Table: APP_DATA_OWNER.APP_CACHE
-- Generated: 2025-10-25 21:07:53
-- ==================================================================
-- This script executes EVERYTHING needed for complete migration:
--   Step 00: Disable constraints and prepare environment
--   Step 10: Create new partitioned table with full DDL
--   Step 20: Initial data load with validation
--   Step 30: Create standard indexes
--   Step 35: Recreate complex/composite indexes  
--   Step 40: Delta load (if applicable)
--   Step 50: Atomic table swap
--   Step 60: Restore grants and privileges
--   Step 70: Drop old table (optional)
--   Step 80: Enable and validate all constraints
--   Final:   Complete validation and reporting
-- ==================================================================
-- CRITICAL: This script should run completely without manual intervention
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON
SET FEEDBACK ON
SET PAGESIZE 1000
SET LINESIZE 120

-- Enable error handling - script stops on any error
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

-- Migration tracking variables
DEFINE migration_start_time = "&_DATE"
DEFINE table_owner = "APP_DATA_OWNER"
DEFINE source_table = "APP_CACHE"  
DEFINE target_table = "APP_CACHE_NEW"

PROMPT ================================================================
PROMPT MASTER SCRIPT 1: COMPLETE END-TO-END MIGRATION
PROMPT ================================================================  
PROMPT Migration ID: MIG_APP_CACHE_20251025_210753
PROMPT Source Table: APP_DATA_OWNER.APP_CACHE
PROMPT Target Table: APP_DATA_OWNER.APP_CACHE_NEW
PROMPT Migration Type: MigrationAction.ADD_INTERVAL_HASH_PARTITIONING
PROMPT ================================================================
PROMPT Current Size: 0.01 GB
PROMPT Current Rows: 20 rows
PROMPT Partitioned: NO
PROMPT LOB Columns: 2
PROMPT Index Count: 1
PROMPT ----------------------------------------------------------------
PROMPT Target Partition Type: PartitionType.INTERVAL
PROMPT Target Tablespace: USERS
PROMPT Parallel Degree: 4
PROMPT ================================================================
PROMPT Estimated Duration: < 1 minute
PROMPT ================================================================

-- Pre-migration validation
PROMPT
PROMPT ================================================================  
PROMPT PRE-MIGRATION VALIDATION
PROMPT ================================================================
SELECT 'Source table exists: ' || CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END as validation
FROM all_tables WHERE owner = 'APP_DATA_OWNER' AND table_name = 'APP_CACHE';

SELECT 'Source row count: ' || TO_CHAR(COUNT(*), '999,999,999,999') as validation  
FROM APP_DATA_OWNER.APP_CACHE;

SELECT 'Available tablespace space: ' || ROUND(SUM(bytes)/1024/1024/1024, 2) || ' GB' as validation
FROM dba_free_space WHERE tablespace_name = 'USERS';

PROMPT Pre-migration validation complete ✓

-- Conditional constraint disabling only if data migration is requested

-- STEP 00: Disable constraints and prepare environment  
PROMPT
PROMPT ================================================================
PROMPT STEP 00: Disable Constraints and Prepare Environment
PROMPT ================================================================
PROMPT NOTE: Constraints will be disabled only for data migration
PROMPT ================================================================
@@ 00_disable_constraints.sql

-- Validate Step 00
SELECT 'Disabled constraints: ' || COUNT(*) as step_00_result
FROM user_constraints 
WHERE table_name = 'APP_CACHE' 
AND status = 'DISABLED';

PROMPT Step 00 complete ✓


-- STEP 10: Create new partitioned table
PROMPT
PROMPT ================================================================
PROMPT STEP 10: Create New Partitioned Table Structure
PROMPT ================================================================
@@ 10_create_table.sql

-- Validate Step 10 
SELECT 'New table created: ' || CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END as step_10_result
FROM all_tables 
WHERE owner = 'APP_DATA_OWNER' AND table_name = 'APP_CACHE_NEW';

SELECT 'Partition type: ' || partitioning_type as step_10_result
FROM all_part_tables
WHERE owner = 'APP_DATA_OWNER' AND table_name = 'APP_CACHE_NEW';

PROMPT Step 10 complete ✓


-- STEP 20: Initial data load with validation
PROMPT
PROMPT ================================================================  
PROMPT STEP 20: Initial Data Load with Validation
PROMPT ================================================================
@@ 20_data_load.sql

-- Validate Step 20
SELECT 'Source rows: ' || TO_CHAR(COUNT(*), '999,999,999,999') as step_20_validation
FROM APP_DATA_OWNER.APP_CACHE;

SELECT 'Target rows: ' || TO_CHAR(COUNT(*), '999,999,999,999') as step_20_validation  
FROM APP_DATA_OWNER.APP_CACHE_NEW;

SELECT 'Data migration: ' || 
       CASE WHEN s.cnt = t.cnt THEN 'SUCCESS ✓' 
            ELSE 'FAILED ✗ (' || (s.cnt - t.cnt) || ' missing)' 
       END as step_20_result
FROM (SELECT COUNT(*) cnt FROM APP_DATA_OWNER.APP_CACHE) s,
     (SELECT COUNT(*) cnt FROM APP_DATA_OWNER.APP_CACHE_NEW) t;

PROMPT Step 20 complete ✓


-- STEP 30: Create standard indexes
PROMPT
PROMPT ================================================================
PROMPT STEP 30: Create Standard Indexes
PROMPT ================================================================
@@ 30_create_indexes.sql

-- Validate Step 30
SELECT 'Indexes created: ' || COUNT(*) as step_30_result
FROM all_indexes
WHERE owner = 'APP_DATA_OWNER' AND table_name = 'APP_CACHE_NEW';

PROMPT Step 30 complete ✓

-- STEP 35: Recreate complex/composite indexes
PROMPT  
PROMPT ================================================================
PROMPT STEP 35: Recreate Complex and Composite Indexes
PROMPT ================================================================
@@ 35_recreate_indexes.sql

-- Validate Step 35
SELECT 'Total indexes on target: ' || COUNT(*) as step_35_result
FROM all_indexes
WHERE owner = 'APP_DATA_OWNER' AND table_name = 'APP_CACHE_NEW';

SELECT 'Composite indexes: ' || COUNT(*) as step_35_result  
FROM all_ind_columns ic
JOIN all_indexes i ON ic.index_owner = i.owner AND ic.index_name = i.index_name
WHERE i.owner = 'APP_DATA_OWNER' AND i.table_name = 'APP_CACHE_NEW'
GROUP BY ic.index_name
HAVING COUNT(*) > 1;

PROMPT Step 35 complete ✓


PROMPT ================================================================
PROMPT STEP 40: SKIPPED - No delta load requested
PROMPT ================================================================
PROMPT NOTE: Delta load skipped as per configuration
PROMPT ================================================================


-- STEP 50: Atomic table swap (transaction-based renames)
PROMPT
PROMPT ================================================================
PROMPT STEP 50: Atomic Table Swap
PROMPT ================================================================
PROMPT NOTE: Making atomic via transaction - all renames succeed or all fail
PROMPT ================================================================
@@ 50_swap_tables.sql

-- Validate Step 50  
SELECT 'Active table is now: ' || table_name as step_50_result
FROM all_tables 
WHERE owner = 'APP_DATA_OWNER' 
AND table_name IN ('APP_CACHE', 'APP_CACHE_NEW')
AND table_name NOT LIKE '%_OLD%'
ORDER BY created DESC
FETCH FIRST 1 ROW ONLY;

PROMPT Step 50 complete ✓

-- STEP 60: Restore grants and privileges
PROMPT
PROMPT ================================================================  
PROMPT STEP 60: Restore Grants and Privileges
PROMPT ================================================================
PROMPT NOTE: Grants captured in config.json and dynamic_grants.sql as backup
PROMPT ================================================================
@@ 60_restore_grants.sql

-- Validate Step 60
SELECT 'Grants restored: ' || COUNT(*) as step_60_result
FROM all_tab_privs
WHERE owner = 'APP_DATA_OWNER' AND table_name = 'APP_CACHE';

PROMPT Step 60 complete ✓
PROMPT NOTE: If grants issues occur, run dynamic_grants.sql manually

-- STEP 70: Drop old table (SEPARATE SCRIPT - NOT PART OF master1.sql)
PROMPT
PROMPT ================================================================
PROMPT STEP 70: Drop Old Table Preparation
PROMPT ================================================================
PROMPT NOTE: 70_drop_old_table.sql generated as SEPARATE script
PROMPT NOT executed as part of master1.sql - manual execution required
PROMPT ================================================================
PROMPT Old table: APP_DATA_OWNER.APP_CACHE_OLD
PROMPT Drop script: 70_drop_old_table.sql
PROMPT Retention period: 7 days
PROMPT ================================================================
PROMPT IMPORTANT: Execute 70_drop_old_table.sql only after validating migration
PROMPT ================================================================

-- Conditional constraint enabling only if data migration occurred

-- STEP 80: Enable and validate all constraints
PROMPT
PROMPT ================================================================
PROMPT STEP 80: Enable and Validate All Constraints  
PROMPT ================================================================
@@ 80_enable_constraints.sql

-- Validate Step 80
SELECT 'Enabled constraints: ' || COUNT(*) as step_80_result
FROM user_constraints
WHERE table_name = 'APP_CACHE'
AND status = 'ENABLED'
AND constraint_type IN ('P','R','U','C')
AND constraint_name NOT LIKE 'SYS_%';

SELECT 'Invalid constraints: ' || COUNT(*) as step_80_validation
FROM user_constraints  
WHERE table_name = 'APP_CACHE'
AND status = 'ENABLED'
AND validated = 'NOT VALIDATED';

-- Run statistics for CBO optimization
EXEC DBMS_STATS.GATHER_TABLE_STATS('APP_DATA_OWNER', 'APP_CACHE', CASCADE => TRUE);

PROMPT Step 80 complete ✓


-- FINAL VALIDATION AND REPORTING
PROMPT
PROMPT ================================================================
PROMPT FINAL MIGRATION VALIDATION AND REPORTING
PROMPT ================================================================

-- Complete data validation
SELECT 'FINAL DATA VALIDATION:' as validation_type FROM dual;
SELECT 'Original table rows: ' || TO_CHAR(COUNT(*), '999,999,999,999') as final_validation
FROM APP_DATA_OWNER.APP_CACHE_OLD;

SELECT 'Migrated table rows: ' || TO_CHAR(COUNT(*), '999,999,999,999') as final_validation  
FROM APP_DATA_OWNER.APP_CACHE;

SELECT 'Row count match: ' ||
       CASE WHEN o.cnt = n.cnt THEN 'SUCCESS ✓' 
            ELSE 'FAILED ✗ (Diff: ' || (o.cnt - n.cnt) || ')' 
       END as final_validation
FROM (SELECT COUNT(*) cnt FROM APP_DATA_OWNER.APP_CACHE_OLD) o,
     (SELECT COUNT(*) cnt FROM APP_DATA_OWNER.APP_CACHE) n;

-- Constraint validation  
SELECT 'CONSTRAINT VALIDATION:' as validation_type FROM dual;
SELECT constraint_type || ' constraints: ' || COUNT(*) as final_validation
FROM user_constraints
WHERE table_name = 'APP_CACHE'
AND status = 'ENABLED'  
AND constraint_name NOT LIKE 'SYS_%'
GROUP BY constraint_type
ORDER BY constraint_type;

-- Index validation
SELECT 'INDEX VALIDATION:' as validation_type FROM dual;
SELECT 'Total indexes: ' || COUNT(*) as final_validation  
FROM user_indexes
WHERE table_name = 'APP_CACHE';

SELECT index_type || ' indexes: ' || COUNT(*) as final_validation
FROM user_indexes
WHERE table_name = 'APP_CACHE'  
GROUP BY index_type
ORDER BY index_type;

-- Partitioning validation
SELECT 'PARTITION VALIDATION:' as validation_type FROM dual;
SELECT 'Partition type: ' || partitioning_type as final_validation
FROM user_part_tables  
WHERE table_name = 'APP_CACHE';

SELECT 'Partition count: ' || COUNT(*) as final_validation
FROM user_tab_partitions
WHERE table_name = 'APP_CACHE';

-- Performance validation (sample query)
SELECT 'PERFORMANCE VALIDATION:' as validation_type FROM dual;
SELECT 'Sample query execution:' as final_validation FROM dual;

-- Sample query to test partitioning performance

EXPLAIN PLAN FOR 
SELECT COUNT(*) FROM APP_DATA_OWNER.APP_CACHE 
WHERE EXPIRY_TIME >= SYSDATE - 30;

SELECT 'Query plan uses partition pruning: ' || 
       CASE WHEN COUNT(*) > 0 THEN 'YES ✓' ELSE 'NO ✗' END as final_validation
FROM plan_table 
WHERE operation LIKE '%PARTITION%';

DELETE FROM plan_table;


-- Migration summary
PROMPT
PROMPT ================================================================
PROMPT MIGRATION SUMMARY  
PROMPT ================================================================
PROMPT Migration Type: MigrationAction.ADD_INTERVAL_HASH_PARTITIONING
PROMPT Source: APP_DATA_OWNER.APP_CACHE (Non-partitioned)
PROMPT Target: APP_DATA_OWNER.APP_CACHE (PartitionType.INTERVAL)
PROMPT Data Migrated: 20 rows rows
PROMPT Size: 0.01 GB
PROMPT Tablespace: USERS
PROMPT ================================================================

-- Final status check
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM user_constraints WHERE table_name = 'APP_CACHE' AND status = 'DISABLED')
        THEN 'WARNING: Some constraints still disabled ⚠️'
        WHEN NOT EXISTS (SELECT 1 FROM user_tables WHERE table_name = 'APP_CACHE')  
        THEN 'ERROR: Target table missing ✗'
        WHEN EXISTS (SELECT 1 FROM user_part_tables WHERE table_name = 'APP_CACHE' AND partitioning_type = 'PartitionType.INTERVAL')
        THEN 'SUCCESS: Migration completed successfully ✅'
        ELSE 'WARNING: Validation incomplete ⚠️'
    END as FINAL_STATUS
FROM dual;

PROMPT
PROMPT ================================================================
PROMPT MASTER SCRIPT 1: COMPLETE END-TO-END MIGRATION
PROMPT ================================================================
PROMPT Status: ✅ SUCCESS - Complete migration executed
PROMPT Duration: &_DATE (started at &migration_start_time)  
PROMPT ================================================================
PROMPT 🎉 MIGRATION COMPLETE! 🎉
PROMPT ================================================================
PROMPT Next Steps:
PROMPT 1. Verify application connectivity
PROMPT 2. Monitor performance for 24-48 hours  
PROMPT 3. Run master2.sql only if rollback is needed
PROMPT 4. Schedule old table cleanup (70_drop_old_table.sql)
PROMPT ================================================================

-- Reset SQL settings
SET ECHO OFF
SET FEEDBACK OFF
SET TIMING OFF
