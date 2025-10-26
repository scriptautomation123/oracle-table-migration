-- ==================================================================
-- RESTORE GRANTS: APP_DATA_OWNER.TEMP_CALCULATIONS
-- ==================================================================
-- Generated: 2025-10-25 16:33:49
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT Step 60: Restoring Grants
PROMPT ================================================================

-- Restore grants using captured grant information from config.json
DECLARE
    v_grant_count NUMBER := 0;
    v_failed_count NUMBER := 0;
    v_total_grants NUMBER := 0;
    v_error_message VARCHAR2(4000);
    v_grant_stmt VARCHAR2(4000);
BEGIN
    -- Count total grants to process from captured grants
    v_total_grants := 0;
    DBMS_OUTPUT.PUT_LINE('Processing ' || v_total_grants || ' grant statements from captured configuration...');
    DBMS_OUTPUT.PUT_LINE('');
    
    DBMS_OUTPUT.PUT_LINE('No grants found in captured configuration - nothing to restore');
    
    -- Summary
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Grant restoration summary:');
    DBMS_OUTPUT.PUT_LINE('  Total grants: ' || v_total_grants);
    DBMS_OUTPUT.PUT_LINE('  Successful: ' || v_grant_count);
    DBMS_OUTPUT.PUT_LINE('  Failed: ' || v_failed_count);
    
    IF v_failed_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('⚠ WARNING: ' || v_failed_count || ' grant(s) failed!');
        DBMS_OUTPUT.PUT_LINE('  Manual intervention may be required to restore privileges');
        DBMS_OUTPUT.PUT_LINE('  Run dynamic_grants.sql for manual grant restoration');
        DBMS_OUTPUT.PUT_LINE('  Check the error messages above for details');
    ELSE
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('✓ All grants restored successfully from captured configuration');
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FATAL ERROR in grant restoration: ' || SQLERRM);
        RAISE;
END;
/

PROMPT ✓ Step 60 Complete: Grants restored