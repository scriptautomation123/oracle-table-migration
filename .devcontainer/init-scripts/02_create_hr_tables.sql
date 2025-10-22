-- ============================================================================
-- Create HR Schema Test Tables (All Tables - Mixed Partition States)
-- ============================================================================
-- Purpose: Create realistic test tables for comprehensive migration testing
-- Run as: HR user
-- ============================================================================
-- Structure:
--   Group 1: Non-Partitioned Tables (for initial partitioning tests)
--   Group 2: Existing Interval Partitioned Tables (for conversion tests)
-- All tables owned by HR schema
-- HR_APP_USER can access via HR_APP role
-- ============================================================================

CONNECT hr/hr123@XEPDB1

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
PROMPT ========================================================================
PROMPT GROUP 1: Non-Partitioned Tables
PROMPT ========================================================================

-- ============================================================================
-- Table 1: EMPLOYEES (Non-Partitioned)
-- Purpose: Test non-partitioned → interval-hash (DAY interval on HIRE_DATE)
-- Size: ~5,000 rows
-- ============================================================================

PROMPT Creating EMPLOYEES table...

CREATE TABLE employees (
    employee_id     NUMBER(6) PRIMARY KEY,
    first_name      VARCHAR2(20),
    last_name       VARCHAR2(25) NOT NULL,
    email           VARCHAR2(100) NOT NULL UNIQUE,
    phone_number    VARCHAR2(20),
    hire_date       DATE NOT NULL,
    job_id          VARCHAR2(10) NOT NULL,
    salary          NUMBER(8,2),
    commission_pct  NUMBER(2,2),
    manager_id      NUMBER(6),
    department_id   NUMBER(4),
    created_date    DATE DEFAULT SYSDATE,
    updated_date    DATE
) TABLESPACE users;

CREATE INDEX emp_dept_idx ON employees(department_id);
CREATE INDEX emp_mgr_idx ON employees(manager_id);
CREATE INDEX emp_hire_date_idx ON employees(hire_date);

PROMPT ✓ EMPLOYEES table created

-- ============================================================================
-- Table 2: ORDERS
-- Purpose: Test non-partitioned → interval-hash (DAY interval on ORDER_DATE)
-- Size: ~50,000 rows
-- ============================================================================

PROMPT Creating ORDERS table...

CREATE TABLE orders (
    order_id        NUMBER(12) PRIMARY KEY,
    customer_id     NUMBER(6) NOT NULL,
    employee_id     NUMBER(6),
    order_date      DATE NOT NULL,
    shipped_date    DATE,
    ship_via        VARCHAR2(20),
    freight         NUMBER(8,2),
    status          VARCHAR2(20) DEFAULT 'PENDING',
    total_amount    NUMBER(10,2),
    notes           VARCHAR2(500),
    created_date    DATE DEFAULT SYSDATE,
    updated_date    DATE
) TABLESPACE users;

CREATE INDEX ord_cust_idx ON orders(customer_id);
CREATE INDEX ord_emp_idx ON orders(employee_id);
CREATE INDEX ord_date_idx ON orders(order_date);
CREATE INDEX ord_status_idx ON orders(status);

PROMPT ✓ ORDERS table created

-- ============================================================================
-- Table 3: DEPARTMENTS
-- Purpose: Small dimension table (no partitioning needed, but useful for testing)
-- Size: ~50 rows
-- ============================================================================

PROMPT Creating DEPARTMENTS table...

CREATE TABLE departments (
    department_id   NUMBER(4) PRIMARY KEY,
    department_name VARCHAR2(30) NOT NULL UNIQUE,
    manager_id      NUMBER(6),
    location_id     NUMBER(4),
    created_date    DATE DEFAULT SYSDATE
) TABLESPACE users;

PROMPT ✓ DEPARTMENTS table created

-- ============================================================================
-- GROUP 2: INTERVAL PARTITIONED TABLES
-- ============================================================================

PROMPT
PROMPT ========================================================================
PROMPT GROUP 2: Interval Partitioned Tables
PROMPT ========================================================================

-- ============================================================================
-- Table 4: TRANSACTIONS (Existing INTERVAL Partitioned - MONTH)
-- Purpose: Test interval → interval-hash conversion (add HASH subpartitions)
-- Current: INTERVAL(NUMTOYMINTERVAL(1,'MONTH')) on TXN_DATE
-- Target: Add HASH subpartitions on TRANSACTION_ID
-- Size: ~500,000 rows
-- ============================================================================

PROMPT Creating TRANSACTIONS table (INTERVAL partitioned - MONTH)...

CREATE TABLE transactions (
    transaction_id  NUMBER(12) PRIMARY KEY,
    account_id      NUMBER(10) NOT NULL,
    txn_date        DATE NOT NULL,
    txn_type        VARCHAR2(20) NOT NULL,
    amount          NUMBER(12,2) NOT NULL,
    balance         NUMBER(15,2),
    description     VARCHAR2(200),
    status          VARCHAR2(20) DEFAULT 'COMPLETED',
    created_date    DATE DEFAULT SYSDATE
)
PARTITION BY RANGE (txn_date)
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(
    PARTITION p_initial VALUES LESS THAN (TO_DATE('2023-01-01', 'YYYY-MM-DD'))
)
ENABLE ROW MOVEMENT
TABLESPACE users;

CREATE INDEX txn_acct_idx ON transactions(account_id) LOCAL;
CREATE INDEX txn_type_idx ON transactions(txn_type) LOCAL;

PROMPT ✓ TRANSACTIONS table created (INTERVAL-MONTH)

-- ============================================================================
-- Table 5: AUDIT_LOG (Existing INTERVAL Partitioned - DAY)
-- Purpose: Test interval reconfiguration (DAY → HOUR + add HASH)
-- Current: INTERVAL(NUMTODSINTERVAL(1,'DAY')) on AUDIT_DATE
-- Target: Change to HOUR interval + HASH on USER_ID
-- Size: ~1,000,000 rows
-- ============================================================================

PROMPT Creating AUDIT_LOG table (INTERVAL partitioned - DAY)...

CREATE TABLE audit_log (
    audit_id        NUMBER(15) PRIMARY KEY,
    user_id         NUMBER(10) NOT NULL,
    audit_date      DATE NOT NULL,
    action_type     VARCHAR2(50) NOT NULL,
    table_name      VARCHAR2(30),
    record_id       VARCHAR2(100),
    old_value       VARCHAR2(4000),
    new_value       VARCHAR2(4000),
    ip_address      VARCHAR2(50),
    session_id      VARCHAR2(100)
)
PARTITION BY RANGE (audit_date)
INTERVAL (NUMTODSINTERVAL(1,'DAY'))
(
    PARTITION p_initial VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD'))
)
ENABLE ROW MOVEMENT
TABLESPACE users;

CREATE INDEX audit_user_idx ON audit_log(user_id) LOCAL;
CREATE INDEX audit_action_idx ON audit_log(action_type) LOCAL;

PROMPT ✓ AUDIT_LOG table created (INTERVAL-DAY)

-- ============================================================================
-- Table 6: EVENTS (Non-Partitioned)
-- Purpose: Test non-partitioned → HOUR interval + HASH (high-frequency data)
-- Target: HOUR interval on EVENT_DATE + HASH on USER_ID
-- Size: ~100,000 rows
-- ============================================================================

PROMPT Creating EVENTS table (non-partitioned)...

CREATE TABLE events (
    event_id        NUMBER(12) PRIMARY KEY,
    user_id         NUMBER(10) NOT NULL,
    event_date      DATE NOT NULL,
    event_type      VARCHAR2(50) NOT NULL,
    event_category  VARCHAR2(30),
    event_data      VARCHAR2(4000),
    duration_ms     NUMBER(10),
    status_code     NUMBER(3),
    created_date    DATE DEFAULT SYSDATE
) TABLESPACE users;

CREATE INDEX evt_user_idx ON events(user_id);
CREATE INDEX evt_date_idx ON events(event_date);
CREATE INDEX evt_type_idx ON events(event_type);

PROMPT ✓ EVENTS table created (non-partitioned)

-- ============================================================================
-- Table 7: CUSTOMER_DATA (Non-Partitioned with LOBs)
-- Purpose: Test LOB handling in partitioned tables + MONTH interval
-- Target: MONTH interval on REGISTRATION_DATE + HASH on CUSTOMER_ID
-- Size: ~25,000 rows
-- ============================================================================

PROMPT Creating CUSTOMER_DATA table (non-partitioned with LOBs)...

CREATE TABLE customer_data (
    customer_id     NUMBER(10) PRIMARY KEY,
    customer_name   VARCHAR2(100) NOT NULL,
    email           VARCHAR2(100) UNIQUE,
    phone           VARCHAR2(20),
    address         VARCHAR2(500),
    registration_date DATE NOT NULL,
    account_status  VARCHAR2(20) DEFAULT 'ACTIVE',
    notes           CLOB,
    profile_photo   BLOB,
    preferences     CLOB,
    created_date    DATE DEFAULT SYSDATE,
    updated_date    DATE
) 
TABLESPACE users
LOB (notes) STORE AS SECUREFILE (
    TABLESPACE users
    ENABLE STORAGE IN ROW
    CHUNK 8192
    CACHE
)
LOB (profile_photo) STORE AS SECUREFILE (
    TABLESPACE users
    DISABLE STORAGE IN ROW
    CHUNK 8192
    CACHE
)
LOB (preferences) STORE AS SECUREFILE (
    TABLESPACE users
    ENABLE STORAGE IN ROW
    CHUNK 8192
    CACHE
);

CREATE INDEX cust_email_idx ON customer_data(email);
CREATE INDEX cust_reg_date_idx ON customer_data(registration_date);
CREATE INDEX cust_status_idx ON customer_data(account_status);

PROMPT ✓ CUSTOMER_DATA table created (non-partitioned with 3 LOBs)

-- ============================================================================
-- Create Sequences
-- ============================================================================

PROMPT Creating sequences...

CREATE SEQUENCE emp_seq START WITH 1000 INCREMENT BY 1 CACHE 100;
CREATE SEQUENCE ord_seq START WITH 100000 INCREMENT BY 1 CACHE 1000;
CREATE SEQUENCE dept_seq START WITH 100 INCREMENT BY 10 CACHE 20;
CREATE SEQUENCE txn_seq START WITH 1000000 INCREMENT BY 1 CACHE 1000;
CREATE SEQUENCE audit_seq START WITH 1000000 INCREMENT BY 1 CACHE 1000;
CREATE SEQUENCE event_seq START WITH 100000 INCREMENT BY 1 CACHE 1000;
CREATE SEQUENCE cust_seq START WITH 10000 INCREMENT BY 1 CACHE 100;

PROMPT ✓ Sequences created

-- ============================================================================
-- Create Views for Testing
-- ============================================================================

PROMPT Creating test views...

CREATE OR REPLACE VIEW v_partition_summary AS
SELECT 
    table_name,
    partitioning_type,
    subpartitioning_type,
    partition_count,
    def_subpartition_count,
    interval
FROM user_part_tables
ORDER BY table_name;

CREATE OR REPLACE VIEW v_table_sizes AS
SELECT 
    segment_name as table_name,
    ROUND(SUM(bytes)/POWER(1024,3), 2) as size_gb,
    COUNT(*) as segment_count
FROM user_segments
WHERE segment_type IN ('TABLE', 'TABLE PARTITION', 'TABLE SUBPARTITION')
GROUP BY segment_name
ORDER BY size_gb DESC;

CREATE OR REPLACE VIEW v_table_summary AS
SELECT 
    t.table_name,
    t.num_rows,
    ROUND(t.num_rows * t.avg_row_len / POWER(1024,3), 2) as est_size_gb,
    p.partitioning_type,
    p.partition_count,
    CASE 
        WHEN p.partitioning_type IS NULL THEN 'Non-Partitioned'
        WHEN p.interval IS NOT NULL THEN 'Interval-' || p.partitioning_type
        ELSE p.partitioning_type
    END as partition_status
FROM user_tables t
LEFT JOIN user_part_tables p ON t.table_name = p.table_name
ORDER BY t.num_rows DESC NULLS LAST;

PROMPT ✓ Views created

-- ============================================================================
-- Grant Privileges to HR_APP Role
-- ============================================================================

PROMPT Granting privileges to HR_APP role...

BEGIN
    -- Tables
    FOR t IN (SELECT table_name FROM user_tables) LOOP
        EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, UPDATE, DELETE ON ' || t.table_name || ' TO hr_app';
    END LOOP;
    
    -- Sequences
    FOR s IN (SELECT sequence_name FROM user_sequences) LOOP
        EXECUTE IMMEDIATE 'GRANT SELECT ON ' || s.sequence_name || ' TO hr_app';
    END LOOP;
    
    -- Views
    FOR v IN (SELECT view_name FROM user_views) LOOP
        EXECUTE IMMEDIATE 'GRANT SELECT ON ' || v.view_name || ' TO hr_app';
    END LOOP;
END;
/

PROMPT ✓ Privileges granted to HR_APP role

-- ============================================================================
-- Gather Statistics
-- ============================================================================

PROMPT Gathering statistics...

BEGIN
    DBMS_STATS.GATHER_SCHEMA_STATS(
        ownname => 'HR',
        cascade => TRUE
    );
END;
/

PROMPT ========================================================================
PROMPT HR Schema Tables Created Successfully
PROMPT ========================================================================
PROMPT
PROMPT Tables Created (7 total):
PROMPT 
PROMPT GROUP 1 - Non-Partitioned (3 tables):
PROMPT   1. EMPLOYEES        (for DAY interval testing)
PROMPT   2. ORDERS           (for DAY interval testing)
PROMPT   3. DEPARTMENTS      (dimension table)
PROMPT
PROMPT GROUP 2 - Interval Partitioned (4 tables):
PROMPT   4. TRANSACTIONS     (INTERVAL-MONTH, for adding hash subpartitions)
PROMPT   5. AUDIT_LOG        (INTERVAL-DAY, for reconfiguration to HOUR)
PROMPT   6. EVENTS           (non-partitioned, for HOUR interval testing)
PROMPT   7. CUSTOMER_DATA    (non-partitioned with 3 LOBs)
PROMPT
PROMPT Sequences Created: 7
PROMPT Views Created: 3 (v_partition_summary, v_table_sizes, v_table_summary)
PROMPT
PROMPT Access:
PROMPT   - Owner: HR (full control)
PROMPT   - HR_APP role: SELECT, INSERT, UPDATE, DELETE on all tables
PROMPT   - HR_APP_USER: Can access via HR.TABLE_NAME
PROMPT
PROMPT Next: Run 04_generate_test_data.sql to populate tables
PROMPT ========================================================================

EXIT;
