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

${GREEN}USAGE:${NC}
    $0 <command> [subcommand] [args...]

${GREEN}COMMANDS:${NC}

  ${YELLOW}validate <operation> [args]${NC}
    Run validation operations
    
    Operations:
      • check_existence <owner> <table>
      • count_rows <owner> <table> [expected]
      • check_constraints <owner> <table> [action]
      • check_partitions <owner> <table>
      • pre_swap <owner> <table> <new> <old>
      • post_swap <owner> <table> <old>

  ${YELLOW}migrate <mode> <owner> <table>${NC}
    Run migration operations
    
    Modes:
      • generate - Create DDL files
      • execute - Execute DDL files
      • auto - Generate and execute

${GREEN}OPTIONS:${NC}
    --connection, -c <conn>     Oracle connection
    --verbose, -v                Verbose output
    --help, -h                   Show help

${GREEN}EXAMPLES:${NC}

  ${CYAN}# Validate table exists${NC}
  $0 validate check_existence APP_OWNER MY_TABLE -c "\$ORACLE_CONN"

  ${CYAN}# Check row count${NC}
  $0 validate count_rows APP_OWNER MY_TABLE 1000000 -c "\$ORACLE_CONN"

  ${CYAN}# Generate migration DDL${NC}
  $0 migrate generate APP_OWNER MY_TABLE -c "\$ORACLE_CONN"

  ${CYAN}# Execute migration${NC}
  $0 migrate execute APP_OWNER MY_TABLE -c "\$ORACLE_CONN"

EOF
}

# Parse arguments
TYPE=""
OPERATION=""
ARGS=""
CONNECTION=""
VERBOSE=false

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
		*)
			ARGS="${ARGS} $1"
			shift
			;;
		esac
	done

	if [ -z "${CONNECTION}" ]; then
		echo -e "${RED}ERROR: Connection string required${NC}"
		echo "Use -c or set ORACLE_CONN"
		exit 1
	fi

	${RUNNER} validation "${CONNECTION}" "${OPERATION}" "${ARGS}"
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

	${RUNNER} migration "${MODE}" "${OWNER}" "${TABLE}" "${CONNECTION}"
	;;

*)
	echo -e "${RED}ERROR: Unknown command: ${COMMAND}${NC}"
	echo "Valid commands: validate, migrate"
	exit 1
	;;
esac
