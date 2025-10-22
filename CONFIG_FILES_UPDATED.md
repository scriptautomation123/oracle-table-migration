# Configuration Files Updated

## Overview

Updated all example configuration files to include the new features added in recent changes:

1. **Table Naming**: Added `new_table_name` and `old_table_name` fields
2. **Constraint Validation**: Added constraint validation settings

## Files Updated

### 1. `examples/configs/config_nonpartitioned_to_interval_hash.json`

**Added to each table:**
```json
{
  "table_name": "ORDERS",
  "new_table_name": "ORDERS_NEW",
  "old_table_name": "ORDERS_OLD",
  // ... other fields
  "migration_settings": {
    // ... existing settings
    "constraint_validation": true,
    "auto_enable_constraints": true
  }
}
```

**Tables updated:**
- `ORDERS` → `ORDERS_NEW` / `ORDERS_OLD`
- `TRANSACTIONS` → `TRANSACTIONS_NEW` / `TRANSACTIONS_OLD`

### 2. `examples/configs/config_interval_to_interval_hash.json`

**Added to each table:**
```json
{
  "table_name": "IE_PC_OFFER_IN",
  "new_table_name": "IE_PC_OFFER_IN_NEW", 
  "old_table_name": "IE_PC_OFFER_IN_OLD",
  // ... other fields
  "migration_settings": {
    // ... existing settings
    "constraint_validation": true,
    "auto_enable_constraints": true
  }
}
```

**Tables updated:**
- `IE_PC_OFFER_IN` → `IE_PC_OFFER_IN_NEW` / `IE_PC_OFFER_IN_OLD`
- `IE_PC_SEQ_OUT` → `IE_PC_SEQ_OUT_NEW` / `IE_PC_SEQ_OUT_OLD`
- `IE_CONTROL_TABLE` → `IE_CONTROL_TABLE_NEW` / `IE_CONTROL_TABLE_OLD`

### 3. `examples/configs/example_migration_config_with_environment.json`

**Already updated** - this file already had:
- ✅ `new_table_name` and `old_table_name` fields
- ✅ `constraint_validation` and `auto_enable_constraints` settings
- ✅ Environment configuration

## New Features Added

### Table Naming
- **`new_table_name`**: Name for the new partitioned table (e.g., `ORDERS_NEW`)
- **`old_table_name`**: Name for the backup of original table (e.g., `ORDERS_OLD`)

### Constraint Validation
- **`constraint_validation`**: `true` - Check constraint states before table swap
- **`auto_enable_constraints`**: `true` - Automatically enable disabled constraints

## Benefits

1. **✅ Consistent Naming**: All tables follow the same naming convention
2. **✅ Constraint Safety**: Prevents swapping tables with disabled constraints
3. **✅ Auto-Recovery**: Automatically enables constraints when possible
4. **✅ Production Ready**: Safe defaults for production environments

## Usage

These updated configuration files can now be used with the latest migration system:

```bash
# Generate scripts from updated config
python3 generate_scripts.py --config examples/configs/config_nonpartitioned_to_interval_hash.json

# The generated scripts will include:
# - Proper table naming in templates
# - Constraint validation in swap operations
# - Environment-specific settings
```

All configuration files are now consistent with the latest migration system features! 🚀
