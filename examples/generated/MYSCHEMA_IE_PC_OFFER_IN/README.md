# Migration Scripts: MYSCHEMA.IE_PC_OFFER_IN

## Overview

**Source Table**: `MYSCHEMA.IE_PC_OFFER_IN`
**Target Configuration**: INTERVAL
**Migration Action**: add_hash_subpartitions

## Current State

- **Partitioned**: True
- **Size**: 45.23 GB
- **Row Count**: 12,500,000
- **LOB Columns**: 2
- **Indexes**: 5

## Target Configuration

- **Partition Column**: `AUDIT_CREATE_DATE`
- **Interval Type**: MONTH
- **Hash Subpartitions**: 8 on `OFFER_ID`
- **Parallel Degree**: 4

## Estimated Time

**Total Migration Time**: ~9.4 hours

## Execution Steps

### Phase 1: Structure and Initial Load

```bash
sqlplus MYSCHEMA/password @master1.sql
```

This executes:
1. `10_create_table.sql` - Create new partitioned table
2. `20_data_load.sql` - Initial data load (~5.7 hours)
3. `30_create_indexes.sql` - Rebuild indexes (~3.8 hours)
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

- **Priority**: MEDIUM
- **Backup Old Table**: True
- **Drop After Days**: 7

Generated: 2025-10-22 01:30:55
