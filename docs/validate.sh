#!/usr/bin/env sh
# ===================================================================
# Validation Wrapper - User-Friendly Validation Interface
# ===================================================================
# Purpose: Easy-to-use wrapper for running validation operations
# Usage: ./validate.sh <operation> [options] [args]
# ===================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNNER="$SCRIPT_DIR/validation_runner.sh"

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
${CYAN}Validation Wrapper - Oracle Table Migration Validator${NC}

${GREEN}USAGE:${NC}
    $0 <operation> [options] [arguments...]

${GREEN}AVAILABLE OPERATIONS:${NC}

  ${YELLOW}Basic Operations (01_validator.sql)${NC}
    check_sessions       Check for active sessions using table
                        Args: owner table_name [table_name2] [table_name3]
    
    check_existence      Verify table exists
                        Args: owner table_name
    
    check_structure      Validate table structure and partitioning
                        Args: owner table_name
    
    count_rows           Count rows with optional comparison
                        Args: owner table_name [expected_count]
    
    check_constraints    Check/enable/disable constraints
                        Args: owner table_name [action] [auto_enable]
                        Actions: check, enable, disable
    
    check_partitions     Show partition distribution
                        Args: owner table_name

  ${YELLOW}Workflow Operations (02_workflow_validator.sql)${NC}
    pre_swap             Pre-swap validation checks
                        Args: owner table_name new_table old_table
    
    post_swap            Post-swap validation
                        Args: owner table_name old_table
    
    rollback             Rollback analysis and recommendations
                        Args: owner table_name old_table new_table
    
    post_create          Post-create validation + stats gathering
                        Args: owner table_name parallel_degree
    
    post_load            Post-data-load validation
                        Args: owner target source source_count parallel_degree

${GREEN}OPTIONS:${NC}
    --connection, -c <conn>     Oracle connection string
                               Format: user/pass@host:port/service
                               Required: YES
    
    --sql-client <path>         Path to sqlcl or sqlplus
                               Optional: auto-detected
    
    --output-dir, -o <dir>      Output directory
                               Optional: auto-generated timestamped dir
    
    --verbose, -v               Enable verbose output
                               Optional: default=false
    
    --help, -h                  Show this help message
                               Optional

${GREEN}ENVIRONMENT VARIABLES:${NC}
    ORACLE_CONN              Default connection string if --connection not provided
    
${GREEN}EXAMPLES:${NC}

  ${CYAN}# Check if a table exists${NC}
  $0 check_existence -c "system/oracle123@localhost:1521/FREEPDB1" OWNER MY_TABLE

  ${CYAN}# Count rows and compare${NC}
  $0 count_rows -c \$ORACLE_CONN OWNER MY_TABLE 1000000

  ${CYAN}# Enable constraints${NC}
  $0 check_constraints -c \$ORACLE_CONN OWNER MY_TABLE enable

  ${CYAN}# Pre-swap validation${NC}
  $0 pre_swap -c \$ORACLE_CONN OWNER MY_TABLE MY_TABLE_NEW MY_TABLE_OLD

  ${CYAN}# Check partition distribution${NC}
  $0 check_partitions -v -c \$ORACLE_CONN OWNER MY_TABLE

  ${CYAN}# Post-data-load validation${NC}
  $0 post_load -c \$ORACLE_CONN OWNER NEW_TABLE OLD_TABLE 1000000 4

  ${CYAN}# Use environment variable${NC}
  export ORACLE_CONN="system/oracle123@localhost:1521/FREEPDB1"
  $0 check_existence OWNER MY_TABLE

${GREEN}OUTPUT:${NC}
    All output is saved to: output/validation_run_YYYYMMDD_HHMMSS/
        ├── validation.log         - Execution log
        └── validation_output.log  - SQL output

${GREEN}EXIT CODES:${NC}
    0  - Validation PASSED
    1  - Validation FAILED
    2  - Result UNKNOWN
    3  - Usage error

EOF
}

# Print error and exit
error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 3
}

# Parse arguments
OPERATION=""
CONNECTION=""
SQL_CLIENT=""
OUTPUT_DIR=""
VERBOSE=false
ARGS=""

# Check for help
if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    print_usage
    exit 0
fi

# Get operation
OPERATION="$1"
shift

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
        --output-dir|-o)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        *)
            ARGS="$ARGS $1"
            shift
            ;;
    esac
done

# Validate operation
case "$OPERATION" in
    check_sessions|check_existence|check_structure|count_rows|check_constraints|check_partitions)
        SCRIPT="01_validator.sql"
        ;;
    pre_swap|post_swap|rollback|post_create|post_load)
        SCRIPT="02_workflow_validator.sql"
        ;;
    *)
        error "Unknown operation: $OPERATION\nRun '$0 --help' for available operations"
        ;;
esac

# Get connection
if [ -z "$CONNECTION" ]; then
    if [ -n "$ORACLE_CONN" ]; then
        CONNECTION="$ORACLE_CONN"
    else
        error "Connection string required. Use --connection or set ORACLE_CONN"
    fi
fi

# Build runner command
RUNNER_CMD="$RUNNER --script $SCRIPT --operation $OPERATION --connection '$CONNECTION'"

if [ -n "$SQL_CLIENT" ]; then
    RUNNER_CMD="$RUNNER_CMD --sql-client '$SQL_CLIENT'"
fi

if [ -n "$OUTPUT_DIR" ]; then
    RUNNER_CMD="$RUNNER_CMD --output-dir '$OUTPUT_DIR'"
fi

if [ "$VERBOSE" = true ]; then
    RUNNER_CMD="$RUNNER_CMD --verbose"
fi

RUNNER_CMD="$RUNNER_CMD -- $ARGS"

# Execute
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}Running: $OPERATION${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

eval $RUNNER_CMD

exit $?
