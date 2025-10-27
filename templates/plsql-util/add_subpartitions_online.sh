#!/usr/bin/env sh
# shellcheck disable=SC3037,SC2034
# ===================================================================
# Online Subpartition Addition
# ===================================================================
# Purpose: Add hash subpartitions to an interval-partitioned table online
# Usage: ./add_subpartitions_online.sh <owner> <table> <subpart_col> <subpart_count> <connection>
# Example: ./add_subpartitions_online.sh APP_DATA_OWNER AUDIT_LOG USER_ID 8 "system/Oracle123@localhost:1521/FREEPDB1 AS SYSDBA"
# ===================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
OWNER="${1}"
TABLE="${2}"
SUBPART_COL="${3}"
SUBPART_COUNT="${4:-8}"
CONNECTION="${5}"

if [ -z "${OWNER}" ] || [ -z "${TABLE}" ] || [ -z "${SUBPART_COL}" ] || [ -z "${CONNECTION}" ]; then
    echo -e "${RED}ERROR: Missing required arguments${NC}"
    echo "Usage: $0 <owner> <table> <subpart_col> [subpart_count] <connection>"
    echo "Example: $0 APP_DATA_OWNER AUDIT_LOG USER_ID 8 'system/Oracle123@localhost:1521/FREEPDB1 AS SYSDBA'"
    exit 1
fi

# Script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLSQL_UTIL="${SCRIPT_DIR}/plsql-util.sql"

# Find SQL client
if command -v sqlcl >/dev/null 2>&1; then
    SQL_CLIENT="sqlcl"
else
    SQL_CLIENT="sqlplus"
fi

echo -e "${CYAN}====================================================================${NC}"
echo -e "${CYAN}ONLINE SUBPARTITION ADDITION${NC}"
echo -e "${CYAN}====================================================================${NC}"
echo "Owner: ${OWNER}"
echo "Table: ${TABLE}"
echo "Subpartition Column: ${SUBPART_COL}"
echo "Subpartition Count: ${SUBPART_COUNT}"
echo "SQL Client: ${SQL_CLIENT}"
echo ""

# Check table exists and is partitioned
echo -e "${YELLOW}Step 1: Validate Table${NC}"
LOG_FILE="/tmp/add_subpart_validate_$$.log"

if [ "${SQL_CLIENT}" = "sqlcl" ]; then
    echo "@${PLSQL_UTIL} READONLY CHECK_TABLE_STRUCTURE ${OWNER} ${TABLE}" | sqlcl "${CONNECTION}" >"${LOG_FILE}" 2>&1
else
    echo "@${PLSQL_UTIL} READONLY CHECK_TABLE_STRUCTURE ${OWNER} ${TABLE}" | sqlplus -S "${CONNECTION}" >"${LOG_FILE}" 2>&1
fi

if [ $? -ne 0 ] || grep -q "FAILED" "${LOG_FILE}"; then
    echo -e "${RED}✗ Table validation failed${NC}"
    cat "${LOG_FILE}"
    rm -f "${LOG_FILE}"
    exit 1
fi

echo -e "${GREEN}✓ Table exists and is partitioned${NC}"
rm -f "${LOG_FILE}"

# Show current partition distribution
echo ""
echo -e "${YELLOW}Step 2: Current Partition Distribution${NC}"

if [ "${SQL_CLIENT}" = "sqlcl" ]; then
    echo "@${PLSQL_UTIL} READONLY CHECK_PARTITION_DIST ${OWNER} ${TABLE}" | sqlcl "${CONNECTION}"
else
    echo "@${PLSQL_UTIL} READONLY CHECK_PARTITION_DIST ${OWNER} ${TABLE}" | sqlplus -S "${CONNECTION}"
fi

# Add hash subpartitions using plsql-util
echo ""
echo -e "${YELLOW}Step 3: Add Hash Subpartitions${NC}"
echo "Adding ${SUBPART_COUNT} hash subpartitions on column ${SUBPART_COL}..."

LOG_FILE="/tmp/add_subpart_$$.log"

if [ "${SQL_CLIENT}" = "sqlcl" ]; then
    echo "@${PLSQL_UTIL} WORKFLOW ADD_HASH_SUBPARTITIONS ${OWNER} ${TABLE} ${SUBPART_COL} ${SUBPART_COUNT}" | sqlcl "${CONNECTION}" >"${LOG_FILE}" 2>&1
else
    echo "@${PLSQL_UTIL} WORKFLOW ADD_HASH_SUBPARTITIONS ${OWNER} ${TABLE} ${SUBPART_COL} ${SUBPART_COUNT}" | sqlplus -S "${CONNECTION}" >"${LOG_FILE}" 2>&1
fi

if [ $? -ne 0 ] || grep -q "FAILED\|ERROR" "${LOG_FILE}"; then
    echo -e "${RED}✗ Failed to add subpartitions${NC}"
    cat "${LOG_FILE}"
    rm -f "${LOG_FILE}"
    exit 1
fi

echo -e "${GREEN}✓ Subpartitions added successfully${NC}"
cat "${LOG_FILE}"
rm -f "${LOG_FILE}"

# Show updated partition distribution
echo ""
echo -e "${YELLOW}Step 4: Updated Partition Distribution${NC}"

if [ "${SQL_CLIENT}" = "sqlcl" ]; then
    echo "@${PLSQL_UTIL} READONLY CHECK_PARTITION_DIST ${OWNER} ${TABLE}" | sqlcl "${CONNECTION}"
else
    echo "@${PLSQL_UTIL} READONLY CHECK_PARTITION_DIST ${OWNER} ${TABLE}" | sqlplus -S "${CONNECTION}"
fi

echo ""
echo -e "${CYAN}====================================================================${NC}"
echo -e "${GREEN}ONLINE SUBPARTITION ADDITION COMPLETE${NC}"
echo -e "${CYAN}====================================================================${NC}"
echo "Table: ${OWNER}.${TABLE}"
echo "Added ${SUBPART_COUNT} hash subpartitions on ${SUBPART_COL}"
echo ""

