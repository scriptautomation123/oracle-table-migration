# Migration Orchestration with plsql-util

## Overview

The orchestration scripts provide a complete, automated workflow for table migration using `plsql-util.sql`. These scripts allow a DBA to run as SYSDBA while executing all DDL operations.

## Architecture

```
orchestrate_migration.sh (Main orchestration)
    ↓
plsql-util.sql (Utility operations)
    ↓
Generated DDL Scripts (from output/)
```

## Components

### 1. Main Orchestration: `orchestrate_migration.sh`

Complete end-to-end migration orchestration that:
- Validates prerequisites
- Creates new partitioned table
- Loads data
- Creates indexes
- Gathers statistics
- Creates renamed view with INSTEAD OF trigger
- Finalizes swap
- Validates results

### 2. Subpartition Addition: `add_subpartitions_online.sh`

Adds hash subpartitions to interval-partitioned tables online:
- Validates table structure
- Adds subpartition template
- Applies to future partitions

### 3. Core Utility: `plsql-util.sql`

Provides operations:
- `READONLY`: Safe read-only checks
- `WRITE`: Constraint enable/disable
- `WORKFLOW`: Multi-step operations
- `CLEANUP`: Table cleanup

## Usage Examples

### Complete Migration

```bash
# Run as SYSDBA
cd templates/plsql-util
./orchestrate_migration.sh \
  APP_DATA_OWNER \
  AUDIT_LOG \
  "system/Oracle123@localhost:1521/FREEPDB1 AS SYSDBA"
```

### Add Hash Subpartitions Online

```bash
# Add 8 hash subpartitions on USER_ID column
cd templates/plsql-util
./add_subpartitions_online.sh \
  APP_DATA_OWNER \
  AUDIT_LOG \
  USER_ID \
  8 \
  "system/Oracle123@localhost:1521/FREEPDB1 AS SYSDBA"
```

### Manual Operations

```bash
# Validate table exists
./unified_wrapper.sh validate check_existence APP_DATA_OWNER AUDIT_LOG -c "$ORACLE_CONN"

# Create renamed view with INSTEAD OF trigger
./unified_wrapper.sh validate create_renamed_view APP_DATA_OWNER AUDIT_LOG -c "$ORACLE_CONN"

# Finalize swap
./unified_wrapper.sh validate finalize_swap APP_DATA_OWNER AUDIT_LOG -c "$ORACLE_CONN"
```

## Workflow Phases

### Phase 1: Pre-Migration Validation
- Check old table exists
- Count rows
- Check constraints

### Phase 2: Create New Table
- Execute `10_create_table.sql`
- Validate structure
- Verify partitioning

### Phase 3: Load Data
- Execute `20_data_load.sql` (initial load)
- Execute `40_delta_load.sql` (incremental)
- Validate row counts match

### Phase 4: Create Indexes
- Execute `30_create_indexes.sql`
- Create LOCAL indexes for partitioning

### Phase 5: Gather Statistics
- Execute `35_gather_statistics.sql`
- Enable optimizer to use new structure

### Phase 6: Rename Tables and Create View
- Rename: `TABLE` → `TABLE_OLD`
- Rename: `TABLE_NEW` → `TABLE`
- Create joined view
- Create INSTEAD OF trigger (INSERT → new table only)

### Phase 7: Swap Tables
- Execute `50_swap_tables.sql`
- Restore grants via `60_restore_grants.sql`

### Phase 8: Finalize and Validate
- Drop INSTEAD OF trigger
- Drop joined view
- Drop old table
- Rename new table to original name
- Recompile invalid objects
- Final validation

## Zero-Downtime Migration Pattern

```sql
-- Step 1: Create new table with partitioning
CREATE TABLE AUDIT_LOG_NEW ...

-- Step 2: Load initial data + delta
INSERT INTO AUDIT_LOG_NEW SELECT * FROM AUDIT_LOG ...

-- Step 3: Create indexes
CREATE INDEX ... LOCAL ON AUDIT_LOG_NEW ...

-- Step 4: Rename tables
ALTER TABLE AUDIT_LOG RENAME TO AUDIT_LOG_OLD;
ALTER TABLE AUDIT_LOG_NEW RENAME TO AUDIT_LOG;

-- Step 5: Create view joining both tables
CREATE VIEW AUDIT_LOG_JOINED AS
SELECT * FROM AUDIT_LOG  -- new table
UNION ALL
SELECT * FROM AUDIT_LOG_OLD  -- old table
WHERE NOT EXISTS (SELECT 1 FROM AUDIT_LOG WHERE ...);

-- Step 6: INSTEAD OF trigger routes INSERT to new table only
CREATE TRIGGER TG_AUDIT_LOG_JOINED_IOT
INSTEAD OF INSERT ON AUDIT_LOG_JOINED
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG VALUES :NEW.*;
END;

-- Step 7: After validation period, finalize
DROP TRIGGER TG_AUDIT_LOG_JOINED_IOT;
DROP VIEW AUDIT_LOG_JOINED;
DROP TABLE AUDIT_LOG_OLD PURGE;
ALTER TABLE AUDIT_LOG RENAME TO AUDIT_LOG_FINAL;
```

## Safety Features

1. **Validation at Each Phase**: Every step validates success before proceeding
2. **Rollback Capability**: View pattern allows rollback if issues found
3. **Statistics Gathering**: Ensures optimizer makes good decisions
4. **Constraint Validation**: Checks are recompiled after changes
5. **Logging**: All operations logged to timestamped directories

## Requirements

- Oracle 19c+ (for interval-hash partitioning)
- SYSDBA privileges for DBA operations
- sqlcl or sqlplus client
- Generated DDL from `output/` directory

## Troubleshooting

### Invalid Objects After Swap

```bash
# Run recompilation via plsql-util
./unified_wrapper.sh validate finalize_swap APP_DATA_OWNER AUDIT_LOG -c "$ORACLE_CONN"
```

### Statistics Not Updated

```bash
# Regather statistics
cd ../../output/APP_DATA_OWNER_AUDIT_LOG
sqlplus system/Oracle123@localhost:1521/FREEPDB1 AS SYSDBA @35_gather_statistics.sql
```

### Partition Distribution Issues

```bash
# Check partition distribution
./unified_wrapper.sh validate check_partitions APP_DATA_OWNER AUDIT_LOG -c "$ORACLE_CONN"
```

