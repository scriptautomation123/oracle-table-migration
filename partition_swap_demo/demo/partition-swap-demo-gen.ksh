#!/bin/ksh
# ============================================================================
# Partition Swap Demo Generator
# ============================================================================
# Purpose: Demonstrate Oracle partition swapping (Active → Staging → History)
# Team: Java developers + Application DBAs + DevOps
# Requirements: Standard user privileges, no elevated access needed
# ============================================================================

set -e

# ============================================================================
# Configuration
# ============================================================================

DB_USER="${DB_USER:-hr}"
DB_PASS="${DB_PASS:-hr123}"
DB_CONNECT="${DB_CONNECT:-localhost:1521/FREEPDB1}"

LOG_FILE="partition_swap_demo_$(date +%Y%m%d_%H%M%S).log"

# ============================================================================
# Helper Functions (ksh)
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

run_sql() {
    local sql_file=$1
    log "Executing: ${sql_file}"
    
    sqlplus -S "${DB_USER}/${DB_PASS}@${DB_CONNECT}" <<EOF 2>&1 | tee -a "${LOG_FILE}"
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
@${sql_file}
EXIT;
EOF
    
    if [ $? -ne 0 ]; then
        error_exit "SQL execution failed: ${sql_file}"
    fi
}

# ============================================================================
# Main Workflow
# ============================================================================

log "=========================================="
log "Partition Swap Demo - Setup"
log "=========================================="
log "Connection: ${DB_USER}@${DB_CONNECT}"
log "Log file: ${LOG_FILE}"

# Step 1: Create tables and load data (SQL)
log ""
log "Step 1: Creating tables..."
cat > /tmp/setup_tables.sql <<'EOSQL'
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

-- Create ACTIVE table
CREATE TABLE active_transactions (
    transaction_id   NUMBER(12) NOT NULL,
    customer_id      NUMBER(10) NOT NULL,
    transaction_ts   TIMESTAMP NOT NULL,
    amount           NUMBER(12,2) NOT NULL,
    CONSTRAINT pk_active PRIMARY KEY (transaction_id, transaction_ts)
)
PARTITION BY RANGE (transaction_ts)
INTERVAL (NUMTODSINTERVAL(1, 'HOUR'))
(PARTITION p_init VALUES LESS THAN (TIMESTAMP '2024-01-01 00:00:00'))
ENABLE ROW MOVEMENT;

CREATE INDEX idx_active_cust ON active_transactions(customer_id) LOCAL;

-- Create STAGING table (non-partitioned, exact structure match)
CREATE TABLE staging_transactions (
    transaction_id   NUMBER(12) NOT NULL,
    customer_id      NUMBER(10) NOT NULL,
    transaction_ts   TIMESTAMP NOT NULL,
    amount           NUMBER(12,2) NOT NULL,
    CONSTRAINT pk_staging PRIMARY KEY (transaction_id, transaction_ts)
);

CREATE INDEX idx_staging_cust ON staging_transactions(customer_id);

-- Create HISTORY table
CREATE TABLE history_transactions (
    transaction_id   NUMBER(12) NOT NULL,
    customer_id      NUMBER(10) NOT NULL,
    transaction_ts   TIMESTAMP NOT NULL,
    amount           NUMBER(12,2) NOT NULL,
    archived_ts      TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_history PRIMARY KEY (transaction_id, transaction_ts)
)
PARTITION BY RANGE (transaction_ts)
INTERVAL (NUMTODSINTERVAL(1, 'HOUR'))
(PARTITION p_hist_init VALUES LESS THAN (TIMESTAMP '2024-01-01 00:00:00'))
ENABLE ROW MOVEMENT;

CREATE INDEX idx_history_cust ON history_transactions(customer_id) LOCAL;

PROMPT Tables created successfully
EXIT;
EOSQL

run_sql /tmp/setup_tables.sql

# Step 2: Load test data (PL/SQL)
log ""
log "Step 2: Loading test data..."
cat > /tmp/load_data.sql <<'EOSQL'
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

DECLARE
    v_base_ts TIMESTAMP := SYSTIMESTAMP - INTERVAL '48' HOUR;
    v_count NUMBER := 0;
BEGIN
    -- Load 4800 rows (48 hours × 100 rows/hour)
    FOR hr IN 0..47 LOOP
        FOR i IN 1..100 LOOP
            v_count := v_count + 1;
            INSERT INTO active_transactions VALUES (
                v_count,
                MOD(v_count, 50) + 1,
                v_base_ts + NUMTODSINTERVAL(hr, 'HOUR') + NUMTODSINTERVAL(i, 'MINUTE'),
                ROUND(DBMS_RANDOM.VALUE(10, 1000), 2)
            );
        END LOOP;
        
        IF MOD(hr, 10) = 0 THEN
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('Loaded ' || v_count || ' rows...');
        END IF;
    END LOOP;
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Total loaded: ' || v_count || ' rows');
    
    -- Gather stats
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'ACTIVE_TRANSACTIONS', cascade => TRUE);
END;
/

EXIT;
EOSQL

run_sql /tmp/load_data.sql

# Step 3: Show initial state (SQL query)
log ""
log "Step 3: Initial state..."
sqlplus -S "${DB_USER}/${DB_PASS}@${DB_CONNECT}" <<'EOSQL'
SET PAGESIZE 50
SET LINESIZE 120
COLUMN table_name FORMAT A20
COLUMN partition_count FORMAT 999
COLUMN row_count FORMAT 999,999

SELECT 'ACTIVE' as table_name, COUNT(*) as partition_count
FROM all_tab_partitions 
WHERE table_owner = USER AND table_name = 'ACTIVE_TRANSACTIONS'
UNION ALL
SELECT 'HISTORY', COUNT(*)
FROM all_tab_partitions 
WHERE table_owner = USER AND table_name = 'HISTORY_TRANSACTIONS';

SELECT 'ACTIVE' as table_name, COUNT(*) as row_count FROM active_transactions
UNION ALL
SELECT 'STAGING', COUNT(*) FROM staging_transactions
UNION ALL
SELECT 'HISTORY', COUNT(*) FROM history_transactions;
EXIT;
EOSQL

# Step 4: Install partition swap package (PL/SQL)
log ""
log "Step 4: Installing partition swap package..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
sqlplus -S "${DB_USER}/${DB_PASS}@${DB_CONNECT}" <<EOSQL 2>&1 | tee -a "${LOG_FILE}"
WHENEVER SQLERROR EXIT SQL.SQLCODE
@${SCRIPT_DIR}/partition_swap_pkg.sql
EXIT;
EOSQL

if [ $? -ne 0 ]; then
    error_exit "Failed to install partition swap package"
fi

# Step 5: Execute partition swap using package
log ""
log "Step 5: Executing partition swap..."
cat > /tmp/swap_partitions.sql <<'EOSQL'
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

BEGIN
    partition_swap_pkg.swap_oldest_partition(
        p_active_table   => 'ACTIVE_TRANSACTIONS',
        p_staging_table  => 'STAGING_TRANSACTIONS',
        p_history_table  => 'HISTORY_TRANSACTIONS'
    );
END;
/

EXIT;
EOSQL

run_sql /tmp/swap_partitions.sql

# Step 6: Show final state (SQL query)
log ""
log "Step 5: Final state..."
sqlplus -S "${DB_USER}/${DB_PASS}@${DB_CONNECT}" <<'EOSQL'
SET PAGESIZE 50
SET LINESIZE 120
COLUMN table_name FORMAT A20
COLUMN row_count FORMAT 999,999

SELECT 'ACTIVE' as table_name, COUNT(*) as row_count FROM active_transactions
UNION ALL
SELECT 'STAGING', COUNT(*) FROM staging_transactions
UNION ALL  
SELECT 'HISTORY', COUNT(*) FROM history_transactions;

SELECT 'ACTIVE' as table_name, COUNT(*) as partition_count
FROM all_tab_partitions 
WHERE table_owner = USER AND table_name = 'ACTIVE_TRANSACTIONS'
UNION ALL
SELECT 'HISTORY', COUNT(*)
FROM all_tab_partitions 
WHERE table_owner = USER AND table_name = 'HISTORY_TRANSACTIONS';
EXIT;
EOSQL

# Cleanup temp files
rm -f /tmp/setup_tables.sql /tmp/load_data.sql /tmp/install_package.sql /tmp/swap_partitions.sql

log ""
log "=========================================="
log "Demo Complete!"
log "=========================================="
log "Results:"
log "  - One partition moved from ACTIVE to HISTORY"
log "  - No data physically copied (metadata swap)"
log "  - All indexes maintained automatically"
log "  - Staging table empty and ready for next swap"
log ""
log "Full log: ${LOG_FILE}"
