-- ==================================================================
-- MASTER SCRIPT 2: Cutover and Cleanup
-- ==================================================================
-- Table: MYSCHEMA.IE_PC_SEQ_OUT
-- Generated: 2025-10-22 01:30:55
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
PROMPT Table: MYSCHEMA.IE_PC_SEQ_OUT
PROMPT ================================================================
PROMPT WARNING: This will swap the active table!
PROMPT Press Ctrl+C to cancel, or press Enter to continue...
PAUSE

-- Execute Step 50: Swap tables
@@ 50_swap_tables.sql

-- Execute Step 60: Restore grants
@@ 60_restore_grants.sql

PROMPT
PROMPT Skipping Step 70: Old table kept as MYSCHEMA.IE_PC_SEQ_OUT_OLD
PROMPT You can drop it later with: DROP TABLE MYSCHEMA.IE_PC_SEQ_OUT_OLD PURGE;

PROMPT
PROMPT ================================================================
PROMPT MASTER SCRIPT 2 COMPLETE
PROMPT ================================================================
PROMPT Status: SUCCESS ✓
PROMPT Migration Complete!
PROMPT ================================================================
PROMPT New partitioned table: MYSCHEMA.IE_PC_SEQ_OUTPROMPT Backup table: MYSCHEMA.IE_PC_SEQ_OUT_OLDPROMPT ================================================================
