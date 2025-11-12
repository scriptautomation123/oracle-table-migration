#!/bin/bash
# Test database initialization after docker-compose up

echo "========================================"
echo "Testing Oracle Database Initialization"
echo "========================================"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

# Wait for database to be healthy
echo ""
echo "Waiting for database to be healthy..."
while true; do
    COMPOSE_PS_OUTPUT=$(docker compose -f "${COMPOSE_FILE}" ps 2>&1)
    if echo "${COMPOSE_PS_OUTPUT}" | grep -q "healthy"; then
        break
    fi
    echo "  Still waiting..."
    sleep 5
done

echo "✓ Database is healthy!"

# Test connection and verify setup
echo ""
echo "Testing database setup..."
echo ""

docker compose -f "${COMPOSE_FILE}" exec -T oracle sqlplus -s hr/hr123@FREEPDB1 <<'EOF'
SET PAGESIZE 100
SET LINESIZE 120

PROMPT ========================================
PROMPT Table Row Counts
PROMPT ========================================

SELECT 
    RPAD(table_name, 30) as "TABLE NAME",
    LPAD(TO_CHAR(num_rows, '999,999'), 12) as "ROW COUNT",
    CASE 
        WHEN partitioned = 'YES' THEN 'Partitioned'
        ELSE 'Regular'
    END as "TYPE"
FROM user_tables
ORDER BY table_name;

PROMPT
PROMPT ========================================
PROMPT Partition Information
PROMPT ========================================

SELECT 
    RPAD(table_name, 30) as "TABLE NAME",
    RPAD(NVL(partitioning_type, 'N/A'), 15) as "PART TYPE",
    LPAD(TO_CHAR(partition_count, '999'), 8) as "PARTS",
    RPAD(NVL(interval, 'N/A'), 25) as "INTERVAL"
FROM user_part_tables
ORDER BY table_name;

PROMPT
PROMPT ========================================
PROMPT Index Summary
PROMPT ========================================

SELECT 
    COUNT(*) as "Total Indexes",
    SUM(CASE WHEN locality = 'LOCAL' THEN 1 ELSE 0 END) as "Local Indexes",
    SUM(CASE WHEN locality = 'GLOBAL' THEN 1 ELSE 0 END) as "Global Indexes"
FROM user_part_indexes;

PROMPT
PROMPT ========================================
PROMPT Database Initialization: SUCCESS ✓
PROMPT ========================================

EXIT;
EOF

echo ""
echo "========================================"
echo "Database initialization test complete!"
echo "========================================"
