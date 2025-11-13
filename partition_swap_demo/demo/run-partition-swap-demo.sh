#!/bin/bash
# Run the partition swap demonstration

echo "========================================"
echo "Partition Swap Demo"
echo "========================================"
echo ""
echo "This will demonstrate:"
echo "  1. Swapping partition from ACTIVE → STAGING"
echo "  2. Moving data from STAGING → HISTORY"
echo "  3. Cleanup of empty partition"
echo ""

read -rp "Continue? [y/N]: " confirm
if [[ ! ${confirm} =~ ^[Yy]$ ]]; then
	echo "Cancelled."
	exit 0
fi

echo ""
echo "Running demo..."
echo ""

docker compose -f "$(dirname "$0")/docker-compose.yml" exec -T oracle \
	sqlplus -s hr/hr123@FREEPDB1 @/container-entrypoint-initdb.d/partition_swap_demo.sql

echo ""
echo "========================================"
echo "Demo Complete!"
echo "========================================"
echo ""
echo "To run again:"
echo "  1. ./manage-oracle-docker.sh reinit"
echo "  2. ./run-partition-swap-demo.sh"
