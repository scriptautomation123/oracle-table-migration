#!/usr/bin/env sh
# shellcheck disable=SC3037,SC2034
# ===================================================================
# Unified Runner - Executes SQL/PL/SQL scripts with error handling
# ===================================================================
# Purpose: Execute SQL or PL/SQL scripts with proper configuration
# Usage: ./unified_runner.sh <type> <mode> <args...>
# ===================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect OS
detect_os() {
	case "$(uname -s)" in
	Linux*) OS=linux ;;
	Darwin*) OS=macos ;;
	MINGW* | CYGWIN* | MSYS*) OS=windows ;;
	*) OS=unknown ;;
	esac
}

# Find SQL client
find_sql_client() {
	if [ -n "${SQL_CLIENT_ARG}" ]; then
		SQL_CLIENT="${SQL_CLIENT_ARG}"
		return
	fi

	if [ "${EXPLICIT_CLIENT}" = "toad" ]; then
		SQL_CLIENT="toad"
		return
	fi

	if [ "${EXPLICIT_CLIENT}" = "sqlcl" ] && command -v sqlcl >/dev/null 2>&1; then
		SQL_CLIENT="sqlcl"
		return
	fi

	if command -v sqlcl >/dev/null 2>&1; then
		SQL_CLIENT="sqlcl"
		return
	fi

	if command -v sqlplus >/dev/null 2>&1; then
		SQL_CLIENT="sqlplus"
		return
	fi

	echo "${RED}ERROR: No SQL client found. Please install sqlcl, sqlplus, or use Toad${NC}" >&2
	exit 1
}

# Create output directory
create_output_dir() {
	if [ -z "${OUTPUT_DIR}" ]; then
		TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
		if [ "${TYPE}" = "validation" ]; then
			OUTPUT_DIR="output/validation_run_${TIMESTAMP}"
		else
			OUTPUT_DIR="output/migration_run_${TIMESTAMP}"
		fi
	fi

	mkdir -p "${OUTPUT_DIR}"
	LOG_FILE="${OUTPUT_DIR}/runner.log"

	if [ "${VERBOSE}" = true ]; then
		echo "${BLUE}Output directory: ${OUTPUT_DIR}${NC}"
	fi
}

# Execute validation
execute_validation() {
	OPERATION="$1"
	shift
	ARGS="$*"

	find_sql_client
	create_output_dir

	# Use consolidated plsql-util.sql
	SQL_SCRIPT="${SCRIPT_DIR}/plsql-util.sql"

	echo -e "${BLUE}============================================================${NC}" | tee "${LOG_FILE}"
	echo -e "${BLUE}VALIDATION RUNNER${NC}" | tee -a "${LOG_FILE}"
	echo -e "${BLUE}============================================================${NC}" | tee -a "${LOG_FILE}"
	echo "Operation: ${OPERATION}" | tee -a "${LOG_FILE}"
	echo "Script: ${SQL_SCRIPT}" | tee -a "${LOG_FILE}"
	echo "Connection: ${CONNECTION}" | tee -a "${LOG_FILE}"
	echo "Output: ${OUTPUT_DIR}" | tee -a "${LOG_FILE}"
	echo "" | tee -a "${LOG_FILE}"

	# Build command with category detection
	# Determine category based on operation (updated for security fixes)
	case "${OPERATION}" in
	check_sessions | check_existence | check_table_structure | count_rows | check_constraints | check_partition_dist)
		CATEGORY="READONLY"
		;;
	enable_constraints | disable_constraints)
		CATEGORY="WRITE"
		;;
	pre_swap | post_swap | post_data_load | post_create | create_renamed_view | finalize_swap | pre_create_partitions | add_hash_subpartitions)
		CATEGORY="WORKFLOW"
		;;
	drop | rename)
		CATEGORY="CLEANUP"
		;;
	check_privileges | check_tablespace | check_sessions_all | kill_sessions | check_invalid_objects)
		CATEGORY="SYS"
		;;
	*)
		CATEGORY="READONLY"
		;;
	esac

	# Build command
	if [ "${SQL_CLIENT}" = "toad" ]; then
		# For Toad, create a parameterized script file
		TOAD_SCRIPT="${OUTPUT_DIR}/toad_script.sql"
		cat > "${TOAD_SCRIPT}" << EOF
-- Toad Standalone Execution Script
-- Generated: $(date)
-- Operation: ${CATEGORY} ${OPERATION} ${ARGS}

-- Set substitution variables for Toad
DEFINE category = '${CATEGORY}'
DEFINE operation = '${OPERATION}'
DEFINE arg3 = '${3:-}'
DEFINE arg4 = '${4:-}'
DEFINE arg5 = '${5:-}'
DEFINE arg6 = '${6:-}'
DEFINE arg7 = '${7:-}'

-- Execute the main script
@${SQL_SCRIPT}
EOF
		CMD="echo 'Toad script created: ${TOAD_SCRIPT}'"
		echo "Toad script created: ${TOAD_SCRIPT}" | tee -a "${LOG_FILE}"
		echo "Open this script in Toad and execute it" | tee -a "${LOG_FILE}"
	elif [ "${SQL_CLIENT}" = "sqlcl" ]; then
		if [ "${CATEGORY}" = "SYS" ]; then
			CMD="echo '@${SQL_SCRIPT} ${CATEGORY} ${OPERATION} ${ARGS}' | sqlcl '/ as sysdba'"
		else
			CMD="echo '@${SQL_SCRIPT} ${CATEGORY} ${OPERATION} ${ARGS}' | sqlcl '${CONNECTION}'"
		fi
	else
		if [ "${CATEGORY}" = "SYS" ]; then
			CMD="echo '@${SQL_SCRIPT} ${CATEGORY} ${OPERATION} ${ARGS}' | sqlplus -S '/ as sysdba'"
		else
			CMD="echo '@${SQL_SCRIPT} ${CATEGORY} ${OPERATION} ${ARGS}' | sqlplus -S '${CONNECTION}'"
		fi
	fi

	echo "Executing validation..." | tee -a "${LOG_FILE}"

	# Execute
	START_TIME=$(date +%s)

	if [ "${SQL_CLIENT}" = "toad" ]; then
		# For Toad, just create the script and exit
		echo -e "${BLUE}✓ Toad script created successfully${NC}" | tee -a "${LOG_FILE}"
		echo -e "${YELLOW}ℹ Open ${TOAD_SCRIPT} in Toad and execute it${NC}"
		exit 0
	elif eval "${CMD}" >"${OUTPUT_DIR}/validation_output.log" 2>&1; then
		END_TIME=$(date +%s)
		DURATION=$((END_TIME - START_TIME))

		echo -e "${GREEN}✓ Validation completed (${DURATION}s)${NC}" | tee -a "${LOG_FILE}"

		# Parse results (updated for improved error handling)
		if grep -q "RESULT: PASSED" "${OUTPUT_DIR}/validation_output.log"; then
			echo -e "${GREEN}✓ Result: PASSED${NC}"
			exit 0
		elif grep -q "RESULT: FAILED" "${OUTPUT_DIR}/validation_output.log"; then
			echo -e "${RED}✗ Result: FAILED${NC}"
			# Show error details if available
			if grep -q "ERROR:" "${OUTPUT_DIR}/validation_output.log"; then
				echo -e "${YELLOW}Error details:${NC}"
				grep "ERROR:" "${OUTPUT_DIR}/validation_output.log" | head -3
			fi
			exit 1
		elif grep -q "RESULT: ERROR" "${OUTPUT_DIR}/validation_output.log"; then
			echo -e "${RED}✗ Result: ERROR${NC}"
			# Show error details
			if grep -q "ERROR:" "${OUTPUT_DIR}/validation_output.log"; then
				echo -e "${YELLOW}Error details:${NC}"
				grep "ERROR:" "${OUTPUT_DIR}/validation_output.log" | head -3
			fi
			exit 1
		elif grep -q "RESULT: WARNING" "${OUTPUT_DIR}/validation_output.log"; then
			echo -e "${YELLOW}⚠ Result: WARNING${NC}"
			exit 2
		elif grep -q "RESULT: INFO" "${OUTPUT_DIR}/validation_output.log"; then
			echo -e "${BLUE}ℹ Result: INFO${NC}"
			exit 0
		else
			echo -e "${YELLOW}? Result: UNKNOWN${NC}"
			exit 2
		fi
	else
		echo -e "${RED}✗ Validation failed${NC}" | tee -a "${LOG_FILE}"
		echo "See: ${OUTPUT_DIR}/validation_output.log" | tee -a "${LOG_FILE}"
		exit 1
	fi
}

# Execute migration
execute_migration() {
	MODE="$1"
	OWNER="$2"
	TABLE="$3"

	find_sql_client
	create_output_dir

	# Using plsql-util.sql for workflow operations
	PLSQL_UTIL="${SCRIPT_DIR}/plsql-util.sql"

	echo -e "${BLUE}============================================================${NC}" | tee "${LOG_FILE}"
	echo -e "${BLUE}MIGRATION RUNNER${NC}" | tee -a "${LOG_FILE}"
	echo -e "${BLUE}============================================================${NC}" | tee -a "${LOG_FILE}"
	echo "Mode: ${MODE}" | tee -a "${LOG_FILE}"
	echo "Owner: ${OWNER}" | tee -a "${LOG_FILE}"
	echo "Table: ${TABLE}" | tee -a "${LOG_FILE}"
	echo "Connection: ${CONNECTION}" | tee -a "${LOG_FILE}"
	echo "Output: ${OUTPUT_DIR}" | tee -a "${LOG_FILE}"
	echo "" | tee -a "${LOG_FILE}"

	# Execute
	START_TIME=$(date +%s)

	# Migration operations use WORKFLOW category
	if [ "${SQL_CLIENT}" = "sqlcl" ]; then
		echo "@${PLSQL_UTIL} WORKFLOW ${MODE} ${OWNER} ${TABLE}" | sqlcl "${CONNECTION}" >"${OUTPUT_DIR}/migration.log" 2>&1
	else
		echo "@${PLSQL_UTIL} WORKFLOW ${MODE} ${OWNER} ${TABLE}" | sqlplus -S "${CONNECTION}" >"${OUTPUT_DIR}/migration.log" 2>&1
	fi

	EXIT_CODE=$?
	END_TIME=$(date +%s)
	DURATION=$((END_TIME - START_TIME))

	if [ "${EXIT_CODE}" -eq 0 ]; then
		echo -e "${GREEN}✓ Migration completed (${DURATION}s)${NC}" | tee -a "${LOG_FILE}"

		if grep -q "RESULT: PASSED" "${OUTPUT_DIR}/migration.log"; then
			echo -e "${GREEN}✓ Status: SUCCESS${NC}"
			exit 0
		else
			echo -e "${YELLOW}? Status: UNKNOWN${NC}"
			exit 2
		fi
	else
		echo -e "${RED}✗ Migration failed (exit code: ${EXIT_CODE})${NC}" | tee -a "${LOG_FILE}"
		echo "See: ${OUTPUT_DIR}/migration.log" | tee -a "${LOG_FILE}"
		exit 1
	fi
}

# Execute workflow operations
execute_workflow() {
	OPERATION="${1}"
	shift
	ARGS="$*"

	find_sql_client
	create_output_dir

	SQL_SCRIPT="${SCRIPT_DIR}/plsql-util.sql"

	echo -e "${BLUE}============================================================${NC}" | tee "${LOG_FILE}"
	echo -e "${BLUE}WORKFLOW OPERATIONS${NC}" | tee -a "${LOG_FILE}"
	echo -e "${BLUE}============================================================${NC}" | tee -a "${LOG_FILE}"
	echo "Operation: ${OPERATION}" | tee -a "${LOG_FILE}"
	echo "Script: ${SQL_SCRIPT}" | tee -a "${LOG_FILE}"
	echo "Connection: ${CONNECTION}" | tee -a "${LOG_FILE}"
	echo "Output: ${OUTPUT_DIR}" | tee -a "${LOG_FILE}"
	echo "" | tee -a "${LOG_FILE}"

	# Build command
	if [ "${SQL_CLIENT}" = "sqlcl" ]; then
		CMD="echo '@${SQL_SCRIPT} WORKFLOW ${OPERATION} ${ARGS}' | sqlcl '${CONNECTION}'"
	else
		CMD="echo '@${SQL_SCRIPT} WORKFLOW ${OPERATION} ${ARGS}' | sqlplus -S '${CONNECTION}'"
	fi

	echo "Executing workflow operation..." | tee -a "${LOG_FILE}"

	START_TIME=$(date +%s)

	if eval "${CMD}" >"${OUTPUT_DIR}/workflow.log" 2>&1; then
		END_TIME=$(date +%s)
		DURATION=$((END_TIME - START_TIME))

		echo -e "${GREEN}✓ Workflow completed (${DURATION}s)${NC}" | tee -a "${LOG_FILE}"

		if grep -q "RESULT: PASSED" "${OUTPUT_DIR}/workflow.log"; then
			echo -e "${GREEN}✓ Result: PASSED${NC}"
			exit 0
		elif grep -q "RESULT: FAILED" "${OUTPUT_DIR}/workflow.log"; then
			echo -e "${RED}✗ Result: FAILED${NC}"
			# Show error details if available
			if grep -q "ERROR:" "${OUTPUT_DIR}/workflow.log"; then
				echo -e "${YELLOW}Error details:${NC}"
				grep "ERROR:" "${OUTPUT_DIR}/workflow.log" | head -3
			fi
			exit 1
		elif grep -q "RESULT: ERROR" "${OUTPUT_DIR}/workflow.log"; then
			echo -e "${RED}✗ Result: ERROR${NC}"
			# Show error details
			if grep -q "ERROR:" "${OUTPUT_DIR}/workflow.log"; then
				echo -e "${YELLOW}Error details:${NC}"
				grep "ERROR:" "${OUTPUT_DIR}/workflow.log" | head -3
			fi
			exit 1
		elif grep -q "RESULT: WARNING" "${OUTPUT_DIR}/workflow.log"; then
			echo -e "${YELLOW}⚠ Result: WARNING${NC}"
			exit 2
		elif grep -q "RESULT: INFO" "${OUTPUT_DIR}/workflow.log"; then
			echo -e "${BLUE}ℹ Result: INFO${NC}"
			exit 0
		else
			echo -e "${YELLOW}? Result: UNKNOWN${NC}"
			exit 2
		fi
	else
		echo -e "${RED}✗ Workflow failed${NC}" | tee -a "${LOG_FILE}"
		echo "See: ${OUTPUT_DIR}/workflow.log" | tee -a "${LOG_FILE}"
		exit 1
	fi
}

# Main
detect_os

TYPE="${1:-validation}"
shift || true

case "${TYPE}" in
validation)
	CONNECTION="${1}"
	OPERATION="${2}"
	shift 2 || true
	execute_validation "${OPERATION}" "$@"
	;;
migration)
	MODE="${1}"
	OWNER="${2}"
	TABLE="${3}"
	CONNECTION="${4}"
	execute_migration "${MODE}" "${OWNER}" "${TABLE}" "${CONNECTION}"
	;;
orchestrate)
	# TODO: Implement complete orchestration workflow here
	echo -e "${RED}ERROR: Orchestrate mode not yet implemented${NC}"
	echo "Use individual operations instead:"
	echo "  validate check_existence"
	echo "  workflow post_create"
	echo "  workflow post_data_load"
	echo "  workflow create_renamed_view"
	echo "  migrate finalize"
	exit 1
	;;
finalize)
	OWNER="${1}"
	TABLE="${2}"
	CONNECTION="${3}"
	execute_workflow "FINALIZE_SWAP" "${OWNER} ${TABLE}"
	;;
add_subparts)
	OWNER="${1}"
	TABLE="${2}"
	SUBPART_COL="${3}"
	SUBPART_COUNT="${4}"
	CONNECTION="${5}"
	execute_workflow "ADD_HASH_SUBPARTITIONS" "${OWNER} ${TABLE} ${SUBPART_COL} ${SUBPART_COUNT}"
	;;
workflow)
	CONNECTION="${1}"
	OPERATION="${2}"
	shift 2 || true
	execute_workflow "${OPERATION}" "$@"
	;;
*)
	echo "Usage: $0 <type> [args...]"
	echo "  type: validation | migration | orchestrate | finalize | add_subparts | workflow"
	echo ""
	echo "Environment Variables:"
	echo "  SQL_CLIENT_ARG=toad|sqlcl|sqlplus  - Force specific SQL client"
	echo "  EXPLICIT_CLIENT=toad               - Use Toad mode (creates script files)"
	echo ""
	echo "For validation:"
	echo "  $0 validation <connection> <operation> [args...]"
	echo "  Operations: check_sessions, check_existence, check_table_structure, count_rows,"
	echo "             check_constraints, check_partition_dist"
	echo ""
	echo "For system operations (requires SYSDBA):"
	echo "  $0 validation <connection> <operation> [args...]"
	echo "  Operations: check_privileges, check_tablespace, check_sessions_all,"
	echo "             kill_sessions, check_invalid_objects"
	echo "  Note: SYS operations automatically use '/ as sysdba' connection"
	echo ""
	echo "For Toad standalone execution:"
	echo "  EXPLICIT_CLIENT=toad $0 validation <connection> <operation> [args...]"
	echo "  Creates a script file that can be opened and executed in Toad"
	echo ""
	echo "For migration:"
	echo "  $0 migration <mode> <owner> <table> <connection>"
	echo ""
	echo "For workflow operations:"
	echo "  $0 workflow <connection> <operation> [args...]"
	echo "  Operations: pre_swap, post_swap, post_data_load, post_create,"
	echo "             create_renamed_view, finalize_swap, pre_create_partitions,"
	echo "             add_hash_subpartitions"
	echo ""
	echo "For orchestration:"
	echo "  $0 orchestrate <owner> <table> <connection>"
	echo ""
	echo "For finalization:"
	echo "  $0 finalize <owner> <table> <connection>"
	echo ""
	echo "For adding subpartitions:"
	echo "  $0 add_subparts <owner> <table> <subpart_col> <subpart_count> <connection>"
	exit 1
	;;
esac
