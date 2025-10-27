# Archived Validation Scripts

## Status: ARCHIVED - Functionality Consolidated

These scripts have been **consolidated into `plsql-util.sql`**.

### Archived Files:
- `01_validator_readonly.sql` - Consolidated into `plsql-util.sql` READONLY category
- `01_validator_write.sql` - Consolidated into `plsql-util.sql` WRITE category
- `01_validator.sql` - Deprecated (combined both read-only and write)
- `02_workflow_validator.sql` - Consolidated into `plsql-util.sql` WORKFLOW category
- `post_create_table_checks.sql` - Consolidated into `plsql-util.sql` WORKFLOW post_create operation

## Why Archived?

All functionality from these scripts is now in **`templates/plsql-util.sql`**:
- Single unified utility
- Category-based architecture (READONLY, WRITE, WORKFLOW, CLEANUP)
- Consistent error handling
- All queries use ALL_* views with owner filters

## New Usage:

Instead of:
```sql
@validation/01_validator_readonly.sql check_existence OWNER TABLE
```

Use:
```sql
@plsql-util.sql READONLY check_existence OWNER TABLE
```

## When to Keep These Archive References:

- Historical reference for migration logic
- Understanding evolution of validation architecture
- Debugging if `plsql-util.sql` issues arise

## Active Scripts (Not Archived):

- `cleanup_tables.sql` - Generic cleanup utility (standalone)
- `instead_of.sql` - Educational INSTEAD OF trigger example
- `rollback/emergency_rollback.sql` - Emergency rollback procedures

