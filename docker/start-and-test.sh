#!/bin/bash
# Complete database startup and verification workflow

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

# Function to clean everything
clean_all() {
	echo "========================================"
	echo "Cleaning Docker Resources"
	echo "========================================"
	echo ""

	# Check if containers are running
	COMPOSE_PS_OUTPUT=$(docker compose -f "${COMPOSE_FILE}" ps --services --filter "status=running" 2>/dev/null)
	if echo "${COMPOSE_PS_OUTPUT}" | grep -q .; then
		echo "⚠️  Running containers detected. Stopping..."
		docker compose -f "${COMPOSE_FILE}" stop
	fi

	echo ""
	echo "Removing containers, volumes, and images..."
	docker compose -f "${COMPOSE_FILE}" down -v --rmi all --remove-orphans

	echo ""
	echo "✓ Cleanup complete!"
	echo ""
}

# Parse command line arguments
if [[ ${1} == "reinit" ]]; then
	echo "========================================"
	echo "Re-initializing Database"
	echo "========================================"
	echo ""
	echo "This will:"
	echo "  1. docker compose stop"
	echo "  2. docker compose down -v"
	echo "  3. docker compose up -d"
	echo "  → Container recreated, init-scripts/ executed"
	echo ""

	echo "Stopping container..."
	docker compose -f "${COMPOSE_FILE}" stop

	echo "Removing container and volume..."
	docker compose -f "${COMPOSE_FILE}" down -v

	echo "Starting fresh container (init scripts will run)..."
	echo ""
	# Continue to normal startup below
elif [[ ${1} == "clean" ]]; then
	clean_all
	exit 0
elif [[ ${1} == "help" ]] || [[ ${1} == "-h" ]] || [[ ${1} == "--help" ]]; then
	echo "Usage: ${0} [COMMAND]"
	echo ""
	echo "Commands:"
	echo "  (none)   - Start/test database (default)"
	echo "  reinit   - Recreate container, re-run init-scripts/"
	echo "  clean    - Remove everything (containers, volumes, images)"
	echo "  help     - Show this help message"
	echo ""
	echo "Reinit process:"
	echo "  1. docker compose stop"
	echo "  2. docker compose down -v"
	echo "  3. docker compose up -d"
	echo "  4. init-scripts/init.sh executes automatically"
	echo ""
	exit 0
fi

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

	if [[ ${SECONDS} -gt 300 ]]; then
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
echo ""
echo "Quick Connect:"
echo "  docker compose -f ${COMPOSE_FILE} exec oracle sqlplus hr/hr123@FREEPDB1"
echo ""
echo "Available Commands:"
Use case: Testing init scripts repeatedly
./manage-oracle-docker.sh              # Start
echo ""
