# Archived Validation Scripts

## Overview

These scripts are **deprecated and archived**. They have been **consolidated into 2 core scripts** for improved maintainability and consistency.

## Deprecation Date

2025-01-27

## Migration

### New Architecture

All validation is now handled by:

1. **`../01_validator.sql`** - Basic validation operations
2. **`../02_workflow_validator.sql`** - Workflow-specific validation

### Migration Guide

See `../README.md` for complete migration documentation.

### Quick Reference

| Old Script | New Script + Operation |
|------------|----------------------|
| `check_active_sessions.sql` | `01_validator.sql check_sessions` |
| `check_table_exists.sql` | `01_validator.sql check_existence` |
| `validate_table_structure.sql` | `01_validator.sql check_table_structure` |
| `count_table_rows.sql` | `01_validator.sql count_rows` |
| `enable_constraints.sql` | `01_validator.sql check_constraints` with `enable` |
| `disable_constraints.sql` | `01_validator.sql check_constraints` with `disable` |
| `partition_distribution_summary.sql` | `01_validator.sql check_partition_dist` |
| `table_swap_validation.sql` | `02_workflow_validator.sql pre_swap` |
| `post_swap_validation.sql` | `02_workflow_validator.sql post_swap` |
| `rollback_validation.sql` | `02_workflow_validator.sql rollback` |
| `post_data_load_checks.sql` | `02_workflow_validator.sql post_data_load` |
| `pre_operation_checks.sql` | Use multiple `01_validator.sql` operations |

## Why Archived?

- **Reduced Complexity**: 16 scripts → 2 core scripts
- **Consistent Patterns**: All validation uses same message format
- **Easier Maintenance**: Single location for each operation type
- **Better Reusability**: Operations can be combined flexibly
- **Simplified Templates**: Easier to read and maintain Jinja2 templates

## Backward Compatibility

These scripts are kept for backward compatibility only. **Do not use for new development.**

If you need to reference the old functionality, see:
- `../README.md` for consolidated validation architecture
- `../CONSOLIDATION_SUMMARY.md` for migration summary
