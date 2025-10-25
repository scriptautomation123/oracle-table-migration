-- Basic query tests for Oracle database
-- SPOOL results to file for download

-- Set output file
SPOOL /tmp/test_results_01_basic_queries.txt

-- Test header
SELECT '=== BASIC QUERY TESTS ===' as test_header FROM DUAL;
SELECT 'Test started at: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') as timestamp FROM DUAL;

-- Test 1: User count verification
SELECT 'Test 1: User Count' as test_name, COUNT(*) as result FROM users;
SELECT 'Expected: 5' as expectation, 'PASS' as status FROM DUAL WHERE (SELECT COUNT(*) FROM users) = 5;

-- Test 2: Order count verification  
SELECT 'Test 2: Order Count' as test_name, COUNT(*) as result FROM orders;
SELECT 'Expected: 7' as expectation, 'PASS' as status FROM DUAL WHERE (SELECT COUNT(*) FROM orders) = 7;

-- Test 3: Show actual user data
SELECT '=== USER DATA ===' as info FROM DUAL;
SELECT username, email, first_name, last_name FROM users ORDER BY id;

-- Test 4: Show actual order data
SELECT '=== ORDER DATA ===' as info FROM DUAL;
SELECT order_number, total_amount, status, user_id FROM orders ORDER BY id;

-- Test 5: Foreign key relationship test
SELECT 'Test 5: FK Relationship' as test_name, COUNT(*) as result 
FROM users u 
JOIN orders o ON u.id = o.user_id;
SELECT 'Expected: 7' as expectation, 'PASS' as status FROM DUAL 
WHERE (SELECT COUNT(*) FROM users u JOIN orders o ON u.id = o.user_id) = 7;

-- Test 6: Aggregation test
SELECT 'Test 6: Total Sales' as test_name, SUM(total_amount) as result FROM orders;
SELECT 'Expected: 1000.49' as expectation, 'PASS' as status FROM DUAL 
WHERE (SELECT SUM(total_amount) FROM orders) = 1000.49;

-- Test 7: Status distribution
SELECT 'Test 7: Status Distribution' as test_name, status, COUNT(*) as count 
FROM orders 
GROUP BY status 
ORDER BY status;

-- Test footer
SELECT '=== TESTS COMPLETED ===' as test_footer FROM DUAL;
SELECT 'Test completed at: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') as timestamp FROM DUAL;

SPOOL OFF
