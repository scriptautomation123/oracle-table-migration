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

while [[ ${attempt} -lt ${max_attempts} ]]; do
	sqlplus_output=$(sqlplus -s hr/hr123@oracle:1521/FREEPDB1 <<<"SELECT 'DB_READY' FROM DUAL;" 2>&1)
	if echo "${sqlplus_output}" | grep -q "DB_READY"; then
		echo "✓ Oracle database is ready"
		break
	fi
	attempt=$((attempt + 1))
	echo "  Waiting for database... (attempt ${attempt}/${max_attempts})"
	sleep 10
done

if [[ ${attempt} -eq ${max_attempts} ]]; then
	echo "✗ Failed to connect to Oracle database"
	exit 1
fi

# Install Python requirements
echo ""
echo "Installing Python dependencies..."
if [[ -f /workspace/table_migration/requirements.txt ]]; then
	pip3 install --user -r /workspace/table_migration/requirements.txt
	echo "✓ Python dependencies installed"
fi

# Create tnsnames.ora for easy connections
echo ""
echo "Creating tnsnames.ora..."
mkdir -p ~/oracle
cat >~/oracle/tnsnames.ora <<EOF
FREEPDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oracle)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = FREEPDB1)
    )
  )
EOF

export TNS_ADMIN=~/oracle
echo "export TNS_ADMIN=~/oracle" >>~/.bashrc
echo "✓ tnsnames.ora created at ~/oracle/tnsnames.ora"

# Test connections
echo ""
echo "Testing database connections..."
echo "  HR schema:"
sqlplus -s hr/hr123@oracle:1521/FREEPDB1 <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF
SELECT '    ✓ Connected as HR' FROM DUAL;
EXIT;
EOF

echo "  HR_APP_USER schema:"
sqlplus -s hr_app_user/hrapp123@oracle:1521/FREEPDB1 <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF
SELECT '    ✓ Connected as HR_APP_USER' FROM DUAL;
EXIT;
EOF

# Display test data summary
echo ""
echo "=========================================="
echo "Test Environment Ready!"
echo "=========================================="
echo ""
echo "Database Credentials:"
echo "  System:      sys/Oracle123!@oracle:1521/FREEPDB1 as sysdba"
echo "  HR:          hr/hr123@oracle:1521/FREEPDB1"
echo "  HR_APP_USER: hr_app_user/hrapp123@oracle:1521/FREEPDB1"
echo ""
echo "Connection String Format:"
echo "  hr/hr123@oracle:1521/FREEPDB1"
echo ""
echo "Test Tables Created:"
sqlplus -s hr/hr123@oracle:1521/FREEPDB1 <<EOF
SET PAGESIZE 50 FEEDBACK OFF
SELECT '  HR.' || table_name || 
       ' (' || NVL(TO_CHAR(num_rows, '999,999,999'), 'NO STATS') || ' rows)' as "Test Tables"
FROM user_tables
ORDER BY table_name;
EXIT;
EOF

echo ""
echo "Verifying HR_APP_USER can access HR tables:"
sqlplus -s hr_app_user/hrapp123@oracle:1521/FREEPDB1 <<EOF
SET PAGESIZE 50 FEEDBACK OFF
SELECT '  HR.' || table_name || ' (accessible)' as "Accessible Tables"
FROM all_tables 
WHERE owner = 'HR'
ORDER BY table_name;
EXIT;
EOF

echo ""
echo "Quick Start Commands:"
echo "  cd /workspace/table_migration"
echo "  python3 02_generator/generate_scripts.py --discover --schema HR --connection hr/hr123@oracle:1521/FREEPDB1"
echo ""
echo "=========================================="
