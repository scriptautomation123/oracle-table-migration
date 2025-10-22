#!/bin/bash
# Oracle Performance Monitoring Script for Codespaces
# This script monitors both system and Oracle database performance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Oracle Performance Monitor${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Function to print section headers
print_header() {
	echo -e "\n${GREEN}=== $1 ===${NC}\n"
}

# Function to check if Oracle is running
check_oracle() {
	local docker_output
	docker_output=$(docker ps)
	if echo "${docker_output}" | grep -q oracle-test-db; then
		echo -e "${GREEN}✓ Oracle container is running${NC}"
		return 0
	else
		echo -e "${RED}✗ Oracle container is not running${NC}"
		return 1
	fi
}

# System Resources
print_header "System Resources"
echo -e "${YELLOW}CPU Cores:${NC}"
nproc
echo ""

echo -e "${YELLOW}Memory (GB):${NC}"
free -h | awk 'NR==2{printf "Total: %s\nUsed: %s (%.2f%%)\nFree: %s\n", $2,$3,$3*100/$2,$4}' || true
echo ""

echo -e "${YELLOW}Disk Space:${NC}"
df -h / | awk 'NR==2{printf "Total: %s\nUsed: %s (%s)\nAvailable: %s\n", $2,$3,$5,$4}' || true
echo ""

# Docker Container Resources
print_header "Docker Container Resources"
check_oracle
oracle_running=$?
if [[ ${oracle_running} -eq 0 ]]; then
	echo -e "${YELLOW}Container Statistics (5 second sample):${NC}"
	docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" oracle-test-db workspace
	echo ""
fi

# Oracle Database Status
check_oracle
oracle_running=$?
if [[ ${oracle_running} -eq 0 ]]; then
	print_header "Oracle Database Status"

	# Check if database is ready
	if docker exec oracle-test-db healthcheck.sh >/dev/null 2>&1; then
		echo -e "${GREEN}✓ Oracle database is healthy${NC}"

		# Get database info
		echo -e "\n${YELLOW}Database Information:${NC}"
		docker exec oracle-test-db sqlplus -s sys/Oracle123!@XEPDB1 as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200
SET FEEDBACK OFF

SELECT 'Database Name: ' || name FROM v\$database;
SELECT 'Instance Name: ' || instance_name || ' (Status: ' || status || ')' FROM v\$instance;
SELECT 'Open Mode: ' || open_mode FROM v\$database;
SELECT 'Startup Time: ' || TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') FROM v\$instance;
SELECT 'Current SCN: ' || current_scn FROM v\$database;

EXIT;
EOF

		# SGA and PGA Information
		print_header "Memory Configuration (SGA/PGA)"
		docker exec oracle-test-db sqlplus -s sys/Oracle123!@XEPDB1 as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

SELECT 
    name,
    ROUND(value/1024/1024, 2) AS value_mb
FROM v\$sga
ORDER BY value DESC;

SELECT 
    ROUND(value/1024/1024, 2) AS pga_aggregate_mb
FROM v\$pgastat 
WHERE name = 'aggregate PGA target parameter';

EXIT;
EOF

		# Active Sessions
		print_header "Active Sessions"
		docker exec oracle-test-db sqlplus -s sys/Oracle123!@XEPDB1 as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

SELECT 
    COUNT(*) as total_sessions,
    COUNT(CASE WHEN status = 'ACTIVE' THEN 1 END) as active_sessions,
    COUNT(CASE WHEN username IS NOT NULL THEN 1 END) as user_sessions
FROM v\$session;

COLUMN username FORMAT A15
COLUMN status FORMAT A10
COLUMN event FORMAT A35
COLUMN wait_sec FORMAT 999999

SELECT 
    sid,
    serial#,
    username,
    status,
    event,
    seconds_in_wait as wait_sec
FROM v\$session
WHERE username IS NOT NULL
AND status = 'ACTIVE'
ORDER BY seconds_in_wait DESC
FETCH FIRST 10 ROWS ONLY;

EXIT;
EOF

		# Tablespace Usage
		print_header "Tablespace Usage"
		docker exec oracle-test-db sqlplus -s sys/Oracle123!@XEPDB1 as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

COLUMN tablespace_name FORMAT A20
COLUMN used_mb FORMAT 99999.99
COLUMN total_mb FORMAT 99999.99
COLUMN used_pct FORMAT 999.99

SELECT 
    tablespace_name,
    ROUND(used_space * 8192 / 1024 / 1024, 2) AS used_mb,
    ROUND(tablespace_size * 8192 / 1024 / 1024, 2) AS total_mb,
    ROUND(used_percent, 2) AS used_pct
FROM dba_tablespace_usage_metrics
ORDER BY used_percent DESC;

EXIT;
EOF

		# Top SQL by Elapsed Time
		print_header "Top SQL Statements (by Elapsed Time)"
		docker exec oracle-test-db sqlplus -s sys/Oracle123!@XEPDB1 as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

COLUMN sql_id FORMAT A15
COLUMN executions FORMAT 999999
COLUMN elapsed_sec FORMAT 999999.99
COLUMN cpu_sec FORMAT 999999.99
COLUMN rows_proc FORMAT 9999999

SELECT 
    sql_id,
    executions,
    ROUND(elapsed_time/1000000, 2) as elapsed_sec,
    ROUND(cpu_time/1000000, 2) as cpu_sec,
    rows_processed as rows_proc
FROM v\$sql
WHERE elapsed_time > 1000000
ORDER BY elapsed_time DESC
FETCH FIRST 10 ROWS ONLY;

EXIT;
EOF

		# Wait Events
		print_header "Top Wait Events (excluding Idle)"
		docker exec oracle-test-db sqlplus -s sys/Oracle123!@XEPDB1 as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

COLUMN event FORMAT A40
COLUMN total_waits FORMAT 9999999
COLUMN time_sec FORMAT 99999.99
COLUMN avg_wait_ms FORMAT 9999.99

SELECT 
    event,
    total_waits,
    ROUND(time_waited_micro/1000000, 2) as time_sec,
    ROUND(average_wait, 2) as avg_wait_ms
FROM v\$system_event
WHERE wait_class != 'Idle'
ORDER BY time_waited_micro DESC
FETCH FIRST 10 ROWS ONLY;

EXIT;
EOF

		# Partition Information (if HR schema has partitioned tables)
		print_header "Partition Information"
		docker exec oracle-test-db sqlplus -s hr/hr123@XEPDB1 <<EOF
SET PAGESIZE 100
SET LINESIZE 200

SELECT COUNT(*) as total_partitioned_tables
FROM user_tables
WHERE partitioned = 'YES';

COLUMN table_name FORMAT A30
COLUMN partition_count FORMAT 9999

SELECT 
    table_name,
    COUNT(*) as partition_count
FROM user_tab_partitions
GROUP BY table_name
ORDER BY partition_count DESC;

EXIT;
EOF

	else
		echo -e "${YELLOW}⚠ Oracle database is starting up...${NC}"
	fi
else
	echo -e "${RED}Oracle container is not running. Start it with:${NC}"
	echo -e "${YELLOW}docker compose -f .devcontainer/docker-compose.yml up -d${NC}"
fi

# Performance Recommendations
print_header "Performance Recommendations"
echo -e "${YELLOW}Based on current resource allocation:${NC}"
echo ""
echo "1. Oracle SGA is set to 8GB - ensure queries leverage buffer cache"
echo "2. Consider using parallel execution for large data operations"
echo "3. Monitor wait events for I/O bottlenecks"
echo "4. Use EXPLAIN PLAN before running large migrations"
echo "5. Enable statistics gathering: EXEC DBMS_STATS.GATHER_SCHEMA_STATS('HR')"
echo ""

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Monitoring complete!${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""
echo -e "To continuously monitor, run: ${YELLOW}watch -n 5 bash .devcontainer/monitor-performance.sh${NC}"
echo ""
