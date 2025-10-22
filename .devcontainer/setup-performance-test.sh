#!/bin/bash
# Performance Test Setup Script
# Automatically configures Oracle for optimal performance testing

set -e

echo "======================================"
echo "Oracle Performance Test Setup"
echo "======================================"
echo ""

# Wait for Oracle to be ready
echo "Waiting for Oracle database to be ready..."
while ! docker exec oracle-test-db healthcheck.sh > /dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo ""
echo "✓ Oracle database is ready!"
echo ""

# Apply performance tuning parameters
echo "Applying performance tuning parameters..."
docker exec oracle-test-db sqlplus -s sys/Oracle123!@XEPDB1 as sysdba <<EOF
-- Set optimal parameters for performance testing
ALTER SYSTEM SET optimizer_mode='ALL_ROWS' SCOPE=BOTH;
ALTER SYSTEM SET parallel_max_servers=16 SCOPE=BOTH;
ALTER SYSTEM SET parallel_min_servers=4 SCOPE=BOTH;
ALTER SYSTEM SET optimizer_index_cost_adj=100 SCOPE=BOTH;
ALTER SYSTEM SET commit_write='BATCH,NOWAIT' SCOPE=BOTH;
ALTER SYSTEM SET deferred_segment_creation=FALSE SCOPE=BOTH;

-- Grant necessary privileges to HR user for performance testing
GRANT UNLIMITED TABLESPACE TO hr;
GRANT SELECT ANY DICTIONARY TO hr;
GRANT CREATE ANY TABLE TO hr;
GRANT DROP ANY TABLE TO hr;
GRANT ALTER ANY TABLE TO hr;
GRANT CREATE ANY INDEX TO hr;
GRANT DROP ANY INDEX TO hr;

-- Gather schema statistics
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('HR');

SELECT 'Configuration complete!' FROM DUAL;
EXIT;
EOF

echo ""
echo "✓ Performance tuning applied successfully!"
echo ""

# Display current configuration
echo "Current Oracle Configuration:"
docker exec oracle-test-db sqlplus -s sys/Oracle123!@XEPDB1 as sysdba <<EOF
SET LINESIZE 200
SELECT name, value FROM v\$parameter 
WHERE name IN (
    'optimizer_mode',
    'parallel_max_servers',
    'parallel_min_servers',
    'optimizer_index_cost_adj',
    'commit_write',
    'deferred_segment_creation'
)
ORDER BY name;
EXIT;
EOF

echo ""
echo "======================================"
echo "Setup Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Run: bash .devcontainer/monitor-performance.sh"
echo "2. Generate test data: python generate_scripts.py"
echo "3. Execute migration scripts and monitor performance"
echo ""
