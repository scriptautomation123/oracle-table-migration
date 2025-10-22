#!/bin/bash
# Generate test data for HR schema
set -e

echo "Generating test data for HR schema..."

sqlplus -s hr/hr123@//localhost/FREEPDB1 <<'EOF'
SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ========================================================================
PROMPT Generating Test Data for HR Schema
PROMPT ========================================================================

-- JOBS data (minimal reference data)
INSERT ALL
    INTO jobs VALUES ('AD_PRES', 'President', 20000, 40000)
    INTO jobs VALUES ('AD_VP', 'Vice President', 15000, 30000)
    INTO jobs VALUES ('IT_PROG', 'Programmer', 4000, 10000)
    INTO jobs VALUES ('SA_REP', 'Sales Representative', 6000, 12000)
    INTO jobs VALUES ('ST_CLERK', 'Stock Clerk', 2000, 5000)
SELECT * FROM dual;

PROMPT ✓ 5 jobs inserted

-- DEPARTMENTS data
INSERT ALL
    INTO departments VALUES (10, 'Administration', 200, 1700, SYSDATE-1000)
    INTO departments VALUES (20, 'Marketing', 201, 1800, SYSDATE-900)
    INTO departments VALUES (50, 'Shipping', 124, 1500, SYSDATE-800)
    INTO departments VALUES (60, 'IT', 103, 1400, SYSDATE-700)
    INTO departments VALUES (80, 'Sales', 145, 2500, SYSDATE-600)
    INTO departments VALUES (90, 'Executive', 100, 1700, SYSDATE-500)
    INTO departments VALUES (110, 'Accounting', 205, 1700, SYSDATE-400)
SELECT * FROM dual;

PROMPT ✓ 7 departments inserted

-- EMPLOYEES data (sample employees)
INSERT INTO employees VALUES (100, 'Steven', 'King', 'SKING', '515.123.4567', DATE '2003-06-17', 'AD_PRES', 24000, NULL, NULL, 90, SYSDATE-2000);
INSERT INTO employees VALUES (101, 'Neena', 'Kochhar', 'NKOCHHAR', '515.123.4568', DATE '2005-09-21', 'AD_VP', 17000, NULL, 100, 90, SYSDATE-1900);
INSERT INTO employees VALUES (102, 'Lex', 'De Haan', 'LDEHAAN', '515.123.4569', DATE '2001-01-13', 'AD_VP', 17000, NULL, 100, 90, SYSDATE-1800);
INSERT INTO employees VALUES (103, 'Alexander', 'Hunold', 'AHUNOLD', '590.423.4567', DATE '2006-01-03', 'IT_PROG', 9000, NULL, 102, 60, SYSDATE-1700);
INSERT INTO employees VALUES (104, 'Bruce', 'Ernst', 'BERNST', '590.423.4568', DATE '2007-05-21', 'IT_PROG', 6000, NULL, 103, 60, SYSDATE-1600);

PROMPT ✓ 5 employees inserted

-- SALES_TRANSACTIONS data (interval partitioned table - will create automatic partitions)
BEGIN
    FOR i IN 1..100 LOOP
        INSERT INTO sales_transactions VALUES (
            i,
            MOD(i, 20) + 1,
            MOD(i, 50) + 1,
            DATE '2023-01-01' + MOD(i, 365),
            TRUNC(DBMS_RANDOM.VALUE(1, 10)),
            ROUND(DBMS_RANDOM.VALUE(10, 500), 2),
            0,
            MOD(i, 5) + 100,
            SYSDATE
        );
    END LOOP;
    COMMIT;
END;
/

UPDATE sales_transactions SET total_amount = quantity * unit_price;
COMMIT;

PROMPT ✓ 100 sales transactions inserted

-- ORDER_HEADERS data
BEGIN
    FOR i IN 1..100 LOOP
        INSERT INTO order_headers VALUES (
            i,
            MOD(i, 20) + 1,
            DATE '2023-01-01' + MOD(i, 365),
            CASE MOD(i, 4) WHEN 0 THEN 'COMPLETED' WHEN 1 THEN 'PENDING' WHEN 2 THEN 'SHIPPED' ELSE 'CANCELLED' END,
            ROUND(DBMS_RANDOM.VALUE(100, 5000), 2),
            CASE MOD(i, 3) WHEN 0 THEN 'CREDIT_CARD' WHEN 1 THEN 'DEBIT_CARD' ELSE 'CASH' END,
            'Address ' || i,
            SYSDATE
        );
    END LOOP;
    COMMIT;
END;
/

PROMPT ✓ 100 order headers inserted

-- CUSTOMER_INTERACTIONS data
BEGIN
    FOR i IN 1..100 LOOP
        INSERT INTO customer_interactions VALUES (
            i,
            MOD(i, 20) + 1,
            DATE '2023-01-01' + MOD(i, 365),
            CASE MOD(i, 4) WHEN 0 THEN 'PHONE_CALL' WHEN 1 THEN 'EMAIL' WHEN 2 THEN 'CHAT' ELSE 'IN_PERSON' END,
            CASE MOD(i, 3) WHEN 0 THEN 'WEB' WHEN 1 THEN 'MOBILE' ELSE 'STORE' END,
            'Interaction notes for customer interaction ' || i,
            MOD(i, 5) + 100,
            SYSDATE
        );
    END LOOP;
    COMMIT;
END;
/

PROMPT ✓ 100 customer interactions inserted

-- AUDIT_LOG data
BEGIN
    FOR i IN 1..100 LOOP
        INSERT INTO audit_log VALUES (
            i,
            CASE MOD(i, 7) 
                WHEN 0 THEN 'EMPLOYEES' 
                WHEN 1 THEN 'DEPARTMENTS' 
                WHEN 2 THEN 'SALES_TRANSACTIONS'
                WHEN 3 THEN 'ORDER_HEADERS'
                WHEN 4 THEN 'CUSTOMER_INTERACTIONS'
                WHEN 5 THEN 'JOBS'
                ELSE 'AUDIT_LOG'
            END,
            CASE MOD(i, 3) WHEN 0 THEN 'INSERT' WHEN 1 THEN 'UPDATE' ELSE 'DELETE' END,
            DATE '2023-01-01' + MOD(i, 365),
            'USER_' || MOD(i, 10),
            'SQL statement ' || i,
            SYSDATE
        );
    END LOOP;
    COMMIT;
END;
/

PROMPT ✓ 100 audit log entries inserted

-- Gather statistics
BEGIN
    DBMS_STATS.GATHER_SCHEMA_STATS('HR');
END;
/

PROMPT ✓ Statistics gathered

PROMPT
PROMPT ========================================================================
PROMPT Test Data Generation Complete
PROMPT ========================================================================

-- Display row counts
SELECT 'JOBS' as table_name, COUNT(*) as row_count FROM jobs
UNION ALL
SELECT 'DEPARTMENTS', COUNT(*) FROM departments
UNION ALL
SELECT 'EMPLOYEES', COUNT(*) FROM employees
UNION ALL
SELECT 'SALES_TRANSACTIONS', COUNT(*) FROM sales_transactions
UNION ALL
SELECT 'ORDER_HEADERS', COUNT(*) FROM order_headers
UNION ALL
SELECT 'CUSTOMER_INTERACTIONS', COUNT(*) FROM customer_interactions
UNION ALL
SELECT 'AUDIT_LOG', COUNT(*) FROM audit_log
ORDER BY 1;

EOF

echo "✓ Test data generated successfully"
