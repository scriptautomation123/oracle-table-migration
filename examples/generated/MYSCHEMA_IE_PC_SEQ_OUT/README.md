# Migration Scripts: MYSCHEMA.IE_PC_SEQ_OUT

## Overview

**Source Table**: `MYSCHEMA.IE_PC_SEQ_OUT`
**Target Configuration**: INTERVAL
**Migration Action**: convert_interval_to_interval_hash

## Current State

- **Partitioned**: True
- **Size**: 12.50 GB
- **Row Count**: 3,200,000
- **LOB Columns**: 1
- **Indexes**: 3

## Target Configuration

- **Partition Column**: `PROCESS_DATE`
- **Interval Type**: DAY
- **Hash Subpartitions**: 4 on `SEQ_ID`
- **Parallel Degree**: 2

## Estimated Time

**Total Migration Time**: ~3.8 hours

## Execution Steps

### Phase 1: Structure and Initial Load

```bash
sqlplus MYSCHEMA/password @master1.sql
```

This executes:
1. `10_create_table.sql` - Create new partitioned table
2. `20_data_load.sql` - Initial data load (~1.6 hours)
3. `30_create_indexes.sql` - Rebuild indexes (~2.2 hours)
4. `40_delta_load.sql` - Load incremental changes

### Phase 2: Cutover and Cleanup

**After validating Phase 1:**

```bash
sqlplus MYSCHEMA/password @master2.sql
```

This executes:
5. `50_swap_tables.sql` - Rename tables (downtime starts here)
6. `60_restore_grants.sql` - Restore privileges
7. `70_drop_old_table.sql` - Drop old table (optional)

## Individual Scripts

Run scripts individually for more control:

```bash
# Create structure
sqlplus MYSCHEMA/password @10_create_table.sql

# Load data
sqlplus MYSCHEMA/password @20_data_load.sql

# Create indexes
sqlplus MYSCHEMA/password @30_create_indexes.sql

# Delta load (if needed)
sqlplus MYSCHEMA/password @40_delta_load.sql

# Cutover (downtime)
sqlplus MYSCHEMA/password @50_swap_tables.sql

# Restore grants
sqlplus MYSCHEMA/password @60_restore_grants.sql

# Drop old table (optional)
sqlplus MYSCHEMA/password @70_drop_old_table.sql
```

## Validation

Before cutover, run validation:

```bash
cd ../../03_validation
sqlplus MYSCHEMA/password @pre_migration_checks.sql
sqlplus MYSCHEMA/password @data_comparison.sql
```

After cutover:

```bash
sqlplus MYSCHEMA/password @post_migration_validation.sql
```

## Rollback

If issues occur, see `../../04_rollback/emergency_rollback.sql`

## Notes

- **Priority**: LOW
- **Backup Old Table**: True
- **Drop After Days**: 7

Generated: 2025-10-22 01:30:55
