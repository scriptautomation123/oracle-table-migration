# Oracle Table Migration - Quick Start Guide

Get started with the Oracle Table Migration Framework in 5 minutes!

## Prerequisites

- **Python 3.8 or higher**
- **Access to Oracle database** (11g or higher)
- **Oracle Instant Client** (automatically configured in dev container)
- **Database privileges**: SELECT, CREATE TABLE, CREATE INDEX on target schema

## Option A: Using GitHub Codespaces (Recommended)

The fastest way to get started with a pre-configured Oracle environment:

1. Open this repository in GitHub Codespaces
2. Everything is pre-configured (Oracle XE 21c, Python, test data)
3. Skip to [Step 3: Discover Your Schema](#step-3-discover-your-schema)

See [.devcontainer/README.md](.devcontainer/README.md) for full Codespaces documentation.

## Option B: Local Installation

### Step 1: Setup Python Environment

#### Linux/Mac

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

#### Windows (PowerShell)

```powershell
# Create virtual environment
python -m venv venv

# Activate virtual environment
.\venv\Scripts\Activate.ps1

# If you get execution policy error, run as Administrator:
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Install dependencies
pip install -r requirements.txt
```

#### Windows (Command Prompt)

```cmd
# Create virtual environment
python -m venv venv

# Activate virtual environment
.\venv\Scripts\activate.bat

# Install dependencies
pip install -r requirements.txt
```

## Step 3: Configure Oracle Connection

Prepare your Oracle connection string:

```sql
user/password@connection_identifier
```

Examples:
```bash
# Using TNS service name (from tnsnames.ora)
hr/hr123@PRODDB

# Using OID (Oracle Internet Directory)
hr/hr123@MYDB_SERVICE

# Using Easy Connect (hostname:port/service_name)
hr/hr123@localhost:1521/FREEPDB1

# Custom port with Easy Connect
hr/hr123@localhost:49125/FREEPDB1

# Remote server with custom port
myuser/mypass@dbserver.example.com:49125/XEPDB1
```

**Note:** 
- If using TNS names, ensure `TNS_ADMIN` environment variable points to your `tnsnames.ora` location
- If using OID, ensure your Oracle client is configured for LDAP directory naming

### Step 2: Install Oracle Instant Client

**Linux:**

```bash
# Download Oracle Instant Client 21
wget --progress=dot:giga https://download.oracle.com/otn_software/linux/instantclient/2113000/instantclient-basic-linux.x64-21.13.0.0.0dbru.zip

# Extract
unzip instantclient-basic-linux.x64-21.13.0.0.0dbru.zip -d /opt/oracle

# Set environment variable
export LD_LIBRARY_PATH=/opt/oracle/instantclient_21_13:$LD_LIBRARY_PATH

# Make permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export LD_LIBRARY_PATH=/opt/oracle/instantclient_21_13:$LD_LIBRARY_PATH' >> ~/.bashrc
```

**Windows:**

1. Download from: <https://www.oracle.com/database/technologies/instant-client/downloads.html>
2. Extract to `C:\oracle\instantclient_21_13`
3. Add to PATH environment variable:
   ```powershell
   $env:PATH += ";C:\oracle\instantclient_21_13"
   ```

**Mac:**

```bash
# Using Homebrew
brew tap InstantClientTap/instantclient
brew install instantclient-basic

# Or manual download from Oracle website
```

## Step 4: Discover Your Schema

Run discovery mode to scan your Oracle schema and generate configuration:

```bash
python3 generate_scripts.py --discover \
  --schema MYSCHEMA \
  --connection "user/password@host:1521/service"
```

**Example with HR schema:**
```bash
python3 generate_scripts.py --discover \
  --schema HR \
  --connection "hr/hr123@localhost:1521/FREEPDB1"
```

**With table filters:**
```bash
# Include only tables starting with IE_
python3 generate_scripts.py --discover \
  --schema MYSCHEMA \
  --include "IE_%" \
  --connection "user/password@host:1521/service"

# Exclude temporary tables
python3 generate_scripts.py --discover \
  --schema MYSCHEMA \
  --exclude "TEMP_%" "BAK_%" \
  --connection "user/password@host:1521/service"
```

This creates: `migration_config.json`

## Step 5: Customize Configuration

Edit `migration_config.json` to customize your migration:

```json
{
  "tables": [
    {
      "table_name": "MY_TABLE",
      "enabled": true,                    // Enable/disable migration
      "migration_action": "MIGRATE",
      "target_configuration": {
        "partition_column": "CREATED_DATE",  // Choose partition column
        "interval_type": "MONTH",            // HOUR/DAY/WEEK/MONTH
        "subpartition_column": "USER_ID",    // Hash subpartition column
        "subpartition_count": 16,            // Number of hash subpartitions
        "parallel_degree": 8                 // Parallelism for operations
      }
    }
  ]
}
```

## Step 6: Validate Configuration

Validate your configuration before generating scripts:

```bash
# Basic validation (no database connection)
python3 generate_scripts.py --config migration_config.json --validate-only

# Validate against database
python3 generate_scripts.py --config migration_config.json \
  --validate-only \
  --check-database \
  --connection "user/password@host:1521/service"
```

## Step 7: Generate Migration Scripts

Generate SQL migration scripts:

```bash
python3 generate_scripts.py --config migration_config.json
```

Scripts are generated in: `output/SCHEMA_TABLE_NAME/`

### Generated Files

Each table gets a directory with:

- `10_create_table.sql` - Create new partitioned table
- `20_data_load.sql` - Initial data load
- `30_create_indexes.sql` - Rebuild indexes
- `40_delta_load.sql` - Load incremental changes
- `50_swap_tables.sql` - Rename tables (cutover)
- `60_restore_grants.sql` - Restore privileges
- `70_drop_old_table.sql` - Drop old table
- `master1.sql` - Phase 1 execution (create + load)
- `master2.sql` - Phase 2 execution (cutover + cleanup)
- `README.md` - Migration instructions

## Step 8: Execute Migration

### Phase 1: Structure and Initial Load

```bash
cd output/SCHEMA_TABLE_NAME/
sqlplus user/password @master1.sql
```

This runs:
1. Create new table structure
2. Load data
3. Create indexes
4. Load delta changes

**Validate before cutover!**

### Phase 2: Cutover (Downtime)

```bash
sqlplus user/password @master2.sql
```

This runs:
5. Swap tables (downtime starts)
6. Restore grants
7. Drop old table (optional)

### Individual Script Execution

For more control, run scripts individually:

```bash
sqlplus user/password @10_create_table.sql
sqlplus user/password @20_data_load.sql
sqlplus user/password @30_create_indexes.sql
# ... etc
```

## Advanced Features

### Pre-Migration Validation

```bash
python3 generate_scripts.py --config migration_config.json \
  --validate-pre \
  --connection "user/password@host:1521/service"
```

### Post-Migration Validation

```bash
python3 generate_scripts.py --config migration_config.json \
  --validate-post \
  --connection "user/password@host:1521/service"
```

### Data Comparison

```bash
python3 generate_scripts.py --config migration_config.json \
  --compare-data \
  --connection "user/password@host:1521/service"
```

### Generate Validation Report

```bash
python3 generate_scripts.py --config migration_config.json \
  --validation-report validation_report.md \
  --connection "user/password@host:1521/service"
```

## Common Use Cases

### Migrate Non-Partitioned to Interval-Hash

```json
{
  "migration_action": "MIGRATE",
  "target_configuration": {
    "partition_type": "INTERVAL_HASH",
    "partition_column": "CREATED_DATE",
    "interval_type": "MONTH",
    "subpartition_column": "USER_ID",
    "subpartition_count": 16
  }
}
```

### Convert Interval to Interval-Hash

```json
{
  "migration_action": "CONVERT",
  "target_configuration": {
    "partition_type": "INTERVAL_HASH",
    "partition_column": "CREATED_DATE",  // Keep existing
    "interval_type": "MONTH",            // Keep existing
    "subpartition_column": "USER_ID",    // Add hash subpartitions
    "subpartition_count": 16
  }
}
```

## Troubleshooting

### Virtual Environment Issues

**Problem:** Cannot activate virtual environment on Windows PowerShell

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Oracle Connection Issues

**Problem:** `DPI-1047: Cannot locate a 64-bit Oracle Client library`

**Solution:** Install Oracle Instant Client and set environment variables:
```bash
export LD_LIBRARY_PATH=/opt/oracle/instantclient_21_13:$LD_LIBRARY_PATH
```

### Import Errors

**Problem:** `ModuleNotFoundError: No module named 'oracledb'`

**Solution:** Make sure virtual environment is activated and dependencies installed:
```bash
source venv/bin/activate  # or .\venv\Scripts\Activate.ps1 on Windows
pip install -r requirements.txt
```

## Deactivate Virtual Environment

When you're done:

```bash
deactivate
```

## Getting Help

- Check the [USER_GUIDE.md](USER_GUIDE.md) for detailed documentation
- Review [README.md](README.md) for architecture overview
- See `examples/` directory for sample configurations
- Check `docs/` directory for implementation plans

## Next Steps

### Migration Workflow Checklist

- [ ] **Setup**: Virtual environment and dependencies installed
- [ ] **Connect**: Database connection string configured
- [ ] **Discover**: Schema scanned and `migration_config.json` created
- [ ] **Customize**: Configuration reviewed and customized
- [ ] **Validate**: Configuration validated (with/without database)
- [ ] **Generate**: Migration SQL scripts generated
- [ ] **Test**: Scripts tested in non-production environment
- [ ] **Execute**: Phase 1 completed (structure + data load)
- [ ] **Verify**: Data validated, row counts checked
- [ ] **Cutover**: Phase 2 completed (table swap)
- [ ] **Cleanup**: Old tables dropped, grants restored

### Additional Resources

- **[USER_GUIDE.md](USER_GUIDE.md)** - Comprehensive documentation
- **[README.md](README.md)** - Architecture and design overview
- **[.devcontainer/README.md](.devcontainer/README.md)** - GitHub Codespaces setup
- **[examples/configs/](examples/configs/)** - Sample configuration files
- **[docs/](docs/)** - Implementation plans and guides

---

## Quick Reference Card

### Environment Setup

| Platform | Activate venv | Python command |
|----------|---------------|----------------|
| Linux/Mac | `source venv/bin/activate` | `python3` |
| Windows PowerShell | `.\venv\Scripts\Activate.ps1` | `python` |
| Windows cmd | `.\venv\Scripts\activate.bat` | `python` |
| GitHub Codespaces | Pre-configured | `python3` |

### Essential Commands

```bash
# 1. Activate virtual environment (local only)
source venv/bin/activate

# 2. Discover schema and generate config
python3 generate_scripts.py --discover \
  --schema MYSCHEMA \
  --connection "user/password@host:1521/service"

# 3. Validate configuration
python3 generate_scripts.py --config migration_config.json --validate-only

# 4. Generate migration scripts
python3 generate_scripts.py --config migration_config.json

# 5. Execute Phase 1 (structure + data)
sqlplus user/password@connection @output/SCHEMA_TABLE/master1.sql

# 6. Execute Phase 2 (cutover)
sqlplus user/password@connection @output/SCHEMA_TABLE/master2.sql

# 7. Deactivate virtual environment
deactivate
```

### Connection String Examples

```bash
# Easy Connect
user/password@hostname:1521/FREEPDB1

# TNS Name
user/password@PRODDB

# With custom port
user/password@dbserver.example.com:49125/XEPDB1

# Codespaces test environment
hr/hr123@oracle:1521/XEPDB1
```

### Common Options

```bash
# Discovery with table filters
--include "IE_%"           # Include only tables starting with IE_
--exclude "TEMP_%" "BAK_%" # Exclude temporary/backup tables

# Validation options
--validate-only            # Validate config without database
--check-database          # Validate against live database
--validate-pre            # Pre-migration validation
--validate-post           # Post-migration validation
--compare-data            # Compare data between old and new tables

# Generation options
--config FILE             # Use specific config file
--validation-report FILE  # Generate validation report
```

Happy migrating! 🚀
