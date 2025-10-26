# VS Code Configuration Management

This directory contains scripts to help manage and monitor your VS Code settings and extensions.

## Quick Reference

### Scripts Available

1. **`check-vscode.sh`** - Quick overview of all VS Code configurations
2. **`vscode-settings-manager.sh`** - Comprehensive settings management tool

### Usage

```bash
# Quick check of current configuration
./scripts/check-vscode.sh

# Detailed analysis and management
./scripts/vscode-settings-manager.sh

# Create backup of current settings
./scripts/vscode-settings-manager.sh backup
```

## VS Code Settings Hierarchy

VS Code settings are applied in this order (later ones override earlier):

1. **Default Settings** - Built into VS Code
2. **User Settings** - `~/.config/Code/User/settings.json` (Global)
3. **Workspace Settings** - `.vscode/settings.json` (Project-specific)
4. **Folder Settings** - For multi-root workspaces

## Oracle Table Migration Test-Driven Development Framework

### Overview
This project now includes a comprehensive TDD framework for Oracle table migration development with:

- **Comprehensive DDL**: Complete test schema with constraints, indexes, and referential integrity
- **TDD Loop**: Automated drop → create → load → generate → test cycle
- **Enhanced Generation**: Constraint-aware migration script generation
- **Iterative Development**: Quick feedback loop for rapid development
- **Extensive Validation**: Multi-level testing and error reporting

### Key Components

#### 1. Test Schema (`test_data/comprehensive_oracle_ddl.sql`)
- **10 test tables** with full Oracle features:
  - Non-partitioned reference tables (REGIONS, PRODUCTS, SALES_REPS, CUSTOMERS)
  - Range partitioned (SALES_HISTORY)
  - List partitioned (CUSTOMER_REGIONS) 
  - Hash partitioned (USER_SESSIONS)
  - Interval partitioned (AUDIT_LOG)
  - Composite partitioned (ORDER_DETAILS, TRANSACTION_LOG)

- **Comprehensive constraints**:
  - Primary keys with identity columns
  - Foreign keys with referential integrity
  - Check constraints with business rules
  - Unique constraints
  - Complex multi-column constraints

- **Advanced indexes**:
  - Simple, composite, and function-based indexes
  - Local partitioned indexes for performance
  - Global indexes for cross-partition queries
  - Bitmap and reverse key indexes

#### 2. TDD Loop Script (`scripts/tdd-migration-loop.sh`)
Complete automated testing workflow:

```bash
# Full TDD loop with Oracle connection
./scripts/tdd-migration-loop.sh --connection my_oracle_db --verbose

# Development mode - just generate scripts
./scripts/tdd-migration-loop.sh --generate-only --verbose

# Test specific table patterns
./scripts/tdd-migration-loop.sh --subset "SALES_*" --iterations 3

# Continuous integration mode
./scripts/tdd-migration-loop.sh --continue-on-error --report-file ci_report.txt
```

#### 3. Enhanced Generator (`enhanced_generate_scripts.py`)
Advanced migration script generation with:
- Constraint disable/enable scripts
- Referential integrity preservation
- Composite index recreation
- Comprehensive validation reporting

#### 4. Schema Discovery Enhancement (`lib/discovery_queries.py`)
Extended with:
- Constraint relationship mapping
- Referential integrity analysis
- Composite and function-based index detection
- Dependency level analysis

### Quick Start

#### 1. Basic Demo
```bash
# Run the demo to see available options
./scripts/demo-tdd-loop.sh
```

#### 2. Environment Setup
```bash
# Validate your environment
./scripts/tdd-migration-loop.sh --validate-only

# Check current VS Code configuration
./scripts/check-vscode.sh
```

#### 3. Oracle Connection Setup
```bash
# Set up Oracle connection (one-time)
sqlcl /nolog
conn username/password@//host:port/service
save connection my_oracle_db
exit
```

#### 4. Full TDD Development Loop
```bash
# Complete cycle: drop → create → load → discover → generate → validate
./scripts/tdd-migration-loop.sh --connection my_oracle_db --verbose

# For rapid development iterations (skip database phases)
./scripts/tdd-migration-loop.sh --generate-only --config my_config.json
```

### TDD Loop Phases

1. **Drop Phase**: Clean removal of existing test tables
2. **Create Phase**: Full DDL execution with constraints and indexes
3. **Load Phase**: Realistic test data insertion with validation
4. **Discovery Phase**: Live schema analysis and metadata extraction
5. **Generation Phase**: Migration script creation with enhancements
6. **Validation Phase**: Script syntax and logic validation
7. **Reporting Phase**: Comprehensive success/error reporting

### Development Workflow

```bash
# 1. Code changes to generation logic
vim lib/migration_models.py
vim generate_scripts.py

# 2. Quick test iteration
./scripts/tdd-migration-loop.sh --generate-only --verbose

# 3. Full validation with database
./scripts/tdd-migration-loop.sh --connection my_db --iterations 1

# 4. Stress test with multiple iterations
./scripts/tdd-migration-loop.sh --connection my_db --iterations 5 --continue-on-error
```

### Generated Artifacts

Each table migration produces:
- `00_disable_constraints.sql` - FK constraint management
- `10_create_table.sql` - New partitioned table DDL
- `20_data_load.sql` - Data migration with validation
- `30_create_indexes.sql` - Standard index creation
- `35_recreate_indexes.sql` - Complex index recreation
- `40_delta_load.sql` - Incremental change handling
- `50_swap_tables.sql` - Atomic table replacement
- `60_restore_grants.sql` - Privilege restoration
- `70_drop_old_table.sql` - Cleanup procedures
- `80_enable_constraints.sql` - Constraint validation
- `master1.sql` - Complete migration execution
- `master2.sql` - Rollback procedures
- `MIGRATION_SUMMARY.md` - Comprehensive report

### Advanced Features

#### Multiple Index Types Support
- **Composite indexes**: Multi-column indexes with proper LOCAL/GLOBAL locality
- **Function-based indexes**: Preserved expressions and computations
- **Bitmap indexes**: For low-cardinality columns
- **Reverse key indexes**: For sequence-based columns

#### Constraint Handling
- **Foreign key cascading**: Proper dependency order management
- **Check constraint validation**: Business rule preservation
- **Identity column migration**: Sequence continuity
- **Unique constraint enforcement**: Data integrity maintenance

#### Referential Integrity Analysis
- **Dependency mapping**: Parent-child relationship identification
- **Cascade impact analysis**: Understanding FK deletion effects
- **Constraint validation**: Post-migration integrity verification
- **Circular dependency detection**: Complex relationship handling

### VS Code Configuration Management

#### Current Configuration Summary

### Workspace Settings (`.vscode/settings.json`)
- File exclusions for search/watch
- Extension recommendations disabled
- Extension details auto-close

### Extensions Configuration (`.vscode/extensions.json`)
- **Recommended**: trunk.io, github.copilot, github.copilot-chat, maciejdems.add-to-gitignore
- **Unwanted**: All other currently installed extensions

### Important Notes

- ⚠️ `extensions.autoCheckUpdates` and `extensions.autoUpdate` can only be set in **User Settings**
- Workspace extension recommendations will prompt you to disable unwanted extensions for this project
- Extensions remain installed globally but can be disabled per-workspace

## Troubleshooting

If you see warnings about settings that "can only be set in user settings":
1. Remove those settings from `.vscode/settings.json`
2. Add them to `~/.config/Code/User/settings.json` instead

## Common Commands

```bash
# List installed extensions
code --list-extensions

# Disable extension for current workspace
code --disable-extension <extension-id>

# Enable extension for current workspace  
code --enable-extension <extension-id>

# Open user settings
code ~/.config/Code/User/settings.json

# Open workspace settings
code .vscode/settings.json
```

## Backup & Recovery

The `vscode-settings-manager.sh backup` command creates timestamped backups in `.vscode-backups/`:
- `settings_YYYYMMDD_HHMMSS.json` - Workspace settings
- `extensions_YYYYMMDD_HHMMSS.json` - Extensions config
- `user_settings_YYYYMMDD_HHMMSS.json` - User settings
- `installed_extensions_YYYYMMDD_HHMMSS.txt` - Extension list

To restore, simply copy the backup files back to their original locations.