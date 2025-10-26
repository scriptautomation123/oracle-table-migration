# Quick Start Guide

Get up and running with Oracle table migration in 5 minutes.

## Prerequisites

- Python 3.7+
- Oracle SQLcl installed and configured
- Access to source Oracle database

## Installation

1. **Clone and setup:**
   ```bash
   git clone <repository-url>
   cd oracle-table-migration
   pip install -r requirements.txt
   ```

## Basic Usage

### 1. Copy Sample Configuration
```bash
cp examples/configs/migration_config.json my_migration.json
```

### 2. Edit Configuration
Edit `my_migration.json` for your table:

```json
{
  "table_name": "MY_TABLE",
  "schema_name": "MY_SCHEMA", 
  "target_partitioning": {
    "type": "RANGE",
    "partition_key": "DATE_COLUMN",
    "interval": "MONTHLY"
  },
  "migration_options": {
    "migrate_data": true,
    "enable_delta_loads": true
  }
}
```

### 3. Generate Migration Scripts
```bash
python src/generate.py --config my_migration.json
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
