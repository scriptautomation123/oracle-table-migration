#!/bin/bash
# Wrapper script to run HR table creation as HR user
set -e

echo "Creating HR tables..."

sqlplus -s hr/hr123@//localhost/FREEPDB1 <<'EOF'
-- ============================================================================
-- Create HR Schema Test Tables (All Tables - Mixed Partition States)
-- ============================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ========================================================================
PROMPT Creating HR Schema Tables
PROMPT ========================================================================
PROMPT
PROMPT Group 1: Non-Partitioned Tables (3 tables)
PROMPT Group 2: Interval Partitioned Tables (4 tables)
PROMPT ========================================================================

-- ============================================================================
-- GROUP 1: NON-PARTITIONED TABLES
-- ============================================================================

PROMPT
PROMPT Creating EMPLOYEES table (non-partitioned)...

CREATE TABLE employees (
    employee_id     NUMBER(6) NOT NULL,
    first_name      VARCHAR2(20),
    last_name       VARCHAR2(25) NOT NULL,
    email           VARCHAR2(25) NOT NULL,
    phone_number    VARCHAR2(20),
    hire_date       DATE NOT NULL,
    job_id          VARCHAR2(10) NOT NULL,
    salary          NUMBER(8,2),
    commission_pct  NUMBER(2,2),
    manager_id      NUMBER(6),
    department_id   NUMBER(4),
    created_date    DATE DEFAULT SYSDATE,
    CONSTRAINT emp_emp_id_pk PRIMARY KEY (employee_id),
    CONSTRAINT emp_email_uk UNIQUE (email)
);

PROMPT ✓ EMPLOYEES table created

PROMPT
PROMPT Creating DEPARTMENTS table (non-partitioned)...

CREATE TABLE departments (
    department_id    NUMBER(4) NOT NULL,
    department_name  VARCHAR2(30) NOT NULL,
    manager_id       NUMBER(6),
    location_id      NUMBER(4),
    created_date     DATE DEFAULT SYSDATE,
    CONSTRAINT dept_id_pk PRIMARY KEY (department_id)
);

PROMPT ✓ DEPARTMENTS table created

PROMPT
PROMPT Creating JOBS table (non-partitioned)...

CREATE TABLE jobs (
    job_id       VARCHAR2(10) NOT NULL,
    job_title    VARCHAR2(35) NOT NULL,
    min_salary   NUMBER(6),
    max_salary   NUMBER(6),
    CONSTRAINT job_id_pk PRIMARY KEY (job_id)
);

PROMPT ✓ JOBS table created

-- ============================================================================
-- GROUP 2: INTERVAL PARTITIONED TABLES (Already Partitioned)
-- ============================================================================

PROMPT
PROMPT Creating SALES_TRANSACTIONS table (interval partitioned)...

CREATE TABLE sales_transactions (
    transaction_id   NUMBER(12) NOT NULL,
    customer_id      NUMBER(10) NOT NULL,
    product_id       NUMBER(10) NOT NULL,
    transaction_date DATE NOT NULL,
    quantity         NUMBER(6) NOT NULL,
    unit_price       NUMBER(10,2) NOT NULL,
    total_amount     NUMBER(12,2) NOT NULL,
    sales_rep_id     NUMBER(6),
    created_date     DATE DEFAULT SYSDATE,
    CONSTRAINT sales_trans_pk PRIMARY KEY (transaction_id, transaction_date)
)
PARTITION BY RANGE (transaction_date)
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
    PARTITION p_2023_01 VALUES LESS THAN (DATE '2023-02-01'),
    PARTITION p_2023_02 VALUES LESS THAN (DATE '2023-03-01'),
    PARTITION p_2023_03 VALUES LESS THAN (DATE '2023-04-01')
);

PROMPT ✓ SALES_TRANSACTIONS table created (interval partitioned)

PROMPT
PROMPT Creating ORDER_HEADERS table (interval partitioned)...

CREATE TABLE order_headers (
    order_id         NUMBER(12) NOT NULL,
    customer_id      NUMBER(10) NOT NULL,
    order_date       DATE NOT NULL,
    order_status     VARCHAR2(20) NOT NULL,
    total_amount     NUMBER(12,2),
    payment_method   VARCHAR2(20),
    shipping_address VARCHAR2(200),
    created_date     DATE DEFAULT SYSDATE,
    CONSTRAINT order_hdr_pk PRIMARY KEY (order_id, order_date)
)
PARTITION BY RANGE (order_date)
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
    PARTITION p_2023_q1 VALUES LESS THAN (DATE '2023-04-01'),
    PARTITION p_2023_q2 VALUES LESS THAN (DATE '2023-07-01')
);

PROMPT ✓ ORDER_HEADERS table created (interval partitioned)

PROMPT
PROMPT Creating CUSTOMER_INTERACTIONS table (interval partitioned)...

CREATE TABLE customer_interactions (
    interaction_id   NUMBER(12) NOT NULL,
    customer_id      NUMBER(10) NOT NULL,
    interaction_date DATE NOT NULL,
    interaction_type VARCHAR2(30) NOT NULL,
    channel          VARCHAR2(20),
    notes            VARCHAR2(4000),
    agent_id         NUMBER(6),
    created_date     DATE DEFAULT SYSDATE,
    CONSTRAINT cust_int_pk PRIMARY KEY (interaction_id, interaction_date)
)
PARTITION BY RANGE (interaction_date)
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
    PARTITION p_2023_01 VALUES LESS THAN (DATE '2023-02-01'),
    PARTITION p_2023_02 VALUES LESS THAN (DATE '2023-03-01')
);

PROMPT ✓ CUSTOMER_INTERACTIONS table created (interval partitioned)

PROMPT
PROMPT Creating AUDIT_LOG table (interval partitioned with HASH subpartitions)...

CREATE TABLE audit_log (
    audit_id         NUMBER(15) NOT NULL,
    table_name       VARCHAR2(30) NOT NULL,
    operation        VARCHAR2(10) NOT NULL,
    audit_date       DATE NOT NULL,
    user_name        VARCHAR2(30),
    sql_text         CLOB,
    created_date     DATE DEFAULT SYSDATE,
    CONSTRAINT audit_log_pk PRIMARY KEY (audit_id, audit_date, table_name)
)
PARTITION BY RANGE (audit_date)
SUBPARTITION BY HASH (table_name)
SUBPARTITIONS 4
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
    PARTITION p_2023_01 VALUES LESS THAN (DATE '2023-02-01'),
    PARTITION p_2023_02 VALUES LESS THAN (DATE '2023-03-01')
);

PROMPT ✓ AUDIT_LOG table created (interval partitioned with hash subpartitions)

-- ============================================================================
-- Create indexes
-- ============================================================================

PROMPT
PROMPT Creating indexes...

CREATE INDEX emp_department_ix ON employees (department_id);
CREATE INDEX emp_job_ix ON employees (job_id);
CREATE INDEX emp_manager_ix ON employees (manager_id);
CREATE INDEX emp_name_ix ON employees (last_name, first_name);

CREATE INDEX dept_location_ix ON departments (location_id);

CREATE INDEX sales_customer_ix ON sales_transactions (customer_id) LOCAL;
CREATE INDEX sales_product_ix ON sales_transactions (product_id) LOCAL;
CREATE INDEX sales_rep_ix ON sales_transactions (sales_rep_id) LOCAL;

CREATE INDEX order_customer_ix ON order_headers (customer_id) LOCAL;
CREATE INDEX order_status_ix ON order_headers (order_status) LOCAL;

CREATE INDEX cust_int_cust_ix ON customer_interactions (customer_id) LOCAL;
CREATE INDEX cust_int_type_ix ON customer_interactions (interaction_type) LOCAL;

CREATE INDEX audit_table_ix ON audit_log (table_name) LOCAL;
CREATE INDEX audit_user_ix ON audit_log (user_name) LOCAL;

PROMPT ✓ Indexes created

PROMPT
PROMPT ========================================================================
PROMPT HR Tables Created Successfully
PROMPT ========================================================================

EOF

echo "✓ HR tables created successfully"
