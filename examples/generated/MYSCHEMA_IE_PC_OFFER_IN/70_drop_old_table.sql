-- ==================================================================
-- DROP OLD TABLE: MYSCHEMA.IE_PC_OFFER_IN_OLD
-- ==================================================================
-- Generated: 2025-10-22 01:30:55
-- WARNING: This is IRREVERSIBLE!
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT Step 70: Drop Old Table (CAUTION)
PROMPT ================================================================
PROMPT Table to drop: MYSCHEMA.IE_PC_OFFER_IN_OLD
PROMPT ================================================================
PROMPT
PROMPT WARNING: This will PERMANENTLY delete the old table!
PROMPT Press Ctrl+C to cancel, or press Enter to continue...
PAUSE

-- Drop the old table
DROP TABLE MYSCHEMA.IE_PC_OFFER_IN_OLD PURGE;

PROMPT ✓ Table MYSCHEMA.IE_PC_OFFER_IN_OLD dropped successfully

-- Verify it's gone
SELECT COUNT(*) AS old_table_exists
FROM all_tables
WHERE owner = 'MYSCHEMA'
  AND table_name = 'IE_PC_OFFER_IN_OLD';

PROMPT ✓ Step 70 Complete: Old table removed
