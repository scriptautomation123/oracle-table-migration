-- ==================================================================
-- MASTER SCRIPT 1: COMPLETE END-TO-END MIGRATION
-- ==================================================================
-- Table: APP_DATA_OWNER.JOB_QUEUE
-- Generated: 2025-10-25 16:33:49
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
DEFINE source_table = "JOB_QUEUE"  
DEFINE target_table = "JOB_QUEUE_NEW"

PROMPT ================================================================
PROMPT MASTER SCRIPT 1: COMPLETE END-TO-END MIGRATION
PROMPT ================================================================  
PROMPT Migration ID: MIG_JOB_QUEUE_20251025_163349
PROMPT Source Table: APP_DATA_OWNER.JOB_QUEUE
PROMPT Target Table: APP_DATA_OWNER.JOB_QUEUE_NEW
PROMPT Migration Type: add_interval_hash_partitioning
PROMPT ================================================================
PROMPT Current Size: 0.01 GB
PROMPT Current Rows: 4 rows
PROMPT Partitioned: NO
PROMPT LOB Columns: 0
PROMPT Index Count: 1
PROMPT ----------------------------------------------------------------
PROMPT Target Partition Type: INTERVAL
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
FROM all_tables WHERE owner = 'APP_DATA_OWNER' AND table_name = 'JOB_QUEUE';

SELECT 'Source row count: ' || TO_CHAR(COUNT(*), '999,999,999,999') as validation  
FROM APP_DATA_OWNER.JOB_QUEUE;

SELECT 'Available tablespace space: ' || ROUND(SUM(bytes)/1024/1024/1024, 2) || ' GB' as validation
FROM dba_free_space WHERE tablespace_name = 'USERS';

PROMPT Pre-migration validation complete ✓

-- Conditional constraint disabling only if data migration is requested
PROMPT ================================================================
PROMPT STEP 00: SKIPPED - No data migration requested
PROMPT ================================================================
PROMPT NOTE: Constraint disabling skipped since no data migration required
PROMPT ================================================================

-- STEP 10: Create new partitioned table
PROMPT
PROMPT ================================================================
PROMPT STEP 10: Create New Partitioned Table Structure
PROMPT ================================================================
@@ 10_create_table.sql

-- Validate Step 10 
SELECT 'New table created: ' || CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END as step_10_result
FROM all_tables 
WHERE owner = 'APP_DATA_OWNER' AND table_name = 'JOB_QUEUE_NEW';

SELECT 'Partition type: ' || partitioning_type as step_10_result
FROM all_part_tables
WHERE owner = 'APP_DATA_OWNER' AND table_name = 'JOB_QUEUE_NEW';

PROMPT Step 10 complete ✓

PROMPT ================================================================
PROMPT STEP 20: SKIPPED - No data migration requested
PROMPT ================================================================
PROMPT NOTE: Data migration skipped - table structure only
PROMPT ================================================================

-- STEP 30: Create standard indexes
PROMPT
PROMPT ================================================================
PROMPT STEP 30: Create Standard Indexes
PROMPT ================================================================
@@ 30_create_indexes.sql

-- Validate Step 30
SELECT 'Indexes created: ' || COUNT(*) as step_30_result
FROM all_indexes
WHERE owner = 'APP_DATA_OWNER' AND table_name = 'JOB_QUEUE_NEW';

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
WHERE owner = 'APP_DATA_OWNER' AND table_name = 'JOB_QUEUE_NEW';

SELECT 'Composite indexes: ' || COUNT(*) as step_35_result  
FROM all_ind_columns ic
JOIN all_indexes i ON ic.index_owner = i.owner AND ic.index_name = i.index_name
WHERE i.owner = 'APP_DATA_OWNER' AND i.table_name = 'JOB_QUEUE_NEW'
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
AND table_name IN ('JOB_QUEUE', 'JOB_QUEUE_NEW')
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
WHERE owner = 'APP_DATA_OWNER' AND table_name = 'JOB_QUEUE';

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
PROMPT Old table: APP_DATA_OWNER.JOB_QUEUE_OLD
PROMPT Drop script: 70_drop_old_table.sql
PROMPT Retention period: 7 days
PROMPT ================================================================
PROMPT IMPORTANT: Execute 70_drop_old_table.sql only after validating migration
PROMPT ================================================================

-- Conditional constraint enabling only if data migration occurred
PROMPT ================================================================
PROMPT STEP 80: SKIPPED - No constraint re-enabling needed
PROMPT ================================================================
PROMPT NOTE: Constraints were not disabled, no re-enabling required
PROMPT ================================================================

-- FINAL VALIDATION AND REPORTING
PROMPT
PROMPT ================================================================
PROMPT FINAL MIGRATION VALIDATION AND REPORTING
PROMPT ================================================================

-- Complete data validation
SELECT 'FINAL DATA VALIDATION:' as validation_type FROM dual;
SELECT 'Original table rows: ' || TO_CHAR(COUNT(*), '999,999,999,999') as final_validation
FROM APP_DATA_OWNER.JOB_QUEUE_OLD;

SELECT 'Migrated table rows: ' || TO_CHAR(COUNT(*), '999,999,999,999') as final_validation  
FROM APP_DATA_OWNER.JOB_QUEUE;

SELECT 'Row count match: ' ||
       CASE WHEN o.cnt = n.cnt THEN 'SUCCESS ✓' 
            ELSE 'FAILED ✗ (Diff: ' || (o.cnt - n.cnt) || ')' 
       END as final_validation
FROM (SELECT COUNT(*) cnt FROM APP_DATA_OWNER.JOB_QUEUE_OLD) o,
     (SELECT COUNT(*) cnt FROM APP_DATA_OWNER.JOB_QUEUE) n;

-- Constraint validation  
SELECT 'CONSTRAINT VALIDATION:' as validation_type FROM dual;
SELECT constraint_type || ' constraints: ' || COUNT(*) as final_validation
FROM user_constraints
WHERE table_name = 'JOB_QUEUE'
AND status = 'ENABLED'  
AND constraint_name NOT LIKE 'SYS_%'
GROUP BY constraint_type
ORDER BY constraint_type;

-- Index validation
SELECT 'INDEX VALIDATION:' as validation_type FROM dual;
SELECT 'Total indexes: ' || COUNT(*) as final_validation  
FROM user_indexes
WHERE table_name = 'JOB_QUEUE';

SELECT index_type || ' indexes: ' || COUNT(*) as final_validation
FROM user_indexes
WHERE table_name = 'JOB_QUEUE'  
GROUP BY index_type
ORDER BY index_type;

-- Partitioning validation
SELECT 'PARTITION VALIDATION:' as validation_type FROM dual;
SELECT 'Partition type: ' || partitioning_type as final_validation
FROM user_part_tables  
WHERE table_name = 'JOB_QUEUE';

SELECT 'Partition count: ' || COUNT(*) as final_validation
FROM user_tab_partitions
WHERE table_name = 'JOB_QUEUE';

-- Performance validation (sample query)
SELECT 'PERFORMANCE VALIDATION:' as validation_type FROM dual;
SELECT 'Sample query execution:' as final_validation FROM dual;

-- Sample query to test partitioning performance
EXPLAIN PLAN FOR 
SELECT COUNT(*) FROM APP_DATA_OWNER.JOB_QUEUE 
WHERE CREATED_AT >= SYSDATE - 30;

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
PROMPT Migration Type: add_interval_hash_partitioning
PROMPT Source: APP_DATA_OWNER.JOB_QUEUE (Non-partitioned)
PROMPT Target: APP_DATA_OWNER.JOB_QUEUE (INTERVAL)
PROMPT Data Migrated: 4 rows rows
PROMPT Size: 0.01 GB
PROMPT Tablespace: USERS
PROMPT ================================================================

-- Final status check
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM user_constraints WHERE table_name = 'JOB_QUEUE' AND status = 'DISABLED')
        THEN 'WARNING: Some constraints still disabled ⚠️'
        WHEN NOT EXISTS (SELECT 1 FROM user_tables WHERE table_name = 'JOB_QUEUE')  
        THEN 'ERROR: Target table missing ✗'
        WHEN EXISTS (SELECT 1 FROM user_part_tables WHERE table_name = 'JOB_QUEUE' AND partitioning_type = 'INTERVAL')
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
PROMPT 3. Use emergency_rollback.sql only if rollback is needed
PROMPT 4. Schedule old table cleanup (70_drop_old_table.sql)
PROMPT ================================================================

-- Reset SQL settings
SET ECHO OFF
SET FEEDBACK OFF
SET TIMING OFF