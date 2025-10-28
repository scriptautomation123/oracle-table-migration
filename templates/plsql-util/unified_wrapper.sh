#!/usr/bin/env sh
# shellcheck disable=SC3037,SC2034
# ===================================================================
# Unified Wrapper - User-Friendly Oracle Migration Interface
# ===================================================================
# Purpose: Single entry point for all validation and migration operations
# Usage: ./unified_wrapper.sh <command> [subcommand] [args...]
# ===================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNNER="${SCRIPT_DIR}/unified_runner.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Print usage
print_usage() {
	cat <<EOF
${CYAN}Oracle Migration Unified Wrapper${NC}
${GREEN}SECURITY: All operations use DBMS_ASSERT for SQL injection protection${NC}

${GREEN}USAGE:${NC}
    $0 <command> [subcommand] [args...]

${GREEN}COMMANDS:${NC}

  ${YELLOW}validate <operation> [args]${NC}
    Run validation operations

    Operations:
      • check_sessions <pattern> - Check for active sessions
      • check_existence <owner> <table> - Verify table exists
      • check_table_structure <owner> <table> - Check table structure and partitioning
      • count_rows <owner> <table> [expected] - Count rows with optional validation
      • check_constraints <owner> <table> - Check constraint status
      • check_partition_dist <owner> <table> - Show partition distribution
      • pre_swap <owner> <table> <new> <old> - Pre-swap validation
      • post_swap <owner> <table> <old> - Post-swap validation

    System Operations (requires SYSDBA):
      • check_privileges - Verify SYSDBA privileges
      • check_tablespace [tablespace] - Check tablespace usage
      • check_sessions_all [pattern] - Check all active sessions
      • kill_sessions <pattern> - Kill sessions matching pattern (CAUTION!)
      • check_invalid_objects [schema] - Check for invalid objects
      Note: These operations automatically use '/ as sysdba' connection

  ${YELLOW}migrate <mode> <owner> <table>${NC}
    Run migration operations

    Modes:
      • generate - Create DDL files
      • execute - Execute DDL files
      • auto - Generate and execute
      • orchestrate - Complete end-to-end migration
      • finalize - Finalize swap (drop old, rename, validate)
      • add_subparts - Add hash subpartitions online

  ${YELLOW}workflow <operation> [args]${NC}
    Run workflow operations

    Operations:
      • pre_swap <owner> <table> <new> <old> - Pre-swap validation
      • post_swap <owner> <table> <old> - Post-swap validation
      • post_data_load <owner> <table> <source> <source_count> [parallel] - Post-load validation
      • post_create <owner> <table> [parallel] - Post-create validation and stats
      • create_renamed_view <owner> <table> - Create view with INSTEAD OF trigger (SECURE)
      • finalize_swap <owner> <table> - Complete swap operation
      • pre_create_partitions <owner> <table> [days] - Pre-create future partitions
      • add_hash_subpartitions <owner> <table> <col> [count] - Add online subpartitions

${GREEN}OPTIONS:${NC}
    --connection, -c <conn>     Oracle connection
    --verbose, -v                Verbose output
    --help, -h                   Show help
    --toad                       Use Toad mode (creates script files)

${GREEN}EXAMPLES:${NC}

  ${CYAN}# Validate table exists${NC}
  $0 validate check_existence APP_OWNER MY_TABLE -c "\$ORACLE_CONN"

  ${CYAN}# Check table structure and partitioning${NC}
  $0 validate check_table_structure APP_OWNER MY_TABLE -c "\$ORACLE_CONN"

  ${CYAN}# Check row count with validation${NC}
  $0 validate count_rows APP_OWNER MY_TABLE 1000000 -c "\$ORACLE_CONN"

  ${CYAN}# Check constraint status${NC}
  $0 validate check_constraints APP_OWNER MY_TABLE -c "\$ORACLE_CONN"

  ${CYAN}# Show partition distribution${NC}
  $0 validate check_partition_dist APP_OWNER MY_TABLE -c "\$ORACLE_CONN"

  ${CYAN}# Complete migration${NC}
  $0 migrate orchestrate APP_OWNER MY_TABLE -c "\$ORACLE_CONN"

  ${CYAN}# Create secure view with INSTEAD OF trigger${NC}
  $0 workflow create_renamed_view APP_OWNER MY_TABLE -c "\$ORACLE_CONN"

  ${CYAN}# Add hash subpartitions${NC}
  $0 workflow add_hash_subpartitions APP_OWNER MY_TABLE USER_ID 8 -c "\$ORACLE_CONN"

  ${CYAN}# Pre-create partitions 2 days ahead${NC}
  $0 workflow pre_create_partitions APP_OWNER MY_TABLE 2 -c "\$ORACLE_CONN"

  ${CYAN}# Post-create validation and statistics${NC}
  $0 workflow post_create APP_OWNER MY_TABLE_NEW 4 -c "\$ORACLE_CONN"

  ${CYAN}# System operations (SYSDBA)${NC}
  $0 validate check_privileges
  $0 validate check_tablespace USERS
  $0 validate check_sessions_all APP_USER
  $0 validate check_invalid_objects APP_OWNER

  ${CYAN}# Toad standalone execution${NC}
  $0 validate check_existence APP_OWNER MY_TABLE --toad
  $0 workflow create_renamed_view APP_OWNER MY_TABLE --toad

EOF
}

# Parse arguments
TYPE=""
OPERATION=""
ARGS=""
CONNECTION=""
VERBOSE=false
TOAD_MODE=false

# Get connection
if [ -z "${CONNECTION}" ] && [ -n "${ORACLE_CONN}" ]; then
	CONNECTION="${ORACLE_CONN}"
fi

# Main dispatch
if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	print_usage
	exit 0
fi

COMMAND="$1"
shift

case "${COMMAND}" in
validate | v)
	TYPE="validation"
	OPERATION="$1"
	shift

	# Parse remaining args
	while [ $# -gt 0 ]; do
		case "$1" in
		-c | --connection)
			CONNECTION="$2"
			shift 2
			;;
		--toad)
			TOAD_MODE=true
			shift
			;;
		*)
			ARGS="${ARGS} $1"
			shift
			;;
		esac
	done

	if [ -z "${CONNECTION}" ] && [ "${TOAD_MODE}" = false ]; then
		echo -e "${RED}ERROR: Connection string required${NC}"
		echo "Use -c or set ORACLE_CONN"
		exit 1
	fi

	if [ "${TOAD_MODE}" = true ]; then
		EXPLICIT_CLIENT=toad ${RUNNER} validation "${CONNECTION}" "${OPERATION}" "${ARGS}"
	else
		${RUNNER} validation "${CONNECTION}" "${OPERATION}" "${ARGS}"
	fi
	;;

migrate | m)
	TYPE="migration"
	MODE="$1"
	OWNER="$2"
	TABLE="$3"
	shift 3

	# Parse remaining args
	while [ $# -gt 0 ]; do
		case "$1" in
		-c | --connection)
			CONNECTION="$2"
			shift 2
			;;
		*)
			shift
			;;
		esac
	done

	if [ -z "${CONNECTION}" ]; then
		echo -e "${RED}ERROR: Connection string required${NC}"
		echo "Use -c or set ORACLE_CONN"
		exit 1
	fi

	# Check for orchestration modes
	if [ "${MODE}" = "orchestrate" ]; then
		${RUNNER} orchestrate "${OWNER}" "${TABLE}" "${CONNECTION}"
	elif [ "${MODE}" = "finalize" ]; then
		${RUNNER} finalize "${OWNER}" "${TABLE}" "${CONNECTION}"
	elif [ "${MODE}" = "add_subparts" ]; then
		SUBPART_COL="${4}"
		SUBPART_COUNT="${5:-8}"
		${RUNNER} add_subparts "${OWNER}" "${TABLE}" "${SUBPART_COL}" "${SUBPART_COUNT}" "${CONNECTION}"
	else
		${RUNNER} migration "${MODE}" "${OWNER}" "${TABLE}" "${CONNECTION}"
	fi
	;;

workflow | w)
	TYPE="workflow"
	OPERATION="$1"
	shift

	# Parse remaining args
	while [ $# -gt 0 ]; do
		case "$1" in
		-c | --connection)
			CONNECTION="$2"
			shift 2
			;;
		--toad)
			TOAD_MODE=true
			shift
			;;
		*)
			ARGS="${ARGS} $1"
			shift
			;;
		esac
	done

	if [ -z "${CONNECTION}" ] && [ "${TOAD_MODE}" = false ]; then
		echo -e "${RED}ERROR: Connection string required${NC}"
		echo "Use -c or set ORACLE_CONN"
		exit 1
	fi

	if [ "${TOAD_MODE}" = true ]; then
		EXPLICIT_CLIENT=toad ${RUNNER} workflow "${CONNECTION}" "${OPERATION}" "${ARGS}"
	else
		${RUNNER} workflow "${CONNECTION}" "${OPERATION}" "${ARGS}"
	fi
	;;

*)
	echo -e "${RED}ERROR: Unknown command: ${COMMAND}${NC}"
	echo "Valid commands: validate, migrate, workflow"
	exit 1
	;;
esac
