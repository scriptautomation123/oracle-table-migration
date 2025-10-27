-- ==================================================================
-- ROW COUNT VALIDATION (Generic)
-- ==================================================================
-- Purpose: Count rows in a table with optional comparison to expected count
-- Usage: @validation/count_table_rows.sql <owner> <table_name> [expected_count]
-- Special: If expected_count is 0 and actual > 0, raises error (for empty table validation)
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT Row Count Validation
PROMPT ================================================================
PROMPT Table: &1.&2
PROMPT Expected: &3
PROMPT ================================================================

-- Variables for row counting
VARIABLE v_actual_count NUMBER
VARIABLE v_expected_count NUMBER

-- Set expected count if provided
BEGIN
    IF '&3' IS NOT NULL AND '&3' != '' THEN
        :v_expected_count := &3;
        DBMS_OUTPUT.PUT_LINE('Expected row count: ' || TO_CHAR(:v_expected_count, '999,999,999,999'));
    ELSE
        :v_expected_count := NULL;
        DBMS_OUTPUT.PUT_LINE('No expected count provided');
    END IF;
END;
/

-- Count actual rows
PROMPT Counting rows in &1.&2...

BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM &1.&2'
    INTO :v_actual_count;
    
    DBMS_OUTPUT.PUT_LINE('Actual row count: ' || TO_CHAR(:v_actual_count, '999,999,999,999'));
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Compare with expected count if provided
    IF :v_expected_count IS NOT NULL THEN
        IF :v_actual_count = :v_expected_count THEN
            DBMS_OUTPUT.PUT_LINE('✓ Row count matches expected value');
        ELSIF :v_actual_count > :v_expected_count THEN
            -- Special case: if expecting 0 rows but found more, raise error
            IF :v_expected_count = 0 THEN
                DBMS_OUTPUT.PUT_LINE('ERROR: Target table has ' || TO_CHAR(:v_actual_count, '999,999,999,999') || ' rows!');
                DBMS_OUTPUT.PUT_LINE('        Consider truncating before load');
                RAISE_APPLICATION_ERROR(-20001, 'Target table is not empty');
            ELSE
                DBMS_OUTPUT.PUT_LINE('⚠ Row count is HIGHER than expected (+' || TO_CHAR(:v_actual_count - :v_expected_count, '999,999,999,999') || ' rows)');
                DBMS_OUTPUT.PUT_LINE('  This may indicate new data was added since discovery');
            END IF;
        ELSE
            DBMS_OUTPUT.PUT_LINE('⚠ Row count is LOWER than expected (-' || TO_CHAR(:v_expected_count - :v_actual_count, '999,999,999,999') || ' rows)');
            DBMS_OUTPUT.PUT_LINE('  This may indicate data was deleted since discovery');
        END IF;
    ELSE
        DBMS_OUTPUT.PUT_LINE('No expected count provided for comparison');
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR counting rows: ' || SQLERRM);
        RAISE;
END;
/

PROMPT
PROMPT ================================================================
PROMPT Row Count Validation Complete
PROMPT ================================================================
