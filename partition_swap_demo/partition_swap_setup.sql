-- ============================================================================
-- Oracle 19c Partition Swap Demo: Active → Staging → History
-- ============================================================================
-- Architecture:
--   ACTIVE_TRANSACTIONS: Range partitioned by HOUR (current data)
--   STAGING_TRANSACTIONS: Non-partitioned (temporary swap target)
--   HISTORY_TRANSACTIONS: Range partitioned by HOUR (archived data)
--
-- Workflow:
--   1. Active table accumulates hourly data
--   2. Swap oldest partition from ACTIVE → STAGING
--   3. Swap partition from STAGING → HISTORY
--   4. Result: Data moved from ACTIVE to HISTORY atomically
-- ============================================================================

SET ECHO ON
SET SERVEROUTPUT ON
SET TIMING ON

PROMPT ========================================
PROMPT Creating ACTIVE_TRANSACTIONS Table
PROMPT ========================================

-- Active table: Range partitioned by HOUR
CREATE TABLE active_transactions (
    transaction_id   NUMBER(12) NOT NULL,
    customer_id      NUMBER(10) NOT NULL,
    transaction_ts   TIMESTAMP NOT NULL,
    amount           NUMBER(12,2) NOT NULL,
    transaction_type VARCHAR2(20) NOT NULL,
    status           VARCHAR2(20) DEFAULT 'PENDING',
    created_date     TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_active_txn PRIMARY KEY (transaction_id, transaction_ts)
)
PARTITION BY RANGE (transaction_ts)
INTERVAL (NUMTODSINTERVAL(1, 'HOUR'))
(
    -- Initial partition: Start from 24 hours ago
    PARTITION p_initial VALUES LESS THAN (TIMESTAMP '2024-01-01 00:00:00')
)
ENABLE ROW MOVEMENT
TABLESPACE users;

-- Local indexes on active table
CREATE INDEX idx_active_customer 
    ON active_transactions(customer_id) 
    LOCAL TABLESPACE users;

CREATE INDEX idx_active_type 
    ON active_transactions(transaction_type) 
    LOCAL TABLESPACE users;

CREATE INDEX idx_active_status 
    ON active_transactions(status) 
    LOCAL TABLESPACE users;

PROMPT ✓ Active table created with 3 local indexes

PROMPT ========================================
PROMPT Creating STAGING_TRANSACTIONS Table
PROMPT ========================================

-- Staging: Non-partitioned, must match ACTIVE structure exactly
CREATE TABLE staging_transactions (
    transaction_id   NUMBER(12) NOT NULL,
    customer_id      NUMBER(10) NOT NULL,
    transaction_ts   TIMESTAMP NOT NULL,
    amount           NUMBER(12,2) NOT NULL,
    transaction_type VARCHAR2(20) NOT NULL,
    status           VARCHAR2(20) DEFAULT 'PENDING',
    created_date     TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_staging_txn PRIMARY KEY (transaction_id, transaction_ts)
)
TABLESPACE users;

-- Local indexes on staging (will become local after swap)
CREATE INDEX idx_staging_customer 
    ON staging_transactions(customer_id) 
    TABLESPACE users;

CREATE INDEX idx_staging_type 
    ON staging_transactions(transaction_type) 
    TABLESPACE users;

CREATE INDEX idx_staging_status 
    ON staging_transactions(status) 
    TABLESPACE users;

PROMPT ✓ Staging table created (non-partitioned)

PROMPT ========================================
PROMPT Creating HISTORY_TRANSACTIONS Table
PROMPT ========================================

-- History: Range partitioned by HOUR (same as ACTIVE)
CREATE TABLE history_transactions (
    transaction_id   NUMBER(12) NOT NULL,
    customer_id      NUMBER(10) NOT NULL,
    transaction_ts   TIMESTAMP NOT NULL,
    amount           NUMBER(12,2) NOT NULL,
    transaction_type VARCHAR2(20) NOT NULL,
    status           VARCHAR2(20) DEFAULT 'PENDING',
    created_date     TIMESTAMP DEFAULT SYSTIMESTAMP,
    archived_date    TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_history_txn PRIMARY KEY (transaction_id, transaction_ts)
)
PARTITION BY RANGE (transaction_ts)
INTERVAL (NUMTODSINTERVAL(1, 'HOUR'))
(
    -- Initial partition: Archive storage
    PARTITION p_history_initial VALUES LESS THAN (TIMESTAMP '2024-01-01 00:00:00')
)
ENABLE ROW MOVEMENT
TABLESPACE users;

-- Local indexes on history table
CREATE INDEX idx_history_customer 
    ON history_transactions(customer_id) 
    LOCAL TABLESPACE users;

CREATE INDEX idx_history_type 
    ON history_transactions(transaction_type) 
    LOCAL TABLESPACE users;

CREATE INDEX idx_history_status 
    ON history_transactions(status) 
    LOCAL TABLESPACE users;

PROMPT ✓ History table created with 3 local indexes

PROMPT ========================================
PROMPT Loading Test Data into ACTIVE
PROMPT ========================================

-- Load data spanning 48 hours (will create 48 hourly partitions)
DECLARE
    v_base_ts TIMESTAMP := SYSTIMESTAMP - INTERVAL '48' HOUR;
    v_txn_id NUMBER := 1;
BEGIN
    -- Generate 10,000 transactions across 48 hours
    FOR hour_offset IN 0..47 LOOP
        FOR txn_in_hour IN 1..200 LOOP
            INSERT INTO active_transactions (
                transaction_id,
                customer_id,
                transaction_ts,
                amount,
                transaction_type,
                status
            ) VALUES (
                v_txn_id,
                MOD(v_txn_id, 100) + 1,
                v_base_ts + INTERVAL '1' HOUR * hour_offset + INTERVAL '1' MINUTE * txn_in_hour,
                ROUND(DBMS_RANDOM.VALUE(10, 5000), 2),
                CASE MOD(v_txn_id, 3)
                    WHEN 0 THEN 'PURCHASE'
                    WHEN 1 THEN 'REFUND'
                    ELSE 'TRANSFER'
                END,
                CASE MOD(v_txn_id, 5)
                    WHEN 0 THEN 'COMPLETED'
                    WHEN 1 THEN 'PENDING'
                    ELSE 'PROCESSING'
                END
            );
            v_txn_id := v_txn_id + 1;
        END LOOP;
        
        IF MOD(hour_offset, 10) = 0 THEN
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('Loaded hour ' || hour_offset || ' (' || v_txn_id || ' transactions)');
        END IF;
    END LOOP;
    COMMIT;
END;
/

PROMPT ✓ Test data loaded (9,600 transactions across 48 hours)

PROMPT ========================================
PROMPT Gathering Statistics
PROMPT ========================================

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => USER,
        tabname => 'ACTIVE_TRANSACTIONS',
        cascade => TRUE
    );
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => USER,
        tabname => 'STAGING_TRANSACTIONS',
        cascade => TRUE
    );
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => USER,
        tabname => 'HISTORY_TRANSACTIONS',
        cascade => TRUE
    );
END;
/

PROMPT ✓ Statistics gathered

PROMPT ========================================
PROMPT Initial State Summary
PROMPT ========================================

-- Show partition counts
SELECT 'ACTIVE' as table_name, COUNT(*) as partition_count
FROM user_tab_partitions
WHERE table_name = 'ACTIVE_TRANSACTIONS'
UNION ALL
SELECT 'HISTORY', COUNT(*)
FROM user_tab_partitions
WHERE table_name = 'HISTORY_TRANSACTIONS';

-- Show row counts
SELECT 'ACTIVE' as table_name, COUNT(*) as row_count
FROM active_transactions
UNION ALL
SELECT 'STAGING', COUNT(*)
FROM staging_transactions
UNION ALL
SELECT 'HISTORY', COUNT(*)
FROM history_transactions;

-- Show partition distribution
SELECT 
    table_name,
    partition_name,
    high_value,
    num_rows,
    blocks
FROM user_tab_partitions
WHERE table_name IN ('ACTIVE_TRANSACTIONS', 'HISTORY_TRANSACTIONS')
ORDER BY table_name, partition_position;

PROMPT ========================================
PROMPT Setup Complete!
PROMPT ========================================
PROMPT
PROMPT Next Steps:
PROMPT   1. Review partition structure
PROMPT   2. Run partition_swap_demo.sql to see swap in action
PROMPT   3. Verify data moved from ACTIVE → HISTORY
PROMPT
PROMPT Tables Created:
PROMPT   - ACTIVE_TRANSACTIONS (48 hourly partitions, ~9,600 rows)
PROMPT   - STAGING_TRANSACTIONS (empty, non-partitioned)
PROMPT   - HISTORY_TRANSACTIONS (1 partition, empty)
PROMPT
PROMPT Each table has 3 local indexes:
PROMPT   - idx_*_customer
PROMPT   - idx_*_type
PROMPT   - idx_*_status
PROMPT ========================================
