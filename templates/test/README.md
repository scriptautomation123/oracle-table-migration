# Oracle Migration End-to-End Testing

## Overview

This directory contains the comprehensive E2E test framework for the Oracle table migration system. The test runner executes the complete workflow following the exact data flow architecture:

```
Schema (JSON) → Models (Python) → Discovery (Oracle) → JSON Config →
Generation (Templates) → SQL Output → Execution (Oracle)
```

## Key Principles

1. **Real Database Only**: No mocking, no fake data - always test against real Oracle database
2. **Repeatable**: Every test run creates timestamped directory with complete artifacts
3. **Type-Safe Throughout**: Use typed dataclasses from `migration_models.py`
4. **Comprehensive Validation**: Validate at each step, not just at the end
5. **Same Workflow**: Dev, test, and production all follow identical workflow

## Test Runner Architecture

### Components

- **`test_runner.py`**: Main orchestrator that executes the E2E workflow
- **`lib/test_config.py`**: Configuration management (CLI args, env vars)
- **`lib/test_executor.py`**: Execute workflow steps (DDL, Python scripts)
- **`lib/test_validator.py`**: Validate results at each step
- **`lib/test_reporter.py`**: Generate JSON and Markdown reports

### Workflow Steps

1. **Schema Setup**: Execute `comprehensive_oracle_ddl.sql` to create test schema
2. **Generate Dataclasses**: Run `schema_to_dataclass.py` to generate Python models
3. **Discover Schema**: Run `generate.py --discover` to query Oracle and create config
4. **Generate DDL**: Run `generate.py --config` to generate SQL scripts
5. **Validate Generated**: Check SQL files exist and are valid
6. **Execute DDL**: Run generated `master1.sql` files against Oracle
7. **Validate Results**: Verify migration completed successfully
8. **Generate Reports**: Create JSON and Markdown reports

## Usage

### Basic Usage

```bash
# Development mode (default)
python3 test/test_runner.py \
  --connection "system/oracle123@localhost:1521/FREEPDB1" \
  --schema APP_DATA_OWNER

# Test mode (cleanup on success)
python3 test/test_runner.py \
  --connection "$ORACLE_CONN" \
  --schema APP_DATA_OWNER \
  --mode test

# Production mode (strict validation)
python3 test/test_runner.py \
  --connection "$ORACLE_CONN" \
  --schema APP_DATA_OWNER \
  --mode prod
```

### Using Environment Variables

```bash
export ORACLE_CONN="system/oracle123@localhost:1521/FREEPDB1"
export ORACLE_SCHEMA="APP_DATA_OWNER"
python3 test/test_runner.py
```

### Advanced Options

```bash
# Skip schema setup for iterative testing
python3 test/test_runner.py --skip-schema-setup

# Verbose output
python3 test/test_runner.py --verbose

# Specific tables only (not yet implemented)
# python3 test/test_runner.py --tables "SALES_HISTORY,CUSTOMER_REGIONS"
```

## Output Structure

Every test run creates a timestamped directory with complete artifacts:

```
output/
└── run_YYYYMMDD_HHMMSS_{mode}_test/
    ├── 00_schema_setup/
    │   ├── comprehensive_oracle_ddl.log
    │   └── schema_verification.sql
    ├── 01_discovery/
    │   ├── config.json              # Migration configuration
    │   └── discovery.log
    ├── 02_generation/
    │   ├── SALES_HISTORY/
    │   │   ├── master1.sql          # Complete migration script
    │   │   ├── 10_create_table.sql
    │   │   ├── 20_data_load.sql
    │   │   └── ...
    │   ├── CUSTOMER_REGIONS/
    │   └── ...
    ├── 03_execution/
    │   ├── SALES_HISTORY_execution.log
    │   ├── CUSTOMER_REGIONS_execution.log
    │   └── ...
    ├── 04_validation/
    │   ├── validation_results.json
    │   └── comparison_report.md
    ├── test_report.json             # Machine-readable report
    └── test_report.md               # Human-readable report
```

## Reports

### JSON Report (`test_report.json`)

Machine-readable report for CI/CD integration:

```json
{
  "test_run_id": "a1b2c3d4",
  "timestamp": "2024-10-26T12:34:56",
  "mode": "dev",
  "status": "SUCCESS",
  "duration_seconds": 123.45,
  "steps": {
    "schema_setup": {...},
    "discovery": {...},
    "generation": {...},
    "execution": {...},
    "validation": {...}
  },
  "metrics": {
    "tables_discovered": 10,
    "tables_migrated": 10,
    "sql_files_generated": 90,
    "master_scripts_executed": 10
  },
  "errors": [],
  "warnings": []
}
```

### Markdown Report (`test_report.md`)

Human-readable report with:

- Test summary (status, duration, mode)
- Metrics (tables discovered, SQL files generated, etc.)
- Step-by-step results with timing
- Errors and warnings
- Validation details

## Data Flow

The complete data flow follows this architecture:

### 1. Schema Definition

- Source: `lib/enhanced_migration_schema.json`
- Type: JSON Schema
- Purpose: Single source of truth for all data structures

### 2. Model Generation

```bash
python3 src/schema_to_dataclass.py
```

- Output: `lib/migration_models.py`
- Type: Python dataclasses
- Purpose: Type-safe Python classes with serialization

### 3. Schema Discovery

```bash
python3 src/generate.py --discover --schema SCHEMA --connection CONN_STRING
```

- Input: Real Oracle database connection
- Output: `migration_config.json`
- Type: Validated JSON matching schema
- Purpose: Discovered table metadata, constraints, indexes

### 4. DDL Generation

```bash
python3 src/generate.py --config path/to/config.json
```

- Input: `migration_config.json`
- Output: SQL scripts (master1.sql, 10_create_table.sql, etc.)
- Type: Executable Oracle DDL
- Purpose: Complete migration scripts

### 5. SQL Execution

```bash
sqlcl user/pass@db @output/TABLE/master1.sql
```

- Input: Generated SQL files
- Output: Executed migration in Oracle
- Purpose: Complete table re-partitioning migration

## Prerequisites

- Python 3.8+
- Oracle database (accessible via sqlcl)
- Required Python packages:
  - oracledb (python-oracledb)
  - jinja2
  - jsonschema
- Oracle client tools (sqlcl or sqlplus)

## Test Requirements

- Real Oracle database (no mocks)
- Connection with CREATE/DROP privileges
- Repeatable: can run multiple times
- Self-contained: `comprehensive_oracle_ddl.sql` creates test schema
- Isolated: uses dedicated APP_DATA_OWNER schema for testing

## Manual Workflow

For reference, the manual workflow steps are:

```bash
# 1. Update schema (if needed)
vi lib/enhanced_migration_schema.json

# 2. Generate dataclasses
python3 src/schema_to_dataclass.py

# 3. Discover schema from Oracle
python3 src/generate.py --discover \
  --schema APP_DATA_OWNER \
  --connection "system/oracle123@localhost:1521/FREEPDB1" \
  --output-dir output/run_001_discovery

# 4. Generate DDL from config
python3 src/generate.py --config \
  output/run_001_discovery/config.json \
  --output-dir output/run_001_generation

# 5. Execute generated DDL
sqlcl system/oracle123@localhost:1521/FREEPDB1 \
  @output/run_001_generation/SALES_HISTORY/master1.sql
```

The E2E test runner automates all of these steps in a single command.

## Troubleshooting

### Connection Issues

```bash
# Test Oracle connection manually
sqlcl user/pass@host:port/service

# Verify environment variables
echo $ORACLE_CONN
echo $ORACLE_SCHEMA
```

### Schema Not Found

Ensure the test schema exists:

```bash
sqlcl $ORACLE_CONN << 'EOF'
SELECT table_name FROM all_tables WHERE owner = 'APP_DATA_OWNER';
EOF
```

### Generated Files Missing

Check generation logs:

```bash
cat output/run_*/02_generation/generation.log
```

## Integration with CI/CD

The test runner provides proper exit codes:

- Exit code 0: Test passed
- Exit code 1: Test failed
- Exit code 130: Interrupted by user

Example CI/CD usage:

```yaml
test:
  script:
    - python3 test/test_runner.py --connection "$ORACLE_CONN" --schema APP_DATA_OWNER
  artifacts:
    paths:
      - output/
    expire_in: 30 days
```

## Best Practices

1. **Always use real Oracle database** - no mocks
2. **Keep output directories** - they contain complete artifacts for review
3. **Review test reports** - check Markdown reports for details
4. **Test iteratively** - use `--skip-schema-setup` for faster iterations
5. **Validate configuration** - ensure config.json is valid before generation

## Development Workflow

When developing or debugging:

1. Make changes to schema or code
2. Run full test: `python3 test/test_runner.py`
3. Review output in timestamped directory
4. If schema unchanged, use `--skip-schema-setup` for speed
5. Iterate until tests pass
6. Review generated SQL and reports
7. Commit changes with test output as reference

## Related Files

- `comprehensive_oracle_ddl.sql`: Complete test schema
- `test_runner.py`: Main E2E test orchestration
- `.cursorrules`: Project rules and architecture documentation
- `plan.md`: Refactoring plan with test integration
