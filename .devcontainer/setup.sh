#!/bin/bash
# Post-create setup script for dev container

set -e

echo "=========================================="
echo "Setting up development environment..."
echo "=========================================="

# Wait for Oracle to be ready
echo "Waiting for Oracle database to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if sqlplus -s hr/hr123@oracle:1521/XEPDB1 <<< "SELECT 'DB_READY' FROM DUAL;" | grep -q "DB_READY"; then
        echo "✓ Oracle database is ready"
        break
    fi
    attempt=$((attempt + 1))
    echo "  Waiting for database... (attempt $attempt/$max_attempts)"
    sleep 10
done

if [ $attempt -eq $max_attempts ]; then
    echo "✗ Failed to connect to Oracle database"
    exit 1
fi

# Install Python requirements
echo ""
echo "Installing Python dependencies..."
if [ -f /workspace/table_migration/requirements.txt ]; then
    pip3 install --user -r /workspace/table_migration/requirements.txt
    echo "✓ Python dependencies installed"
fi

# Create tnsnames.ora for easy connections
echo ""
echo "Creating tnsnames.ora..."
mkdir -p ~/oracle
cat > ~/oracle/tnsnames.ora <<EOF
XEPDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oracle)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = XEPDB1)
    )
  )
EOF

export TNS_ADMIN=~/oracle
echo "export TNS_ADMIN=~/oracle" >> ~/.bashrc
echo "✓ tnsnames.ora created at ~/oracle/tnsnames.ora"

# Test connections
echo ""
echo "Testing database connections..."
echo "  HR schema:"
sqlplus -s hr/hr123@oracle:1521/XEPDB1 <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF
SELECT '    ✓ Connected as HR' FROM DUAL;
EXIT;
EOF

echo "  HR_APP schema:"
sqlplus -s hr_app/hrapp123@oracle:1521/XEPDB1 <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF
SELECT '    ✓ Connected as HR_APP' FROM DUAL;
EXIT;
EOF

# Display test data summary
echo ""
echo "=========================================="
echo "Test Environment Ready!"
echo "=========================================="
echo ""
echo "Database Credentials:"
echo "  System:  sys/Oracle123!@oracle:1521/XEPDB1 as sysdba"
echo "  HR:      hr/hr123@oracle:1521/XEPDB1"
echo "  HR_APP:  hr_app/hrapp123@oracle:1521/XEPDB1"
echo ""
echo "Connection String Format:"
echo "  hr/hr123@oracle:1521/XEPDB1"
echo ""
echo "Test Tables Created:"
sqlplus -s hr/hr123@oracle:1521/XEPDB1 <<EOF
SET PAGESIZE 50 FEEDBACK OFF
SELECT '  HR.' || table_name || 
       ' (' || NVL(TO_CHAR(num_rows, '999,999,999'), 'NO STATS') || ' rows)' as "Test Tables"
FROM user_tables
ORDER BY table_name;
EXIT;
EOF

sqlplus -s hr_app/hrapp123@oracle:1521/XEPDB1 <<EOF
SET PAGESIZE 50 FEEDBACK OFF
SELECT '  HR_APP.' || table_name || 
       ' (' || NVL(TO_CHAR(num_rows, '999,999,999'), 'NO STATS') || ' rows)' as "Test Tables"
FROM user_tables
ORDER BY table_name;
EXIT;
EOF

echo ""
echo "Quick Start Commands:"
echo "  cd /workspace/table_migration"
echo "  python3 02_generator/generate_scripts.py --discover --schema HR --connection hr/hr123@oracle:1521/XEPDB1"
echo ""
echo "=========================================="
