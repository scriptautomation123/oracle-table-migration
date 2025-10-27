# DDL Executor - PL/SQL-Driven Migration Framework

## Overview

The DDL Executor provides a **PL/SQL-driven approach** to table migrations, moving all logic into Oracle while maintaining clean separation of concerns through multiple shell script layers.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 4: executor.sh (User Interface)                          │
│  • Validates input parameters                                  │
│  • Provides help and documentation                            │
│  • Calls runner.sh                                              │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 3: runner.sh (Execution Orchestrator)                    │
│  • Executes PL/SQL with correct parameters                     │
│  • Handles output redirection and logging                     │
│  • Manages SQL client selection                               │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 2: executor.sql (PL/SQL Controller)                      │
│  • GENERATE: Creates SQL files to disk                        │
│  • EXECUTE: Reads and executes SQL files from disk            │
│  • AUTO: Generates and executes in memory                      │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 1: Pure SQL Scripts (.sql)                               │
│  • Only SQL DDL statements                                     │
│  • No control flow, no variables                               │
│  • Example: CREATE TABLE, ALTER TABLE, etc.                    │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. executor.sh (Wrapper)
**Purpose**: User-friendly interface for running migrations

**Usage**:
```bash
./validation/executor.sh <mode> <owner> <table> [options]
```

**Features**:
- Parameter validation
- Help and documentation
- Environment variable support
- Colored output

### 2. runner.sh (Runner)
**Purpose**: Execute PL/SQL with proper configuration

**Usage**:
```bash
./validation/runner.sh <mode> <owner> <table> [connection] [sql_client]
```

**Features**:
- SQL client auto-detection
- Output directory creation
- Logging and error handling
- Timestamped output

### 3. executor.sql (PL/SQL Controller)
**Purpose**: PL/SQL script that handles DDL generation and execution

**Modes**:
- **GENERATE**: Create SQL files to disk
- **EXECUTE**: Read and execute SQL files from disk
- **AUTO**: Generate and execute in memory

**Usage**:
```sql
@validation/templates/executor.sql GENERATE APP_DATA_OWNER MY_TABLE
@validation/templates/executor.sql EXECUTE APP_DATA_OWNER MY_TABLE
@validation/templates/executor.sql AUTO APP_DATA_OWNER MY_TABLE
```

### 4. Pure SQL Files
**Location**: `validation/templates/migration_scripts/`

**Examples**:
- `10_create_table.sql` - CREATE TABLE statements
- `20_data_load.sql` - INSERT/SELECT statements
- `30_create_indexes.sql` - CREATE INDEX statements
- `40_delta_load.sql` - MERGE statements
- `50_swap_tables.sql` - ALTER TABLE RENAME statements
- `60_restore_grants.sql` - GRANT statements
- `master1.sql` - Complete workflow orchestration

## Usage Examples

### Generate Mode
Generate DDL files to disk for review:
```bash
export ORACLE_CONN="system/oracle123@localhost:1521/FREEPDB1"

./validation/executor.sh generate APP_DATA_OWNER MY_TABLE \
  -c "$ORACLE_CONN"
```
**Output**: Creates SQL files in `validation/templates/migration_scripts/`

### Execute Mode
Execute pre-generated DDL files:
```bash
./validation/executor.sh execute APP_DATA_OWNER MY_TABLE \
  -c "$ORACLE_CONN"
```
**Requires**: SQL files already exist in `validation/templates/migration_scripts/`

### Auto Mode
Generate and execute immediately:
```bash
./validation/executor.sh auto APP_DATA_OWNER MY_TABLE \
  -c "$ORACLE_CONN"
```
**Output**: No files created, all execution in-memory

## Detailed Mode Behavior

### GENERATE Mode
1. Reads table metadata from Oracle
2. Generates DDL for each migration step
3. Writes SQL files to disk:
   - `10_create_table.sql`
   - `20_data_load.sql`
   - `30_create_indexes.sql`
   - `40_delta_load.sql`
   - `50_swap_tables.sql`
   - `60_restore_grants.sql`
   - `master1.sql` (orchestrates all steps)
4. **No execution** - files ready for review

### EXECUTE Mode
1. Reads SQL files from disk
2. Executes each file in order
3. Validates each step
4. Produces execution logs
5. **No generation** - uses existing files

### AUTO Mode
1. Reads table metadata from Oracle
2. Generates DDL in memory
3. Executes immediately
4. No files written to disk
5. **Everything in-memory** - fastest mode

## Configuration

### Environment Variables

```bash
# Default connection (used if -c not provided)
export ORACLE_CONN="system/oracle123@localhost:1521/FREEPDB1"

# Custom SQL client path (optional)
export SQL_CLIENT="/path/to/sqlcl"
```

### Connection String Format

```
user/password@host:port/service_name
```

**Examples**:
- `system/oracle123@localhost:1521/FREEPDB1`
- `app_data_owner/password@db.example.com:1521/ORCL`

## Output Structure

Every execution creates a timestamped output directory:

```
output/
└── migration_run_YYYYMMDD_HHMMSS/
    ├── runner.log         - Shell execution log
    └── executor.log       - PL/SQL output
```

For GENERATE mode, also creates:
```
validation/templates/migration_scripts/
├── 10_create_table.sql
├── 20_data_load.sql
├── 30_create_indexes.sql
├── 40_delta_load.sql
├── 50_swap_tables.sql
├── 60_restore_grants.sql
└── master1.sql
```

## Comparison with Validation Framework

| Feature | Validation Scripts | DDL Executor |
|---------|-------------------|--------------|
| **Purpose** | Validate database state | Execute migrations |
| **Entry Point** | `validate.sh` | `executor.sh` |
| **Operations** | check_existence, count_rows, etc. | generate, execute, auto |
| **SQL Scripts** | 01_validator_readonly.sql, 02_workflow_validator.sql | executor.sql |
| **Use Case** | Pre/post migration validation | Run actual migrations |
| **Output** | Validation results | DDL files or execution logs |

## Integration

### Using with Validation Framework

```bash
# 1. Validate pre-migration state
./validation/validate.sh check_existence APP_DATA_OWNER MY_TABLE

# 2. Generate migration DDL
./validation/executor.sh generate APP_DATA_OWNER MY_TABLE

# 3. Review generated SQL files
cat validation/templates/migration_scripts/master1.sql

# 4. Execute migration
./validation/executor.sh execute APP_DATA_OWNER MY_TABLE

# 5. Validate post-migration state
./validation/validate.sh post_swap APP_DATA_OWNER MY_TABLE
```

## Troubleshooting

### SQL Client Not Found
```bash
# Check available clients
which sqlcl sqlplus

# Specify custom path
./validation/executor.sh generate APP_DATA_OWNER MY_TABLE \
  --sql-client /path/to/sqlcl
```

### Connection Issues
```bash
# Test connection
sqlplus system/oracle123@localhost:1521/FREEPDB1 << EOF
SELECT 1 FROM dual;
EXIT;
EOF

# Use environment variable
export ORACLE_CONN="system/oracle123@localhost:1521/FREEPDB1"
./validation/executor.sh generate APP_DATA_OWNER MY_TABLE
```

### Generated Files Not Found
```bash
# Check output directory
ls -la validation/templates/migration_scripts/

# Check logs
tail -f output/migration_run_*/executor.log
```

## Best Practices

1. **Development**: Use GENERATE mode to review DDL before execution
2. **Testing**: Use EXECUTE mode to test with pre-generated files
3. **Production**: Use AUTO mode for fast, controlled execution
4. **Always validate**: Use validation framework before and after migration
5. **Review logs**: Check executor.log for detailed execution details

## See Also

- `validation/README.md` - Validation framework documentation
- `validation/validate.sh` - Validation wrapper script
- `validation/templates/executor.sql` - PL/SQL executor source
