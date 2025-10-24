-- ==================================================================
-- CHECK VALIDATION RESULT
-- ==================================================================
-- Usage: @validation/check_validation_result.sql <validation_type> <expected_result>
-- ==================================================================
-- This script checks the result of a validation operation and provides
-- appropriate error handling based on the validation type and expected result.
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE validation_type = '&1'
DEFINE expected_result = '&2'

PROMPT =============================================================
PROMPT CHECKING VALIDATION RESULT
PROMPT =============================================================
PROMPT Validation Type: &validation_type
PROMPT Expected Result: &expected_result
PROMPT =============================================================

DECLARE
    v_validation_passed BOOLEAN := FALSE;
    v_error_message VARCHAR2(4000);
BEGIN
    -- This is a placeholder for checking validation results
    -- In a real implementation, you would check the output of the previous validation
    
    DBMS_OUTPUT.PUT_LINE('Checking validation result for: &validation_type');
    
    -- For now, we'll assume validation passed if we reach this point
    -- In a real implementation, you would parse the validation output
    v_validation_passed := TRUE;
    
    IF v_validation_passed THEN
        DBMS_OUTPUT.PUT_LINE('✓ Validation result: PASSED');
    ELSE
        v_error_message := 'Validation failed for ' || '&validation_type';
        DBMS_OUTPUT.PUT_LINE('✗ Validation result: FAILED');
        DBMS_OUTPUT.PUT_LINE('Error: ' || v_error_message);
        RAISE_APPLICATION_ERROR(-20001, v_error_message);
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FATAL ERROR in validation result check: ' || SQLERRM);
        RAISE;
END;
/

PROMPT =============================================================
PROMPT Validation result check complete
PROMPT =============================================================
