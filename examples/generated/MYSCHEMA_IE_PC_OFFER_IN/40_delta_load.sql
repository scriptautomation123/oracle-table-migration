-- ==================================================================
-- DELTA LOAD: MYSCHEMA.IE_PC_OFFER_IN_NEW
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
PROMPT Source: MYSCHEMA.IE_PC_OFFER_IN
PROMPT Target: MYSCHEMA.IE_PC_OFFER_IN_NEW
PROMPT Cutoff: 2025-10-22 01:30:55
PROMPT ================================================================

-- Merge incremental changes
MERGE /*+ PARALLEL(4) */ INTO MYSCHEMA.IE_PC_OFFER_IN_NEW tgt
USING (
    SELECT AUDIT_CREATE_DATE, LAST_UPDATE_DATE, PROCESS_DATE, OFFER_ID, CUSTOMER_ID, SEQ_NUM, OFFER_CODE, STATUS
    FROM MYSCHEMA.IE_PC_OFFER_IN
    WHERE AUDIT_CREATE_DATE >= TO_DATE('2025-10-22 01:30:55', 'YYYY-MM-DD HH24:MI:SS')
) src
ON (tgt.AUDIT_CREATE_DATE = src.AUDIT_CREATE_DATE)
WHEN MATCHED THEN
    UPDATE SET -- UPDATE SET clause
WHEN NOT MATCHED THEN
    INSERT (AUDIT_CREATE_DATE, LAST_UPDATE_DATE, PROCESS_DATE, OFFER_ID, CUSTOMER_ID, SEQ_NUM, OFFER_CODE, STATUS)
    VALUES (src.AUDIT_CREATE_DATE, src.LAST_UPDATE_DATE, src.PROCESS_DATE, src.OFFER_ID, src.CUSTOMER_ID, src.SEQ_NUM, src.OFFER_CODE, src.STATUS);

COMMIT;

PROMPT ✓ Step 40 Complete: Delta load finished
