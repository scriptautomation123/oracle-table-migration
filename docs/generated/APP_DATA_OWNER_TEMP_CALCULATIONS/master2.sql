
-- ==================================================================
-- MASTER SCRIPT 2: Cutover and Cleanup
-- ==================================================================
-- Table: APP_DATA_OWNER.TEMP_CALCULATIONS
-- Generated: 2025-10-25 21:07:54
-- ==================================================================
-- This script executes:
--   Step 50: Swap tables (rename)
--   Step 60: Restore grants
--   Step 70: Drop old table (optional)
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON
SET FEEDBACK ON

WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT ================================================================
PROMPT MASTER SCRIPT 2: Cutover and Cleanup
PROMPT ================================================================
PROMPT Table: APP_DATA_OWNER.TEMP_CALCULATIONS
PROMPT ================================================================
PROMPT WARNING: This will swap the active table!
PROMPT Press Ctrl+C to cancel, or press Enter to continue...
PAUSE

-- Execute Step 50: Swap tables
PROMPT
PROMPT ================================================================
PROMPT Executing Step 50: Swap Tables
PROMPT ================================================================
@@ 50_swap_tables.sql

-- Validate Step 50 completion
PROMPT Validating Step 50 completion...
SELECT table_name, partitioned, status
FROM all_tables
WHERE owner = 'APP_DATA_OWNER'
  AND table_name IN ('TEMP_CALCULATIONS', 'TEMP_CALCULATIONS_OLD')
ORDER BY table_name;

-- Execute Step 60: Restore grants
PROMPT
PROMPT ================================================================
PROMPT Executing Step 60: Restore Grants
PROMPT ================================================================
@@ 60_restore_grants.sql

-- Validate Step 60 completion
PROMPT Validating Step 60 completion...
SELECT COUNT(*) AS grant_count
FROM all_tab_privs
WHERE owner = 'APP_DATA_OWNER'
  AND table_name = 'TEMP_CALCULATIONS';


PROMPT
PROMPT Skipping Step 70: Old table kept as APP_DATA_OWNER.TEMP_CALCULATIONS_OLD
PROMPT You can drop it later with: DROP TABLE APP_DATA_OWNER.TEMP_CALCULATIONS_OLD PURGE;


PROMPT
PROMPT ================================================================
PROMPT MASTER SCRIPT 2 COMPLETE
PROMPT ================================================================
PROMPT Status: SUCCESS ✓
PROMPT Migration Complete!
PROMPT ================================================================
PROMPT New partitioned table: APP_DATA_OWNER.TEMP_CALCULATIONS
PROMPT Backup table: APP_DATA_OWNER.TEMP_CALCULATIONS_OLD
PROMPT ================================================================
