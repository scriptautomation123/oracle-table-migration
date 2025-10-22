-- ============================================================================
-- Generate Test Data for Migration Framework Testing
-- ============================================================================
-- Purpose: Populate HR tables with realistic test data
-- Run as: HR schema
-- Note: All tables owned by HR, accessible via HR_APP role granted to HR_APP_USER
-- ============================================================================

SET ECHO ON
SET SERVEROUTPUT ON
SET TIMING ON

PROMPT ========================================================================
PROMPT Generating Test Data for HR Schema
PROMPT ========================================================================

-- Connect as HR (table owner)
CONNECT hr/hr123@XEPDB1

-- ============================================================================
-- GROUP 1: Non-Partitioned Tables (for interval conversion testing)
-- ============================================================================

-- ============================================================================
-- DEPARTMENTS (50 rows) - reference dimension table
-- ============================================================================

PROMPT Populating HR.DEPARTMENTS (50 rows)...

INSERT ALL
    INTO departments VALUES (10, 'Administration', 200, 1700, SYSDATE-1000)
    INTO departments VALUES (20, 'Marketing', 201, 1800, SYSDATE-950)
    INTO departments VALUES (30, 'Purchasing', 114, 1700, SYSDATE-900)
    INTO departments VALUES (40, 'Human Resources', 203, 2400, SYSDATE-850)
    INTO departments VALUES (50, 'Shipping', 121, 1500, SYSDATE-800)
    INTO departments VALUES (60, 'IT', 103, 1400, SYSDATE-750)
    INTO departments VALUES (70, 'Public Relations', 204, 2700, SYSDATE-700)
    INTO departments VALUES (80, 'Sales', 145, 2500, SYSDATE-650)
    INTO departments VALUES (90, 'Executive', 100, 1700, SYSDATE-600)
    INTO departments VALUES (100, 'Finance', 108, 1700, SYSDATE-550)
SELECT 1 FROM DUAL;

-- Generate more departments
INSERT INTO departments
SELECT 
    100 + ROWNUM * 10,
    'Department ' || (100 + ROWNUM * 10),
    NULL,
    TRUNC(DBMS_RANDOM.VALUE(1000, 3000)),
    SYSDATE - TRUNC(DBMS_RANDOM.VALUE(100, 1000))
FROM dual
CONNECT BY ROWNUM <= 40;

COMMIT;

PROMPT ✓ 50 departments created

-- ============================================================================
-- HR Schema: EMPLOYEES (5,000 rows)
-- ============================================================================

PROMPT Populating HR.EMPLOYEES (5,000 rows)...

DECLARE
    v_first_names DBMS_SQL.VARCHAR2_TABLE;
    v_last_names DBMS_SQL.VARCHAR2_TABLE;
    v_jobs DBMS_SQL.VARCHAR2_TABLE;
BEGIN
    -- Sample data arrays
    v_first_names(1) := 'John'; v_first_names(2) := 'Jane'; v_first_names(3) := 'Michael';
    v_first_names(4) := 'Sarah'; v_first_names(5) := 'David'; v_first_names(6) := 'Lisa';
    v_first_names(7) := 'Robert'; v_first_names(8) := 'Jennifer'; v_first_names(9) := 'William';
    v_first_names(10) := 'Mary';
    
    v_last_names(1) := 'Smith'; v_last_names(2) := 'Johnson'; v_last_names(3) := 'Williams';
    v_last_names(4) := 'Brown'; v_last_names(5) := 'Jones'; v_last_names(6) := 'Garcia';
    v_last_names(7) := 'Miller'; v_last_names(8) := 'Davis'; v_last_names(9) := 'Rodriguez';
    v_last_names(10) := 'Martinez';
    
    v_jobs(1) := 'IT_PROG'; v_jobs(2) := 'SA_REP'; v_jobs(3) := 'ST_CLERK';
    v_jobs(4) := 'FI_ACCOUNT'; v_jobs(5) := 'MK_REP'; v_jobs(6) := 'HR_REP';
    v_jobs(7) := 'PU_CLERK'; v_jobs(8) := 'SH_CLERK'; v_jobs(9) := 'AD_ASST';
    v_jobs(10) := 'PR_REP';
    
    FOR i IN 1..5000 LOOP
        INSERT INTO employees (
            employee_id, first_name, last_name, email, phone_number,
            hire_date, job_id, salary, commission_pct, manager_id, department_id,
            created_date, updated_date
        ) VALUES (
            i,
            v_first_names(MOD(i, 10) + 1),
            v_last_names(MOD(i, 10) + 1) || '_' || i,
            LOWER(v_first_names(MOD(i, 10) + 1)) || '.' || 
            LOWER(v_last_names(MOD(i, 10) + 1)) || i || '@company.com',
            '+1-555-' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1000000, 9999999)), 7, '0'),
            SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 3650)), -- Random hire date within last 10 years
            v_jobs(MOD(i, 10) + 1),
            TRUNC(DBMS_RANDOM.VALUE(30000, 150000), -2),
            CASE WHEN MOD(i, 5) = 0 THEN TRUNC(DBMS_RANDOM.VALUE(1, 30), 2) / 100 ELSE NULL END,
            CASE WHEN i > 100 THEN TRUNC(DBMS_RANDOM.VALUE(1, i-1)) ELSE NULL END,
            (MOD(i, 10) + 1) * 10,
            SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 365)),
            SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 30))
        );
        
        IF MOD(i, 1000) = 0 THEN
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('  ' || i || ' employees inserted...');
        END IF;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ 5,000 employees created');
END;
/

-- ============================================================================
-- HR Schema: ORDERS (50,000 rows)
-- ============================================================================

PROMPT Populating HR.ORDERS (50,000 rows)...

DECLARE
    v_statuses DBMS_SQL.VARCHAR2_TABLE;
BEGIN
    v_statuses(1) := 'PENDING';
    v_statuses(2) := 'PROCESSING';
    v_statuses(3) := 'SHIPPED';
    v_statuses(4) := 'DELIVERED';
    v_statuses(5) := 'CANCELLED';
    
    FOR i IN 1..50000 LOOP
        INSERT INTO orders (
            order_id, customer_id, employee_id, order_date, shipped_date,
            ship_via, freight, status, total_amount, notes,
            created_date, updated_date
        ) VALUES (
            i,
            TRUNC(DBMS_RANDOM.VALUE(1, 10000)),
            TRUNC(DBMS_RANDOM.VALUE(1, 5000)),
            SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 1095)), -- Random date within last 3 years
            CASE WHEN MOD(i, 5) != 0 THEN SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 1000)) ELSE NULL END,
            'Carrier_' || MOD(i, 5),
            TRUNC(DBMS_RANDOM.VALUE(10, 500), 2),
            v_statuses(MOD(i, 5) + 1),
            TRUNC(DBMS_RANDOM.VALUE(100, 50000), 2),
            CASE WHEN MOD(i, 10) = 0 THEN 'Special handling required' ELSE NULL END,
            SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 1095)),
            SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 30))
        );
        
        IF MOD(i, 5000) = 0 THEN
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('  ' || i || ' orders inserted...');
        END IF;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ 50,000 orders created');
END;
/

-- Gather statistics
EXEC DBMS_STATS.GATHER_TABLE_STATS('HR', 'DEPARTMENTS');
EXEC DBMS_STATS.GATHER_TABLE_STATS('HR', 'EMPLOYEES');
EXEC DBMS_STATS.GATHER_TABLE_STATS('HR', 'ORDERS');

-- ============================================================================
-- GROUP 2: Interval-Partitioned Tables (for interval-hash conversion testing)
-- ============================================================================

-- ============================================================================
-- TRANSACTIONS (500,000 rows across multiple MONTH partitions)
-- ============================================================================

PROMPT Populating HR.TRANSACTIONS (500,000 rows)...

DECLARE
    v_txn_types DBMS_SQL.VARCHAR2_TABLE;
    v_statuses DBMS_SQL.VARCHAR2_TABLE;
    v_base_date DATE := TO_DATE('2022-01-01', 'YYYY-MM-DD');
BEGIN
    v_txn_types(1) := 'DEPOSIT';
    v_txn_types(2) := 'WITHDRAWAL';
    v_txn_types(3) := 'TRANSFER';
    v_txn_types(4) := 'PAYMENT';
    v_txn_types(5) := 'FEE';
    
    v_statuses(1) := 'COMPLETED';
    v_statuses(2) := 'PENDING';
    v_statuses(3) := 'FAILED';
    v_statuses(4) := 'REVERSED';
    
    FOR i IN 1..500000 LOOP
        INSERT INTO transactions (
            transaction_id, account_id, txn_date, txn_type, amount,
            balance, description, status, created_date
        ) VALUES (
            i,
            TRUNC(DBMS_RANDOM.VALUE(1000, 50000)),
            v_base_date + TRUNC(DBMS_RANDOM.VALUE(1, 1095)), -- Spread over 3 years
            v_txn_types(MOD(i, 5) + 1),
            TRUNC(DBMS_RANDOM.VALUE(-10000, 50000), 2),
            TRUNC(DBMS_RANDOM.VALUE(100, 500000), 2),
            'Transaction ' || i || ' - ' || v_txn_types(MOD(i, 5) + 1),
            v_statuses(CASE WHEN MOD(i, 20) = 0 THEN MOD(i, 4) + 1 ELSE 1 END),
            v_base_date + TRUNC(DBMS_RANDOM.VALUE(1, 1095))
        );
        
        IF MOD(i, 10000) = 0 THEN
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('  ' || i || ' transactions inserted...');
        END IF;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ 500,000 transactions created');
END;
/

-- ============================================================================
-- AUDIT_LOG (1,000,000 rows across multiple DAY partitions)
-- ============================================================================

PROMPT Populating HR.AUDIT_LOG (1,000,000 rows - this may take a few minutes)...

DECLARE
    v_actions DBMS_SQL.VARCHAR2_TABLE;
    v_tables DBMS_SQL.VARCHAR2_TABLE;
    v_base_date DATE := TO_DATE('2024-01-01', 'YYYY-MM-DD');
BEGIN
    v_actions(1) := 'INSERT';
    v_actions(2) := 'UPDATE';
    v_actions(3) := 'DELETE';
    v_actions(4) := 'SELECT';
    v_actions(5) := 'LOGIN';
    v_actions(6) := 'LOGOUT';
    
    v_tables(1) := 'EMPLOYEES';
    v_tables(2) := 'ORDERS';
    v_tables(3) := 'CUSTOMERS';
    v_tables(4) := 'TRANSACTIONS';
    
    FOR i IN 1..1000000 LOOP
        INSERT INTO audit_log (
            audit_id, user_id, audit_date, action_type, table_name,
            record_id, old_value, new_value, ip_address, session_id
        ) VALUES (
            i,
            TRUNC(DBMS_RANDOM.VALUE(1, 10000)),
            v_base_date + TRUNC(DBMS_RANDOM.VALUE(1, 300)) + (DBMS_RANDOM.VALUE(0, 86399)/86400), -- Random date+time over 300 days
            v_actions(MOD(i, 6) + 1),
            v_tables(MOD(i, 4) + 1),
            TRUNC(DBMS_RANDOM.VALUE(1, 100000)),
            CASE WHEN MOD(i, 3) = 0 THEN 'Old Value ' || i ELSE NULL END,
            CASE WHEN MOD(i, 3) = 0 THEN 'New Value ' || i ELSE NULL END,
            '192.168.' || TRUNC(DBMS_RANDOM.VALUE(1, 255)) || '.' || TRUNC(DBMS_RANDOM.VALUE(1, 255)),
            'SID_' || TRUNC(DBMS_RANDOM.VALUE(100000, 999999))
        );
        
        IF MOD(i, 25000) = 0 THEN
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('  ' || i || ' audit records inserted...');
        END IF;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ 1,000,000 audit records created');
END;
/

-- ============================================================================
-- EVENTS (100,000 rows) - non-partitioned for HOUR interval testing
-- ============================================================================

PROMPT Populating HR.EVENTS (100,000 rows)...

DECLARE
    v_event_types DBMS_SQL.VARCHAR2_TABLE;
    v_categories DBMS_SQL.VARCHAR2_TABLE;
    v_base_date DATE := SYSDATE - 90;
BEGIN
    v_event_types(1) := 'PAGE_VIEW';
    v_event_types(2) := 'BUTTON_CLICK';
    v_event_types(3) := 'FORM_SUBMIT';
    v_event_types(4) := 'API_CALL';
    v_event_types(5) := 'ERROR';
    v_event_types(6) := 'WARNING';
    
    v_categories(1) := 'NAVIGATION';
    v_categories(2) := 'USER_ACTION';
    v_categories(3) := 'SYSTEM';
    v_categories(4) := 'PERFORMANCE';
    
    FOR i IN 1..100000 LOOP
        INSERT INTO events (
            event_id, user_id, event_date, event_type, event_category,
            event_data, duration_ms, status_code, created_date
        ) VALUES (
            i,
            TRUNC(DBMS_RANDOM.VALUE(1, 5000)),
            v_base_date + (DBMS_RANDOM.VALUE(0, 90)) + (DBMS_RANDOM.VALUE(0, 86399)/86400), -- High frequency within 90 days
            v_event_types(MOD(i, 6) + 1),
            v_categories(MOD(i, 4) + 1),
            '{"key": "value_' || i || '", "timestamp": "' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || '"}',
            TRUNC(DBMS_RANDOM.VALUE(10, 5000)),
            CASE WHEN MOD(i, 20) = 0 THEN 500 ELSE 200 END,
            v_base_date + (DBMS_RANDOM.VALUE(0, 90))
        );
        
        IF MOD(i, 10000) = 0 THEN
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('  ' || i || ' events inserted...');
        END IF;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ 100,000 events created');
END;
/

-- ============================================================================
-- CUSTOMER_DATA (25,000 rows with LOBs) - non-partitioned with 3 LOB columns
-- ============================================================================

PROMPT Populating HR.CUSTOMER_DATA (25,000 rows with LOBs)...

DECLARE
    v_statuses DBMS_SQL.VARCHAR2_TABLE;
    v_notes CLOB;
    v_prefs CLOB;
BEGIN
    v_statuses(1) := 'ACTIVE';
    v_statuses(2) := 'INACTIVE';
    v_statuses(3) := 'SUSPENDED';
    v_statuses(4) := 'PENDING';
    
    FOR i IN 1..25000 LOOP
        -- Generate sample CLOB data
        v_notes := 'Customer notes for ID ' || i || '. ' || RPAD('Sample note content ', 500, 'x');
        v_prefs := '{"theme": "dark", "language": "en", "notifications": true, "id": ' || i || '}';
        
        INSERT INTO customer_data (
            customer_id, customer_name, email, phone, address,
            registration_date, account_status, notes, profile_photo, preferences,
            created_date, updated_date
        ) VALUES (
            i,
            'Customer_' || i || '_' || DBMS_RANDOM.STRING('U', 8),
            'customer' || i || '@test.com',
            '+1-555-' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1000000, 9999999)), 7, '0'),
            TRUNC(DBMS_RANDOM.VALUE(1, 9999)) || ' Main St, City ' || MOD(i, 100),
            SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 1825)), -- Random within last 5 years
            v_statuses(MOD(i, 4) + 1),
            v_notes,
            NULL, -- We'll skip actual BLOB data for performance
            v_prefs,
            SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 1825)),
            SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 30))
        );
        
        IF MOD(i, 2500) = 0 THEN
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('  ' || i || ' customers inserted...');
        END IF;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ 25,000 customers created (with 3 LOB columns each)');
END;
/

-- Gather statistics for all HR tables
EXEC DBMS_STATS.GATHER_TABLE_STATS('HR', 'TRANSACTIONS');
EXEC DBMS_STATS.GATHER_TABLE_STATS('HR', 'AUDIT_LOG');
EXEC DBMS_STATS.GATHER_TABLE_STATS('HR', 'EVENTS');
EXEC DBMS_STATS.GATHER_TABLE_STATS('HR', 'CUSTOMER_DATA');

PROMPT ========================================================================
PROMPT Test Data Generation Complete
PROMPT ========================================================================
PROMPT
PROMPT Data Summary (All in HR Schema):
PROMPT   Group 1 - Non-Partitioned Tables:
PROMPT     - DEPARTMENTS: 50 rows
PROMPT     - EMPLOYEES: 5,000 rows (test DAY interval + 4 hash on EMPLOYEE_ID)
PROMPT     - ORDERS: 50,000 rows (test DAY interval + 8 hash on ORDER_ID)
PROMPT
PROMPT   Group 2 - Interval-Partitioned Tables:
PROMPT     - TRANSACTIONS: 500,000 rows (MONTH interval → add 8 hash on TRANSACTION_ID)
PROMPT     - AUDIT_LOG: 1,000,000 rows (DAY interval → change to HOUR + hash on USER_ID)
PROMPT     - EVENTS: 100,000 rows (non-part → HOUR interval + 16 hash on USER_ID)
PROMPT     - CUSTOMER_DATA: 25,000 rows (non-part + 3 LOBs → MONTH interval + hash)
PROMPT
PROMPT Total Rows: 1,675,050
PROMPT
PROMPT Access:
PROMPT   - Table owner: HR (hr/hr123@oracle:1521/XEPDB1)
PROMPT   - Application user: HR_APP_USER (hr_app_user/hrapp123@oracle:1521/XEPDB1)
PROMPT     Note: HR_APP_USER has HR_APP role with SELECT/INSERT/UPDATE/DELETE on all HR objects
PROMPT
PROMPT Next: Test discovery with:
PROMPT   cd /workspace/table_migration/02_generator
PROMPT   python3 generate_scripts.py --discover --schema HR --connection "hr/hr123@oracle:1521/XEPDB1"
PROMPT ========================================================================

EXIT;
