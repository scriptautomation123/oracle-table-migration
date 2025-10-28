# INSTEAD OF Trigger on View - SQL*Plus Command Line Guide

## Overview
This guide shows how to run the `CREATE_RENAMED_VIEW` operation using SQL*Plus from the command line, both as a regular user and as SYSDBA. This operation creates a migration view with INSTEAD OF triggers for seamless table migration.

## Prerequisites

### Required Tables
Before running the operation, you need:
1. **Original table** (e.g., `MYSCHEMA.MYTABLE`)
2. **New table** (e.g., `MYSCHEMA.MYTABLE_NEW`) - with data loaded
3. **Old table** (e.g., `MYSCHEMA.MYTABLE_OLD`) - backup of original

### Table Structure Requirements
- **Primary Key**: The NEW table MUST have a primary key for deduplication
- **Same Schema**: All tables must be in the same schema
- **Compatible Structure**: Tables should have compatible column structures

## Command Line Execution

### Method 1: Using unified_runner.sh (Recommended)

#### Regular User Connection:
```bash
# Basic usage
./unified_runner.sh workflow "username/password@host:port/service" create_renamed_view SCHEMA TABLE

# Example
./unified_runner.sh workflow "hr/hr@localhost:1521/XE" create_renamed_view HR EMPLOYEES
```

#### SYSDBA Connection:
```bash
# SYSDBA automatically uses '/ as sysdba'
./unified_runner.sh workflow "" create_renamed_view HR EMPLOYEES

# Or explicitly specify SYSDBA
./unified_runner.sh workflow "/ as sysdba" create_renamed_view HR EMPLOYEES
```

### Method 2: Direct SQL*Plus Execution

#### Regular User Connection:
```bash
# Create a parameter file
cat > create_view_params.sql << 'EOF'
DEFINE category = 'WORKFLOW'
DEFINE operation = 'create_renamed_view'
DEFINE arg3 = 'HR'
DEFINE arg4 = 'EMPLOYEES'
DEFINE arg5 = ''
DEFINE arg6 = ''
DEFINE arg7 = ''
EOF

# Execute with SQL*Plus
sqlplus -S hr/hr@localhost:1521/XE @templates/plsql-util/plsql-util.sql @create_view_params.sql
```

#### SYSDBA Connection:
```bash
# Create a parameter file for SYSDBA
cat > create_view_sysdba.sql << 'EOF'
DEFINE category = 'WORKFLOW'
DEFINE operation = 'create_renamed_view'
DEFINE arg3 = 'HR'
DEFINE arg4 = 'EMPLOYEES'
DEFINE arg5 = ''
DEFINE arg6 = ''
DEFINE arg7 = ''
EOF

# Execute as SYSDBA
sqlplus -S "/ as sysdba" @templates/plsql-util/plsql-util.sql @create_view_sysdba.sql
```

### Method 3: Inline Parameters

#### Regular User:
```bash
sqlplus -S hr/hr@localhost:1521/XE @templates/plsql-util/plsql-util.sql WORKFLOW create_renamed_view HR EMPLOYEES
```

#### SYSDBA:
```bash
sqlplus -S "/ as sysdba" @templates/plsql-util/plsql-util.sql WORKFLOW create_renamed_view HR EMPLOYEES
```

## Step-by-Step Migration Process

### Step 1: Prepare Your Tables

```sql
-- Connect to your database
sqlplus hr/hr@localhost:1521/XE

-- Create backup of original table
CREATE TABLE HR.EMPLOYEES_OLD AS SELECT * FROM HR.EMPLOYEES;

-- Create new table with same structure
CREATE TABLE HR.EMPLOYEES_NEW AS SELECT * FROM HR.EMPLOYEES WHERE 1=0;

-- Load data into new table (your migration process)
-- INSERT INTO HR.EMPLOYEES_NEW SELECT * FROM HR.EMPLOYEES WHERE ...;
```

### Step 2: Create Migration View and Triggers

```bash
# Using unified_runner.sh (recommended)
./unified_runner.sh workflow "hr/hr@localhost:1521/XE" create_renamed_view HR EMPLOYEES

# Or direct SQL*Plus
sqlplus -S hr/hr@localhost:1521/XE @templates/plsql-util/plsql-util.sql WORKFLOW create_renamed_view HR EMPLOYEES
```

### Step 3: Test the Migration View

```sql
-- Connect and test
sqlplus hr/hr@localhost:1521/XE

-- Test SELECT (should show combined data)
SELECT COUNT(*) FROM HR.EMPLOYEES_JOINED;

-- Test INSERT (should go to NEW table)
INSERT INTO HR.EMPLOYEES_JOINED (employee_id, first_name, last_name, email, hire_date, job_id)
VALUES (999, 'Test', 'User', 'test@example.com', SYSDATE, 'IT_PROG');

-- Verify data went to NEW table
SELECT COUNT(*) FROM HR.EMPLOYEES_NEW WHERE employee_id = 999;

-- Test UPDATE (should raise error)
UPDATE HR.EMPLOYEES_JOINED SET first_name = 'Updated' WHERE employee_id = 999;
-- Expected: ORA-20100: UPDATE not supported on migration view

-- Test DELETE (should raise error)
DELETE FROM HR.EMPLOYEES_JOINED WHERE employee_id = 999;
-- Expected: ORA-20101: DELETE not supported on migration view
```

### Step 4: Complete the Migration

```bash
# Finalize the swap
./unified_runner.sh workflow "hr/hr@localhost:1521/XE" finalize_swap HR EMPLOYEES
```

## SYSDBA Operations

### When to Use SYSDBA
- **Cross-schema operations**: When tables are in different schemas
- **System-level privileges**: When you need DBA privileges
- **Emergency situations**: When regular user doesn't have sufficient privileges

### SYSDBA Command Examples

```bash
# Check SYSDBA privileges
sqlplus -S "/ as sysdba" @templates/plsql-util/plsql-util.sql SYS check_privileges

# Create view as SYSDBA
sqlplus -S "/ as sysdba" @templates/plsql-util/plsql-util.sql WORKFLOW create_renamed_view HR EMPLOYEES

# Check tablespace usage
sqlplus -S "/ as sysdba" @templates/plsql-util/plsql-util.sql SYS check_tablespace USERS

# Check all sessions
sqlplus -S "/ as sysdba" @templates/plsql-util/plsql-util.sql SYS check_sessions_all
```

## Troubleshooting

### Common Issues

#### 1. "Table does not exist" Error
```bash
# Check if tables exist
sqlplus -S hr/hr@localhost:1521/XE @templates/plsql-util/plsql-util.sql READONLY check_existence HR EMPLOYEES_NEW
sqlplus -S hr/hr@localhost:1521/XE @templates/plsql-util/plsql-util.sql READONLY check_existence HR EMPLOYEES_OLD
```

#### 2. "Primary key not found" Error
```sql
-- Check primary key on NEW table
SELECT constraint_name, column_name
FROM all_cons_columns cc
JOIN all_constraints c ON cc.constraint_name = c.constraint_name
WHERE c.owner = 'HR' AND c.table_name = 'EMPLOYEES_NEW' AND c.constraint_type = 'P';
```

#### 3. Permission Issues
```bash
# Use SYSDBA if you have permission issues
sqlplus -S "/ as sysdba" @templates/plsql-util/plsql-util.sql WORKFLOW create_renamed_view HR EMPLOYEES
```

#### 4. View Creation Failed
```sql
-- Check for existing objects
SELECT object_name, object_type, status
FROM all_objects
WHERE owner = 'HR' AND object_name LIKE '%EMPLOYEES%';

-- Drop existing view if needed
DROP VIEW HR.EMPLOYEES_JOINED;
```

### Debugging Commands

```bash
# Enable verbose output
sqlplus -S hr/hr@localhost:1521/XE << 'EOF'
SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF
@templates/plsql-util/plsql-util.sql WORKFLOW create_renamed_view HR EMPLOYEES
EOF

# Check what was created
sqlplus -S hr/hr@localhost:1521/XE << 'EOF'
SELECT object_name, object_type, status
FROM all_objects
WHERE owner = 'HR' AND object_name LIKE '%EMPLOYEES%'
ORDER BY object_name;
EOF
```

## Complete Example Script

### Migration Script (migrate_employees.sh)

```bash
#!/bin/bash

# Configuration
SCHEMA="HR"
TABLE="EMPLOYEES"
CONNECTION="hr/hr@localhost:1521/XE"

echo "Starting migration for $SCHEMA.$TABLE..."

# Step 1: Check prerequisites
echo "Step 1: Checking prerequisites..."
./unified_runner.sh readonly "$CONNECTION" check_existence "$SCHEMA" "${TABLE}_NEW"
./unified_runner.sh readonly "$CONNECTION" check_existence "$SCHEMA" "${TABLE}_OLD"

# Step 2: Create migration view
echo "Step 2: Creating migration view and triggers..."
./unified_runner.sh workflow "$CONNECTION" create_renamed_view "$SCHEMA" "$TABLE"

# Step 3: Test the view
echo "Step 3: Testing migration view..."
sqlplus -S "$CONNECTION" << 'EOF'
SET SERVEROUTPUT ON
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM HR.EMPLOYEES_JOINED;
    DBMS_OUTPUT.PUT_LINE('Migration view row count: ' || v_count);
END;
/
EOF

# Step 4: Finalize (when ready)
echo "Step 4: Ready to finalize? (y/n)"
read -r response
if [ "$response" = "y" ]; then
    ./unified_runner.sh workflow "$CONNECTION" finalize_swap "$SCHEMA" "$TABLE"
    echo "Migration completed!"
else
    echo "Migration view created. Run finalize_swap when ready."
fi
```

### SYSDBA Migration Script (migrate_employees_sysdba.sh)

```bash
#!/bin/bash

# Configuration
SCHEMA="HR"
TABLE="EMPLOYEES"

echo "Starting SYSDBA migration for $SCHEMA.$TABLE..."

# Step 1: Check SYSDBA privileges
echo "Step 1: Checking SYSDBA privileges..."
sqlplus -S "/ as sysdba" @templates/plsql-util/plsql-util.sql SYS check_privileges

# Step 2: Check tablespace
echo "Step 2: Checking tablespace usage..."
sqlplus -S "/ as sysdba" @templates/plsql-util/plsql-util.sql SYS check_tablespace USERS

# Step 3: Create migration view
echo "Step 3: Creating migration view and triggers..."
sqlplus -S "/ as sysdba" @templates/plsql-util/plsql-util.sql WORKFLOW create_renamed_view "$SCHEMA" "$TABLE"

# Step 4: Test the view
echo "Step 4: Testing migration view..."
sqlplus -S "/ as sysdba" << 'EOF'
SET SERVEROUTPUT ON
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM HR.EMPLOYEES_JOINED;
    DBMS_OUTPUT.PUT_LINE('Migration view row count: ' || v_count);
END;
/
EOF

echo "Migration view created successfully!"
```

## Security Notes

### SQL Injection Protection
The script uses `DBMS_ASSERT` functions to prevent SQL injection:
- `safe_sql_name()` - Validates SQL identifiers
- `safe_schema_table()` - Validates schema.table combinations
- `DBMS_ASSERT.ENQUOTE_NAME()` - Properly quotes identifiers

### Privilege Requirements
- **Regular User**: Needs CREATE VIEW, CREATE TRIGGER privileges on target schema
- **SYSDBA**: Has all privileges, can work across schemas

### Best Practices
1. **Test First**: Always test on non-production data
2. **Backup**: Ensure you have backups before migration
3. **Monitor**: Watch for invalid objects after migration
4. **Cleanup**: Use `finalize_swap` to clean up migration objects

## Output Examples

### Successful Execution
```
=============================================================
PL/SQL UTILITY - Category: WORKFLOW | Operation: create_renamed_view
=============================================================
Creating migration view and trigger...
  Schema: HR
  Table: EMPLOYEES
  New table: EMPLOYEES_NEW
  Old table: EMPLOYEES_OLD
  View: EMPLOYEES_JOINED
  Trigger: TG_EMPLOYEES_IOT
  ✓ New table exists
  ✓ Old table exists
  ✓ Primary key found: EMPLOYEE_ID
  ✓ Found 11 columns
  ✓ Join condition: n.EMPLOYEE_ID = o.EMPLOYEE_ID
  ✓ Dropped existing view
  ✓ Created view EMPLOYEES_JOINED
  ✓ Dropped existing trigger
  ✓ Created INSTEAD OF trigger TG_EMPLOYEES_IOT
  ✓ UPDATE restriction trigger created
  ✓ DELETE restriction trigger created

================================================================
✓ Migration view and triggers created successfully
================================================================
View: HR.EMPLOYEES_JOINED
  - Combines data from NEW and OLD tables
  - Deduplicates using PK: EMPLOYEE_ID
  - Supports: INSERT only
  - Restrictions: UPDATE and DELETE will raise errors

Usage:
  INSERT INTO HR.EMPLOYEES_JOINED VALUES (...);
  -- Data will be inserted into EMPLOYEES_NEW
================================================================

RESULT: PASSED - View and trigger created successfully
```

This guide provides everything you need to run the INSTEAD OF trigger functionality from the command line using SQL*Plus, both as a regular user and as SYSDBA.
