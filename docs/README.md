# Oracle Table Migration Tool

A comprehensive tool for migrating Oracle tables to different partitioning strategies with zero manual intervention.

## Purpose

This tool performs **Oracle table re-partitioning migrations** by:
1. Creating a new table with different partitioning strategy
2. Optionally migrating data with constraint management
3. Performing delta loads until differences are minimal  
4. Executing atomic table swaps
5. Restoring all constraints, indexes, and grants

**Core Principle:** *"It should just run master1.sql, nothing else should be required"*

## Quick Start

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Copy sample configuration:**
   ```bash
   cp examples/configs/migration_config.json my_config.json
   ```

3. **Edit configuration for your table:**
   ```bash
   nano my_config.json
   ```

4. **Generate migration scripts:**
   ```bash
   python src/generate.py --config my_config.json
   ```

5. **Execute migration:**
   ```sql
   @output/master1.sql
   ```

## Project Structure

```
oracle-table-migration/
├── src/                        # Core application
│   └── generate.py            # Main entry point
├── lib/                       # Support libraries  
├── templates/                 # Jinja2 SQL templates
├── scripts/                   # Development utilities
├── test/                      # Testing framework
├── examples/                  # Sample configs & outputs
└── docs/                      # Documentation
```

## Key Features

- ✅ **Zero Manual Intervention** - Complete automation
- ✅ **All Partitioning Types** - Range, List, Hash, Interval, Composite
- ✅ **Constraint Management** - Dynamic disable/enable during migration
- ✅ **Referential Integrity** - Preserves all FK relationships
- ✅ **Index Recreation** - All index types supported
- ✅ **Grant Restoration** - Automatic privilege management
- ✅ **Atomic Operations** - All-or-nothing table swaps
- ✅ **Delta Loads** - Configurable incremental synchronization
- ✅ **Comprehensive Testing** - TDD framework included

## Development Workflow

For development and testing:

```bash
# Run TDD loop for iterative development
./scripts/tdd-migration-loop.sh --connection my_oracle_db --verbose

# Final validation test
./scripts/final-migration-test.sh --connection my_oracle_db
```

## Documentation

- [Quick Start Guide](docs/quick-start.md) - Get started in 5 minutes
- [User Guide](docs/user-guide.md) - Comprehensive usage documentation  
- [Project Structure](docs/project-structure.md) - Detailed architecture

## Success Criteria

A successful migration means:
- ✅ `master1.sql` executes without errors
- ✅ All data migrated (exact row count match)
- ✅ All constraints re-enabled and validated
- ✅ All indexes recreated with proper partitioning
- ✅ Referential integrity preserved
- ✅ All grants restored
- ✅ **Zero manual intervention required**

## License

See LICENSE file for details.