# Table Migration Framework - User Guide

## Overview

This framework provides a **JSON-driven, automated approach** to migrating Oracle tables to interval-partitioned or interval-hash-partitioned structures. It supports:

✅ **All scenarios**: Non-partitioned → Partitioned, Interval → Interval-Hash  
✅ **Flexible intervals**: HOUR, DAY, WEEK, MONTH  
✅ **Hash subpartitioning**: User-controlled column and count  
✅ **Integrated validation**: Pre/post-migration checks and data comparison  
✅ **Jinja2 templates**: Powerful, customizable SQL generation  

---

## Quick Start (5 Minutes)

```bash
# 1. Install dependencies
pip install --user oracledb jinja2 jsonschema

# 2. Discover your schema
cd table_migration/generator
python3 generate_scripts.py --discover --schema MYSCHEMA \
    --connection "user/password@host:1521/service"

# 3. Edit migration_config.json (customize intervals, hash settings)
vim migration_config.json

# 4. Validate configuration
python3 generate_scripts.py --config migration_config.json --validate-only

# 5. Generate migration scripts
python3 generate_scripts.py --config migration_config.json

# 6. Execute scripts
cd ../generated_scripts/MYSCHEMA_TABLENAME
sqlplus user/password@host:1521/service @master1.sql
```

---

## Complete Workflow

### Phase 1: Discovery

**Purpose**: Analyze your schema and generate a JSON configuration file.

```bash
cd table_migration/generator

# Discover all tables in schema
python3 generate_scripts.py --discover --schema HR \
    --connection "hr/hr123@localhost:1521/XEPDB1"

# Discover specific tables only
python3 generate_scripts.py --discover --schema HR \
    --connection "hr/hr123@localhost:1521/XEPDB1" \
    --include "EMPLOYEES,ORDERS,TRANSACTIONS"

# Exclude certain tables
python3 generate_scripts.py --discover --schema HR \
    --connection "hr/hr123@localhost:1521/XEPDB1" \
    --exclude "TEMP_*,ARCHIVE_*"

# Custom output file
python3 generate_scripts.py --discover --schema HR \
    --connection "hr/hr123@localhost:1521/XEPDB1" \
    --output-file my_migration.json
```

**Output**: `migration_config.json` in current directory

**What it discovers**:
- All tables in schema (or filtered subset)
- Current partition status (partitioned/non-partitioned)
- Available timestamp columns (for interval partitioning)
- Available numeric columns (for hash subpartitioning)
- Table sizes, row counts, LOB counts, index counts
- Intelligent defaults for partition/hash columns
- Recommended interval types based on data distribution

---

### Phase 2: Configuration

**Purpose**: Customize the migration plan for your needs.

#### Example Configuration

```json
{
  "metadata": {
    "generated_date": "2025-10-22 10:30:00",
    "schema": "HR",
    "total_tables_found": 7,
    "tables_selected_for_migration": 3
  },
  "tables": [
    {
      "enabled": true,
      "owner": "HR",
      "table_name": "EMPLOYEES",
      
      "current_state": {
        "is_partitioned": false,
        "partition_type": "NONE",
        "size_gb": 0.5,
        "row_count": 5000
      },
      
      "target_configuration": {
        "partition_type": "INTERVAL",
        "partition_column": "HIRE_DATE",
        "interval_type": "DAY",
        "interval_value": 1,
        "initial_partition_value": "TO_DATE('2020-01-01', 'YYYY-MM-DD')",
        
        "subpartition_type": "HASH",
        "subpartition_column": "EMPLOYEE_ID",
        "subpartition_count": 4,
        
        "tablespace": "USERS",
        "parallel_degree": 2
      },
      
      "migration_settings": {
        "estimated_hours": 0.2,
        "priority": "MEDIUM",
        "validate_data": true,
        "backup_old_table": true,
        "drop_old_after_days": 7
      }
    }
  ]
}
```

#### Key Configuration Options

##### Interval Types
- `"HOUR"`: Partition by hour (high-frequency data)
- `"DAY"`: Partition by day (most common)
- `"WEEK"`: Partition by week
- `"MONTH"`: Partition by month (low-frequency data)

##### Hash Subpartition Count
**Must be power of 2**: 2, 4, 8, 16, 32, 64, 128

**Guidelines**:
- Small tables (< 1M rows): 4-8 subpartitions
- Medium tables (1M-10M): 8-16 subpartitions
- Large tables (> 10M): 16-32 subpartitions
- Very large (> 100M): 32-64 subpartitions

##### Parallel Degree
**Recommendation**: 2-4x CPU cores, max 16

**Examples**:
- Small tables: 2
- Medium tables: 4
- Large tables: 8
- Very large: 16

##### Enable/Disable Tables
Set `"enabled": false` to skip a table without deleting it from config.

---

### Phase 3: Validation

**Purpose**: Validate configuration before generating scripts.

#### Schema Validation Only (Fast)

```bash
python3 generate_scripts.py --config migration_config.json --validate-only
```

**Checks**:
- JSON schema compliance
- Interval type valid (HOUR/DAY/WEEK/MONTH)
- Hash count is power of 2
- Required fields present
- Data types correct

#### Database Validation (Thorough)

```bash
python3 generate_scripts.py --config migration_config.json --validate-only \
    --check-database --connection "hr/hr123@localhost:1521/XEPDB1"
```

**Additional checks**:
- Tables exist in database
- Partition columns exist
- Hash columns exist
- Column data types suitable
- Tablespace exists

#### Pre-Migration Validation (Before Execution)

```bash
python3 generate_scripts.py --config migration_config.json --validate-pre \
    --connection "hr/hr123@localhost:1521/XEPDB1"
```

**Checks**:
- Source table accessible
- No active locks
- Sufficient tablespace (2x table size)
- No conflicting indexes/constraints
- Partition syntax valid
- Dependencies identified

**Output**: Pass/fail for each table with detailed findings

---

### Phase 4: Script Generation

**Purpose**: Generate migration SQL scripts from validated config.

```bash
python3 generate_scripts.py --config migration_config.json

# Custom output directory
python3 generate_scripts.py --config migration_config.json \
    --output-dir /path/to/scripts

# Custom template directory
python3 generate_scripts.py --config migration_config.json \
    --template-dir /path/to/custom/templates
```

**Generated Structure**:
```
generated_scripts/
└── HR_EMPLOYEES/
    ├── 10_create_table.sql      # Create new partitioned table
    ├── 20_data_load.sql          # Initial data load
    ├── 30_create_indexes.sql     # Rebuild indexes
    ├── 40_delta_load.sql         # Load incremental changes
    ├── 50_swap_tables.sql        # Rename tables (cutover)
    ├── 60_restore_grants.sql     # Restore privileges
    ├── 70_drop_old_table.sql     # Drop old table
    ├── master1.sql               # Execute steps 10-40
    ├── master2.sql               # Execute steps 50-70
    └── README.md                 # Table-specific documentation
```

---

### Phase 5: Execution

#### Step 1: Review Generated Scripts

```bash
cd ../generated_scripts/HR_EMPLOYEES
cat README.md          # Review migration plan
cat 10_create_table.sql # Review CREATE TABLE statement
```

#### Step 2: Execute Initial Load (master1.sql)

```bash
# Connect and run
sqlplus hr/hr123@localhost:1521/XEPDB1 @master1.sql
```

**What master1.sql does**:
1. Creates new partitioned table (`<TABLE>_NEW`)
2. Loads all data with parallel execution
3. Creates indexes (local to partitions)
4. Loads any delta changes

**Timing**: Most time spent here (data load + index creation)

#### Step 3: Validate Post-Migration

```bash
cd ../../02_generator
python3 generate_scripts.py --config migration_config.json --validate-post \
    --connection "hr/hr123@localhost:1521/XEPDB1"
```

**Checks**:
- New table exists with correct partition type
- Interval definition matches config
- Subpartition count correct
- Row counts match (old vs new)
- Indexes created
- Constraints enabled

#### Step 4: Compare Data

```bash
python3 generate_scripts.py --config migration_config.json --compare-data \
    --connection "hr/hr123@localhost:1521/XEPDB1"
```

**Checks**:
- Total row count comparison
- Sample 1000 random rows (compare values)
- MIN/MAX values for partition column
- Partition distribution statistics

#### Step 5: Cutover (master2.sql)

**IMPORTANT**: This is the downtime window. Applications should be stopped.

```bash
cd ../generated_scripts/HR_EMPLOYEES
sqlplus hr/hr123@localhost:1521/XEPDB1 @master2.sql
```

**What master2.sql does**:
1. Renames `EMPLOYEES` to `EMPLOYEES_OLD`
2. Renames `EMPLOYEES_NEW` to `EMPLOYEES`
3. Restores grants/privileges
4. Optionally drops old table

**Downtime**: Typically 1-5 minutes (rename operations are fast)

#### Step 6: Generate Validation Report

```bash
cd ../../02_generator
python3 generate_scripts.py --config migration_config.json \
    --validation-report migration_report.md \
    --connection "hr/hr123@localhost:1521/XEPDB1"
```

**Report includes**:
- Summary of all validations
- Pass/fail status per table
- Detailed findings
- Performance metrics
- Recommendations

---

## Real-World Examples

### Example 1: Non-Partitioned Table → Daily Interval + Hash

**Scenario**: ORDERS table, 50K rows, needs daily partitions

```json
{
  "enabled": true,
  "owner": "HR",
  "table_name": "ORDERS",
  "target_configuration": {
    "partition_type": "INTERVAL",
    "partition_column": "ORDER_DATE",
    "interval_type": "DAY",
    "interval_value": 1,
    "initial_partition_value": "TO_DATE('2024-01-01', 'YYYY-MM-DD')",
    "subpartition_type": "HASH",
    "subpartition_column": "ORDER_ID",
    "subpartition_count": 8,
    "parallel_degree": 4
  }
}
```

**Generated SQL**:
```sql
CREATE TABLE ORDERS_NEW (
  -- columns...
)
PARTITION BY RANGE (ORDER_DATE)
INTERVAL (NUMTODSINTERVAL(1, 'DAY'))
SUBPARTITION BY HASH (ORDER_ID) SUBPARTITIONS 8
(
  PARTITION p_initial VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD'))
)
PARALLEL 4;
```

---

### Example 2: Existing Interval → Add Hash Subpartitions

**Scenario**: TRANSACTIONS table already has MONTH interval, add hash

```json
{
  "enabled": true,
  "owner": "HR",
  "table_name": "TRANSACTIONS",
  "current_state": {
    "is_partitioned": true,
    "is_interval": true,
    "interval_definition": "INTERVAL(NUMTOYMINTERVAL(1,'MONTH'))"
  },
  "target_configuration": {
    "partition_type": "INTERVAL",
    "partition_column": "TXN_DATE",
    "interval_type": "MONTH",
    "interval_value": 1,
    "subpartition_type": "HASH",
    "subpartition_column": "TRANSACTION_ID",
    "subpartition_count": 16
  }
}
```

**Migration action**: Convert from INTERVAL to INTERVAL-HASH (adds subpartitions)

---

### Example 3: High-Frequency Data → Hourly Partitions

**Scenario**: AUDIT_LOG table, 1M rows, needs hourly partitions

```json
{
  "enabled": true,
  "owner": "HR",
  "table_name": "AUDIT_LOG",
  "target_configuration": {
    "partition_type": "INTERVAL",
    "partition_column": "AUDIT_DATE",
    "interval_type": "HOUR",
    "interval_value": 1,
    "subpartition_type": "HASH",
    "subpartition_column": "USER_ID",
    "subpartition_count": 32,
    "parallel_degree": 8
  }
}
```

**Generated SQL**:
```sql
PARTITION BY RANGE (AUDIT_DATE)
INTERVAL (NUMTODSINTERVAL(1, 'HOUR'))
SUBPARTITION BY HASH (USER_ID) SUBPARTITIONS 32
```

---

### Example 4: Table with LOBs

**Scenario**: CUSTOMER_DATA with CLOB/BLOB columns

```json
{
  "enabled": true,
  "owner": "HR",
  "table_name": "CUSTOMER_DATA",
  "current_state": {
    "lob_count": 3
  },
  "target_configuration": {
    "partition_type": "INTERVAL",
    "partition_column": "REGISTRATION_DATE",
    "interval_type": "MONTH",
    "interval_value": 1,
    "subpartition_type": "HASH",
    "subpartition_column": "CUSTOMER_ID",
    "subpartition_count": 8
  }
}
```

**Note**: Framework automatically handles LOB storage (SECUREFILE, COMPRESS HIGH)

---

## Advanced Topics

### Custom Templates

You can customize Jinja2 templates in `templates/`:

```bash
cd table_migration/01_templates

# Copy template
cp 10_create_table.sql.j2 10_create_table.sql.j2.custom

# Edit template
vim 10_create_table.sql.j2

# Use custom template directory

python3 generate_scripts.py --config migration_config.json \
    --template-dir /path/to/custom/templates
```

### Parallel Execution

**Data Load**: Controlled by `parallel_degree` in config

```sql
-- Generated with parallel_degree: 8
INSERT /*+ PARALLEL(EMPLOYEES_NEW, 8) */ INTO EMPLOYEES_NEW
SELECT /*+ PARALLEL(EMPLOYEES, 8) */ * FROM EMPLOYEES;
```

**Index Creation**: Automatically parallelized

```sql
CREATE INDEX idx_name ON table_name (column)
PARALLEL 8 NOLOGGING;
```

### Rollback Procedures

If migration fails, use scripts in `rollback/`:

```bash
cd table_migration/04_rollback

# Emergency rollback (restores original table)
sqlplus hr/hr123@localhost:1521/XEPDB1 @emergency_rollback.sql
```

**Note**: Rollback scripts are standalone (not part of JSON workflow yet)

### Monitoring Progress

**During data load**:
```sql
-- Check progress
SELECT COUNT(*) FROM EMPLOYEES_NEW;

-- Check partition count
SELECT COUNT(*) FROM USER_TAB_PARTITIONS WHERE TABLE_NAME = 'EMPLOYEES_NEW';

-- Check subpartition distribution
SELECT SUBPARTITION_NAME, NUM_ROWS 
FROM USER_TAB_SUBPARTITIONS 
WHERE TABLE_NAME = 'EMPLOYEES_NEW'
ORDER BY SUBPARTITION_NAME;
```

---

## Troubleshooting

### Issue: "ORA-00001: unique constraint violated"

**Cause**: Primary key or unique constraint conflict during data load

**Solution**:
```sql
-- Check for duplicates
SELECT column, COUNT(*) 
FROM EMPLOYEES 
GROUP BY column 
HAVING COUNT(*) > 1;

-- Clean data before migration
DELETE FROM EMPLOYEES WHERE rowid NOT IN (
  SELECT MIN(rowid) FROM EMPLOYEES GROUP BY primary_key_column
);
```

---

### Issue: "ORA-14760: interval must be power of 2"

**Cause**: Hash subpartition count is not power of 2

**Solution**: Edit `migration_config.json`:
```json
"subpartition_count": 8  // Change from 6 to 8 (power of 2)
```

---

### Issue: "Insufficient tablespace"

**Cause**: Not enough space for new table

**Solution**:
```sql
-- Check available space
SELECT TABLESPACE_NAME, ROUND(SUM(BYTES)/1024/1024/1024, 2) GB_AVAILABLE
FROM DBA_FREE_SPACE
GROUP BY TABLESPACE_NAME;

-- Add datafile
ALTER TABLESPACE USERS ADD DATAFILE SIZE 10G AUTOEXTEND ON NEXT 1G MAXSIZE 50G;
```

---

### Issue: "Table has active locks"

**Cause**: Other sessions are using the table

**Solution**:
```sql
-- Find locking sessions
SELECT s.sid, s.serial#, s.username, s.program
FROM v$session s, v$lock l
WHERE s.sid = l.sid
  AND l.id1 IN (SELECT object_id FROM dba_objects WHERE object_name = 'EMPLOYEES');

-- Kill session (if safe)
ALTER SYSTEM KILL SESSION 'sid,serial#';
```

---

### Issue: "Validation failed: row count mismatch"

**Cause**: Data changed between load and validation

**Solution**: Re-run delta load:
```bash
cd ../generated_scripts/HR_EMPLOYEES
sqlplus hr/hr123@localhost:1521/XEPDB1 @40_delta_load.sql
```

---

## Best Practices

### 1. Test on Non-Production First

Always test the complete workflow in a test environment:

```bash
# Use GitHub Codespaces test environment
# See .devcontainer/README.md for setup
```

### 2. Choose Appropriate Intervals

| Data Frequency | Recommended Interval | Example |
|----------------|---------------------|---------|
| High (millions/day) | HOUR | Audit logs, events |
| Medium (thousands/day) | DAY | Transactions, orders |
| Low (hundreds/day) | WEEK or MONTH | Reports, summaries |

### 3. Optimize Hash Subpartitions

**Rule of thumb**: `subpartition_count = CEIL(row_count / 1_000_000)`

**Examples**:
- 500K rows → 4 subpartitions
- 5M rows → 8 subpartitions
- 50M rows → 32 subpartitions

### 4. Schedule Migrations During Maintenance Windows

- Downtime required: Step 5 (master2.sql) only
- Typical downtime: 1-5 minutes
- Steps 1-4 can run with application online

### 5. Keep Old Table for Safety

```json
"migration_settings": {
  "drop_old_after_days": 7  // Keep old table for 7 days
}
```

### 6. Monitor Resource Usage

```sql
-- Check CPU usage
SELECT sid, username, sql_id, cpu_time
FROM v$session
WHERE username = 'HR'
ORDER BY cpu_time DESC;

-- Check I/O
SELECT sid, username, physical_reads, block_changes
FROM v$sess_io
WHERE username = 'HR';
```

---

## Performance Tuning

### Large Table Optimizations

For tables > 100GB:

1. **Increase parallel degree**:
   ```json
   "parallel_degree": 16
   ```

2. **Use direct path insert**:
   ```sql
   INSERT /*+ APPEND PARALLEL(16) */ INTO ...
   ```

3. **Disable logging temporarily**:
   ```sql
   ALTER TABLE EMPLOYEES_NEW NOLOGGING;
   ```

4. **Increase PGA/SGA**:
   ```sql
   ALTER SYSTEM SET PGA_AGGREGATE_TARGET = 20G;
   ALTER SYSTEM SET SGA_TARGET = 40G;
   ```

### Index Creation Tuning

```sql
-- Parallel index creation
CREATE INDEX idx_name ON table (column)
PARALLEL 16 NOLOGGING;

-- After creation, rebuild with logging
ALTER INDEX idx_name REBUILD LOGGING PARALLEL 4;
```

---

## Migration Checklist

Use this checklist for each table migration:

- [ ] Run discovery and generate config
- [ ] Review and customize config
- [ ] Validate config (schema + database)
- [ ] Run pre-migration validation
- [ ] Generate scripts
- [ ] Review generated SQL
- [ ] Backup production data
- [ ] Execute master1.sql (initial load)
- [ ] Run post-migration validation
- [ ] Compare data
- [ ] Schedule maintenance window
- [ ] Execute master2.sql (cutover)
- [ ] Test application
- [ ] Generate validation report
- [ ] Monitor for 24-48 hours
- [ ] Drop old table (after safety period)

---

## Getting Help

### Documentation

- `IMPLEMENTATION_PLAN.md` - Architecture and design
- `lib/README.md` - Generator usage
- `templates/README.md` - Template reference
- `.devcontainer/README.md` - Test environment guide

### Common Commands Reference

```bash
# Discovery
python3 generate_scripts.py --discover --schema SCHEMA --connection "..."

# Validation
python3 generate_scripts.py --config migration_config.json --validate-only
python3 generate_scripts.py --config migration_config.json --validate-pre --connection "..."

# Generation
python3 generate_scripts.py --config migration_config.json

# Post-execution
python3 generate_scripts.py --config migration_config.json --validate-post --connection "..."
python3 generate_scripts.py --config migration_config.json --compare-data --connection "..."
python3 generate_scripts.py --config migration_config.json --validation-report report.md --connection "..."
```

---

## FAQ

**Q: Can I migrate multiple tables at once?**  
A: Yes, enable multiple tables in `migration_config.json`. Scripts generated for each table.

**Q: What if my table has triggers?**  
A: Triggers are automatically recreated. Check `60_restore_grants.sql`.

**Q: Can I change interval type after migration?**  
A: Yes, but requires another migration (old → new with different interval).

**Q: How do I handle foreign keys?**  
A: Framework detects dependencies in pre-migration validation. Disable FKs before migration, re-enable after.

**Q: Can I use this for Oracle 11g?**  
A: No, requires Oracle 12c+ for INTERVAL partitioning. 11g doesn't support it.

**Q: What about Oracle Autonomous Database?**  
A: Yes, fully supported. Use wallet-based connection strings.

---

## Summary

This framework provides a complete, production-ready solution for Oracle table partitioning migrations:

✅ **Automated discovery** - Analyzes your schema  
✅ **JSON-driven config** - Full user control  
✅ **Flexible intervals** - HOUR/DAY/WEEK/MONTH  
✅ **Hash subpartitioning** - Improved performance  
✅ **Integrated validation** - Pre/post checks  
✅ **Jinja2 templates** - Customizable SQL  
✅ **Minimal downtime** - Fast cutover  
✅ **Safe rollback** - Emergency procedures  

**Next Steps**: Try the [Quick Start](#quick-start-5-minutes) or explore the [Codespaces Test Environment](.devcontainer/README.md)
