# Unified Runner Consolidation Plan

## Overview
Create `src/runner.py` to replace `test_runner.py` + `unified_wrapper.sh` + `unified_runner.sh`, providing a single tool for development testing, validation, and production deployment.

## Architecture

### Command Structure (Hybrid)
```bash
# Test/E2E mode (orchestrates full workflow)
python3 src/runner.py test --connection CONN --schema SCHEMA [options]

# Validation mode (direct plsql-util.sql invocation)
python3 src/runner.py validate <operation> <args> --connection CONN

# Migration mode (direct execution)
python3 src/runner.py migrate <mode> <owner> <table> --connection CONN

# Discovery mode (schema discovery only)
python3 src/runner.py discover --schema SCHEMA --connection CONN [options]

# Generation mode (DDL generation only)
python3 src/runner.py generate --config CONFIG.json [options]
```

### Key Features
- Auto-detect SQL client (sqlcl → sqlplus fallback) with `--sql-client` override
- Direct plsql-util.sql invocation for validation operations
- LDAP thin client support via connection string detection
- Unified output directory structure for all modes
- Comprehensive error handling and reporting

## Implementation Steps

### 1. Create Core Runner Module (`src/runner.py`)
- Main entry point with argparse subcommands: `test`, `validate`, `migrate`, `discover`, `generate`
- SQL client detection function (check sqlcl, then sqlplus, with override)
- LDAP connection string parsing and handling
- Unified output directory creation with timestamping

### 2. Create SQL Executor Module (`src/lib/sql_executor.py`)
Consolidate SQL execution logic from shell scripts:
- `find_sql_client()` - auto-detect sqlcl/sqlplus
- `execute_sql_script()` - run SQL file with sqlcl/sqlplus
- `execute_plsql_util()` - invoke plsql-util.sql with category/operation/args
- `parse_sql_output()` - extract RESULT: PASSED/FAILED from logs
- Connection string parsing for LDAP thin client support

### 3. Create Validation Module (`src/lib/validation_runner.py`)
Port unified_runner.sh validation logic:
- `validate_table_existence(owner, table, connection)`
- `validate_row_count(owner, table, expected, connection)`
- `validate_constraints(owner, table, connection)`
- `validate_pre_swap(owner, table, new, old, connection)`
- `validate_post_swap(owner, table, old, connection)`
All operations call plsql-util.sql via sql_executor

### 4. Refactor Test Orchestrator (`src/lib/test_orchestrator.py`)
Move E2E workflow logic from `test_runner.py`:
- Keep 8-step workflow (schema setup → dataclass gen → discover → generate → validate → execute → validate → report)
- Use sql_executor for all SQL operations
- Use validation_runner for database validation
- Maintain TestConfig, TestValidator, TestReporter integration

### 5. Update Existing Library Modules
Relocate and enhance test/lib modules:
- Move `test/lib/*.py` → `src/lib/`
- Update imports in all modules
- Enhance `test_executor.py` to use sql_executor for SQL operations
- Add LDAP connection support to test_config.py

### 6. Create Unified CLI Interface (`src/runner.py` main)
Implement argparse with subcommands:

**test subcommand:**
```python
parser_test = subparsers.add_parser('test')
parser_test.add_argument('--connection', required=True)
parser_test.add_argument('--schema', required=True)
parser_test.add_argument('--mode', choices=['dev', 'test', 'prod'], default='dev')
parser_test.add_argument('--skip-schema-setup', action='store_true')
parser_test.add_argument('--sql-client', choices=['sqlcl', 'sqlplus'])
```

**validate subcommand:**
```python
parser_validate = subparsers.add_parser('validate')
parser_validate.add_argument('operation', choices=['check_existence', 'count_rows', ...])
parser_validate.add_argument('args', nargs='*')
parser_validate.add_argument('--connection', required=True)
parser_validate.add_argument('--sql-client', choices=['sqlcl', 'sqlplus'])
```

**migrate subcommand:**
```python
parser_migrate = subparsers.add_parser('migrate')
parser_migrate.add_argument('mode', choices=['generate', 'execute', 'auto'])
parser_migrate.add_argument('owner')
parser_migrate.add_argument('table')
parser_migrate.add_argument('--connection', required=True)
```

**discover subcommand:**
```python
parser_discover = subparsers.add_parser('discover')
parser_discover.add_argument('--schema', required=True)
parser_discover.add_argument('--connection', required=True)
parser_discover.add_argument('--output-dir')
```

**generate subcommand:**
```python
parser_generate = subparsers.add_parser('generate')
parser_generate.add_argument('--config', required=True)
parser_generate.add_argument('--output-dir')
```

### 7. Implement LDAP Thin Client Support
- Parse connection strings for LDAP format
- Handle both standard and LDAP Oracle connections
- Pass appropriate connection format to sqlcl/sqlplus

### 8. Update Documentation
- Create `src/README.md` with comprehensive usage examples
- Update root README.md to reference src/runner.py
- Add examples for all command modes
- Document LDAP connection format

### 9. Archive Old Files
After validation:
- Archive `templates/test/test_runner.py` → `docs/archive/`
- Archive `templates/plsql-util/unified_runner.sh` → `docs/archive/`
- Archive `templates/plsql-util/unified_wrapper.sh` → `docs/archive/`
- Archive `templates/test/lib/*.py` (after moving to src/lib/)
- Update `.cursorrules` to reference new runner location

### 10. Integration Testing
- Test all command modes: test, validate, migrate, discover, generate
- Verify sqlcl/sqlplus auto-detection
- Test LDAP connection strings
- Validate plsql-util.sql invocation
- Ensure output directory structure consistency

## File Structure After Changes
```
src/
  runner.py                    # Main unified CLI entry point
  generate.py                  # Existing (unchanged)
  schema_to_dataclass.py      # Existing (unchanged)
  lib/
    sql_executor.py            # NEW: SQL client detection & execution
    validation_runner.py       # NEW: Database validation operations
    test_orchestrator.py       # NEW: E2E test workflow (from test_runner.py)
    test_config.py            # MOVED from templates/test/lib/
    test_executor.py          # MOVED (enhanced with sql_executor)
    test_validator.py         # MOVED from templates/test/lib/
    test_reporter.py          # MOVED from templates/test/lib/
    __init__.py               # NEW

templates/
  plsql-util/
    plsql-util.sql           # KEEP (unchanged)
    README.md                # KEEP (unchanged)
  
docs/archive/
  test_runner.py             # ARCHIVED
  unified_runner.sh          # ARCHIVED
  unified_wrapper.sh         # ARCHIVED
```

## Success Criteria
1. Single `src/runner.py` handles all modes (test, validate, migrate, discover, generate)
2. Auto-detects SQL client (sqlcl → sqlplus fallback)
3. Supports LDAP thin client connections
4. Direct plsql-util.sql invocation for validation
5. Maintains full E2E test workflow compatibility
6. Same tool works for dev, test, and production
7. Comprehensive CLI help for all subcommands
8. All existing test cases pass with new runner

## Migration Path
1. Create new modules without touching existing files
2. Implement and test each subcommand independently
3. Validate against existing test workflows
4. Archive old files only after full validation
5. Update documentation last