#!/bin/bash
# Quick cleanup script for Oracle database

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

echo "========================================"
echo "Oracle Database Cleanup Menu"
echo "========================================"
echo ""
echo "What would you like to clean?"
echo ""
echo "  1) Clean data only (keep image for faster restart)"
echo "  2) Clean everything (containers, volumes, images)"
echo "  3) Cancel"
echo ""
read -rp "Enter choice [1-3]: " choice

case ${choice} in
1)
	echo ""
	echo "Cleaning database data (keeping image)..."
	echo ""

	# Check if containers are running
	if docker compose -f "${COMPOSE_FILE}" ps --services --filter "status=running" 2>/dev/null | grep -q .; then
		echo "⚠️  Running containers detected."
		read -rp "Stop running containers? [y/N]: " confirm
		if [[ ${confirm} =~ ^[Yy]$ ]]; then
			echo "Stopping containers..."
			docker compose -f "${COMPOSE_FILE}" stop
		else
			echo "Cancelled. Containers still running."
			exit 0
		fi
	fi

	echo "Removing containers and volumes..."
	docker compose -f "${COMPOSE_FILE}" down -v
	echo ""
	echo "✓ Data cleaned! Image preserved for faster restart."
	;;
2)
	echo ""
	echo "Cleaning everything (containers, volumes, images)..."
	echo ""

	# Check if containers are running
	if docker compose -f "${COMPOSE_FILE}" ps --services --filter "status=running" 2>/dev/null | grep -q .; then
		echo "⚠️  Running containers detected."
		read -rp "Stop running containers and remove everything? [y/N]: " confirm
		if [[ ! ${confirm} =~ ^[Yy]$ ]]; then
			echo "Cancelled. Containers still running."
			exit 0
		fi
	fi

	echo "Stopping containers..."
	docker compose -f "${COMPOSE_FILE}" stop

	echo "Removing containers, volumes, and images..."
	docker compose -f "${COMPOSE_FILE}" down -v --rmi all --remove-orphans

	# Force remove image if still in use by other containers
	if docker images | grep -q "gvenzl/oracle-free.*23-slim-faststart"; then
		echo ""
		echo "⚠️  Image still exists (may be used by other containers)"
		read -rp "Force remove image? [y/N]: " force_remove
		if [[ ${force_remove} =~ ^[Yy]$ ]]; then
			echo "Force removing image..."
			docker rmi -f gvenzl/oracle-free:23-slim-faststart 2>/dev/null || true
		fi
	fi

	echo ""
	echo "✓ Complete cleanup done!"
	;;
3)
	echo ""
	echo "Cancelled."
	exit 0
	;;
*)
	echo ""
	echo "Invalid choice. Exiting."
	exit 1
	;;
esac

echo ""
echo "Next steps:"
echo "  ./start-and-test.sh       - Start fresh database"
echo "  ./start-and-test.sh fresh - Clean and start in one command"
echo ""
