# Oracle Table Migration - Quick Start

## Prerequisites

```bash
# Python 3 and venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Oracle connection
export ORACLE_CONN="system/Oracle123!@localhost:1521/FREEPDB1"
```

## Recommended: Complete E2E Workflow

**Best option:** Use the unified workflow command with interactive pauses:

```bash
# Activate virtual environment first
source venv/bin/activate

# Complete workflow: discover → generate
export ORACLE_CONN="system/Oracle123!@localhost:1521/FREEPDB1"

python3 src/runner.py workflow --schema APP_DATA_OWNER --connection "$ORACLE_CONN"

# Automatically:
# - Creates timestamped output folder
# - Discovers schema and saves config
# - Pauses for review (press Enter to continue)
# - Generates all DDL scripts
# - Shows summary and next steps
```

**Skip pauses for automation:**
```bash
source venv/bin/activate

python3 src/runner.py workflow \
  --schema APP_DATA_OWNER \
  --connection "$ORACLE_CONN" \
  --no-pause
```

**Deploy generated DDL:**
```bash
source venv/bin/activate

python3 src/runner.py deploy \
  --script output/20251027_143022_app_data_owner/APP_DATA_OWNER_TABLE/master1.sql \
  --connection "$ORACLE_CONN"
```

---

## Alternative: Manual Step-by-Step

If you prefer to run each step individually:

### Step 1: Discovery

```bash
# Activate virtual environment
source venv/bin/activate

# Discover tables and generate config (creates timestamped folder)
python3 src/generate.py --discover \
  --schema APP_DATA_OWNER \
  --connection "$ORACLE_CONN"

# Output will be in: output/YYYYMMDD_HHMMSS_schema/
# Example: output/20251027_091146_app_data_owner/
```

### Step 2: Generate DDL

```bash
# Activate virtual environment
source venv/bin/activate

# Generate all migration DDL (uses timestamped folder from discovery)
python3 src/generate.py -c output/20251027_091146_app_data_owner/migration_config.json

# All DDL files will be in the same timestamped folder
```

## Validate

**Using runner.py (recommended):**
```bash
# Activate virtual environment
source venv/bin/activate

# Check table exists
python3 src/runner.py validate check_existence APP_DATA_OWNER AUDIT_LOG \
  --connection "$ORACLE_CONN"

# Count rows
python3 src/runner.py validate count_rows APP_DATA_OWNER AUDIT_LOG \
  --connection "$ORACLE_CONN"

# Check constraints
python3 src/runner.py validate check_constraints APP_DATA_OWNER AUDIT_LOG \
  --connection "$ORACLE_CONN"
```

**Or using config validation:**
```bash
source venv/bin/activate

python3 src/generate.py -c output/20251027_091146_app_data_owner/migration_config.json --validate-only
```

## Migration Operations (Advanced)

For advanced operations like online subpartitioning and zero-downtime swaps, use the PL/SQL utilities:

```bash
cd templates/plsql-util
chmod +x unified_wrapper.sh

# Add hash subpartitions online
./unified_wrapper.sh workflow add_hash_subpartitions APP_DATA_OWNER AUDIT_LOG USER_ID 8 -c "$ORACLE_CONN"

# Create view with INSTEAD OF trigger
./unified_wrapper.sh workflow create_renamed_view APP_DATA_OWNER AUDIT_LOG -c "$ORACLE_CONN"

# Pre-create future partitions
./unified_wrapper.sh workflow pre_create_partitions APP_DATA_OWNER AUDIT_LOG 2 -c "$ORACLE_CONN"

# Finalize swap (drop old, rename, validate)
./unified_wrapper.sh workflow finalize_swap APP_DATA_OWNER AUDIT_LOG -c "$ORACLE_CONN"
```

## Generated Files Structure

Each discovery/generation creates a timestamped folder with everything in one place:

```
output/
└── 20251027_091146_app_data_owner/
    ├── migration_config.json          # Configuration file
    ├── APP_DATA_OWNER_AUDIT_LOG/
    │   ├── 10_create_table.sql
    │   ├── 20_data_load.sql
    │   ├── 30_create_indexes.sql
    │   ├── 35_gather_statistics.sql
    │   ├── 40_delta_load.sql
    │   ├── 50_swap_tables.sql
    │   ├── 60_restore_grants.sql
    │   ├── 70_drop_old_table.sql
    │   └── master1.sql
    ├── APP_DATA_OWNER_CUSTOMERS/
    │   └── ... (same structure)
    └── ... (other tables)

Benefits:
- Each execution isolated in its own timestamped folder
- Config, DDL, and logs all together
- Easy to track and replay executions
```

### Migration Scripts

- `10_create_table.sql` - Create partitioned table
- `20_data_load.sql` - Load initial data
- `30_create_indexes.sql` - Create LOCAL indexes
- `35_gather_statistics.sql` - Gather stats
- `40_delta_load.sql` - Load incremental data
- `50_swap_tables.sql` - Swap operations
- `60_restore_grants.sql` - Restore privileges
- `70_drop_old_table.sql` - Cleanup
- `master1.sql` - Complete orchestrated script

python3 src/generate.py --discover --schema GD \
  --connection "nbk5k9e/***@ldap://ldap-hostname:389/cn=your-distinguished-name" \
  --thin-ldap

