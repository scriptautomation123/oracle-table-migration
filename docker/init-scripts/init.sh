#!/bin/bash
# Single initialization script - creates schemas, tables, and loads data

echo "Initializing Oracle database..."

# Run partition swap setup first if it exists
if [ -f "$(dirname "$0")/partition_swap_setup.sql" ]; then
    echo "Setting up partition swap demo..."
    sqlplus -s hr/hr123@//localhost/FREEPDB1 @"$(dirname "$0")/partition_swap_setup.sql"
fi

# Connect as HR user and do everything
sqlplus -s hr/hr123@//localhost/FREEPDB1 <<'EOF'
SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ========================================
PROMPT Creating Tables
PROMPT ========================================

-- EMPLOYEES table
CREATE TABLE employees (
    employee_id     NUMBER(6) PRIMARY KEY,
    first_name      VARCHAR2(20),
    last_name       VARCHAR2(25) NOT NULL,
    email           VARCHAR2(100) NOT NULL UNIQUE,
    hire_date       DATE NOT NULL,
    salary          NUMBER(8,2),
    department_id   NUMBER(4)
);

-- DEPARTMENTS table  
CREATE TABLE departments (
    department_id   NUMBER(4) PRIMARY KEY,
    department_name VARCHAR2(30) NOT NULL,
    manager_id      NUMBER(6)
);

-- SALES_TRANSACTIONS table (partitioned)
CREATE TABLE sales_transactions (
    transaction_id   NUMBER(12) PRIMARY KEY,
    customer_id      NUMBER(10) NOT NULL,
    transaction_date DATE NOT NULL,
    amount           NUMBER(12,2) NOT NULL
)
PARTITION BY RANGE (transaction_date)
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
    PARTITION p_2023 VALUES LESS THAN (DATE '2024-01-01')
)
ENABLE ROW MOVEMENT;

PROMPT ✓ Tables created

PROMPT ========================================
PROMPT Loading Test Data
PROMPT ========================================

-- Insert departments
INSERT INTO departments VALUES (10, 'IT', 100);
INSERT INTO departments VALUES (20, 'Sales', 101);
INSERT INTO departments VALUES (30, 'Finance', 102);

-- Insert employees
INSERT INTO employees VALUES (100, 'John', 'Doe', 'jdoe@example.com', DATE '2023-01-15', 75000, 10);
INSERT INTO employees VALUES (101, 'Jane', 'Smith', 'jsmith@example.com', DATE '2023-02-20', 80000, 20);
INSERT INTO employees VALUES (102, 'Bob', 'Johnson', 'bjohnson@example.com', DATE '2023-03-10', 70000, 30);

-- Insert sales transactions
BEGIN
    FOR i IN 1..100 LOOP
        INSERT INTO sales_transactions VALUES (
            i,
            MOD(i, 10) + 1,
            DATE '2023-01-01' + MOD(i, 365),
            ROUND(DBMS_RANDOM.VALUE(100, 5000), 2)
        );
    END LOOP;
    COMMIT;
END;
/

PROMPT ✓ Test data loaded (3 departments, 3 employees, 100 transactions)

PROMPT ========================================
PROMPT Gathering Statistics
PROMPT ========================================

BEGIN
    DBMS_STATS.GATHER_SCHEMA_STATS('HR', cascade => TRUE);
END;
/

PROMPT ✓ Statistics gathered

PROMPT ========================================
PROMPT Database Initialization Complete
PROMPT ========================================

EXIT;
EOF

echo "✓ Initialization complete!"
