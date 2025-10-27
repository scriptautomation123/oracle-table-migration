#!/usr/bin/env sh
# ===================================================================
# Validation Runner - Cross-Platform SQL Execution
# ===================================================================
# Purpose: Execute validation SQL scripts with proper error handling
# Platforms: Linux, macOS, Windows (via Git Bash/WSL)
# ===================================================================

set -e  # Exit on error

# Colors for output (cross-platform compatible)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATION_SCRIPT=""
OPERATION=""
ARGS=""
ORACLE_CONN=""
SQLCL_OR_SQLPLUS=""
OUTPUT_DIR=""
LOG_FILE=""
VERBOSE=false

# Parse arguments
parse_args() {
    while [ $# -gt 0 ]; do
        case $1 in
            --script)
                VALIDATION_SCRIPT="$2"
                shift 2
                ;;
            --operation)
                OPERATION="$2"
                shift 2
                ;;
            --connection)
                ORACLE_CONN="$2"
                shift 2
                ;;
            --sql-client)
                SQLCL_OR_SQLPLUS="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --)
                shift
                ARGS="$*"
                break
                ;;
            *)
                ARGS="$ARGS $1"
                shift
                ;;
        esac
    done
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS=linux;;
        Darwin*)    OS=macos;;
        MINGW*|CYGWIN*|MSYS*) OS=windows;;
        *)          OS=unknown;;
    esac
}

# Find sql client
find_sql_client() {
    if [ -n "$SQLCL_OR_SQLPLUS" ]; then
        SQL_CLIENT="$SQLCL_OR_SQLPLUS"
        return
    fi
    
    # Try sqlcl first
    if command -v sqlcl >/dev/null 2>&1; then
        SQL_CLIENT="sqlcl"
        return
    fi
    
    # Try sqlplus
    if command -v sqlplus >/dev/null 2>&1; then
        SQL_CLIENT="sqlplus"
        return
    fi
    
    echo "${RED}ERROR: No SQL client found. Please install sqlcl or sqlplus${NC}" >&2
    exit 1
}

# Create output directory
create_output_dir() {
    if [ -z "$OUTPUT_DIR" ]; then
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        OUTPUT_DIR="output/validation_run_${TIMESTAMP}"
    fi
    
    mkdir -p "$OUTPUT_DIR"
    LOG_FILE="$OUTPUT_DIR/validation.log"
    
    if [ "$VERBOSE" = true ]; then
        echo "${BLUE}Output directory: $OUTPUT_DIR${NC}"
    fi
}

# Log function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Print colored output
print_status() {
    local color="$1"
    shift
    echo -e "${color}$*${NC}" | tee -a "$LOG_FILE"
}

# Execute validation script
execute_validation() {
    if [ -z "$VALIDATION_SCRIPT" ]; then
        print_status "$RED" "ERROR: --script is required"
        exit 1
    fi
    
    if [ -z "$ORACLE_CONN" ]; then
        print_status "$RED" "ERROR: --connection is required"
        exit 1
    fi
    
    find_sql_client
    create_output_dir
    
    # Resolve script path
    if [ ! -f "$VALIDATION_SCRIPT" ]; then
        VALIDATION_SCRIPT="$SCRIPT_DIR/$VALIDATION_SCRIPT"
    fi
    
    if [ ! -f "$VALIDATION_SCRIPT" ]; then
        print_status "$RED" "ERROR: Validation script not found: $VALIDATION_SCRIPT"
        exit 1
    fi
    
    print_status "$BLUE" "============================================================"
    print_status "$BLUE" "VALIDATION RUNNER"
    print_status "$BLUE" "============================================================"
    log "INFO" "Script: $VALIDATION_SCRIPT"
    log "INFO" "Operation: $OPERATION"
    log "INFO" "Connection: $ORACLE_CONN"
    log "INFO" "SQL Client: $SQL_CLIENT"
    log "INFO" "Output Directory: $OUTPUT_DIR"
    log "INFO" "Args: $ARGS"
    
    # Build command
    if [ "$SQL_CLIENT" = "sqlcl" ]; then
        CMD="echo '@$VALIDATION_SCRIPT $OPERATION $ARGS' | sqlcl $ORACLE_CONN"
    else
        CMD="echo '@$VALIDATION_SCRIPT $OPERATION $ARGS' | sqlplus -S $ORACLE_CONN"
    fi
    
    print_status "$BLUE" "Executing validation..."
    
    # Execute and capture output
    START_TIME=$(date +%s)
    
    if $CMD > "$OUTPUT_DIR/validation_output.log" 2>&1; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        
        print_status "$GREEN" "✓ Validation completed successfully"
        log "SUCCESS" "Duration: ${DURATION}s"
        
        # Parse results
        if grep -q "VALIDATION RESULT: PASSED" "$OUTPUT_DIR/validation_output.log"; then
            print_status "$GREEN" "✓ Result: PASSED"
            exit 0
        elif grep -q "VALIDATION RESULT: FAILED" "$OUTPUT_DIR/validation_output.log"; then
            print_status "$RED" "✗ Result: FAILED"
            exit 1
        else
            print_status "$YELLOW" "? Result: UNKNOWN"
            exit 2
        fi
    else
        print_status "$RED" "✗ Validation execution failed"
        log "ERROR" "See $OUTPUT_DIR/validation_output.log for details"
        exit 1
    fi
}

# Main
main() {
    detect_os
    parse_args "$@"
    
    if [ $# -eq 0 ]; then
        echo "Usage: $0 --script <script> --operation <operation> --connection <connection> [args...]"
        echo "  --script <file>        Validation SQL script to execute"
        echo "  --operation <name>     Operation name (e.g., check_existence)"
        echo "  --connection <conn>    Oracle connection string"
        echo "  --sql-client <path>    Path to sqlcl or sqlplus (optional)"
        echo "  --output-dir <path>    Output directory (optional)"
        echo "  --verbose              Enable verbose output"
        echo ""
        echo "Example:"
        echo "  $0 --script 01_validator.sql --operation check_existence --connection 'user/pass@host:port/service' -- 'OWNER' 'TABLE_NAME'"
        exit 1
    fi
    
    execute_validation
}

main "$@"
