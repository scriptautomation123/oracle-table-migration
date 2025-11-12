#!/bin/bash
# Complete database startup and verification workflow

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

echo "========================================"
echo "Oracle Database Startup & Test"
echo "========================================"

# Start database
echo ""
echo "Starting Oracle database..."
docker compose -f "${COMPOSE_FILE}" up -d

# Wait for healthy status
echo ""
echo "Waiting for database to be healthy..."
echo "(This may take 60-120 seconds on first startup)"
echo ""

SECONDS=0
while true; do
    # Check health status separately to avoid masking return value
    COMPOSE_PS_OUTPUT=$(docker compose -f "${COMPOSE_FILE}" ps 2>&1)
    if echo "${COMPOSE_PS_OUTPUT}" | grep -q "healthy"; then
        break
    fi
    
    if [[ "${SECONDS}" -gt 300 ]]; then
        echo "❌ Timeout waiting for database (5 minutes)"
        echo ""
        echo "Check logs with:"
        echo "  docker compose -f ${COMPOSE_FILE} logs oracle"
        exit 1
    fi
    
    echo "  Still waiting... (${SECONDS}s elapsed)"
    sleep 10
done

echo ""
echo "✓ Database is healthy! (took ${SECONDS}s)"

# Run verification
echo ""
echo "========================================"
echo "Running Database Verification"
echo "========================================"
echo ""

"${SCRIPT_DIR}/test-db-init.sh"

echo ""
echo "========================================"
echo "✓ All Done!"
echo "========================================"
echo ""
echo "Connection Info:"
echo "  Host: localhost"
echo "  Port: 1521"
echo "  Service: FREEPDB1"
echo "  HR User: hr/hr123"
echo "  App User: hr_app_user/hrapp123"
echo ""
echo "Quick Connect:"
echo "  docker compose -f ${COMPOSE_FILE} exec oracle sqlplus hr/hr123@FREEPDB1"
echo ""
