-- Basic query tests for Oracle database
-- These tests verify fundamental database operations

-- Test 1: User count verification
SELECT 'User Count Test' as test_name, COUNT(*) as result FROM users;
SELECT 'Expected: 5' as expectation, 'PASS' as status FROM DUAL WHERE (SELECT COUNT(*) FROM users) = 5;

-- Test 2: Order count verification
SELECT 'Order Count Test' as test_name, COUNT(*) as result FROM orders;
SELECT 'Expected: 7' as expectation, 'PASS' as status FROM DUAL WHERE (SELECT COUNT(*) FROM orders) = 7;

-- Test 3: Foreign key relationship test
SELECT 'FK Relationship Test' as test_name, COUNT(*) as result 
FROM users u 
JOIN orders o ON u.id = o.user_id;
SELECT 'Expected: 7' as expectation, 'PASS' as status FROM DUAL 
WHERE (SELECT COUNT(*) FROM users u JOIN orders o ON u.id = o.user_id) = 7;

-- Test 4: Aggregation test
SELECT 'Total Sales Test' as test_name, SUM(total_amount) as result FROM orders;
SELECT 'Expected: 1000.49' as expectation, 'PASS' as status FROM DUAL 
WHERE (SELECT SUM(total_amount) FROM orders) = 1000.49;

-- Test 5: Status distribution test
SELECT 'Status Distribution' as test_name, status, COUNT(*) as count 
FROM orders 
GROUP BY status 
ORDER BY status;
