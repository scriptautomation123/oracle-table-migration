# Critical Operations - Quick Reference

**🔒 SECURITY: All operations use DBMS_ASSERT for SQL injection protection**

## Setup (Do Once)
```bash
source venv/bin/activate
export ORACLE_CONN="username/password@hostname:1521/service_name"
# OR for LDAP:
# export ORACLE_CONN="username/password@ldap://ldap-server:389/cn=DB,cn=OracleContext"
```

---

## 1. DISCOVER TABLES (Critical First Step)
```bash
cd /home/swapa/code/oracle-table-migration
source venv/bin/activate

python3 src/generate.py --discover \
  --schema GD \
  --connection "nbk5k9e/***@EOMIEP01_SVC01"

# Output: output/20251027_HHMMSS_gd/migration_config.json
```

**For LDAP:**
```bash
python3 src/generate.py --discover \
  --schema GD \
  --connection "nbk5k9e/***@ldap://ldap-host:389/cn=EOMIEP01_SVC01,cn=OracleContext" \
  --thin-ldap
```

---

## 2. GENERATE MIGRATION DDL
```bash
python3 src/generate.py -c output/20251027_HHMMSS_gd/migration_config.json

# Generates all DDL files in same timestamped folder
```

---

## 3. VALIDATE TABLES (Before Operations)
```bash
cd templates/plsql-util
chmod +x unified_runner.sh

# Check for active sessions
./unified_runner.sh validation "nbk5k9e/***@EOMIEP01_SVC01" \
  check_sessions MY_TABLE

# Check table exists
./unified_runner.sh validation "nbk5k9e/***@EOMIEP01_SVC01" \
  check_existence GD MY_TABLE

# Check table structure and partitioning
./unified_runner.sh validation "nbk5k9e/***@EOMIEP01_SVC01" \
  check_table_structure GD MY_TABLE

# Count rows
./unified_runner.sh validation "nbk5k9e/***@EOMIEP01_SVC01" \
  count_rows GD MY_TABLE 1000000

# Check constraints
./unified_runner.sh validation "nbk5k9e/***@EOMIEP01_SVC01" \
  check_constraints GD MY_TABLE

# Check partition distribution
./unified_runner.sh validation "nbk5k9e/***@EOMIEP01_SVC01" \
  check_partition_dist GD MY_TABLE

# System operations (SYSDBA - automatically uses '/ as sysdba')
./unified_runner.sh validation "" check_privileges
./unified_runner.sh validation "" check_tablespace USERS
./unified_runner.sh validation "" check_sessions_all APP_USER
./unified_runner.sh validation "" check_invalid_objects APP_OWNER
```

---

## 4. CREATE NEW PARTITIONED TABLE (Zero-Downtime)
```bash
sqlplus "nbk5k9e/***@EOMIEP01_SVC01" @output/20251027_HHMMSS_gd/GD_MY_TABLE/10_create_table.sql
```

**Or use PL/SQL tool:**
```bash
cd templates/plsql-util
./unified_runner.sh workflow "nbk5k9e/***@EOMIEP01_SVC01" post_create GD MY_TABLE_NEW
```

---

## 5. VALIDATE NEW TABLE STRUCTURE
```bash
./unified_runner.sh workflow "nbk5k9e/***@EOMIEP01_SVC01" post_create GD MY_TABLE_NEW

# Shows: partitioning, subpartitioning, LOB config, indexes, stats
```

---

## 6. ADD HASH SUBPARTITIONS ONLINE (Optional)
```bash
./unified_runner.sh add_subparts GD MY_TABLE_NEW USER_ID 8 "nbk5k9e/***@EOMIEP01_SVC01"

# Adds 8 hash subpartitions by USER_ID column
# Uses SET SUBPARTITION TEMPLATE - applies to future partitions
```

---

## 7. PRE-CREATE FUTURE PARTITIONS (Recommended)
```bash
./unified_runner.sh workflow "nbk5k9e/***@EOMIEP01_SVC01" \
  pre_create_partitions GD MY_TABLE_NEW 2

# Creates next 2 partitions ahead of time
# Supports DAY, HOUR, MONTH intervals
```

---

## 8. LOAD DATA
```bash
sqlplus "nbk5k9e/***@EOMIEP01_SVC01" @output/20251027_HHMMSS_gd/GD_MY_TABLE/20_data_load.sql
```

---

## 9. VALIDATE DATA LOAD
```bash
# Compare row counts, gather stats
./unified_runner.sh workflow "nbk5k9e/***@EOMIEP01_SVC01" \
  post_data_load GD MY_TABLE_NEW OLD_TABLE 1000000 4

# args: schema, new_table, old_table, expected_count, parallel_degree
```

---

## 10. CREATE INSTEAD OF VIEW (Zero-Downtime Read/Write) - SECURE
```bash
./unified_runner.sh workflow "nbk5k9e/***@EOMIEP01_SVC01" \
  create_renamed_view GD MY_TABLE

# Creates MY_TABLE_JOINED view showing both old + new tables
# Creates secure INSTEAD OF trigger for INSERT to new table
# 🔒 Uses DBMS_ASSERT for SQL injection protection
# 🔒 Automatically detects primary key for proper deduplication
# 🔒 Creates restriction triggers for UPDATE/DELETE operations
```

---

## 11. FINALIZE SWAP (Critical - One-Way Operation!)
```bash
./unified_runner.sh finalize GD MY_TABLE "nbk5k9e/***@EOMIEP01_SVC01"

# Drops trigger, drops view, drops _OLD table, renames _NEW to original
# Recompiles invalid objects
# VALIDATES everything exists after swap
```

---

## 12. POST-SWAP VALIDATION
```bash
# Verify swap successful
./unified_runner.sh workflow "nbk5k9e/***@EOMIEP01_SVC01" post_swap GD MY_TABLE

# Check row count after swap
./unified_runner.sh validation "nbk5k9e/***@EOMIEP01_SVC01" \
  count_rows GD MY_TABLE

# Check constraints
./unified_runner.sh validation "nbk5k9e/***@EOMIEP01_SVC01" \
  check_constraints GD MY_TABLE

# View partition distribution
./unified_runner.sh validation "nbk5k9e/***@EOMIEP01_SVC01" \
  check_partition_dist GD MY_TABLE
```

---

## QUICK VALIDATION CHECKLIST
```bash
# Run these after critical operations:

# 1. Table exists?
./unified_runner.sh validation "$CONN" check_existence GD MY_TABLE

# 2. Row count?
./unified_runner.sh validation "$CONN" count_rows GD MY_TABLE

# 3. Constraints enabled?
./unified_runner.sh validation "$CONN" check_constraints GD MY_TABLE

# 4. Partition structure OK?
./unified_runner.sh workflow "$CONN" post_create GD MY_TABLE

# 5. Swap successful?
./unified_runner.sh workflow "$CONN" post_swap GD MY_TABLE
```

---

## CONSTRAINTS MANAGEMENT
```bash
# Disable constraints before large operations (with proper error handling)
./unified_runner.sh validation "$CONN" disable_constraints GD MY_TABLE

# Enable constraints after operations (with proper error handling)
./unified_runner.sh validation "$CONN" enable_constraints GD MY_TABLE
```

---

## TYPICAL PRODUCTION WORKFLOW

```bash
# 1. Setup
source venv/bin/activate
export ORACLE_CONN="user/pass@host:port/service"

# 2. Discover
python3 src/generate.py --discover --schema GD --connection "$ORACLE_CONN"

# 3. Review/edit: output/YYYYMMDD_HHMMSS_gd/migration_config.json
# Enable tables, set partition columns, hash subpartitions

# 4. Generate DDL
python3 src/generate.py -c output/YYYYMMDD_HHMMSS_gd/migration_config.json

# 5. Create new table
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/10_create_table.sql

# 6. Validate structure
cd templates/plsql-util
./unified_runner.sh workflow "$ORACLE_CONN" post_create GD MY_TABLE_NEW

# 7. Optional: Add hash subpartitions
./unified_runner.sh add_subparts GD MY_TABLE_NEW USER_ID 8 "$ORACLE_CONN"

# 8. Optional: Pre-create partitions
./unified_runner.sh workflow "$ORACLE_CONN" pre_create_partitions GD MY_TABLE_NEW 7

# 9. Load data
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/20_data_load.sql

# 10. Validate data load
./unified_runner.sh workflow "$ORACLE_CONN" post_data_load GD MY_TABLE_NEW MY_TABLE 1000000 4

# 11. Create indexes
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/30_create_indexes.sql

# 12. Gather statistics
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/35_gather_statistics.sql

# 13. Create zero-downtime view (optional - allows gradual migration)
./unified_runner.sh workflow "$ORACLE_CONN" create_renamed_view GD MY_TABLE

# 14. Delta load (incremental data)
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/40_delta_load.sql

# 15. SWAP (CRITICAL - POINT OF NO RETURN!)
./unified_runner.sh finalize GD MY_TABLE "$ORACLE_CONN"

# 16. Verify post-swap
./unified_runner.sh workflow "$ORACLE_CONN" post_swap GD MY_TABLE
./unified_runner.sh validation "$ORACLE_CONN" count_rows GD MY_TABLE
./unified_runner.sh validation "$ORACLE_CONN" check_constraints GD MY_TABLE
```

---

## Output Logs Location
All operations create timestamped logs:
- `output/validation_run_YYYYMMDD_HHMMSS/` - Validation operations
- `output/migration_run_YYYYMMDD_HHMMSS/` - Migration operations

Each contains:
- `runner.log` - Full execution log
- `validation_output.log` or `workflow.log` - SQL output

---

## 🔒 Security Features

**SQL Injection Protection:**
- All dynamic SQL uses `DBMS_ASSERT.SIMPLE_SQL_NAME()` for identifier validation
- All dynamic SQL uses `DBMS_ASSERT.ENQUOTE_NAME()` for proper quoting
- Input validation prevents malicious SQL injection attempts

**Error Handling:**
- Comprehensive error codes (-20001 to -20101)
- Specific error messages for troubleshooting
- No silent failures - all errors are reported
- Proper exception handling with context

**INSTEAD OF Trigger Security:**
- Automatically detects primary key columns
- Creates proper deduplication logic
- Restricts UPDATE/DELETE operations with clear error messages
- Validates all prerequisites before execution

**Operation Categories:**
- **READONLY**: Safe SELECT-only operations
- **WRITE**: Schema modifications with validation
- **WORKFLOW**: Multi-step operations with comprehensive checks
- **CLEANUP**: Safe cleanup operations with validation

