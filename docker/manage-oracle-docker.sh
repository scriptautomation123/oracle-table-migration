#!/bin/bash
# Oracle Docker Management Script
# Manages Oracle database container lifecycle and initialization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

# ============================================================================
# Helper Functions
# ============================================================================

stop_if_running() {
	local ps_output
	ps_output=$(docker compose -f "${COMPOSE_FILE}" ps --services --filter "status=running" 2>/dev/null || true)
	if [[ -n "${ps_output}" ]]; then
		echo "Stopping containers..."
		docker compose -f "${COMPOSE_FILE}" stop
	fi
}

wait_for_healthy() {
	echo ""
	echo "Waiting for database to be healthy..."
	echo "(This may take 60-120 seconds on first startup)"
	echo ""

	local elapsed=0
	local timeout=300
	local ps_output

	while true; do
		ps_output=$(docker compose -f "${COMPOSE_FILE}" ps 2>&1 || true)
		if echo "${ps_output}" | grep -q "healthy"; then
			break
		fi

		if [[ ${elapsed} -gt ${timeout} ]]; then
			echo "❌ Timeout waiting for database (5 minutes)"
			echo ""
			echo "Check logs with:"
			echo "  docker compose -f ${COMPOSE_FILE} logs oracle"
			exit 1
		fi

		echo "  Still waiting... (${elapsed}s elapsed)"
		sleep 10
		elapsed=$((elapsed + 10))
	done

	echo ""
	echo "✓ Database is healthy! (took ${elapsed}s)"
}

# ============================================================================
# Command Functions
# ============================================================================

cmd_reinit() {
	echo "========================================"
	echo "Reinitializing Database"
	echo "========================================"
	echo ""
	echo "Actions:"
	echo "  1. Stop container"
	echo "  2. Remove container and volume"
	echo "  3. Start fresh container"
	echo "  4. Run init-scripts/"
	echo ""

	stop_if_running
	echo "Removing container and volume..."
	docker compose -f "${COMPOSE_FILE}" down -v

	cmd_start
}

cmd_cleaninit() {
	echo "========================================"
	echo "Clean + Reinitialize Database"
	echo "========================================"
	echo ""
	echo "Actions:"
	echo "  1. Remove container, volume, and image"
	echo "  2. Pull fresh image"
	echo "  3. Start container"
	echo "  4. Run init-scripts/"
	echo ""

	stop_if_running
	echo "Removing everything..."
	docker compose -f "${COMPOSE_FILE}" down -v --rmi all --remove-orphans

	cmd_start
}

cmd_clean() {
	echo "========================================"
	echo "Cleaning All Resources"
	echo "========================================"
	echo ""

	stop_if_running
	echo "Removing containers, volumes, and images..."
	docker compose -f "${COMPOSE_FILE}" down -v --rmi all --remove-orphans

	echo ""
	echo "✓ Cleanup complete!"
}

cmd_start() {
	echo "========================================"
	echo "Starting Oracle Database"
	echo "========================================"

	echo ""
	echo "Starting database container..."
	docker compose -f "${COMPOSE_FILE}" up -d

	wait_for_healthy

	# Run verification if test script exists
	if [[ -f "${SCRIPT_DIR}/test-db-init.sh" ]]; then
		echo ""
		echo "========================================"
		echo "Running Database Verification"
		echo "========================================"
		echo ""
		"${SCRIPT_DIR}/test-db-init.sh"
	fi

	echo ""
	echo "========================================"
	echo "✓ Database Ready"
	echo "========================================"
	echo ""
	echo "Connection Info:"
	echo "  Host: localhost"
	echo "  Port: 1521"
	echo "  Service: FREEPDB1"
	echo "  User: hr/hr123"
	echo ""
	echo "Quick Connect:"
	echo "  docker compose -f ${COMPOSE_FILE} exec oracle sqlplus hr/hr123@FREEPDB1"
	echo ""
}

cmd_help() {
	cat <<-'EOF'
	Usage: ./manage-oracle-docker.sh [COMMAND]

	Commands:
	  start      Start database (default if no command)
	  reinit     Reinitialize database (recreate container + run init-scripts/)
	  cleaninit  Clean everything + reinitialize (pulls fresh image)
	  clean      Remove all resources (containers, volumes, images)
	  help       Show this help message

	Examples:
	  ./manage-oracle-docker.sh              # Start database
	  ./manage-oracle-docker.sh reinit       # Fast reinit (keeps image)
	  ./manage-oracle-docker.sh cleaninit    # Full clean + reinit (re-downloads image)
	  ./manage-oracle-docker.sh clean        # Cleanup only

	Workflow:
	  1. Edit init-scripts/init.sh (add your schemas/tables)
	  2. Run: ./manage-oracle-docker.sh reinit
	  3. Database recreates and runs your init script
	EOF
}

# ============================================================================
# Main
# ============================================================================

case "${1:-start}" in
	start)
		cmd_start
		;;
	reinit)
		cmd_reinit
		;;
	cleaninit)
		cmd_cleaninit
		;;
	clean)
		cmd_clean
		;;
	help | -h | --help)
		cmd_help
		;;
	*)
		echo "Error: Unknown command '${1}'"
		echo ""
		cmd_help
		exit 1
		;;
esac
