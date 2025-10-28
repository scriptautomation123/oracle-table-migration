# Critical Operations - SQL*Plus Direct Reference

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

## 3. VALIDATE TABLES (Before Operations) - SQL*Plus Direct

**Check for active sessions:**
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql READONLY check_sessions MY_TABLE
EOF
```

**System-level operations (requires SYSDBA):**
```bash
# Check SYSDBA privileges
sqlplus -S "/ as sysdba" <<EOF
@templates/plsql-util/plsql-util.sql SYS check_privileges
EOF

# Check tablespace usage
sqlplus -S "/ as sysdba" <<EOF
@templates/plsql-util/plsql-util.sql SYS check_tablespace USERS
EOF

# Check all active sessions
sqlplus -S "/ as sysdba" <<EOF
@templates/plsql-util/plsql-util.sql SYS check_sessions_all APP_USER
EOF

# Check for invalid objects
sqlplus -S "/ as sysdba" <<EOF
@templates/plsql-util/plsql-util.sql SYS check_invalid_objects APP_OWNER
EOF
```

**Check table exists:**
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql READONLY check_existence GD MY_TABLE
EOF
```

**Check table structure and partitioning:**
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql READONLY check_table_structure GD MY_TABLE
EOF
```

**Count rows:**
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql READONLY count_rows GD MY_TABLE 1000000
EOF
```

**Check constraints:**
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql READONLY check_constraints GD MY_TABLE
EOF
```

**Check partition distribution:**
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql READONLY check_partition_dist GD MY_TABLE
EOF
```

---

## 4. CREATE NEW PARTITIONED TABLE (Zero-Downtime)
```bash
sqlplus "nbk5k9e/***@EOMIEP01_SVC01" @output/20251027_HHMMSS_gd/GD_MY_TABLE/10_create_table.sql
```

**Validate structure:**
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW post_create GD MY_TABLE_NEW 4
EOF
```

---

## 5. ADD HASH SUBPARTITIONS ONLINE (Optional)
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW add_hash_subpartitions GD MY_TABLE_NEW USER_ID 8
EOF
```

---

## 6. PRE-CREATE FUTURE PARTITIONS (Recommended)
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW pre_create_partitions GD MY_TABLE_NEW 2
EOF
```

---

## 7. LOAD DATA
```bash
sqlplus "nbk5k9e/***@EOMIEP01_SVC01" @output/20251027_HHMMSS_gd/GD_MY_TABLE/20_data_load.sql
```

---

## 8. VALIDATE DATA LOAD
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW post_data_load GD MY_TABLE_NEW MY_TABLE 1000000 4
EOF
```

---

## 9. CREATE INDEXES AND STATISTICS
```bash
# Create indexes
sqlplus "nbk5k9e/***@EOMIEP01_SVC01" @output/20251027_HHMMSS_gd/GD_MY_TABLE/30_create_indexes.sql

# Gather statistics
sqlplus "nbk5k9e/***@EOMIEP01_SVC01" @output/20251027_HHMMSS_gd/GD_MY_TABLE/35_gather_statistics.sql
```

---

## 10. CREATE INSTEAD OF VIEW (Zero-Downtime Read/Write) - SECURE
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW create_renamed_view GD MY_TABLE
EOF
```

**🔒 Security Features:**
- Uses DBMS_ASSERT for SQL injection protection
- Automatically detects primary key for proper deduplication
- Creates restriction triggers for UPDATE/DELETE operations
- Proper error handling with specific error codes
- Validates all prerequisites before execution

---

## 11. DELTA LOAD (Incremental Data)
```bash
sqlplus "nbk5k9e/***@EOMIEP01_SVC01" @output/20251027_HHMMSS_gd/GD_MY_TABLE/40_delta_load.sql
```

---

## 12. FINALIZE SWAP (Critical - One-Way Operation!)
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW finalize_swap GD MY_TABLE
EOF
```

---

## 13. POST-SWAP VALIDATION
```bash
# Verify swap successful
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW post_swap GD MY_TABLE
EOF

# Check row count after swap
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql READONLY count_rows GD MY_TABLE
EOF

# Check constraints
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql READONLY check_constraints GD MY_TABLE
EOF

# View partition distribution
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql READONLY check_partition_dist GD MY_TABLE
EOF
```

---

## CONSTRAINTS MANAGEMENT - SQL*Plus Direct

**Disable constraints before large operations:**
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql WRITE disable_constraints GD MY_TABLE
EOF
```

**Enable constraints after operations:**
```bash
sqlplus -S "nbk5k9e/***@EOMIEP01_SVC01" <<EOF
@templates/plsql-util/plsql-util.sql WRITE enable_constraints GD MY_TABLE
EOF
```

---

## QUICK VALIDATION CHECKLIST - SQL*Plus Direct
```bash
# 1. Table exists?
sqlplus -S "$CONN" <<EOF
@templates/plsql-util/plsql-util.sql READONLY check_existence GD MY_TABLE
EOF

# 2. Row count?
sqlplus -S "$CONN" <<EOF
@templates/plsql-util/plsql-util.sql READONLY count_rows GD MY_TABLE
EOF

# 3. Constraints enabled?
sqlplus -S "$CONN" <<EOF
@templates/plsql-util/plsql-util.sql READONLY check_constraints GD MY_TABLE
EOF

# 4. Partition structure OK?
sqlplus -S "$CONN" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW post_create GD MY_TABLE
EOF

# 5. Swap successful?
sqlplus -S "$CONN" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW post_swap GD MY_TABLE
EOF
```

---

## COMPLETE PRODUCTION WORKFLOW - SQL*Plus Direct

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
sqlplus -S "$ORACLE_CONN" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW post_create GD MY_TABLE_NEW 4
EOF

# 7. Optional: Add hash subpartitions
sqlplus -S "$ORACLE_CONN" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW add_hash_subpartitions GD MY_TABLE_NEW USER_ID 8
EOF

# 8. Optional: Pre-create partitions
sqlplus -S "$ORACLE_CONN" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW pre_create_partitions GD MY_TABLE_NEW 7
EOF

# 9. Load data
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/20_data_load.sql

# 10. Validate data load
sqlplus -S "$ORACLE_CONN" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW post_data_load GD MY_TABLE_NEW MY_TABLE 1000000 4
EOF

# 11. Create indexes
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/30_create_indexes.sql

# 12. Gather statistics
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/35_gather_statistics.sql

# 13. Create zero-downtime view (optional - allows gradual migration)
sqlplus -S "$ORACLE_CONN" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW create_renamed_view GD MY_TABLE
EOF

# 14. Delta load (incremental data)
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/40_delta_load.sql

# 15. SWAP (CRITICAL - POINT OF NO RETURN!)
sqlplus -S "$ORACLE_CONN" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW finalize_swap GD MY_TABLE
EOF

# 16. Verify post-swap
sqlplus -S "$ORACLE_CONN" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW post_swap GD MY_TABLE
EOF

sqlplus -S "$ORACLE_CONN" <<EOF
@templates/plsql-util/plsql-util.sql READONLY count_rows GD MY_TABLE
EOF

sqlplus -S "$ORACLE_CONN" <<EOF
@templates/plsql-util/plsql-util.sql READONLY check_constraints GD MY_TABLE
EOF
```

---

## PL/SQL UTILITY CATEGORIES

### READONLY Operations (Safe - SELECT only)
- `check_existence` - Verify table exists
- `count_rows` - Count rows (with optional expected value)
- `check_constraints` - Check constraint status
- `check_structure` - Validate table structure
- `check_partition_dist` - Show partition distribution
- `check_sessions` - Check for active sessions

### WRITE Operations (Schema modifications)
- `enable_constraints` - Enable disabled constraints
- `disable_constraints` - Disable enabled constraints

### WORKFLOW Operations (Multi-step)
- `post_create` - Validate table structure after creation
- `post_data_load` - Validate data load and gather stats
- `pre_swap` - Pre-swap validation
- `post_swap` - Post-swap validation
- `create_renamed_view` - Create zero-downtime view
- `finalize_swap` - Complete swap operation
- `pre_create_partitions` - Pre-create future partitions
- `add_hash_subpartitions` - Add hash subpartitions online

### CLEANUP Operations
- `drop` - Drop table with CASCADE PURGE
- `rename` - Rename table

### SYS Operations (requires SYSDBA)
- `check_privileges` - Verify SYSDBA privileges
- `check_tablespace` - Check tablespace usage and availability
- `check_sessions_all` - Check all active sessions system-wide
- `kill_sessions` - Kill sessions matching pattern (use with caution!)
- `check_invalid_objects` - Check for invalid objects in schema or system-wide

---

## Usage Pattern
```bash
sqlplus -S "connection_string" <<EOF
@templates/plsql-util/plsql-util.sql CATEGORY operation [args...]
EOF
```

**Examples:**
```bash
# Check table exists
sqlplus -S "$CONN" <<EOF
@templates/plsql-util/plsql-util.sql READONLY check_existence SCHEMA TABLE
EOF

# Add subpartitions
sqlplus -S "$CONN" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW add_hash_subpartitions SCHEMA TABLE COLUMN 8
EOF

# Finalize swap
sqlplus -S "$CONN" <<EOF
@templates/plsql-util/plsql-util.sql WORKFLOW finalize_swap SCHEMA TABLE
EOF

# System operations (SYSDBA)
sqlplus -S "/ as sysdba" <<EOF
@templates/plsql-util/plsql-util.sql SYS check_privileges
EOF

sqlplus -S "/ as sysdba" <<EOF
@templates/plsql-util/plsql-util.sql SYS check_tablespace USERS
EOF
```

---

## TOAD STANDALONE EXECUTION

**For Toad standalone execution:**

1. **Using unified_runner.sh:**
```bash
# Create Toad script files
EXPLICIT_CLIENT=toad ./unified_runner.sh validation "" check_existence SCHEMA TABLE
EXPLICIT_CLIENT=toad ./unified_runner.sh workflow "" create_renamed_view SCHEMA TABLE
```

2. **Using unified_wrapper.sh:**
```bash
# Create Toad script files
./unified_wrapper.sh validate check_existence SCHEMA TABLE --toad
./unified_wrapper.sh workflow create_renamed_view SCHEMA TABLE --toad
```

3. **Direct Toad execution:**
```sql
-- In Toad, set substitution variables manually:
DEFINE category = 'READONLY'
DEFINE operation = 'check_existence'
DEFINE arg3 = 'SCHEMA_NAME'
DEFINE arg4 = 'TABLE_NAME'

-- Then execute the script
@templates/plsql-util/plsql-util.sql
```

**Toad Script Generation:**
- Scripts are created in `output/validation_run_YYYYMMDD_HHMMSS/toad_script.sql`
- Open the generated script in Toad and execute it
- All substitution variables are pre-configured

---

## Output Interpretation

**Success indicators:**
- `RESULT: PASSED` - Operation completed successfully
- `✓` symbols - Individual steps completed
- No error messages in output

**Failure indicators:**
- `RESULT: FAILED` - Operation failed
- `✗` symbols - Individual steps failed
- Error messages with details

**Warning indicators:**
- `RESULT: WARNING` - Operation completed with warnings
- `⚠` symbols - Warning conditions detected
