#!/bin/ksh
# ============================================================================
# Production Partition Swap Runner
# ============================================================================
# Purpose: Execute partition swap (Active → Staging → History)
# Usage: Standalone script for Autosys or cron scheduling
# Requirements: Standard user privileges, partition_swap_pkg must be installed
# ============================================================================

set -e
set -o pipefail

# ============================================================================
# Configuration (Override via environment variables)
# ============================================================================

DB_USER="${DB_USER:-hr}"
DB_PASS="${DB_PASS:-hr123}"
DB_CONNECT="${DB_CONNECT:-localhost:1521/FREEPDB1}"

ACTIVE_TABLE="${ACTIVE_TABLE:-ACTIVE_TRANSACTIONS}"
STAGING_TABLE="${STAGING_TABLE:-STAGING_TRANSACTIONS}"
HISTORY_TABLE="${HISTORY_TABLE:-HISTORY_TRANSACTIONS}"

# Logging
LOG_DIR="${LOG_DIR:-/tmp/partition_swap_logs}"
LOG_FILE="${LOG_DIR}/partition_swap_$(date +%Y%m%d_%H%M%S).log"
RETAIN_LOGS_DAYS="${RETAIN_LOGS_DAYS:-30}"

# Exit codes
EXIT_SUCCESS=0
EXIT_DB_CONNECTION_FAILED=1
EXIT_PACKAGE_NOT_FOUND=2
EXIT_SWAP_FAILED=3
EXIT_VALIDATION_FAILED=4

# ============================================================================
# Setup
# ============================================================================

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Temp SQL file
TEMP_SQL="/tmp/partition_swap_$$.sql"
trap 'rm -f ${TEMP_SQL}' EXIT

# ============================================================================
# Logging Functions
# ============================================================================

log() {
	local level=$1
	shift
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}"
}

log_info() {
	log "INFO" "$@"
}

log_error() {
	log "ERROR" "$@"
}

log_warn() {
	log "WARN" "$@"
}

# ============================================================================
# Database Helper Functions
# ============================================================================

run_sql_query() {
	local sql=$1

	sqlplus -S "${DB_USER}/${DB_PASS}@${DB_CONNECT}" <<EOF
SET HEADING OFF
SET FEEDBACK OFF
SET PAGESIZE 0
SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
${sql}
EXIT;
EOF
}

check_db_connection() {
	log_info "Checking database connection..."

	local result
	result=$(run_sql_query "SELECT 'OK' FROM DUAL;" 2>&1)

	if [ $? -ne 0 ] || [ "${result}" != "OK" ]; then
		log_error "Database connection failed: ${result}"
		return ${EXIT_DB_CONNECTION_FAILED}
	fi

	log_info "Database connection successful"
	return 0
}

check_package_exists() {
	log_info "Checking if partition_swap_pkg exists..."

	local result
	result=$(run_sql_query "SELECT COUNT(*) FROM all_objects WHERE object_type = 'PACKAGE' AND object_name = 'PARTITION_SWAP_PKG' AND owner = USER;" 2>&1)

	if [ "${result}" != "1" ]; then
		log_error "Package partition_swap_pkg not found. Please install it first."
		return ${EXIT_PACKAGE_NOT_FOUND}
	fi

	log_info "Package partition_swap_pkg found"
	return 0
}

get_table_stats() {
	local table_name=$1

	run_sql_query "SELECT COUNT(*) FROM ${table_name};" 2>&1
}

get_partition_count() {
	local table_name=$1

	run_sql_query "SELECT COUNT(*) FROM all_tab_partitions WHERE table_owner = USER AND table_name = '${table_name}';" 2>&1
}

# ============================================================================
# Pre-execution Validation
# ============================================================================

validate_preconditions() {
	log_info "=========================================="
	log_info "Pre-execution Validation"
	log_info "=========================================="

	# Check DB connection
	check_db_connection || return $?

	# Check package exists
	check_package_exists || return $?

	# Check tables exist and get stats
	log_info "Gathering table statistics..."

	local active_count staging_count history_count
	active_count=$(get_table_stats "${ACTIVE_TABLE}")
	staging_count=$(get_table_stats "${STAGING_TABLE}")
	history_count=$(get_table_stats "${HISTORY_TABLE}")

	if [ $? -ne 0 ]; then
		log_error "Failed to query table statistics"
		return ${EXIT_VALIDATION_FAILED}
	fi

	log_info "Before swap:"
	log_info "  ${ACTIVE_TABLE}: ${active_count} rows"
	log_info "  ${STAGING_TABLE}: ${staging_count} rows"
	log_info "  ${HISTORY_TABLE}: ${history_count} rows"

	# Validate staging is empty
	if [ "${staging_count}" != "0" ]; then
		log_error "Staging table ${STAGING_TABLE} is not empty (${staging_count} rows)"
		log_error "Swap cannot proceed - staging must be empty"
		return ${EXIT_VALIDATION_FAILED}
	fi

	# Check partition counts
	local active_partitions
	active_partitions=$(get_partition_count "${ACTIVE_TABLE}")

	if [ "${active_partitions}" = "0" ]; then
		log_error "No partitions found in ${ACTIVE_TABLE}"
		return ${EXIT_VALIDATION_FAILED}
	fi

	log_info "Active table has ${active_partitions} partition(s)"
	log_info "Validation passed"

	return 0
}

# ============================================================================
# Execute Partition Swap
# ============================================================================

execute_swap() {
	log_info "=========================================="
	log_info "Executing Partition Swap"
	log_info "=========================================="

	# Create SQL script
	cat >"${TEMP_SQL}" <<EOSQL
SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET TIMING ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

BEGIN
    partition_swap_pkg.swap_oldest_partition(
        p_active_table   => '${ACTIVE_TABLE}',
        p_staging_table  => '${STAGING_TABLE}',
        p_history_table  => '${HISTORY_TABLE}'
    );
END;
/

EXIT;
EOSQL

	# Execute swap
	log_info "Calling partition_swap_pkg.swap_oldest_partition..."

	local swap_output
	swap_output=$(sqlplus -S "${DB_USER}/${DB_PASS}@${DB_CONNECT}" @"${TEMP_SQL}" 2>&1)
	local swap_status=$?

	# Log output
	echo "${swap_output}" | tee -a "${LOG_FILE}"

	if [ ${swap_status} -ne 0 ]; then
		log_error "Partition swap failed with exit code ${swap_status}"
		return ${EXIT_SWAP_FAILED}
	fi

	log_info "Partition swap completed successfully"
	return 0
}

# ============================================================================
# Post-execution Validation
# ============================================================================

validate_postconditions() {
	log_info "=========================================="
	log_info "Post-execution Validation"
	log_info "=========================================="

	# Get final stats
	local active_count staging_count history_count
	active_count=$(get_table_stats "${ACTIVE_TABLE}")
	staging_count=$(get_table_stats "${STAGING_TABLE}")
	history_count=$(get_table_stats "${HISTORY_TABLE}")

	log_info "After swap:"
	log_info "  ${ACTIVE_TABLE}: ${active_count} rows"
	log_info "  ${STAGING_TABLE}: ${staging_count} rows"
	log_info "  ${HISTORY_TABLE}: ${history_count} rows"

	# Validate staging is empty again
	if [ "${staging_count}" != "0" ]; then
		log_warn "Staging table is not empty after swap (${staging_count} rows)"
		log_warn "This may indicate an incomplete swap"
	fi

	return 0
}

# ============================================================================
# Cleanup Old Logs
# ============================================================================

cleanup_old_logs() {
	log_info "Cleaning up logs older than ${RETAIN_LOGS_DAYS} days..."

	find "${LOG_DIR}" -name "partition_swap_*.log" -type f -mtime +${RETAIN_LOGS_DAYS} -delete 2>/dev/null || true

	log_info "Log cleanup complete"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
	local start_time
	start_time=$(date +%s)

	log_info "=========================================="
	log_info "Partition Swap Runner - START"
	log_info "=========================================="
	log_info "Configuration:"
	log_info "  Database: ${DB_USER}@${DB_CONNECT}"
	log_info "  Active Table: ${ACTIVE_TABLE}"
	log_info "  Staging Table: ${STAGING_TABLE}"
	log_info "  History Table: ${HISTORY_TABLE}"
	log_info "  Log File: ${LOG_FILE}"
	log_info ""

	# Pre-execution validation
	if ! validate_preconditions; then
		local exit_code=$?
		log_error "Pre-execution validation failed"
		return ${exit_code}
	fi

	# Execute swap
	if ! execute_swap; then
		local exit_code=$?
		log_error "Partition swap execution failed"
		return ${exit_code}
	fi

	# Post-execution validation
	validate_postconditions

	# Cleanup old logs
	cleanup_old_logs

	# Calculate duration
	local end_time duration
	end_time=$(date +%s)
	duration=$((end_time - start_time))

	log_info ""
	log_info "=========================================="
	log_info "Partition Swap Runner - SUCCESS"
	log_info "=========================================="
	log_info "Duration: ${duration} seconds"
	log_info "Log file: ${LOG_FILE}"

	return ${EXIT_SUCCESS}
}

# ============================================================================
# Execute
# ============================================================================

main
exit $?
