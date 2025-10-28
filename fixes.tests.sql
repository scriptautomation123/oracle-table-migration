-- ==================================================================
-- PL/SQL SECURITY FIXES - UNIT TESTS
-- ==================================================================
-- This script tests the security fixes and improvements
-- Run this in a test environment before deploying to production
-- ==================================================================
-- Prerequisites:
--   1. Execute PLSQL_SECURITY_FIXES.sql first to create functions
--   2. Have CREATE TABLE, CREATE VIEW, CREATE TRIGGER privileges
--   3. Have test schema available (defaults to current user)
-- ==================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO ON
SET FEEDBACK ON

PROMPT ==================================================================
PROMPT PL/SQL SECURITY FIXES - UNIT TEST SUITE
PROMPT ==================================================================
PROMPT Running comprehensive tests on security fixes
PROMPT ==================================================================

-- ==================================================================
-- TEST SUITE 1: SQL Injection Protection Tests
-- ==================================================================

PROMPT
PROMPT ==================================================================
PROMPT TEST SUITE 1: SQL Injection Protection
PROMPT ==================================================================

-- Test 1.1: Valid identifier should pass
PROMPT
PROMPT Test 1.1: Valid identifier should pass
DECLARE
    v_result VARCHAR2(128);
BEGIN
    v_result := safe_sql_name('MY_TABLE_123');
    
    IF v_result = 'MY_TABLE_123' THEN
        DBMS_OUTPUT.PUT_LINE('  ✓ PASS: Valid identifier accepted');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: Expected MY_TABLE_123, got ' || v_result);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: Unexpected error: ' || SQLERRM);
END;
/

-- Test 1.2: SQL injection attempt should fail
PROMPT
PROMPT Test 1.2: SQL injection attempt should fail
DECLARE
    v_result VARCHAR2(128);
    v_test_passed BOOLEAN := FALSE;
BEGIN
    BEGIN
        v_result := safe_sql_name('EVIL; DROP TABLE USERS; --');
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: SQL injection was NOT blocked!');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20001 THEN
                DBMS_OUTPUT.PUT_LINE('  ✓ PASS: SQL injection blocked correctly');
                v_test_passed := TRUE;
            ELSE
                DBMS_OUTPUT.PUT_LINE('  ⚠ WARNING: Blocked but wrong error code: ' || SQLCODE);
            END IF;
    END;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: Unexpected error: ' || SQLERRM);
END;
/

-- Test 1.3: Special characters should be rejected
PROMPT
PROMPT Test 1.3: Special characters should be rejected
DECLARE
    v_result VARCHAR2(128);
    v_tests_passed NUMBER := 0;
    v_tests_total NUMBER := 4;
    TYPE string_array IS TABLE OF VARCHAR2(100);
    v_bad_inputs string_array := string_array(
        'table; SELECT',
        'table OR 1=1',
        'table'' --',
        '../../../etc/passwd'
    );
BEGIN
    FOR i IN 1..v_bad_inputs.COUNT LOOP
        BEGIN
            v_result := safe_sql_name(v_bad_inputs(i));
            DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: Accepted bad input: ' || v_bad_inputs(i));
        EXCEPTION
            WHEN OTHERS THEN
                v_tests_passed := v_tests_passed + 1;
        END;
    END LOOP;
    
    IF v_tests_passed = v_tests_total THEN
        DBMS_OUTPUT.PUT_LINE('  ✓ PASS: All ' || v_tests_total || ' injection attempts blocked');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: Only ' || v_tests_passed || ' of ' || v_tests_total || ' blocked');
    END IF;
END;
/

-- Test 1.4: Schema.Table validation
PROMPT
PROMPT Test 1.4: Schema.Table validation
DECLARE
    v_result VARCHAR2(256);
BEGIN
    v_result := safe_schema_table('TEST_SCHEMA', 'TEST_TABLE');
    
    IF v_result LIKE '%TEST_SCHEMA%' AND v_result LIKE '%TEST_TABLE%' THEN
        DBMS_OUTPUT.PUT_LINE('  ✓ PASS: Schema.Table validation works');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: Unexpected result: ' || v_result);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: ' || SQLERRM);
END;
/

-- ==================================================================
-- TEST SUITE 2: INSTEAD OF Trigger Implementation Tests
-- ==================================================================

PROMPT
PROMPT ==================================================================
PROMPT TEST SUITE 2: INSTEAD OF Trigger Implementation
PROMPT ==================================================================
PROMPT NOTE: This requires CREATE TABLE, VIEW, TRIGGER privileges
PROMPT ==================================================================

-- Setup test tables
PROMPT
PROMPT Setting up test environment...
DECLARE
    v_schema VARCHAR2(128) := USER;
    v_table_base VARCHAR2(128) := 'IOTTEST_' || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS');
    v_new_table VARCHAR2(128);
    v_old_table VARCHAR2(128);
BEGIN
    v_new_table := v_table_base || '_NEW';
    v_old_table := v_table_base || '_OLD';
    
    DBMS_OUTPUT.PUT_LINE('Creating test tables: ' || v_table_base);
    
    -- Create NEW table with PK
    EXECUTE IMMEDIATE 
        'CREATE TABLE ' || v_new_table || ' (
            id NUMBER PRIMARY KEY,
            name VARCHAR2(100),
            status VARCHAR2(20),
            created_date DATE DEFAULT SYSDATE
        )';
    DBMS_OUTPUT.PUT_LINE('  ✓ Created ' || v_new_table);
    
    -- Create OLD table with same structure
    EXECUTE IMMEDIATE 
        'CREATE TABLE ' || v_old_table || ' (
            id NUMBER PRIMARY KEY,
            name VARCHAR2(100),
            status VARCHAR2(20),
            created_date DATE DEFAULT SYSDATE
        )';
    DBMS_OUTPUT.PUT_LINE('  ✓ Created ' || v_old_table);
    
    -- Insert test data into OLD table
    EXECUTE IMMEDIATE 
        'INSERT INTO ' || v_old_table || ' VALUES (1, ''Old Record'', ''MIGRATED'', SYSDATE-30)';
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('  ✓ Inserted test data into ' || v_old_table);
    
    -- Store table name for later tests
    EXECUTE IMMEDIATE 
        'CREATE GLOBAL TEMPORARY TABLE temp_test_context (table_name VARCHAR2(128)) ON COMMIT PRESERVE ROWS';
    EXECUTE IMMEDIATE 
        'INSERT INTO temp_test_context VALUES (:1)' USING v_table_base;
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -955 THEN -- Table already exists
            DBMS_OUTPUT.PUT_LINE('  ⚠ Test tables already exist, continuing...');
        ELSE
            DBMS_OUTPUT.PUT_LINE('  ✗ Failed to create test tables: ' || SQLERRM);
            RAISE;
        END IF;
END;
/

-- Test 2.1: Create migration view and trigger
PROMPT
PROMPT Test 2.1: Creating migration view and trigger
DECLARE
    v_schema VARCHAR2(128) := USER;
    v_table_base VARCHAR2(128);
BEGIN
    -- Get table name from temp context
    SELECT table_name INTO v_table_base FROM temp_test_context WHERE ROWNUM = 1;
    
    -- Create migration view using our new procedure
    create_migration_view(v_schema, v_table_base);
    
    DBMS_OUTPUT.PUT_LINE('  ✓ PASS: Migration view created successfully');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: ' || SQLERRM);
END;
/

-- Test 2.2: Verify view shows data from both tables
PROMPT
PROMPT Test 2.2: Verify view combines both tables
DECLARE
    v_schema VARCHAR2(128) := USER;
    v_table_base VARCHAR2(128);
    v_view_name VARCHAR2(128);
    v_count NUMBER;
BEGIN
    SELECT table_name INTO v_table_base FROM temp_test_context WHERE ROWNUM = 1;
    v_view_name := v_table_base || '_JOINED';
    
    -- Count rows in view
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_view_name INTO v_count;
    
    IF v_count = 1 THEN
        DBMS_OUTPUT.PUT_LINE('  ✓ PASS: View shows data from OLD table (1 row)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: Expected 1 row, got ' || v_count);
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: ' || SQLERRM);
END;
/

-- Test 2.3: Test INSERT through view
PROMPT
PROMPT Test 2.3: Test INSERT through view (trigger functionality)
DECLARE
    v_schema VARCHAR2(128) := USER;
    v_table_base VARCHAR2(128);
    v_view_name VARCHAR2(128);
    v_new_table VARCHAR2(128);
    v_count NUMBER;
BEGIN
    SELECT table_name INTO v_table_base FROM temp_test_context WHERE ROWNUM = 1;
    v_view_name := v_table_base || '_JOINED';
    v_new_table := v_table_base || '_NEW';
    
    -- Insert through view
    EXECUTE IMMEDIATE 
        'INSERT INTO ' || v_view_name || ' VALUES (2, ''New Record'', ''ACTIVE'', SYSDATE)';
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('  ✓ INSERT through view succeeded');
    
    -- Verify data went to NEW table
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_new_table || ' WHERE id = 2' INTO v_count;
    
    IF v_count = 1 THEN
        DBMS_OUTPUT.PUT_LINE('  ✓ PASS: Data correctly inserted into NEW table');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: Data not found in NEW table');
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: ' || SQLERRM);
END;
/

-- Test 2.4: Test UPDATE restriction
PROMPT
PROMPT Test 2.4: Test UPDATE restriction (should fail with clear error)
DECLARE
    v_schema VARCHAR2(128) := USER;
    v_table_base VARCHAR2(128);
    v_view_name VARCHAR2(128);
BEGIN
    SELECT table_name INTO v_table_base FROM temp_test_context WHERE ROWNUM = 1;
    v_view_name := v_table_base || '_JOINED';
    
    BEGIN
        EXECUTE IMMEDIATE 
            'UPDATE ' || v_view_name || ' SET status = ''UPDATED'' WHERE id = 1';
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: UPDATE was not blocked!');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20100 THEN
                DBMS_OUTPUT.PUT_LINE('  ✓ PASS: UPDATE correctly blocked with clear error');
            ELSE
                DBMS_OUTPUT.PUT_LINE('  ⚠ WARNING: UPDATE blocked but unexpected error: ' || SQLERRM);
            END IF;
    END;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: ' || SQLERRM);
END;
/

-- Test 2.5: Test DELETE restriction
PROMPT
PROMPT Test 2.5: Test DELETE restriction (should fail with clear error)
DECLARE
    v_schema VARCHAR2(128) := USER;
    v_table_base VARCHAR2(128);
    v_view_name VARCHAR2(128);
BEGIN
    SELECT table_name INTO v_table_base FROM temp_test_context WHERE ROWNUM = 1;
    v_view_name := v_table_base || '_JOINED';
    
    BEGIN
        EXECUTE IMMEDIATE 
            'DELETE FROM ' || v_view_name || ' WHERE id = 1';
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: DELETE was not blocked!');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20101 THEN
                DBMS_OUTPUT.PUT_LINE('  ✓ PASS: DELETE correctly blocked with clear error');
            ELSE
                DBMS_OUTPUT.PUT_LINE('  ⚠ WARNING: DELETE blocked but unexpected error: ' || SQLERRM);
            END IF;
    END;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: ' || SQLERRM);
END;
/

-- Cleanup test objects
PROMPT
PROMPT Cleaning up test objects...
DECLARE
    v_schema VARCHAR2(128) := USER;
    v_table_base VARCHAR2(128);
BEGIN
    BEGIN
        SELECT table_name INTO v_table_base FROM temp_test_context WHERE ROWNUM = 1;
        
        -- Drop in correct order (view/triggers first, then tables)
        BEGIN
            EXECUTE IMMEDIATE 'DROP VIEW ' || v_table_base || '_JOINED';
            DBMS_OUTPUT.PUT_LINE('  ✓ Dropped view');
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || v_table_base || '_NEW PURGE';
            DBMS_OUTPUT.PUT_LINE('  ✓ Dropped NEW table');
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || v_table_base || '_OLD PURGE';
            DBMS_OUTPUT.PUT_LINE('  ✓ Dropped OLD table');
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE temp_test_context PURGE';
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        
        DBMS_OUTPUT.PUT_LINE('  ✓ Cleanup complete');
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('  ⚠ No test context found, skipping cleanup');
    END;
END;
/

-- ==================================================================
-- TEST SUITE 3: Atomic Swap Tests
-- ==================================================================

PROMPT
PROMPT ==================================================================
PROMPT TEST SUITE 3: Atomic Swap Implementation
PROMPT ==================================================================
PROMPT NOTE: Full atomic swap testing requires separate transaction context
PROMPT Testing validation logic only...
PROMPT ==================================================================

-- Test 3.1: Input validation
PROMPT
PROMPT Test 3.1: Atomic swap input validation
DECLARE
    v_test_passed BOOLEAN := FALSE;
BEGIN
    BEGIN
        atomic_table_swap(
            p_schema => 'NONEXISTENT_SCHEMA',
            p_table_original => 'NONEXISTENT_TABLE',
            p_table_new => 'NONEXISTENT_NEW',
            p_table_old => 'NONEXISTENT_OLD'
        );
        DBMS_OUTPUT.PUT_LINE('  ✗ FAIL: Should have failed with missing table error');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20020 OR SQLCODE = -20021 THEN
                DBMS_OUTPUT.PUT_LINE('  ✓ PASS: Correctly validates table existence');
                v_test_passed := TRUE;
            ELSE
                DBMS_OUTPUT.PUT_LINE('  ⚠ WARNING: Failed but unexpected error: ' || SQLERRM);
            END IF;
    END;
END;
/

-- ==================================================================
-- TEST SUMMARY
-- ==================================================================

PROMPT
PROMPT ==================================================================
PROMPT TEST SUMMARY
PROMPT ==================================================================
PROMPT All critical security fixes have been tested
PROMPT 
PROMPT Next steps:
PROMPT   1. Review test results above
PROMPT   2. Verify all tests show ✓ PASS
PROMPT   3. If any ✗ FAIL, investigate before deploying
PROMPT   4. Deploy to test environment for integration testing
PROMPT   5. Security review before production deployment
PROMPT ==================================================================

-- ==================================================================
-- PERFORMANCE TESTS (Optional)
-- ==================================================================

PROMPT
PROMPT ==================================================================
PROMPT PERFORMANCE BASELINE (Optional)
PROMPT ==================================================================
PROMPT Run these tests to establish performance baselines
PROMPT ==================================================================

-- Test P.1: Measure safe_sql_name performance
PROMPT
PROMPT Test P.1: safe_sql_name() performance (10000 iterations)
DECLARE
    v_start_time TIMESTAMP := SYSTIMESTAMP;
    v_end_time TIMESTAMP;
    v_result VARCHAR2(128);
    v_duration NUMBER;
BEGIN
    FOR i IN 1..10000 LOOP
        v_result := safe_sql_name('TEST_TABLE_' || i);
    END LOOP;
    
    v_end_time := SYSTIMESTAMP;
    v_duration := EXTRACT(SECOND FROM (v_end_time - v_start_time));
    
    DBMS_OUTPUT.PUT_LINE('  Duration: ' || ROUND(v_duration, 3) || ' seconds');
    DBMS_OUTPUT.PUT_LINE('  Per call: ' || ROUND(v_duration / 10000 * 1000, 3) || ' ms');
    
    IF v_duration < 1 THEN
        DBMS_OUTPUT.PUT_LINE('  ✓ PASS: Performance acceptable');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  ⚠ WARNING: Performance may need optimization');
    END IF;
END;
/

PROMPT
PROMPT ==================================================================
PROMPT PL/SQL SECURITY FIXES - TEST SUITE COMPLETE
PROMPT ==================================================================
PROMPT Review results above and ensure all critical tests pass
PROMPT before deploying to production
PROMPT ==================================================================
