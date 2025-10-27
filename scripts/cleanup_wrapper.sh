#!/bin/bash
# ==================================================================
# Wrapper for comprehensive_oracle_ddl.sql
# ==================================================================
# 1. Checks if schema exists
# 2. For each table: check existence and evaluate tablespace capacity
# 3. Default action: BACKUP (rename to _OLD)
# 4. Optional: Explicit DROP flag to drop instead of rename
# 5. Validates tablespace has capacity for rename (existing + new < 80% TBS)
# 6. Only proceeds to DDL creation if all tables handled successfully
# ==================================================================

SCHEMA_USER="${SCHEMA_USER:-APP_DATA_OWNER}"
SCHEMA_PASS="${SCHEMA_PASS:-your_password}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-1521}"
DB_SERVICE="${DB_SERVICE:-ORCLPDB1}"
DB_CONNECTION="//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"

# Action flag: "backup" (default) or "drop" (explicit)
ACTION="${ACTION:-backup}"

# Tablespace usage threshold (80%)
TBS_THRESHOLD=80

# ==================================================================
# Helper Functions
# ==================================================================

# Check if schema exists and has tables
check_schema() {
    local result=$(sqlplus -S "${SCHEMA_USER}/${SCHEMA_PASS}@${DB_CONNECTION}" <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 VERIFY OFF
SELECT 'SCHEMA_EXISTS:' || COUNT(*) FROM dual WHERE USER = UPPER('${SCHEMA_USER}');
SELECT 'TABLE_COUNT:' || COUNT(*) FROM user_tables;
EXIT
EOF
)
    
    local schema_exists=$(echo "$result" | grep "SCHEMA_EXISTS:" | cut -d: -f2 | tr -d ' ')
    local table_count=$(echo "$result" | grep "TABLE_COUNT:" | cut -d: -f2 | tr -d ' ')
    
    if [[ "$schema_exists" != "1" ]]; then
        echo "ERROR: Schema ${SCHEMA_USER} does not exist or cannot be accessed"
        return 1
    fi
    
    echo "✓ Schema ${SCHEMA_USER} exists with ${table_count} table(s)"
    return 0
}

# Check if specific table exists
check_table_exists() {
    local table_name=$1
    local result=$(sqlplus -S "${SCHEMA_USER}/${SCHEMA_PASS}@${DB_CONNECTION}" <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 VERIFY OFF
SELECT COUNT(*) FROM user_tables WHERE table_name = UPPER('${table_name}');
EXIT
EOF
)
    
    result=$(echo "$result" | tr -d ' \n')
    [[ "$result" == "1" ]]
}

# Get table size in MB and tablespace usage
evaluate_tablespace_capacity() {
    local table_name=$1
    
    local result=$(sqlplus -S "${SCHEMA_USER}/${SCHEMA_PASS}@${DB_CONNECTION}" <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 VERIFY OFF LINESIZE 200
SELECT 
    'TABLE_SIZE_MB:' || ROUND(SUM(bytes)/1024/1024, 2) || 
    '|TABLESPACE:' || tablespace_name ||
    '|TBS_TOTAL_MB:' || ROUND(MAX(total_bytes)/1024/1024, 2) ||
    '|TBS_USED_MB:' || ROUND(MAX(used_bytes)/1024/1024, 2) ||
    '|TBS_PCT_USED:' || ROUND((MAX(used_bytes)/MAX(total_bytes))*100, 2)
FROM (
    SELECT s.bytes, s.tablespace_name,
           (SELECT SUM(bytes) FROM dba_data_files WHERE tablespace_name = s.tablespace_name) AS total_bytes,
           (SELECT SUM(bytes) FROM dba_segments WHERE tablespace_name = s.tablespace_name) AS used_bytes
    FROM dba_segments s
    WHERE s.segment_name = UPPER('${table_name}')
    AND s.owner = UPPER('${SCHEMA_USER}')
)
GROUP BY tablespace_name;
EXIT
EOF
)
    
    if [[ -z "$result" ]] || [[ "$result" == *"no rows selected"* ]]; then
        echo "TABLE_SIZE_MB:0|TABLESPACE:UNKNOWN|TBS_TOTAL_MB:0|TBS_USED_MB:0|TBS_PCT_USED:0"
        return
    fi
    
    echo "$result"
}

# Evaluate if rename is safe (won't exceed 80% tablespace)
can_rename_table() {
    local table_name=$1
    local eval_result=$(evaluate_tablespace_capacity "$table_name")
    
    local table_size=$(echo "$eval_result" | grep -oP 'TABLE_SIZE_MB:\K[0-9.]+')
    local tbs_name=$(echo "$eval_result" | grep -oP 'TABLESPACE:\K[A-Z0-9_]+')
    local tbs_total=$(echo "$eval_result" | grep -oP 'TBS_TOTAL_MB:\K[0-9.]+')
    local tbs_used=$(echo "$eval_result" | grep -oP 'TBS_USED_MB:\K[0-9.]+')
    local tbs_pct=$(echo "$eval_result" | grep -oP 'TBS_PCT_USED:\K[0-9.]+')
    
    # If table doesn't exist or is empty, safe to proceed
    if [[ -z "$table_size" ]] || [[ "$table_size" == "0" ]]; then
        echo "✓ Table ${table_name}: does not exist or empty (safe to proceed)"
        return 0
    fi
    
    # Calculate projected usage after rename (existing table stays, new table created)
    local projected_used=$(echo "$tbs_used + $table_size" | bc)
    local projected_pct=$(echo "scale=2; ($projected_used / $tbs_total) * 100" | bc)
    
    echo "Table ${table_name}: ${table_size}MB | Tablespace ${tbs_name}: ${tbs_pct}% used"
    echo "  Projected after rename: ${projected_pct}% used (${projected_used}MB / ${tbs_total}MB)"
    
    # Check if projected usage exceeds threshold
    if (( $(echo "$projected_pct > $TBS_THRESHOLD" | bc -l) )); then
        echo "  ✗ FAIL: Would exceed ${TBS_THRESHOLD}% threshold"
        return 1
    else
        echo "  ✓ PASS: Within ${TBS_THRESHOLD}% threshold"
        return 0
    fi
}

# ==================================================================
# Main Functions
# ==================================================================

# Process all tables with evaluation and cleanup
process_tables() {
    local tables=(TRANSACTION_LOG ORDER_DETAILS AUDIT_LOG USER_SESSIONS CUSTOMER_REGIONS \
                  SALES_HISTORY PRODUCTS CUSTOMERS SALES_REPS REGIONS)
    local failed_tables=()
    local processed_tables=()
    
    echo "==========================================================="
    echo "Step 1: Schema Validation"
    echo "==========================================================="
    check_schema || exit 1
    
    echo ""
    echo "==========================================================="
    echo "Step 2: Table Evaluation (Action: ${ACTION})"
    echo "==========================================================="
    
    # Evaluate each table
    for table in "${tables[@]}"; do
        echo ""
        echo "--- Evaluating: ${table} ---"
        
        if ! check_table_exists "$table"; then
            echo "✓ Table ${table}: does not exist (safe to create)"
            processed_tables+=("$table:skip")
            continue
        fi
        
        if [[ "$ACTION" == "drop" ]]; then
            echo "Action: DROP (explicit)"
            processed_tables+=("$table:drop")
        else
            echo "Action: BACKUP (rename to _OLD)"
            if can_rename_table "$table"; then
                processed_tables+=("$table:backup")
            else
                echo "✗ Cannot safely rename ${table} - insufficient tablespace"
                failed_tables+=("$table")
            fi
        fi
    done
    
    # Check if any tables failed evaluation
    if [[ ${#failed_tables[@]} -gt 0 ]]; then
        echo ""
        echo "==========================================================="
        echo "ERROR: Tablespace Capacity Check Failed"
        echo "==========================================================="
        echo "The following tables cannot be renamed (would exceed ${TBS_THRESHOLD}% tablespace usage):"
        for table in "${failed_tables[@]}"; do
            echo "  - ${table}"
        done
        echo ""
        echo "Options:"
        echo "  1. Run with ACTION=drop to explicitly drop tables instead of rename:"
        echo "     ACTION=drop $0 rebuild"
        echo "  2. Free up tablespace by dropping old backups (_OLD, _OLD1, etc.)"
        echo "  3. Extend tablespace capacity"
        exit 1
    fi
    
    echo ""
    echo "==========================================================="
    echo "Step 3: Execute Cleanup"
    echo "==========================================================="
    
    # Execute cleanup for each table
    for entry in "${processed_tables[@]}"; do
        local table="${entry%%:*}"
        local action="${entry##*:}"
        
        case "$action" in
            skip)
                echo "Skipping: ${table} (does not exist)"
                ;;
            drop)
                echo "Dropping: ${table}"
                echo "D" | sqlplus -S "${SCHEMA_USER}/${SCHEMA_PASS}@${DB_CONNECTION}" @cleanup_tables.sql "$table"
                ;;
            backup)
                echo "Backing up: ${table} → ${table}_OLD"
                echo "B" | sqlplus -S "${SCHEMA_USER}/${SCHEMA_PASS}@${DB_CONNECTION}" @cleanup_tables.sql "$table"
                ;;
        esac
    done
    
    echo ""
    echo "✓ All tables processed successfully"
}

# Rebuild entire test schema
rebuild_schema() {
    process_tables
    
    echo ""
    echo "==========================================================="
    echo "Step 4: Create and Load Schema"
    echo "==========================================================="
    
    # Pass SCHEMA_USER to SQL script for dynamic schema setting
    sqlplus "${SCHEMA_USER}/${SCHEMA_PASS}@${DB_CONNECTION}" <<EOF
DEFINE SCHEMA_USER=${SCHEMA_USER}
@comprehensive_oracle_ddl.sql
EXIT
EOF
    
    echo ""
    echo "==========================================================="
    echo "✓ Schema rebuild complete"
    echo "==========================================================="
}

# ==================================================================
# Main execution
# ==================================================================

case "${1:-help}" in
    rebuild)
        rebuild_schema
        ;;
    *)
        echo "Usage: $0 rebuild"
        echo ""
        echo "Description:"
        echo "  Comprehensive wrapper for rebuilding test schema"
        echo ""
        echo "Process:"
        echo "  1. Validate schema exists"
        echo "  2. Evaluate each table (existence + tablespace capacity)"
        echo "  3. Default: BACKUP (rename to _OLD) if space permits"
        echo "  4. Execute cleanup (drop or backup based on evaluation)"
        echo "  5. Create and load new schema via comprehensive_oracle_ddl.sql"
        echo ""
        echo "Environment Variables:"
        echo "  SCHEMA_USER     - Database user (default: APP_DATA_OWNER)"
        echo "  SCHEMA_PASS     - Database password (required)"
        echo "  DB_HOST         - Database host (default: localhost)"
        echo "  DB_PORT         - Database port (default: 1521)"
        echo "  DB_SERVICE      - Database service name (default: ORCLPDB1)"
        echo "  ACTION          - Cleanup action: 'backup' (default) or 'drop' (explicit)"
        echo "  TBS_THRESHOLD   - Max tablespace % before failing (default: 80)"
        echo ""
        echo "Examples:"
        echo "  # Default: backup existing tables to _OLD (if space permits)"
        echo "  SCHEMA_PASS=mypass $0 rebuild"
        echo ""
        echo "  # Explicit drop (no backup)"
        echo "  ACTION=drop SCHEMA_PASS=mypass $0 rebuild"
        echo ""
        echo "  # Custom database and threshold"
        echo "  SCHEMA_PASS=mypass DB_SERVICE=XEPDB1 TBS_THRESHOLD=75 $0 rebuild"
        exit 1
        ;;
esac
