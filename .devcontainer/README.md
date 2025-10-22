# GitHub Codespaces Oracle Test Environment

## Overview

This dev container provides a complete Oracle Database XE 21c environment for testing the Table Migration Framework. It includes:

- **Oracle Database XE 21c** (container: `oracle`)
- **Python 3.11** with migration tools
- **Pre-configured test schemas**: HR and HR_APP
- **Pre-loaded test data**: 1.67M rows across 7 tables

## Quick Start

### 1. Open in Codespaces

Click the "Code" button → "Codespaces" → "Create codespace on [branch]"

The environment will automatically:
1. Start Oracle XE database
2. Create HR and HR_APP schemas
3. Create 7 test tables (partitioned and non-partitioned)
4. Load 1.67 million rows of test data
5. Install Python dependencies
6. Configure Oracle clients

**Startup time:** ~3-5 minutes

### 2. Verify Environment

```bash
# Check Oracle database is running
sqlplus hr/hr123@oracle:1521/XEPDB1 <<EOF
SELECT 'Database Ready!' FROM DUAL;
EXIT;
EOF

# List test tables
sqlplus hr/hr123@oracle:1521/XEPDB1 <<EOF
SELECT table_name, num_rows FROM user_tables ORDER BY table_name;
EXIT;
EOF
```

### 3. Run Your First Discovery

```bash
cd /workspace/table_migration

# Discover all tables in HR schema
python3 02_generator/generate_scripts.py \
    --discover \
    --schema HR \
    --connection "hr/hr123@oracle:1521/XEPDB1"

# This generates: migration_config.json
```

### 4. Customize and Generate Scripts

```bash
# Edit the generated config
vim migration_config.json

# Validate configuration
python3 02_generator/generate_scripts.py \
    --config migration_config.json \
    --validate-only

# Generate migration scripts
python3 02_generator/generate_scripts.py \
    --config migration_config.json
```

### 5. Execute Migration

```bash
# Navigate to generated table directory
cd 05_tables/HR_EMPLOYEES

# Review scripts
ls -lh *.sql

# Execute migration (in SQL*Plus)
sqlplus hr/hr123@oracle:1521/XEPDB1 @master1.sql
```

## Test Schemas

### HR Schema (Non-Partitioned Tables)

| Table | Rows | Purpose |
|-------|------|---------|
| **EMPLOYEES** | 5,000 | Test DAY interval on HIRE_DATE |
| **ORDERS** | 50,000 | Test DAY interval on ORDER_DATE |
| **DEPARTMENTS** | 50 | Dimension table (reference) |

**Connection**: `hr/hr123@oracle:1521/XEPDB1`

### HR_APP Schema (Mixed Partition States)

| Table | Rows | Current State | Test Scenario |
|-------|------|---------------|---------------|
| **TRANSACTIONS** | 500,000 | INTERVAL(MONTH) | Convert to INTERVAL-HASH |
| **AUDIT_LOG** | 1,000,000 | INTERVAL(DAY) | Change to HOUR + HASH |
| **EVENTS** | 100,000 | Non-partitioned | Add HOUR interval + HASH |
| **CUSTOMER_DATA** | 25,000 | Non-partitioned + 3 LOBs | Add MONTH interval + HASH |

**Connection**: `hr_app/hrapp123@oracle:1521/XEPDB1`

## Test Scenarios

### Scenario 1: Non-Partitioned → Interval-Hash (DAY)

**Table**: HR.EMPLOYEES

```bash
# Discovery
python3 02_generator/generate_scripts.py \
    --discover --schema HR \
    --connection "hr/hr123@oracle:1521/XEPDB1"

# Edit migration_config.json:
#   - partition_column: HIRE_DATE
#   - interval_type: DAY
#   - subpartition_column: EMPLOYEE_ID
#   - subpartition_count: 4

# Generate and execute
python3 02_generator/generate_scripts.py --config migration_config.json
cd 05_tables/HR_EMPLOYEES
sqlplus hr/hr123@oracle:1521/XEPDB1 @master1.sql
```

### Scenario 2: Interval → Interval-Hash (Add Subpartitions)

**Table**: HR_APP.TRANSACTIONS (already INTERVAL-MONTH)

```bash
# Discovery
python3 02_generator/generate_scripts.py \
    --discover --schema HR_APP \
    --connection "hr_app/hrapp123@oracle:1521/XEPDB1"

# Edit migration_config.json:
#   - Keep interval_type: MONTH
#   - Add subpartition_type: HASH
#   - subpartition_column: TRANSACTION_ID
#   - subpartition_count: 8

# Generate and execute
python3 02_generator/generate_scripts.py --config migration_config.json
cd 05_tables/HR_APP_TRANSACTIONS
sqlplus hr_app/hrapp123@oracle:1521/XEPDB1 @master1.sql
```

### Scenario 3: High-Frequency Data (HOUR Interval)

**Table**: HR_APP.EVENTS (100K rows)

```bash
# Discovery finds non-partitioned table
python3 02_generator/generate_scripts.py \
    --discover --schema HR_APP --include "EVENTS" \
    --connection "hr_app/hrapp123@oracle:1521/XEPDB1"

# Edit migration_config.json:
#   - partition_column: EVENT_DATE
#   - interval_type: HOUR
#   - interval_value: 1
#   - subpartition_column: USER_ID
#   - subpartition_count: 16

# Generate and execute
python3 02_generator/generate_scripts.py --config migration_config.json
```

### Scenario 4: LOB Handling

**Table**: HR_APP.CUSTOMER_DATA (25K rows with 3 LOBs)

```bash
# Discovery detects 3 LOB columns
python3 02_generator/generate_scripts.py \
    --discover --schema HR_APP --include "CUSTOMER_DATA" \
    --connection "hr_app/hrapp123@oracle:1521/XEPDB1"

# Review LOB warning in validation
# Edit config for MONTH interval
# Execute and verify LOBs copied correctly
```

## Database Credentials

| User | Password | Purpose |
|------|----------|---------|
| `system` | `Oracle123!` | Admin (SYSDBA) |
| `hr` | `hr123` | HR schema owner |
| `hr_app` | `hrapp123` | HR_APP schema owner |

**Connection String Format**: `user/password@oracle:1521/XEPDB1`

## Useful SQL Queries

### Check Partition Configuration

```sql
-- As HR_APP
SELECT 
    table_name,
    partitioning_type,
    subpartitioning_type,
    partition_count,
    def_subpartition_count,
    interval
FROM user_part_tables
ORDER BY table_name;
```

### Check Table Sizes

```sql
SELECT 
    segment_name,
    ROUND(SUM(bytes)/POWER(1024,3), 2) as size_gb,
    COUNT(*) as segment_count
FROM user_segments
WHERE segment_type LIKE 'TABLE%'
GROUP BY segment_name
ORDER BY 2 DESC;
```

### Check Partition Distribution

```sql
-- After migration
SELECT 
    table_name,
    partition_name,
    subpartition_count,
    num_rows,
    ROUND(num_rows / NULLIF(subpartition_count, 0), 0) as avg_rows_per_subpart
FROM user_tab_partitions
WHERE table_name = 'EMPLOYEES_NEW'
ORDER BY partition_position DESC;
```

## Troubleshooting

### Database Not Ready

```bash
# Check Oracle container logs
docker logs oracle-test-db

# Restart database
docker restart oracle-test-db

# Wait for health check
docker ps --filter name=oracle
```

### Connection Issues

```bash
# Test connection
sqlplus hr/hr123@oracle:1521/XEPDB1 <<< "SELECT 'OK' FROM DUAL;"

# Check listener
lsnrctl status

# Verify TNS configuration
cat ~/oracle/tnsnames.ora
```

### Out of Space

```bash
# Check tablespace usage
sqlplus hr/hr123@oracle:1521/XEPDB1 <<EOF
SELECT 
    tablespace_name,
    ROUND(SUM(bytes)/POWER(1024,3), 2) as free_gb
FROM dba_free_space
GROUP BY tablespace_name;
EXIT;
EOF

# Extend tablespace (as SYSTEM)
sqlplus system/Oracle123!@oracle:1521/XEPDB1 <<EOF
ALTER DATABASE DATAFILE '/opt/oracle/oradata/XE/XEPDB1/users01.dbf' 
    RESIZE 2G;
EXIT;
EOF
```

## Development Workflow

1. **Discover** schema: `--discover --schema <NAME>`
2. **Edit** `migration_config.json`
3. **Validate** config: `--config file.json --validate-only`
4. **Generate** scripts: `--config file.json`
5. **Review** scripts in `05_tables/<schema>_<table>/`
6. **Execute** via SQL*Plus: `@master1.sql`
7. **Validate** results: check row counts, partitions
8. **Swap** tables: `@master2.sql`

## Cleaning Up

### Drop Test Tables

```bash
# Drop _NEW tables after testing
sqlplus hr/hr123@oracle:1521/XEPDB1 <<EOF
BEGIN
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name LIKE '%_NEW') LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' PURGE';
    END LOOP;
END;
/
EXIT;
EOF
```

### Reset Environment

```bash
# Re-run init scripts
sqlplus system/Oracle123!@oracle:1521/XEPDB1 @.devcontainer/init-scripts/01_create_schemas.sql
sqlplus hr/hr123@oracle:1521/XEPDB1 @.devcontainer/init-scripts/02_create_hr_tables.sql
sqlplus hr_app/hrapp123@oracle:1521/XEPDB1 @.devcontainer/init-scripts/03_create_hr_app_tables.sql
sqlplus system/Oracle123!@oracle:1521/XEPDB1 @.devcontainer/init-scripts/04_generate_test_data.sql
```

## Performance Tips

- Use `PARALLEL` hints for large tables (already in templates)
- Monitor progress with `V$SESSION_LONGOPS`
- Check partition distribution after migration
- Gather statistics after migration (`DBMS_STATS`)

## VS Code Extensions Installed

- **Oracle Developer Tools** - SQL editing and execution
- **SQLTools** - Database exploration
- **Python** - Code editing and debugging
- **Jinja** - Template syntax highlighting
- **YAML** - Configuration file editing

## Resources

- [Oracle XE Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/21/xeinl/)
- [Partition Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/21/vldbg/partition-intro.html)
- [Migration Framework Docs](../table_migration/README.md)

---

**Ready to test?** Start with: `python3 02_generator/generate_scripts.py --help`
