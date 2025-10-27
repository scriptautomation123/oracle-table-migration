#!/usr/bin/env sh
# ===================================================================
# Runner - Executes PL/SQL executor with proper parameters
# ===================================================================
# Purpose: Execute PL/SQL executor with correct configuration
# Usage: ./runner.sh <mode> <owner> <table> [connection]
# ===================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLSQL_EXECUTOR="$SCRIPT_DIR/templates/executor.sql"

MODE="$1"
OWNER="$2"
TABLE="$3"
CONNECTION="$4"
SQL_CLIENT="${5:-sqlplus}"

# Validate arguments
if [ $# -lt 3 ]; then
    echo -e "${RED}ERROR: Missing required arguments${NC}"
    echo "Usage: $0 <mode> <owner> <table> [connection] [sql_client]"
    echo "  mode: GENERATE | EXECUTE | AUTO"
    echo "  owner: Schema owner"
    echo "  table: Table name"
    echo "  connection: Oracle connection string (optional)"
    echo "  sql_client: Path to sqlcl/sqlplus (optional, default: sqlplus)"
    exit 1
fi

# Find SQL client if not provided
if ! command -v "$SQL_CLIENT" >/dev/null 2>&1; then
    if [ "$SQL_CLIENT" = "sqlplus" ] && command -v sqlcl >/dev/null 2>&1; then
        SQL_CLIENT="sqlcl"
        echo -e "${YELLOW}Note: Using sqlcl instead of sqlplus${NC}"
    else
        echo -e "${RED}ERROR: SQL client '$SQL_CLIENT' not found${NC}"
        exit 1
    fi
fi

# Create output directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="output/migration_run_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"
LOG_FILE="$OUTPUT_DIR/runner.log"

echo -e "${BLUE}============================================================${NC}" | tee "$LOG_FILE"
echo -e "${BLUE}DDL RUNNER${NC}" | tee -a "$LOG_FILE"
echo -e "${BLUE}============================================================${NC}" | tee -a "$LOG_FILE"
echo "Mode: $MODE" | tee -a "$LOG_FILE"
echo "Owner: $OWNER" | tee -a "$LOG_FILE"
echo "Table: $TABLE" | tee -a "$LOG_FILE"
echo "Output: $OUTPUT_DIR" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Execute PL/SQL script
START_TIME=$(date +%s)

if [ -n "$CONNECTION" ]; then
    # With connection string
    if [ "$SQL_CLIENT" = "sqlcl" ]; then
        echo "BEGIN" | "$SQL_CLIENT" "$CONNECTION" > "$OUTPUT_DIR/executor.log" 2>&1 << EOF
        @$PLSQL_EXECUTOR $MODE $OWNER $TABLE
        EXIT;
EOF
    else
        echo "@$PLSQL_EXECUTOR $MODE $OWNER $TABLE" | "$SQL_CLIENT" -S "$CONNECTION" > "$OUTPUT_DIR/executor.log" 2>&1
    fi
else
    # Without connection string (assumes already connected)
    if [ "$SQL_CLIENT" = "sqlcl" ]; then
        echo "BEGIN" | "$SQL_CLIENT" > "$OUTPUT_DIR/executor.log" 2>&1 << EOF
        @$PLSQL_EXECUTOR $MODE $OWNER $TABLE
        EXIT;
EOF
    else
        echo "@$PLSQL_EXECUTOR $MODE $OWNER $TABLE" | "$SQL_CLIENT" -S > "$OUTPUT_DIR/executor.log" 2>&1
    fi
fi

EXIT_CODE=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Display results
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Execution completed successfully (${DURATION}s)${NC}" | tee -a "$LOG_FILE"
    echo "Output: $OUTPUT_DIR/executor.log" | tee -a "$LOG_FILE"
    
    # Check for success message
    if grep -q "STATUS: SUCCESS" "$OUTPUT_DIR/executor.log"; then
        echo -e "${GREEN}✓ Status: SUCCESS${NC}"
        exit 0
    else
        echo -e "${YELLOW}? Status: UNKNOWN${NC}"
        exit 2
    fi
else
    echo -e "${RED}✗ Execution failed (exit code: $EXIT_CODE)${NC}" | tee -a "$LOG_FILE"
    echo "See: $OUTPUT_DIR/executor.log" | tee -a "$LOG_FILE"
    exit 1
fi
