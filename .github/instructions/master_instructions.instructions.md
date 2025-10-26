````instructions
# Master Development Instructions

## Tool Purpose: Oracle Table Re-Partitioning Migration
**This tool migrates existing partitioned tables to differently partitioned tables**

The whole purpose is to:
1. Create `table_new` with different partitioning strategy
2. Optionally migrate data with constraint handling
3. Perform atomic rename operations: `table → table_old; table_new → table`
4. Validate complete success with zero manual intervention

## Core Development Principles

### 1. Single Source of Truth
- **Schema**: `comprehensive_oracle_ddl.sql` defines ALL supported Oracle features
- **Templates**: `master1.sql.j2` contains complete re-partitioning workflow
- **Validation**: `final-migration-test.sh` proves zero-manual-intervention requirement

### 2. Test-Driven Development Workflow
```bash
# ALWAYS start here
./scripts/tdd-migration-loop.sh --validate-only

# Develop iteratively
./scripts/tdd-migration-loop.sh --generate-only --verbose

# Final validation before commit
./scripts/final-migration-test.sh --connection my_oracle_db
```

### 3. Code Generation Strategy
- **Generate JSON config** → **Create DDL scripts** → **Run master1.sql** → **Validate success**
- Never manually edit generated files
- Always enhance templates, not output
- Must include option to backup or drop `table_new` if it already exists

## When You Need To:

### Add New Oracle Feature
1. Add to `test_data/comprehensive_oracle_ddl.sql`
2. Update `lib/discovery_queries.py` detection logic
3. Enhance `lib/migration_models.py` enums/dataclasses
4. Update `templates/master1.sql.j2` with new functionality
5. Test with TDD loop until final validation passes

### Fix Re-Partitioning Issue
1. Identify gap in `master1.sql.j2` template
2. Enhance template with missing functionality
3. Run `./scripts/final-migration-test.sh` until it passes
4. Never add manual steps - fix the template instead

### Add Grants Management
1. Capture grants as part of generation into `config.json`
2. Create `dynamic_grants.sql` script for grant restoration
3. Include grants restoration in workflow but keep it separate
4. Test grant preservation across table rename operations

### Enhance Validation
1. Add test case to `comprehensive_oracle_ddl.sql`
2. Update `final-migration-test.sh` validation criteria
3. Ensure template handles new validation requirement
4. Create demo script showing new capability

## Critical Success Criteria

### master1.sql Must:
- ✅ Execute without any errors
- ✅ Create `table_new` with different partitioning
- ✅ Optionally migrate data with constraint disabling/enabling
- ✅ Perform atomic table renames: `table → table_old; table_new → table` 
- ✅ Recreate all constraints and indexes
- ✅ Preserve referential integrity and grants
- ✅ Handle deltas with configurable partition keys (last day/hour)
- ✅ Require ZERO manual intervention

### Test Success Definition:
- ✅ Generate JSON config successfully
- ✅ Create DDL scripts from templates  
- ✅ Run master1.sql and get everything running
- ✅ Zero errors and zero manual intervention
- ✅ All data migrated with validation (row counts match exactly)
- ✅ All constraints re-enabled and validated
- ✅ All indexes recreated with proper partitioning

### Development Must:
- ✅ Always use TDD loop for testing
- ✅ Validate against comprehensive DDL schema
- ✅ Pass final migration test before commit
- ✅ Follow single-script principle religiously
- ✅ Include option to backup or drop existing `table_new`

## Context File Priority
1. **master_instructions.md** (this file) - Overall development approach
2. **quick_reference.md** - Essential commands and current state
3. **tdd_framework.md** - Testing workflow and validation
4. **project_structure.md** - Architecture and file relationships
5. **configuration.md** - Settings and environment setup
6. **data_models.md** - Data structures and templates