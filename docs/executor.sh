#!/usr/bin/env sh
# ===================================================================
# Executor Wrapper - User-Friendly Migration DDL Interface
# ===================================================================
# Purpose: Easy-to-use wrapper for running DDL migrations
# Usage: ./executor.sh <mode> <owner> <table> [options]
# ===================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNNER="$SCRIPT_DIR/runner.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Print usage
print_usage() {
    cat << EOF
${CYAN}DDL Executor - Oracle Table Migration Wrapper${NC}

${GREEN}USAGE:${NC}
    $0 <mode> <owner> <table> [options]

${GREEN}MODES:${NC}
    generate    Generate DDL files to disk (no execution)
    execute     Execute pre-generated DDL files
    auto        Generate and execute DDL in memory

${GREEN}OPTIONS:${NC}
    --connection, -c <conn>     Oracle connection string
                               Format: user/pass@host:port/service
                               Optional: can use ORACLE_CONN env var
    
    --sql-client <path>         Path to sqlcl or sqlplus
                               Optional: auto-detected
    
    --help, -h                  Show this help message

${GREEN}EXAMPLES:${NC}

  ${CYAN}# Generate DDL files${NC}
  $0 generate APP_DATA_OWNER MY_TABLE -c "\$ORACLE_CONN"

  ${CYAN}# Execute pre-generated DDL files${NC}
  $0 execute APP_DATA_OWNER MY_TABLE -c "\$ORACLE_CONN"

  ${CYAN}# Auto mode (generate and execute)${NC}
  $0 auto APP_DATA_OWNER MY_TABLE -c "\$ORACLE_CONN"

  ${CYAN}# Use environment variable${NC}
  export ORACLE_CONN="system/oracle123@localhost:1521/FREEPDB1"
  $0 generate APP_DATA_OWNER MY_TABLE

${GREEN}OUTPUT:${NC}
    All output is saved to: output/migration_run_YYYYMMDD_HHMMSS/
        ├── runner.log         - Execution log
        └── executor.log        - PL/SQL output

${GREEN}EXIT CODES:${NC}
    0  - Success
    1  - Failure
    2  - Unknown result

EOF
}

# Parse arguments
MODE=""
OWNER=""
TABLE=""
CONNECTION=""
SQL_CLIENT=""

# Check for help
if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    print_usage
    exit 0
fi

# Get required arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}ERROR: Mode, owner, and table are required${NC}"
    echo "Run '$0 --help' for usage"
    exit 1
fi

MODE="$1"
OWNER="$2"
TABLE="$3"
shift 3

# Parse options
while [ $# -gt 0 ]; do
    case "$1" in
        --connection|-c)
            CONNECTION="$2"
            shift 2
            ;;
        --sql-client)
            SQL_CLIENT="$2"
            shift 2
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}"
            echo "Run '$0 --help' for usage"
            exit 1
            ;;
    esac
done

# Validate mode
case "$MODE" in
    generate|execute|auto)
        MODE_UPPER=$(echo "$MODE" | tr '[:lower:]' '[:upper:]')
        ;;
    *)
        echo -e "${RED}ERROR: Invalid mode: $MODE${NC}"
        echo "Valid modes: generate, execute, auto"
        exit 1
        ;;
esac

# Get connection
if [ -z "$CONNECTION" ]; then
    if [ -n "$ORACLE_CONN" ]; then
        CONNECTION="$ORACLE_CONN"
    else
        echo -e "${YELLOW}WARNING: No connection string provided${NC}"
        echo "  Use --connection or set ORACLE_CONN environment variable"
    fi
fi

# Execute
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}DDL Executor - $MODE_UPPER Mode${NC}"
echo -e "${CYAN}============================================================${NC}"
echo -e "${BLUE}Owner: $OWNER${NC}"
echo -e "${BLUE}Table: $TABLE${NC}"
if [ -n "$CONNECTION" ]; then
    echo -e "${BLUE}Connection: $CONNECTION${NC}"
fi
echo ""

# Build runner command
RUNNER_CMD="$RUNNER $MODE_UPPER $OWNER $TABLE"

if [ -n "$CONNECTION" ]; then
    RUNNER_CMD="$RUNNER_CMD '$CONNECTION'"
fi

if [ -n "$SQL_CLIENT" ]; then
    RUNNER_CMD="$RUNNER_CMD '$SQL_CLIENT'"
fi

eval $RUNNER_CMD

exit $?
