-- ==================================================================
-- SWAP TABLES: MYSCHEMA.IE_PC_SEQ_OUT <-> MYSCHEMA.IE_PC_SEQ_OUT_NEW
-- ==================================================================
-- Generated: 2025-10-22 01:30:55
-- ==================================================================

SET ECHO ON
SET TIMING ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT Step 50: Swapping Tables
PROMPT ================================================================
PROMPT Old table: MYSCHEMA.IE_PC_SEQ_OUT
PROMPT New table: MYSCHEMA.IE_PC_SEQ_OUT_NEW
PROMPT Backup: MYSCHEMA.IE_PC_SEQ_OUT_OLD
PROMPT ================================================================

-- Rename original table to _OLD
ALTER TABLE MYSCHEMA.IE_PC_SEQ_OUT RENAME TO IE_PC_SEQ_OUT_OLD;
PROMPT ✓ Renamed IE_PC_SEQ_OUT to IE_PC_SEQ_OUT_OLD

-- Rename new table to original name
ALTER TABLE MYSCHEMA.IE_PC_SEQ_OUT_NEW RENAME TO IE_PC_SEQ_OUT;
PROMPT ✓ Renamed IE_PC_SEQ_OUT_NEW to IE_PC_SEQ_OUT

-- Verify
SELECT table_name, partitioned, status
FROM all_tables
WHERE owner = 'MYSCHEMA'
  AND table_name IN ('IE_PC_SEQ_OUT', 'IE_PC_SEQ_OUT_OLD')
ORDER BY table_name;

PROMPT ✓ Step 50 Complete: Tables swapped successfully
