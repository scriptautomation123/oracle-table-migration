-- ==================================================================
-- DELTA LOAD: MYSCHEMA.IE_PC_SEQ_OUT_NEW
-- ==================================================================
-- Generated: 2025-10-22 01:30:55
-- Captures changes since: 2025-10-22 01:30:55
-- ==================================================================

SET ECHO ON
SET TIMING ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT Step 40: Delta Load (Incremental Changes)
PROMPT ================================================================
PROMPT Source: MYSCHEMA.IE_PC_SEQ_OUT
PROMPT Target: MYSCHEMA.IE_PC_SEQ_OUT_NEW
PROMPT Cutoff: 2025-10-22 01:30:55
PROMPT ================================================================

-- Merge incremental changes
MERGE /*+ PARALLEL(2) */ INTO MYSCHEMA.IE_PC_SEQ_OUT_NEW tgt
USING (
    SELECT PROCESS_DATE, CREATE_DATE, SEQ_ID, BATCH_ID, SEQ_TYPE
    FROM MYSCHEMA.IE_PC_SEQ_OUT
    WHERE PROCESS_DATE >= TO_DATE('2025-10-22 01:30:55', 'YYYY-MM-DD HH24:MI:SS')
) src
ON (tgt.PROCESS_DATE = src.PROCESS_DATE)
WHEN MATCHED THEN
    UPDATE SET -- UPDATE SET clause
WHEN NOT MATCHED THEN
    INSERT (PROCESS_DATE, CREATE_DATE, SEQ_ID, BATCH_ID, SEQ_TYPE)
    VALUES (src.PROCESS_DATE, src.CREATE_DATE, src.SEQ_ID, src.BATCH_ID, src.SEQ_TYPE);

COMMIT;

PROMPT ✓ Step 40 Complete: Delta load finished
