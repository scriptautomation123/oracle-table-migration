#!/bin/bash
# ============================================================================
# Test Installation in Docker Container
# ============================================================================
# Purpose: Copy install scripts to Docker and run interactively
# Usage: ./test_in_docker.sh
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTAINER_NAME="${CONTAINER_NAME:-oracle-test-db}"
INSTALL_SRC="${SCRIPT_DIR}/install"
INSTALL_DEST="/opt/oracle/install"

log() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error_exit() {
	log "ERROR: $1"
	exit 1
}

# Check if container is running
if ! docker ps | grep -q "${CONTAINER_NAME}"; then
	error_exit "Container ${CONTAINER_NAME} is not running. Start it first with: cd docker && ./manage-oracle-docker.sh start"
fi

log "Container: ${CONTAINER_NAME}"
log "Source: ${INSTALL_SRC}"
log "Destination: ${INSTALL_DEST}"

# Remove existing install folder and copy fresh
log "Copying install scripts to container..."
docker exec --user root "${CONTAINER_NAME}" rm -rf "${INSTALL_DEST}"
docker cp "${INSTALL_SRC}" "${CONTAINER_NAME}:/opt/oracle/" || error_exit "Failed to copy files to container"

# Set ownership and permissions (run as root)
docker exec --user root "${CONTAINER_NAME}" chown -R oracle:dba "${INSTALL_DEST}"
docker exec --user root "${CONTAINER_NAME}" chmod +x "${INSTALL_DEST}/install.sh"

log "Files copied successfully"
log ""
log "=========================================="
log "Entering container for interactive install"
log "=========================================="
log ""
log "Run these commands inside the container:"
log "  cd ${INSTALL_DEST}"
log "  ./install.sh logging_pkg HR --sysdba"
log "  ./install.sh partition_swap_pkg HR --sysdba"
log "  exit"
log ""

# Enter container interactively
docker exec -it "${CONTAINER_NAME}" bash -c "cd ${INSTALL_DEST} && exec bash"

log ""
log "Exited container"
