# Development Instructions - Quick Reference

## 📚 **New Project Organization**

**🎯 Start Here:** `master_instructions_simplified.instructions.md` - The one-page overview

**📊 Architecture:** `project_overview.instructions.md` - Complete structure & diagrams

**🔄 Development:** `development_workflow.instructions.md` - Step-by-step development process

**🧪 Testing:** `tdd_framework.instructions.md` - Testing workflows & validation

**⚡ Quick Ref:** This file - Essential commands and current state

## When Working on This Project, Always:

1. **Start with simplified instructions** - Read `master_instructions_simplified.instructions.md` first
2. **Follow the core principle**: "it should just run master1.sql, nothing else should be required"
3. **Remember the purpose**: Migrate existing partitioned tables to differently partitioned tables
4. **Test changes** using the TDD loop before committing
5. **Validate completeness** with final-migration-test.sh

### Essential Commands for Development

### Discovery Mode (Generate Config from Database)
```bash
# Generate config from real Oracle database
python3 src/generate.py --discover --schema APP_DATA_OWNER --connection "sys/oracle123@localhost:1521/freepdb1" --output-file migration_config.json

# Discovery with table filtering
python3 src/generate.py --discover --schema SCHEMA --connection "conn_string" --include "APP_%"
```

### Generation Mode (Create Scripts from Config)
```bash
# Generate migration scripts from discovered config
python3 src/generate.py --config migration_config.json

# Validation mode
python3 src/generate.py --config migration_config.json --validate-only
```

### TDD Development Loop
```bash
# Full TDD loop with Oracle connection
./scripts/tdd-migration-loop.sh --connection my_oracle_db --verbose

# Development mode - just generate scripts  
./scripts/tdd-migration-loop.sh --generate-only --verbose

# Test specific tables
./scripts/tdd-migration-loop.sh --subset 'SALES_*' --iterations 3
```

### Final Validation
```bash
# Ultimate test - master1.sql completeness
./scripts/final-migration-test.sh --connection my_oracle_db --verbose

# Demo the validation framework
./scripts/demo-final-test.sh
```

### VS Code Management
```bash
# Quick config check
./scripts/check-vscode.sh

# Comprehensive settings management
./scripts/vscode-settings-manager.sh

# Disable unwanted extensions
./scripts/disable-unwanted-extensions.sh
```

### Critical Files for Development

### Must-Have for Context
1. **`src/generate.py`** - UNIFIED main entry point (discovery + generation)
2. **`src/generate_scripts.py`** - Reference implementation (complete discovery architecture)
3. **`templates/master1.sql.j2`** - Complete migration template  
4. **`test/data/comprehensive_oracle_ddl.sql`** - Full test schema
5. **`lib/migration_models.py`** - Core data structures
6. **`lib/discovery_queries.py`** - TableDiscovery class (database-driven schema analysis)
7. **`scripts/tdd-migration-loop.sh`** - TDD automation

### Configuration Files
- **`migration_config.json`** - Main migration config
- **`.vscode/settings.json`** - Workspace settings
- **`requirements.txt`** - Python dependencies

## Current State Summary

### ✅ Completed
- Complete Oracle DDL with constraints, indexes, referential integrity
- TDD framework with 7-phase automated workflow for re-partitioning testing
- Enhanced migration generation with constraint handling  
- Final validation test ensuring master1.sql completeness
- VS Code extension management system
- Comprehensive documentation and demo scripts

### 🎯 Current Focus: Re-Partitioning Migration Tool
**Purpose**: Migrate existing partitioned tables to differently partitioned tables

**Workflow**: 
1. Generate JSON config from existing table
2. Create DDL scripts from templates
3. Run master1.sql for complete re-partitioning
4. Validate zero errors and zero manual intervention

### 🔧 Key Features to Validate:
- ✅ **Discovery-driven**: Config generated from real Oracle database only
- ✅ Create `table_new` with different partitioning strategy
- ✅ Optional data migration with constraint disabling/enabling
- ✅ Delta loads configurable by partition key (last day/hour)
- ✅ Atomic table renames: `table → table_old; table_new → table`
- ✅ Grants capture in config.json and dynamic restoration
- ✅ Separate drop script generation (not part of master1.sql)
- ✅ **Real database connection required** - no mocking allowed

### 🎯 Next Steps
1. **Execute final test**: `./scripts/final-migration-test.sh --connection my_oracle_db`
2. **If test fails**: Enhance master1.sql template until it passes
3. **Production ready**: Ensure zero manual intervention required

### 🔑 Key Principle
**"it should just run master1.sql, nothing else should be required"** - This is the core requirement driving all development and validation efforts.

## Context File Usage
- **project_structure.md**: Architecture, dependencies, file relationships
- **configuration.md**: VS Code, Oracle, environment, and test configurations  
- **tdd_framework.md**: Test workflows, validation, and automation details
- **data_models.md**: Database schema, data structures, and template integration
- **quick_reference.md**: Essential commands and current state (this file)