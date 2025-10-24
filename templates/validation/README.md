# Validation Scripts

This directory contains reusable validation scripts for Oracle database operations.

## Available Scripts

### 1. `check_active_sessions.sql`
**Purpose**: Check for active sessions using specified tables
**Usage**: `@validation/check_active_sessions.sql <owner> <table_name1> [table_name2] [table_name3]`
**Features**:
- Checks for active sessions using the specified tables
- Provides detailed session information if found
- Raises error if active sessions are detected
- Supports up to 3 table names

### 2. `check_active_sessions_function.sql`
**Purpose**: PL/SQL function to check active sessions
**Usage**: Can be called from within PL/SQL blocks
**Features**:
- Returns count of active sessions
- Accepts comma-separated table names
- Can be used in conditional logic
- Handles errors gracefully

### 3. `pre_operation_checks.sql`
**Purpose**: Comprehensive pre-operation validation
**Usage**: `@validation/pre_operation_checks.sql <owner> <table_name1> [table_name2] [table_name3]`
**Features**:
- Active session checks
- Table existence validation
- Constraint state validation
- Permission checks
- Comprehensive error reporting

### 4. `check_table_exists.sql`
**Purpose**: Check if a table exists
**Usage**: `@validation/check_table_exists.sql <owner> <table_name>`
**Features**:
- Validates table existence
- Provides drop command if table exists
- Raises error if table already exists

### 5. `validate_table_structure.sql`
**Purpose**: Validate table structure after creation
**Usage**: `@validation/validate_table_structure.sql <owner> <table_name>`
**Features**:
- Verifies table was created successfully
- Shows partitioning information
- Validates table properties

### 6. `enable_constraints.sql`
**Purpose**: Enable constraints on a table
**Usage**: `@validation/enable_constraints.sql <owner> <table_name>`
**Features**:
- Enables all disabled constraints
- Orders by constraint type (PK, UK, Check, FK)
- Provides detailed feedback

### 7. `disable_constraints.sql`
**Purpose**: Disable constraints on a table
**Usage**: `@validation/disable_constraints.sql <owner> <table_name>`
**Features**:
- Disables all constraints
- Orders by constraint type (FK, Check, UK, PK)
- Provides detailed feedback

### 8. `count_table_rows.sql`
**Purpose**: Count rows in tables
**Usage**: `@validation/count_table_rows.sql <owner> <table_name>`
**Features**:
- Counts rows in specified table
- Shows row count information
- Useful for data validation

### 9. `partition_distribution_summary.sql`
**Purpose**: Show partition distribution
**Usage**: `@validation/partition_distribution_summary.sql <owner> <table_name>`
**Features**:
- Shows partition information
- Displays row counts per partition
- Useful for partitioned table validation

### 10. `post_data_load_checks.sql`
**Purpose**: Post-data-load validation
**Usage**: `@validation/post_data_load_checks.sql <owner> <table_name>`
**Features**:
- Validates data load success
- Checks row counts
- Verifies data integrity

### 11. `post_create_table_checks.sql`
**Purpose**: Post-table-creation validation
**Usage**: `@validation/post_create_table_checks.sql <owner> <table_name>`
**Features**:
- Validates table creation
- Checks constraints
- Verifies table properties

### 12. `table_swap_validation.sql`
**Purpose**: Comprehensive table swap validation
**Usage**: `@validation/table_swap_validation.sql <owner> <table_name> <new_table_name> <old_table_name>`
**Features**:
- Active session checks
- Table existence validation
- Constraint state validation
- Permission checks
- Pre-swap state verification

### 13. `post_swap_validation.sql`
**Purpose**: Post-swap validation
**Usage**: `@validation/post_swap_validation.sql <owner> <table_name> <old_table_name>`
**Features**:
- Verifies swap success
- Checks table naming
- Validates data accessibility
- Verifies constraint states

### 14. `rollback_validation.sql`
**Purpose**: Rollback validation for failed swaps
**Usage**: `@validation/rollback_validation.sql <owner> <table_name> <old_table_name> <new_table_name>`
**Features**:
- Analyzes current state
- Provides rollback recommendations
- Checks data integrity
- Suggests recovery actions

### 15. `swap_constraint_validation.sql`
**Purpose**: Constraint validation specifically for table swap operations
**Usage**: `@validation/swap_constraint_validation.sql <owner> <table_name> <auto_enable>`
**Features**:
- Checks for disabled constraints
- Optionally auto-enables constraints
- Provides detailed constraint status
- Handles constraint enabling in proper order

### 16. `verify_table_states.sql`
**Purpose**: Verify current state of specified tables
**Usage**: `@validation/verify_table_states.sql <owner> <table_name1> [table_name2] [table_name3]`
**Features**:
- Shows table existence
- Displays partitioning status
- Shows table status and properties
- Provides row counts and analysis dates
- Supports up to 3 tables for comparison

## Integration with Templates

The validation scripts are designed to be called from Jinja2 templates:

```sql
-- In a Jinja2 template
@validation/pre_operation_checks.sql {{ owner }} {{ table_name }} {{ new_table_name }}
```

## Error Handling

All validation scripts:
- Use consistent error codes
- Provide detailed error messages
- Include recommendations for resolution
- Support graceful failure handling

## Best Practices

1. **Always run pre-operation checks** before critical operations
2. **Use comprehensive validation** for table swaps and migrations
3. **Check active sessions** before any DDL operations
4. **Validate constraints** before and after operations
5. **Use appropriate validation level** based on operation criticality

## Example Usage in Templates

```sql
-- Pre-operation validation
@validation/pre_operation_checks.sql {{ owner }} {{ table_name }} {{ new_table_name }}

-- Post-operation validation
@validation/post_create_table_checks.sql {{ owner }} {{ table_name }}
```

## Error Codes

- `-20001`: Active sessions found
- `-20002`: Table does not exist
- `-20003`: Constraint validation failed
- `-20004`: Permission denied
- `-20005`: Validation failed

## Dependencies

- Oracle Database 11g or later
- Appropriate database privileges
- Access to system views (v$session, v$sqlarea, all_tables, etc.)
