
-- ==================================================================
-- DYNAMIC GRANTS RESTORATION: APP_DATA_OWNER.SESSION_DATA
-- ==================================================================
-- Generated: 2025-10-25 21:07:54
-- Purpose: Backup script to restore grants if automatic restoration fails
-- Note: This script is NOT part of the main migration workflow
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT DYNAMIC GRANTS RESTORATION (BACKUP SCRIPT)
PROMPT ================================================================
PROMPT Table: APP_DATA_OWNER.SESSION_DATA
PROMPT Total grants to restore: 0
PROMPT ================================================================


PROMPT No grants found for table APP_DATA_OWNER.SESSION_DATA
PROMPT Nothing to restore.


-- Summary report
DECLARE
    v_expected_grants NUMBER := 0;
    v_actual_grants NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO v_actual_grants
    FROM all_tab_privs
    WHERE owner = 'APP_DATA_OWNER'
    AND table_name = 'SESSION_DATA'
    AND grantee NOT IN ('SYS', 'SYSTEM', 'PUBLIC');
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('GRANTS RESTORATION SUMMARY:');
    DBMS_OUTPUT.PUT_LINE('  Expected grants: ' || v_expected_grants);
    DBMS_OUTPUT.PUT_LINE('  Actual grants: ' || v_actual_grants);
    
    IF v_actual_grants = v_expected_grants THEN
        DBMS_OUTPUT.PUT_LINE('  Status: SUCCESS ✓');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  Status: MISMATCH ⚠️');
        DBMS_OUTPUT.PUT_LINE('  Difference: ' || (v_expected_grants - v_actual_grants));
    END IF;
END;
/

PROMPT ================================================================