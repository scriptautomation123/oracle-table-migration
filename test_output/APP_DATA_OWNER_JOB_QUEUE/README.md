# Migration Scripts for APP_DATA_OWNER.JOB_QUEUE

Generated on: 2025-10-25T22:09:23.503599

## Files Generated:
- `master1.sql` - **MAIN SCRIPT** - Complete migration (run this only)
- `10_create_table.sql` - Create new partitioned table
- `20_data_load.sql` - Migrate data (if enabled)
- `30_create_indexes.sql` - Recreate indexes
- `40_delta_load.sql` - Delta load script (if enabled)
- `50_swap_tables.sql` - Atomic table swap
- `60_restore_grants.sql` - Restore grants
- `70_drop_old_table.sql` - Drop old table (manual step)
- `dynamic_grants.sql` - Backup grants script

## Usage:
1. Review the generated scripts
2. Connect to Oracle database as appropriate user
3. Execute: `@master1.sql`
4. Validate results
5. Optionally run: `@70_drop_old_table.sql` (after verification)

## Migration Details:
- **Source Table**: APP_DATA_OWNER.JOB_QUEUE
- **Target Table**: APP_DATA_OWNER.JOB_QUEUE_NEW
- **Migration Action**: add_interval_hash_partitioning
- **Current Size**: 0.01 GB
- **Row Count**: 4 rows
- **Current Partitioning**: NONE
- **Target Partitioning**: INTERVAL

## Important Notes:
- **CRITICAL**: master1.sql should run completely without manual intervention
- All steps are included in master1.sql for zero-downtime migration
- Review scripts before execution in production
- Keep backups before running migration
