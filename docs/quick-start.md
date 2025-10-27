# Quick Start Guide

Get up and running with Oracle table migration in 5 minutes.

## Prerequisites

- Python 3.7+
- Access to source Oracle database with connection details

## Installation

1. **Clone and setup:**
   ```bash
   git clone <repository-url>
   cd oracle-table-migration
   pip install -r requirements.txt
   ```

## Basic Usage

### 1. Discover Your Schema
```bash
python3 src/generate.py --discover --schema YOUR_SCHEMA --connection "user/password@host:port/service"
```

**Example:**
```bash
python3 src/generate.py --discover --schema APP_DATA_OWNER --connection "system/oracle123@localhost:1521/FREEPDB1"
```

This will:
- Analyze all tables in your schema
- Generate a complete configuration file
- Display the config file location prominently

### 2. Generate Migration Scripts
```bash
python3 src/generate.py --config output/run_*/01_discovery/config.json
```

This creates `output/MY_SCHEMA_MY_TABLE/` directory with:
- `master1.sql` - Complete migration script
- Individual step scripts (called by master1.sql)
- `README.md` - Migration documentation

### 4. Execute Migration
```bash
sqlcl user/pass@database @output/MY_SCHEMA_MY_TABLE/master1.sql
```

### 5. Optional Cleanup
```bash
sqlcl user/pass@database @output/MY_SCHEMA_MY_TABLE/70_drop_old_table.sql
```

## Validation

Before running in production, validate your configuration:
```bash
python src/generate.py --config my_migration.json --validate-only
```

## Development/Testing

For development work:
```bash
# Run TDD loop for testing
./scripts/tdd-migration-loop.sh --connection my_db --verbose

# Final validation
./scripts/final-migration-test.sh --connection my_db
```

## Next Steps

- Review [User Guide](user-guide.md) for advanced configuration
- Check [Project Structure](project-structure.md) for architecture details
- See `examples/generated/` for sample outputs
