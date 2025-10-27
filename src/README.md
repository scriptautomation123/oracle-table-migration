# Oracle Table Migration - Unified Runner

## Overview

The unified runner (`src/runner.py`) provides a single tool for:
- **Development**: Full end-to-end testing of migration workflows
- **Testing**: Automated validation and verification
- **Production**: Deployment and execution of table migrations

## Features

- Auto-detects SQL client (sqlcl → sqlplus fallback)
- Direct plsql-util.sql invocation for database validation
- LDAP thin client connection support
- Unified output directory structure
- Comprehensive error handling and reporting

## Installation

```bash
# Install dependencies
pip install oracledb jinja2 jsonschema

# Install SQL client (one of)
# Option 1: Oracle SQLcl
# Download from: https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/download/

# Option 2: Oracle SQL*Plus
# Download from: https://www.oracle.com/database/technologies/oracle-database-software-downloads.html
```

## Usage

### Test Mode - Full E2E Test

Executes complete workflow: schema setup → discovery → generation → execution → validation

```bash
# Basic usage
python3 src/runner.py test \
  --connection "system/oracle123@localhost:1521/FREEPDB1" \
  --schema APP_DATA_OWNER

# With options
python3 src/runner.py test \
  --connection "$ORACLE_CONN" \
  --schema APP_DATA_OWNER \
  --mode test \
  --skip-schema-setup \
  --sql-client sqlcl \
  --verbose

# Using environment variables
export ORACLE_CONN="system/oracle123@localhost:1521/FREEPDB1"
export SCHEMA="APP_DATA_OWNER"

python3 src/runner.py test --connection "$ORACLE_CONN" --schema "$SCHEMA"
```

**Available modes:**
- `dev` - Development mode (default)
- `test` - CI/CD test mode (auto-cleanup)
- `prod` - Production mode (no cleanup)

### Validate Mode - Database Validation

Execute validation operations directly on the database.

```bash
# Check if table exists
python3 src/runner.py validate check_existence \
  APP_OWNER MY_TABLE \
  --connection "$ORACLE_CONN"

# Count table rows
python3 src/runner.py validate count_rows \
  APP_OWNER MY_TABLE 1000 \
  --connection "$ORACLE_CONN"

# Validate constraints
python3 src/runner.py validate check_constraints \
  APP_OWNER MY_TABLE \
  --connection "$ORACLE_CONN"

# With options
python3 src/runner.py validate check_existence \
  APP_OWNER MY_TABLE \
  --connection "$ORACLE_CONN" \
  --sql-client sqlplus \
  --thin-ldap \
  --verbose
```

**Available operations:**
- `check_existence` - Verify table exists
- `count_rows` - Count table rows (optional expected value)
- `check_constraints` - Validate table constraints

### Discover Mode - Schema Discovery

Discover Oracle schema and generate migration configuration.

```bash
# Basic discovery
python3 src/runner.py discover \
  --schema APP_DATA_OWNER \
  --connection "$ORACLE_CONN"

# With output directory
python3 src/runner.py discover \
  --schema APP_DATA_OWNER \
  --connection "$ORACLE_CONN" \
  --output-dir output/my_discovery
```

### Generate Mode - DDL Generation

Generate DDL scripts from migration configuration.

```bash
# Generate from config
python3 src/runner.py generate \
  --config output/run_20251026_064542_full_workflow_test/01_discovery/config.json

# With custom output directory
python3 src/runner.py generate \
  --config path/to/config.json \
  --output-dir output/my_generation
```

### Migrate Mode - Migration Execution

Execute table migration operations.

```bash
# Generate migration DDL
python3 src/runner.py migrate generate \
  APP_OWNER MY_TABLE \
  --connection "$ORACLE_CONN"

# Execute migration
python3 src/runner.py migrate execute \
  APP_OWNER MY_TABLE \
  --connection "$ORACLE_CONN"

# Auto mode (generate + execute)
python3 src/runner.py migrate auto \
  APP_OWNER MY_TABLE \
  --connection "$ORACLE_CONN"
```

## Connection String Formats

### Standard Oracle Connection

```bash
# Format: username/password@hostname:port/service_name
python3 src/runner.py test \
  --connection "system/oracle123@localhost:1521/FREEPDB1" \
  --schema APP_DATA_OWNER
```

### LDAP Thin Client Connection

```bash
# Format: username/password@ldap://ldap-server:389/distinguished-name
python3 src/runner.py test \
  --connection "system/oracle123@ldap://ldap.example.com:389/cn=Database,cn=OracleContext" \
  --schema APP_DATA_OWNER \
  --thin-ldap
```

## Output Structure

All modes create timestamped output directories:

```
output/
└── run_20251026_064542_dev_test/
    ├── 00_schema_setup/         # Schema setup logs
    ├── 01_discovery/             # Discovery config
    │   └── config.json
    ├── 02_generation/            # Generated DDL
    │   └── SCHEMA_TABLE/
    │       └── master1.sql
    ├── 03_execution/              # Execution logs
    ├── 04_validation/             # Validation results
    └── test_report.md             # Test report
```

## CLI Options

### Global Options

- `--connection` - Oracle connection string (required for most commands)
- `--sql-client` - Force specific SQL client: `sqlcl` or `sqlplus`
- `--thin-ldap` - Enable LDAP thin client mode
- `--verbose` - Enable verbose output

### Test Mode Options

- `--mode` - Test mode: `dev`, `test`, `prod` (default: `dev`)
- `--skip-schema-setup` - Skip schema setup phase

### Validation Mode Options

- `operation` - Validation operation (check_existence, count_rows, check_constraints)
- `args` - Arguments for the operation (owner, table, [additional...])

## Examples

### Complete Development Workflow

```bash
# 1. Discover schema
python3 src/runner.py discover \
  --schema APP_DATA_OWNER \
  --connection "system/oracle123@localhost:1521/FREEPDB1"

# Output: output/run_YYYYMMDD_HHMMSS_discovery/discovery/

# 2. Generate DDL from discovered config
python3 src/runner.py generate \
  --config output/run_YYYYMMDD_HHMMSS_discovery/discovery/config.json

# Output: output/run_YYYYMMDD_HHMMSS_generation/SCHEMA_TABLE/master1.sql

# 3. Execute generated DDL
sqlcl system/oracle123@localhost:1521/FREEPDB1 @output/run_YYYYMMDD_HHMMSS_generation/SCHEMA_TABLE/master1.sql
```

### Production Deployment

```bash
# Deploy migration
python3 src/runner.py migrate auto \
  APP_OWNER MY_TABLE \
  --connection "prod_user/password@ldap://ldap.prod.com:389/cn=ProdDB" \
  --thin-ldap

# Validate deployment
python3 src/runner.py validate check_existence \
  APP_OWNER MY_TABLE \
  --connection "prod_user/password@ldap://ldap.prod.com:389/cn=ProdDB" \
  --thin-ldap
```

### CI/CD Testing

```bash
# Run full E2E test with auto-cleanup
python3 src/runner.py test \
  --connection "$ORACLE_TEST_CONN" \
  --schema APP_DATA_OWNER \
  --mode test \
  --verbose
```

## Troubleshooting

### SQL Client Not Found

If you see `ERROR: No SQL client found`, install sqlcl or sqlplus:

```bash
# Check if installed
which sqlcl
which sqlplus

# Install sqlcl
# Download from Oracle website and add to PATH

# Or install sqlplus
# Download from Oracle website and add to PATH
```

### LDAP Connection Issues

Enable `--thin-ldap` flag for LDAP connections:

```bash
python3 src/runner.py discover \
  --schema APP_DATA_OWNER \
  --connection "$LDAP_CONN" \
  --thin-ldap
```

### Permission Errors

Ensure your Oracle user has required privileges:
- `SELECT` on target schemas
- `CREATE TABLE` for migration
- `ALTER TABLE` for table swaps
- `DROP TABLE` for cleanup

## Architecture

```
src/runner.py (Main CLI)
    │
    ├── cmd_test()      → TestOrchestrator (E2E workflow)
    ├── cmd_validate()  → ValidationRunner (Database validation)
    ├── cmd_migrate()   → Migration execution
    ├── cmd_discover()  → Schema discovery
    └── cmd_generate()  → DDL generation

src/lib/
    ├── sql_executor.py       # SQL client detection & execution
    ├── validation_runner.py  # Database validation operations
    ├── test_orchestrator.py  # E2E test workflow
    ├── test_config.py        # Configuration management
    ├── test_executor.py      # Step execution
    ├── test_validator.py     # Validation logic
    └── test_reporter.py      # Report generation
```

## Related Documentation

- [Pl/SQL Utility Suite](../../templates/plsql-util/README.md) - Database validation utilities
- [Migration Schema](../../lib/enhanced_migration_schema.json) - Configuration schema
- [Template Documentation](../templates/) - DDL generation templates

