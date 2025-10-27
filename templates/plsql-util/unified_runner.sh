#!/usr/bin/env sh
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
        Linux*)     OS=linux;;
        Darwin*)    OS=macos;;
        MINGW*|CYGWIN*|MSYS*) OS=windows;;
        *)          OS=unknown;;
    esac
}

# Find SQL client
find_sql_client() {
    if [ -n "$SQL_CLIENT_ARG" ]; then
        SQL_CLIENT="$SQL_CLIENT_ARG"
        return
    fi
    
    if [ "$EXPLICIT_CLIENT" = "sqlcl" ] && command -v sqlcl >/dev/null 2>&1; then
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
    
    echo "${RED}ERROR: No SQL client found. Please install sqlcl or sqlplus${NC}" >&2
    exit 1
}

# Create output directory
create_output_dir() {
    if [ -z "$OUTPUT_DIR" ]; then
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        if [ "$TYPE" = "validation" ]; then
            OUTPUT_DIR="output/validation_run_${TIMESTAMP}"
        else
            OUTPUT_DIR="output/migration_run_${TIMESTAMP}"
        fi
    fi
    
    mkdir -p "$OUTPUT_DIR"
    LOG_FILE="$OUTPUT_DIR/runner.log"
    
    if [ "$VERBOSE" = true ]; then
        echo "${BLUE}Output directory: $OUTPUT_DIR${NC}"
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
    SQL_SCRIPT="$SCRIPT_DIR/plsql-util.sql"
    
    echo -e "${BLUE}============================================================${NC}" | tee "$LOG_FILE"
    echo -e "${BLUE}VALIDATION RUNNER${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}============================================================${NC}" | tee -a "$LOG_FILE"
    echo "Operation: $OPERATION" | tee -a "$LOG_FILE"
    echo "Script: $SQL_SCRIPT" | tee -a "$LOG_FILE"
    echo "Connection: $CONNECTION" | tee -a "$LOG_FILE"
    echo "Output: $OUTPUT_DIR" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    # Build command with category detection
    # Determine category based on operation
    case "$OPERATION" in
        check_sessions|check_existence|check_structure|count_rows|check_constraints|check_partitions)
            CATEGORY="READONLY"
            ;;
        enable_constraints|disable_constraints)
            CATEGORY="WRITE"
            ;;
        pre_swap|post_swap|post_create|post_load)
            CATEGORY="WORKFLOW"
            ;;
        drop|rename)
            CATEGORY="CLEANUP"
            ;;
        *)
            CATEGORY="READONLY"
            ;;
    esac
    
    # Build command
    if [ "$SQL_CLIENT" = "sqlcl" ]; then
        CMD="echo '@$SQL_SCRIPT $CATEGORY $OPERATION $ARGS' | sqlcl '$CONNECTION'"
    else
        CMD="echo '@$SQL_SCRIPT $CATEGORY $OPERATION $ARGS' | sqlplus -S '$CONNECTION'"
    fi
    
    echo "Executing validation..." | tee -a "$LOG_FILE"
    
    # Execute
    START_TIME=$(date +%s)
    
    if eval "$CMD" > "$OUTPUT_DIR/validation_output.log" 2>&1; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        
        echo -e "${GREEN}✓ Validation completed (${DURATION}s)${NC}" | tee -a "$LOG_FILE"
        
        # Parse results
        if grep -q "VALIDATION RESULT: PASSED" "$OUTPUT_DIR/validation_output.log"; then
            echo -e "${GREEN}✓ Result: PASSED${NC}"
            exit 0
        elif grep -q "VALIDATION RESULT: FAILED" "$OUTPUT_DIR/validation_output.log"; then
            echo -e "${RED}✗ Result: FAILED${NC}"
            exit 1
        else
            echo -e "${YELLOW}? Result: UNKNOWN${NC}"
            exit 2
        fi
    else
        echo -e "${RED}✗ Validation failed${NC}" | tee -a "$LOG_FILE"
        echo "See: $OUTPUT_DIR/validation_output.log" | tee -a "$LOG_FILE"
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
    PLSQL_UTIL="$SCRIPT_DIR/plsql-util.sql"
    
    echo -e "${BLUE}============================================================${NC}" | tee "$LOG_FILE"
    echo -e "${BLUE}MIGRATION RUNNER${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}============================================================${NC}" | tee -a "$LOG_FILE"
    echo "Mode: $MODE" | tee -a "$LOG_FILE"
    echo "Owner: $OWNER" | tee -a "$LOG_FILE"
    echo "Table: $TABLE" | tee -a "$LOG_FILE"
    echo "Connection: $CONNECTION" | tee -a "$LOG_FILE"
    echo "Output: $OUTPUT_DIR" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    # Execute
    START_TIME=$(date +%s)
    
    # Migration operations use WORKFLOW category
    if [ "$SQL_CLIENT" = "sqlcl" ]; then
        echo "@$PLSQL_UTIL WORKFLOW $MODE $OWNER $TABLE" | sqlcl "$CONNECTION" > "$OUTPUT_DIR/migration.log" 2>&1
    else
        echo "@$PLSQL_UTIL WORKFLOW $MODE $OWNER $TABLE" | sqlplus -S "$CONNECTION" > "$OUTPUT_DIR/migration.log" 2>&1
    fi
    
    EXIT_CODE=$?
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ Migration completed (${DURATION}s)${NC}" | tee -a "$LOG_FILE"
        
        if grep -q "RESULT: PASSED" "$OUTPUT_DIR/migration.log"; then
            echo -e "${GREEN}✓ Status: SUCCESS${NC}"
            exit 0
        else
            echo -e "${YELLOW}? Status: UNKNOWN${NC}"
            exit 2
        fi
    else
        echo -e "${RED}✗ Migration failed (exit code: $EXIT_CODE)${NC}" | tee -a "$LOG_FILE"
        echo "See: $OUTPUT_DIR/migration.log" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Main
detect_os

TYPE="${1:-validation}"
shift || true

case "$TYPE" in
    validation)
        CONNECTION="${1}"
        OPERATION="${2}"
        shift 2 || true
        execute_validation "$OPERATION" "$@"
        ;;
    migration)
        MODE="${1}"
        OWNER="${2}"
        TABLE="${3}"
        CONNECTION="${4}"
        execute_migration "$MODE" "$OWNER" "$TABLE" "$CONNECTION"
        ;;
    *)
        echo "Usage: $0 <type> [args...]"
        echo "  type: validation | migration"
        echo ""
        echo "For validation:"
        echo "  $0 validation <connection> <operation> [args...]"
        echo ""
        echo "For migration:"
        echo "  $0 migration <mode> <owner> <table> <connection>"
        exit 1
        ;;
esac
