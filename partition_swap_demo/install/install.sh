#!/bin/bash
# ============================================================================
# Universal Install Script
# ============================================================================
# Purpose: Install any package by name via install_all.sql
# Usage: ./install.ksh <package_name> [schema_name] [--sysdba]
# Example: ./install.ksh logging_pkg HR
# Example: ./install.ksh logging_pkg --sysdba
# ============================================================================

set -e

# ============================================================================
# Configuration
# ============================================================================

DB_USER="${DB_USER:-system}"
DB_PASS="${DB_PASS:-oracle}"
DB_CONNECT="${DB_CONNECT:-localhost:1521/FREEPDB1}"
USE_SYSDBA=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ============================================================================
# Functions
# ============================================================================

usage() {
	cat <<EOF
Usage: $0 <package_name|sql_file> [schema_name] [--sysdba]

Install a package or run a SQL file

Arguments:
    package_name    Name of package folder (e.g., logging_pkg, partition_swap_pkg)
                    OR path to SQL file (e.g., demo-setup/demo-setup.sql)
    schema_name     Optional: Schema to install into (can be prompted later)
    --sysdba        Optional: Connect as SYSDBA (no username/password required)

Environment Variables (not used with --sysdba):
    DB_USER         Database user with install privileges (default: system)
    DB_PASS         Database password (default: oracle)
    DB_CONNECT      Connection string (default: localhost:1521/FREEPDB1)

Examples:
    # Package installation
    ./install.sh logging_pkg HR_OWNER --sysdba
    
    # SQL file execution
    ./install.sh demo-setup/demo-setup.sql HR_OWNER --sysdba
    
    # Interactive (prompts for schema)
    ./install.sh logging_pkg
    
    # Custom connection
    DB_USER=sys DB_PASS=syspass DB_CONNECT=prod:1521/PROD ./install.sh partition_swap_pkg HR

Available packages:
EOF
	for dir in "${SCRIPT_DIR}"/*/; do
		if [ -d "$dir" ]; then
			pkg=$(basename "$dir")
			if [ -f "${dir}install_all.sql" ]; then
				echo "    - ${pkg}"
			fi
		fi
	done
	exit 1
}

log() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error_exit() {
	log "ERROR: $1"
	exit 1
}

# ============================================================================
# Main
# ============================================================================

# Check arguments
if [ $# -lt 1 ]; then
	usage
fi

# Parse arguments
INPUT=$1
SCHEMA_NAME=""
IS_SQL_FILE=0

# Check for --sysdba flag in any position
for arg in "$@"; do
	if [ "$arg" = "--sysdba" ]; then
		USE_SYSDBA=1
	fi
done

# Set schema name (if not --sysdba)
if [ $# -ge 2 ] && [ "$2" != "--sysdba" ]; then
	SCHEMA_NAME=$2
fi

log "=========================================="
log "Oracle Package Installer"
log "=========================================="

# Determine if input is a SQL file or package name
if [[ ${INPUT} == *.sql ]]; then
	IS_SQL_FILE=1
	INSTALL_SCRIPT="${SCRIPT_DIR}/${INPUT}"

	# Validate SQL file exists
	if [ ! -f "${INSTALL_SCRIPT}" ]; then
		error_exit "SQL file not found: ${INSTALL_SCRIPT}"
	fi

	WORK_DIR="$(dirname "${INSTALL_SCRIPT}")"
	log "SQL File: ${INSTALL_SCRIPT}"
else
	PACKAGE_NAME="${INPUT}"
	PACKAGE_DIR="${SCRIPT_DIR}/${PACKAGE_NAME}"

	# Validate package folder exists
	if [ ! -d "${PACKAGE_DIR}" ]; then
		error_exit "Package folder not found: ${PACKAGE_DIR}"
	fi

	# Validate install_all.sql exists
	INSTALL_SCRIPT="${PACKAGE_DIR}/install_all.sql"
	if [ ! -f "${INSTALL_SCRIPT}" ]; then
		error_exit "install_all.sql not found in: ${PACKAGE_DIR}"
	fi

	WORK_DIR="${PACKAGE_DIR}"
	log "Package: ${PACKAGE_NAME}"
	log "Package directory: ${PACKAGE_DIR}"
fi

if [ ${USE_SYSDBA} -eq 1 ]; then
	log "Connection: / as sysdba"
else
	log "Database: ${DB_USER}@${DB_CONNECT}"
fi

log "Install script: ${INSTALL_SCRIPT}"

# Change to working directory (for relative @@ includes)
cd "${WORK_DIR}" || error_exit "Failed to change to working directory"

log ""
log "Running installation..."
log "=========================================="

# Determine script name for execution
if [ ${IS_SQL_FILE} -eq 1 ]; then
	SCRIPT_NAME="$(basename "${INSTALL_SCRIPT}")"
else
	SCRIPT_NAME="install_all.sql"
fi

# Run installation with optional schema parameter
# For SQL files, only pass schema if the file has ACCEPT prompts
if [ ${IS_SQL_FILE} -eq 1 ]; then
	# Check if SQL file has ACCEPT statements (needs schema parameter)
	if grep -q "ACCEPT.*schema" "${WORK_DIR}/${SCRIPT_NAME}" 2>/dev/null; then
		HAS_SCHEMA_PARAM=1
	else
		HAS_SCHEMA_PARAM=0
	fi
else
	# Packages always use install_all.sql which has ACCEPT
	HAS_SCHEMA_PARAM=1
fi

if [ ${USE_SYSDBA} -eq 1 ]; then
	# Connect as SYSDBA (no username/password needed)
	if [ -n "${SCHEMA_NAME}" ] && [ ${HAS_SCHEMA_PARAM} -eq 1 ]; then
		# Non-interactive with schema provided
		echo "${SCHEMA_NAME}" | sqlplus / as sysdba @"${SCRIPT_NAME}"
	else
		# Interactive or no schema parameter needed
		sqlplus / as sysdba @"${SCRIPT_NAME}"
	fi
else
	# Regular connection with username/password
	if [ -n "${SCHEMA_NAME}" ] && [ ${HAS_SCHEMA_PARAM} -eq 1 ]; then
		# Non-interactive with schema provided
		echo "${SCHEMA_NAME}" | sqlplus "${DB_USER}/${DB_PASS}@${DB_CONNECT}" @"${SCRIPT_NAME}"
	else
		# Interactive or no schema parameter needed
		sqlplus "${DB_USER}/${DB_PASS}@${DB_CONNECT}" @"${SCRIPT_NAME}"
	fi
fi

EXIT_CODE=$?

log "=========================================="
if [ ${EXIT_CODE} -eq 0 ]; then
	log "Installation completed successfully"
else
	log "Installation failed with exit code: ${EXIT_CODE}"
fi
log "=========================================="

exit ${EXIT_CODE}
