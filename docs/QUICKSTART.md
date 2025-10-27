# Oracle Table Migration - Quick Start Guide

## What This Tool Does

Migrates Oracle tables to different partitioning strategies with **zero manual intervention**. 

Execute one SQL file (`master1.sql`) and the complete migration runs automatically:
- Creates new partitioned table
- Migrates data (optional)
- Recreates constraints and indexes
- Atomically swaps old/new tables
- Restores grants

## Prerequisites

- Python 3.8+
- Oracle database (accessible)
- Oracle client tools (`sqlcl` or `sqlplus`)
- Sufficient database privileges (CREATE/DROP tables)

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd oracle-table-migration

# Install Python dependencies
pip3 install oracledb jinja2 jsonschema

# Verify Oracle client is available
sqlcl --version
```

## Quick Start: Run E2E Test

The easiest way to get started is to run the comprehensive E2E test:

```bash
# Set your Oracle connection details
export ORACLE_CONN="system/oracle123@localhost:1521/FREEPDB1"
export ORACLE_SCHEMA="APP_DATA_OWNER"

# Run the complete E2E test
python3 test/test_runner.py
```

This will:
1. Create a test schema with 10+ tables
2. Discover the schema structure
3. Generate migration SQL scripts
4. Execute the migrations
5. Validate the results
6. Generate comprehensive reports

## Manual Workflow

If you want to run individual steps manually:

### Step 1: Update Schema (if needed)

Edit the schema definition:
```bash
vi lib/enhanced_migration_schema.json
```

Generate Python dataclasses:
```bash
python3 src/schema_to_dataclass.py
```

### Step 2: Discover Your Schema

Discover tables from your Oracle database:
```bash
python3 src/generate.py --discover \
  --schema YOUR_SCHEMA \
  --connection "user/pass@host:port/service" \
  --output-dir output/discovery
```

This creates `output/discovery/config.json` with all table metadata.

### Step 3: Generate Migration Scripts

Generate the migration DDL:
```bash
python3 src/generate.py --config \
  output/discovery/config.json \
  --output-dir output/migration
```

This creates SQL scripts in `output/migration/`.

### Step 4: Execute Migration

Execute the generated migration:
```bash
sqlcl user/pass@database @output/migration/YOUR_TABLE/master1.sql
```

That's it! The migration runs completely automated.

## Output Structure

Every run creates a timestamped directory with complete artifacts:

```
output/run_YYYYMMDD_HHMMSS_dev_test/
├── 00_schema_setup/        # DDL execution logs
├── 01_discovery/           # Discovered configuration (JSON)
├── 02_generation/          # Generated SQL files
│   ├── YOUR_TABLE/
│   │   ├── master1.sql     # Complete migration script
│   │   ├── 10_create_table.sql
│   │   ├── 20_data_load.sql
│   │   ├── 30_create_indexes.sql
│   │   └── ...
├── 03_execution/           # Execution logs
├── 04_validation/          # Validation results
├── test_report.json        # Machine-readable report
└── test_report.md          # Human-readable report
```

## Key Features

### ✅ Schema-Driven Architecture
- Single source of truth: `enhanced_migration_schema.json`
- Auto-generated type-safe Python dataclasses
- Never work with dicts - always typed objects

### ✅ Real Database Only
- No mocks, no fake data
- Test against real Oracle databases
- Works identically in dev, test, and production

### ✅ Complete Automation
- Discovery from real Oracle schema
- Automatic partition strategy recommendation
- Template-based SQL generation
- Zero manual SQL writing required

### ✅ Comprehensive Validation
- Schema validation at each step
- SQL syntax validation
- Execution result verification
- Detailed error reporting

## Common Use Cases

### Migrate Range-Partitioned Table to Interval

```bash
# 1. Discover your current table
python3 src/generate.py --discover \
  --schema MY_SCHEMA \
  --connection "user/pass@db" \
  --output-dir output/my_migration

# 2. Edit config to specify interval partitioning
vi output/my_migration/config.json
# Set "target_partition_type": "INTERVAL"
# Set "interval_type": "DAY"

# 3. Generate migration
python3 src/generate.py --config output/my_migration/config.json

# 4. Execute
sqlcl user/pass@db @output/my_migration/MY_TABLE/master1.sql
```

### Test Complete Workflow

Use the comprehensive test suite:
```bash
# Run full E2E test with sample schema
python3 test/test_runner.py \
  --connection "system/oracle123@localhost:1521/FREEPDB1" \
  --schema APP_DATA_OWNER

# Review results
cat output/run_*_dev_test/test_report.md
```

### Iterate During Development

Skip schema setup for faster iterations:
```bash
# First run - creates test schema
python3 test/test_runner.py --connection "$ORACLE_CONN" --schema TEST_SCHEMA

# Subsequent runs - skip schema setup
python3 test/test_runner.py \
  --connection "$ORACLE_CONN" \
  --schema TEST_SCHEMA \
  --skip-schema-setup
```

## Data Flow Architecture

The tool follows this exact data flow:

```
1. Schema (JSON)          lib/enhanced_migration_schema.json
         ↓
2. Models (Python)        lib/migration_models.py (auto-generated)
         ↓
3. Discovery (Oracle DB)  Query real database → migration_config.json
         ↓
4. Generation (Templates) Jinja2 templates → SQL scripts
         ↓
5. Execution (Oracle DB)  Run master1.sql → Complete migration
```

**Never bypass this flow.** All data is type-safe throughout.

## Configuration

### Environment Variables

```bash
export ORACLE_CONN="system/oracle123@localhost:1521/FREEPDB1"
export ORACLE_SCHEMA="APP_DATA_OWNER"
```

### CLI Options

```bash
python3 test/test_runner.py \
  --connection "user/pass@host:port/service" \
  --schema SCHEMA_NAME \
  --mode dev          # dev (default), test, prod
  --skip-schema-setup # Skip creating test schema
  --verbose          # Detailed output
```

## Troubleshooting

### Connection Issues

```bash
# Test Oracle connection
sqlcl user/pass@host:port/service << 'EOF'
SELECT 1 FROM dual;
EXIT;
EOF
```

### Import Errors

```bash
# Verify Python packages
python3 -c "import oracledb, jinja2, jsonschema; print('OK')"
```

### Generation Errors

```bash
# Check configuration file
cat output/run_*/01_discovery/config.json

# Validate schema matches
python3 -c "from lib.migration_models import MigrationConfig; \
  MigrationConfig.from_json_file('output/run_*/01_discovery/config.json')"
```

## Next Steps

1. **Review Documentation**: See `test/README.md` for detailed E2E testing guide
2. **Explore Examples**: Check `output/` directory for sample migrations
3. **Read Architecture**: See `.cursorrules` for architecture principles
4. **Customize**: Edit `lib/enhanced_migration_schema.json` to add features

## Getting Help

- **Documentation**: Check `test/README.md` and `.cursorrules`
- **Examples**: Review generated output in `output/run_*/` directories
- **Reports**: Each test run creates detailed JSON and Markdown reports

## Success Criteria

Your migration is working correctly when:

✅ `master1.sql` runs completely without manual steps  
✅ All data migrated (if enabled)  
✅ Constraints and indexes recreated  
✅ Grants restored  
✅ Old table renamed to `TABLE_OLD`  
✅ New table is live as `TABLE`  

---

**Remember**: "It should just run master1.sql, nothing else should be required."
