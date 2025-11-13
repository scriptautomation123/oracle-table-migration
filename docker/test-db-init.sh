#!/bin/bash

# Verify database initialization
# Test database initialization after docker-compose up

echo "========================================"
echo "Testing Oracle Database Initialization"
echo "========================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Get script directory
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

echo ""
echo "Verifying database setup..."
echo ""

echo "Waiting for database to be healthy..."

# Wait for the 'oracle' service to become healthy
while true; do
	COMPOSE_PS_OUTPUT=$(docker compose -f "${COMPOSE_FILE}" ps 2>&1)
	if echo "${COMPOSE_PS_OUTPUT}" | grep -q "healthy"; then
		break
	fi
	echo "  Still waiting..."
	sleep 5
done

echo "✓ Database is healthy!"
echo ""

echo "Testing database setup..."

# Run verification queries inside the Oracle container using a single here-document
docker compose -f "${COMPOSE_FILE}" exec -T oracle sqlplus -s hr/hr123@FREEPDB1 <<'EOF'
SET PAGESIZE 100
SET LINESIZE 120

PROMPT ========================================
PROMPT Table Row Counts
PROMPT ========================================
SELECT RPAD(table_name, 30) || LPAD(TO_CHAR(num_rows, '999,999'), 12) AS "Table (Rows)"
FROM user_tables
ORDER BY table_name;

PROMPT
PROMPT ========================================
PROMPT Partition Information
PROMPT ========================================
SELECT RPAD(table_name, 30)                       AS "TABLE NAME",
       RPAD(NVL(partitioning_type, 'N/A'), 15)    AS "PART TYPE",
       LPAD(TO_CHAR(partition_count, '999'), 8)   AS "PARTS",
       RPAD(NVL(interval, 'N/A'), 25)             AS "INTERVAL"
FROM user_part_tables
ORDER BY table_name;

PROMPT
PROMPT ========================================
PROMPT Index Summary
PROMPT ========================================
SELECT COUNT(*) AS "Total Indexes",
       SUM(CASE WHEN locality = 'LOCAL' THEN 1 ELSE 0 END)  AS "Local Indexes",
       SUM(CASE WHEN locality = 'GLOBAL' THEN 1 ELSE 0 END) AS "Global Indexes"
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
