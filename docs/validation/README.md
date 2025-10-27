# Validation Scripts - Consolidated Architecture

## Overview

The validation architecture has been **consolidated from 16 scripts into 3 core scripts** for improved maintainability and consistency:

1. **`01_validator.sql`** - Unified validator for basic operations
2. **`02_workflow_validator.sql`** - Workflow-specific validation (swap, rollback)
3. **`README.md`** - This documentation

## Core Scripts

### 1. `01_validator.sql` - Unified Operations

**Purpose**: Single validator for basic validation operations

**Usage**: `@validation/01_validator.sql <operation> <owner> <table_name> [args...]`

**Operations**:

| Operation | Args | Description |
|-----------|------|-------------|
| `check_sessions` | `<owner>` `<table_name>` | Check for active sessions using table |
| `check_existence` | `<owner>` `<table_name>` | Verify table exists |
| `check_table_structure` | `<owner>` `<table_name>` | Validate table structure + partitioning |
| `count_rows` | `<owner>` `<table_name>` `[expected_count]` | Count rows with optional comparison |
| `check_constraints` | `<owner>` `<table_name>` `[action]` `[auto_enable]` | Check/enable/disable constraints |
| `check_partition_dist` | `<owner>` `<table_name>` | Show partition distribution |

**Examples**:
```sql
-- Check for active sessions
@validation/01_validator.sql check_sessions {{ owner }} {{ table_name }}

-- Count rows with comparison
@validation/01_validator.sql count_rows {{ owner }} {{ table_name }} {{ expected_count }}

-- Enable constraints
@validation/01_validator.sql check_constraints {{ owner }} {{ table_name }} enable

-- Check partition distribution
@validation/01_validator.sql check_partition_dist {{ owner }} {{ table_name }}
```

### 2. `02_workflow_validator.sql` - Workflow Validation

**Purpose**: Workflow-specific validation for table swaps and rollback scenarios

**Usage**: `@validation/02_workflow_validator.sql <operation> <owner> <table_name> [args...]`

**Operations**:

| Operation | Args | Description |
|-----------|------|-------------|
| `pre_swap` | `<owner>` `<table_name>` `<new_table_name>` `<old_table_name>` | Pre-swap validation |
| `post_swap` | `<owner>` `<table_name>` `<old_table_name>` | Post-swap validation |
| `rollback` | `<owner>` `<table_name>` `<old_table_name>` `<new_table_name>` | Rollback analysis |
| `post_create` | `<owner>` `<table_name>` `<parallel_degree>` | Post-create validation + stats |
| `post_data_load` | `<owner>` `<target>` `<source>` `<source_count>` `<parallel_degree>` | Post-load validation |

**Examples**:
```sql
-- Pre-swap validation
@validation/02_workflow_validator.sql pre_swap {{ owner }} {{ table_name }} {{ new_table_name }} {{ old_table_name }}

-- Post-swap validation
@validation/02_workflow_validator.sql post_swap {{ owner }} {{ table_name }} {{ old_table_name }}

-- Rollback analysis
@validation/02_workflow_validator.sql rollback {{ owner }} {{ table_name }} {{ old_table_name }} {{ new_table_name }}

-- Post-create with stats gathering
@validation/02_workflow_validator.sql post_create {{ owner }} {{ table_name }} {{ parallel_degree }}

-- Post-data-load validation
@validation/02_workflow_validator.sql post_data_load {{ owner }} {{ target }} {{ source }} {{ source_count }} {{ parallel_degree }}
```

## Migration from Old Scripts

### Old → New Mapping

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
| `post_create_table_checks.sql` | `02_workflow_validator.sql post_create` |
| `post_data_load_checks.sql` | `02_workflow_validator.sql post_data_load` |
| `pre_operation_checks.sql` | Use multiple `01_validator.sql` operations |
| `swap_constraint_validation.sql` | `01_validator.sql check_constraints` with `auto_enable` |
| `verify_table_states.sql` | `01_validator.sql check_table_structure` |
| `check_validation_result.sql` | Obsolete - handled internally |

### Example Migrations

**Old**:
```sql
@validation/check_active_sessions.sql {{ owner }} {{ table_name }} {{ new_table_name }}
@validation/check_table_exists.sql {{ owner }} {{ table_name }}
@validation/enable_constraints.sql {{ owner }} {{ table_name }}
```

**New**:
```sql
@validation/01_validator.sql check_sessions {{ owner }} {{ table_name }}
@validation/01_validator.sql check_existence {{ owner }} {{ table_name }}
@validation/01_validator.sql check_constraints {{ owner }} {{ table_name }} enable
```

## Validation Result Messages

All validators use **consistent status messages**:

- `VALIDATION RESULT: PASSED - [description]` - Validation succeeded
- `VALIDATION RESULT: FAILED - [description]` - Validation failed  
- `VALIDATION RESULT: WARNING - [description]` - Warning (non-fatal)
- `VALIDATION RESULT: ERROR - [error details]` - Error occurred
- `VALIDATION RESULT: COMPLETED - [description]` - Operation completed
- `VALIDATION RESULT: INFO - [description]` - Informational message

## Error Handling Pattern

Validation scripts **return status messages** but **do not raise exceptions**. The caller (template) decides how to handle failures:

```sql
BEGIN
    @validation/01_validator.sql check_constraints {{ owner }} {{ table_name }} enable {{ auto_enable }}
EXCEPTION
    WHEN OTHERS THEN
        -- Template decides how to handle
        IF {{ continue_on_error }} THEN
            DBMS_OUTPUT.PUT_LINE('Warning: Continuing despite validation failure');
        ELSE
            RAISE_APPLICATION_ERROR(-20004, 'Validation failed: ' || SQLERRM);
        END IF;
END;
```

## Benefits

1. **Reduced Complexity**: 16 scripts → 2 core scripts
2. **Consistent Patterns**: All validation uses same message format
3. **Easier Maintenance**: Single location for each operation type
4. **Better Reusability**: Operations can be combined flexibly
5. **Simplified Templates**: Easier to read and maintain Jinja2 templates

## Template Integration

All validation is called from Jinja2 templates with proper error handling:

```sql
-- Example from master1.sql.j2
BEGIN
    @validation/02_workflow_validator.sql post_data_load 
        {{ owner }} 
        {{ new_table_name }} 
        {{ table_name }} 
        {{ current_state.row_count }} 
        {{ target_configuration.parallel_degree }}
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Data load validation failed: ' || SQLERRM);
        RAISE;
END;
```

## Legacy Scripts

The old individual scripts are still present for backward compatibility but are **deprecated**. All new templates should use the consolidated validators.
