# PL/SQL Utility Suite

## Overview

This directory contains the **consolidated PL/SQL utility suite** for Oracle table migration operations.

## Files

### Core Utility
- **plsql-util.sql** - Main consolidated utility with category-based operations

### Execution Layer
- **unified_runner.sh** - Low-level SQL script execution wrapper
- **unified_wrapper.sh** - High-level user-friendly interface

### Emergency Procedures
- **rollback/** - Emergency rollback procedures (if needed)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ unified_wrapper.sh (High-Level User Interface)              │
│  • User-friendly commands                                    │
│  • Color-coded output                                        │
│  • Argument parsing                                          │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ unified_runner.sh (Execution Wrapper)                       │
│  • SQL client detection                                      │
│  • Output directory management                               │
│  • Error handling                                            │
│  • Result parsing                                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ plsql-util.sql (Core Utility)                               │
│  • Category: READONLY - Safe validation                     │
│  • Category: WRITE - Schema modifications                   │
│  • Category: WORKFLOW - Multi-step operations               │
│  • Category: CLEANUP - Table management                     │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Direct SQL Usage

```sql
@plsql-util.sql <category> <operation> <args...>
```

**Examples:**
```sql
-- Check if table exists
@plsql-util.sql READONLY check_existence OWNER TABLE_NAME

-- Count rows with expected value
@plsql-util.sql READONLY count_rows OWNER TABLE_NAME 1000000

-- Enable constraints
@plsql-util.sql WRITE enable_constraints OWNER TABLE_NAME

-- Post-create validation
@plsql-util.sql WORKFLOW post_create OWNER TABLE_NAME 4
```

### Shell Wrapper Usage

**Validate:**
```bash
./unified_wrapper.sh validate check_existence APP_OWNER MY_TABLE -c "$ORACLE_CONN"
./unified_wrapper.sh validate count_rows APP_OWNER MY_TABLE 1000000 -c "$ORACLE_CONN"
```

**Migrate:**
```bash
./unified_wrapper.sh migrate generate APP_OWNER MY_TABLE -c "$ORACLE_CONN"
./unified_wrapper.sh migrate execute APP_OWNER MY_TABLE -c "$ORACLE_CONN"
```

## Categories

### READONLY
- `check_sessions` - Check for active sessions
- `check_existence` - Verify table exists
- `check_table_structure` - Validate table structure
- `count_rows` - Count rows (with optional comparison)
- `check_constraints` - Check constraint status
- `check_partition_dist` - Show partition distribution

### WRITE
- `enable_constraints` - Enable all constraints
- `disable_constraints` - Disable all constraints

### WORKFLOW
- `pre_swap` - Pre-swap validation
- `post_swap` - Post-swap validation
- `post_data_load` - Post-load validation and stats
- `post_create` - Post-create validation and stats

### CLEANUP
- `drop` - Drop table with purge
- `rename` - Rename table

## Features

✅ **Consolidated** - All validation operations in one file
✅ **Category-based** - Clear separation (READONLY, WRITE, WORKFLOW, CLEANUP)
✅ **Consistent** - Uniform error handling across all operations
✅ **ALL_* views** - All queries use ALL_* views with owner filters
✅ **Production-ready** - No TODOs, comprehensive error handling

## Migration from Old Scripts

All old validation scripts have been archived:
- `01_validator_readonly.sql` → `plsql-util.sql` READONLY category
- `01_validator_write.sql` → `plsql-util.sql` WRITE category
- `02_workflow_validator.sql` → `plsql-util.sql` WORKFLOW category
- `post_create_table_checks.sql` → `plsql-util.sql` WORKFLOW post_create operation

See `templates/validation/archive/` for historical reference.
