# Oracle Table Migration - Complete User Guide


The Issue
The problem is with this syntax in your CREATE TABLE statement:



Corrected SQL Script
Here's the corrected version of your CREATE TABLE statement:
TABLESPACE set (IE_LOB_01, IE_LOB_02, IE_LOB_03)

Key Changes Made
Fixed LOB tablespace syntax:
Changed TABLESPACE set (IE_LOB_01, IE_LOB_02, IE_LOB_03) to TABLESPACE IE_LOB_01 and TABLESPACE IE_LOB_02
You can only specify one tablespace per LOB in CREATE TABLE
Fixed partition LOB tablespace syntax:
Changed TABLESPACE (IE_LOB_01,IE_LOB_02, IE_LOB_03) to individual TABLESPACE IE_LOB_01 and TABLESPACE IE_LOB_02
Fixed BUFFER POOL syntax:
Changed BUFFER POOL DEFAU to BUFFER POOL DEFAULT
Alternative: Using Tablespace Groups
If you want to use multiple tablespaces for LOBs, you need to create a tablespace group first:

```sql
CREATE TABLE GD.IE_PC_OFFER_IN_NEW1
(
    TRACE_ID             VARCHAR2(36 BYTE) NOT NULL,
    SEQ_NUM_UUID         VARCHAR2(36 BYTE) NOT NULL,
    AUDIT_CREATE_DATE    TIMESTAMP(6)      NOT NULL,
    FOOD_FILECREATE_DT   TIMESTAMP(6),
    OFFER_IN             BLOB,
    SUB_OFFER_IN         BLOB
)
LOB (OFFER_IN) STORE AS SECUREFILE
(
    TABLESPACE IE_LOB_01
    ENABLE STORAGE IN ROW
    CHUNK 8192
    RETENTION
    CACHE READS
    STORAGE (INITIAL 4M NEXT 4M MINEXTENTS 2 MAXEXTENTS UNLIMITED PCTINCREASE 0 BUFFER POOL DEFAULT)
)
LOB (SUB_OFFER_IN) STORE AS SECUREFILE
(
    TABLESPACE IE_LOB_02
    ENABLE STORAGE IN ROW
    CHUNK 8192
    RETENTION
    CACHE READS
    STORAGE (INITIAL 4M NEXT 4M MINEXTENTS 2 MAXEXTENTS UNLIMITED PCTINCREASE 0 BUFFER POOL DEFAULT)
)
TABLESPACE OMIE_DATA
PARTITION BY RANGE (AUDIT_CREATE_DATE)
INTERVAL (NUMTODSINTERVAL (1, 'HOUR'))
SUBPARTITION BY HASH(TRACE_ID)
SUBPARTITIONS 24
(
    PARTITION P_PRE2020 VALUES LESS THAN (TIMESTAMP '2025-03-01 00:00:00')
    LOB (OFFER_IN) STORE AS SECUREFILE
    (
        TABLESPACE IE_LOB_01
        ENABLE STORAGE IN ROW
        CHUNK 8192
        RETENTION
        CACHE READS
    )
    LOB (SUB_OFFER_IN) STORE AS SECUREFILE
    (
        TABLESPACE IE_LOB_02
        ENABLE STORAGE IN ROW
        CHUNK 8192
        RETENTION
        CACHE READS
    )
)
NOCACHE;
```

alternative; 
-- First, create a tablespace group (if it doesn't exist)

```sql
ALTER TABLESPACE IE_LOB_01 TABLESPACE GROUP LOB_GROUP;
ALTER TABLESPACE IE_LOB_02 TABLESPACE GROUP LOB_GROUP;
ALTER TABLESPACE IE_LOB_03 TABLESPACE GROUP LOB_GROUP;

-- Then use the group in your CREATE TABLE
CREATE TABLE GD.IE_PC_OFFER_IN_NEW1
(
    TRACE_ID             VARCHAR2(36 BYTE) NOT NULL,
    SEQ_NUM_UUID         VARCHAR2(36 BYTE) NOT NULL,
    AUDIT_CREATE_DATE    TIMESTAMP(6)      NOT NULL,
    FOOD_FILECREATE_DT   TIMESTAMP(6),
    OFFER_IN             BLOB,
    SUB_OFFER_IN         BLOB
)
LOB (OFFER_IN) STORE AS SECUREFILE
(
    TABLESPACE GROUP LOB_GROUP
    ENABLE STORAGE IN ROW
    CHUNK 8192
    RETENTION
    CACHE READS
    STORAGE (INITIAL 4M NEXT 4M MINEXTENTS 2 MAXEXTENTS UNLIMITED PCTINCREASE 0 BUFFER POOL DEFAULT)
)
LOB (SUB_OFFER_IN) STORE AS SECUREFILE
(
    TABLESPACE GROUP LOB_GROUP
    ENABLE STORAGE IN ROW
    CHUNK 8192
    RETENTION
    CACHE READS
    STORAGE (INITIAL 4M NEXT 4M MINEXTENTS 2 MAXEXTENTS UNLIMITED PCTINCREASE 0 BUFFER POOL DEFAULT)
)
TABLESPACE OMIE_DATA
PARTITION BY RANGE (AUDIT_CREATE_DATE)
INTERVAL (NUMTODSINTERVAL (1, 'HOUR'))
SUBPARTITION BY HASH(TRACE_ID)
SUBPARTITIONS 24
(
    PARTITION P_PRE2020 VALUES LESS THAN (TIMESTAMP '2025-03-01 00:00:00')
    LOB (OFFER_IN) STORE AS SECUREFILE
    (
        TABLESPACE GROUP LOB_GROUP
        ENABLE STORAGE IN ROW
        CHUNK 8192
        RETENTION
        CACHE READS
    )
    LOB (SUB_OFFER_IN) STORE AS SECUREFILE
    (
        TABLESPACE GROUP LOB_GROUP
        ENABLE STORAGE IN ROW
        CHUNK 8192
        RETENTION
        CACHE READS
    )
)
NOCACHE;
```

Summary
The ORA-02538: invalid TABLESPACE SET clause error occurs because:
TABLESPACE SET is not valid syntax for CREATE TABLE
You need to use either a single tablespace name or a tablespace group
The corrected script above should resolve the error
Choose the first option (single tablespace per LOB) for simplicity, or the second option (tablespace groups) if you specifically need multiple tablespaces for load balancing.


## Table of Contents

1. [Introduction](#introduction)
2. [System Overview](#system-overview)
3. [Installation and Setup](#installation-and-setup)
4. [Quick Start](#quick-start)
5. [Core Concepts](#core-concepts)
6. [Python CLI Workflow](#python-cli-workflow)
7. [PL/SQL Utilities](#plsql-utilities)
8. [Migration Process](#migration-process)
9. [Advanced Operations](#advanced-operations)
10. [Troubleshooting](#troubleshooting)
11. [Best Practices](#best-practices)
12. [Reference](#reference)

---

## Introduction

The Oracle Table Migration framework is designed to provide **zero-downtime migration** of Oracle tables from non-partitioned to partitioned structures. It combines Python-based discovery and generation with PL/SQL utilities for database operations.

### Key Capabilities

- **Automatic Schema Discovery**: Scan Oracle schemas and identify tables to migrate
- **DDL Generation**: Generate complete migration scripts with partitioning configurations
- **Zero-Downtime Migration**: Swap tables using views and INSTEAD OF triggers
- **Online Operations**: Add subpartitions, pre-create partitions without downtime
- **Comprehensive Validation**: Multi-level validation at every stage
- **Production-Ready**: Full error handling, logging, and rollback capabilities

### What This Guide Covers

- Complete architecture and components
- Step-by-step workflows for development and production
- Detailed explanations of all operations
- Real-world examples with actual commands
- Troubleshooting common issues
- Best practices for safe migrations

---

## System Overview

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Python CLI Layer                            │
│  • generate.py - Discovery and DDL generation                       │
│  • runner.py - Workflow orchestration                              │
└─────────────────────┬───────────────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      Oracle Database Layer                           │
│  • plsql-util.sql - Core validation and workflow operations        │
│  • unified_runner.sh - Execution wrapper with logging             │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Breakdown

**1. Discovery Layer (`src/generate.py`)**
- Connects to Oracle database
- Discovers table structures, columns, indexes, constraints
- Identifies LOB columns and storage parameters
- Generates JSON configuration files

**2. Generation Layer (`src/generate.py`)**
- Reads JSON configuration
- Applies Jinja2 templates
- Generates complete DDL script suites
- Creates orchestration scripts (master1.sql, master2.sql)

**3. Execution Layer (`templates/plsql-util/unified_runner.sh`)**
- Executes SQL scripts via sqlcl or sqlplus
- Manages output directories and logging
- Parses results (PASSED/FAILED status)
- Provides colored output for operators

**4. Validation Layer (`plsql-util.sql`)**
- Category-based operations (READONLY, WRITE, WORKFLOW, CLEANUP)
- Comprehensive table validation
- Constraint management
- Statistics gathering
- Zero-downtime swap operations

### Directory Structure

```
oracle-table-migration/
├── src/
│   ├── generate.py          # Discovery and DDL generation
│   ├── runner.py            # CLI workflow orchestration
│   └── lib/                 # Python modules
│       ├── config_validator.py
│       ├── discovery_queries.py
│       ├── migration_models.py
│       └── template_filters.py
├── templates/               # Jinja2 templates for DDL generation
│   ├── 10_create_table.sql.j2
│   ├── 20_data_load.sql.j2
│   ├── 30_create_indexes.sql.j2
│   └── ...
├── templates/plsql-util/    # PL/SQL utilities
│   ├── unified_runner.sh   # Execution wrapper
│   ├── plsql-util.sql      # Core validation operations
│   └── unified_wrapper.sh # High-level interface
├── output/                 # Generated artifacts (timestamped)
│   └── YYYYMMDD_HHMMSS_schema/
│       ├── migration_config.json
│       └── SCHEMA_TABLE/
│           ├── 10_create_table.sql
│           ├── 20_data_load.sql
│           └── ...
└── requirements.txt
```

---

## Installation and Setup

### Prerequisites

- Python 3.8+ (Python 3.10+ recommended)
- Oracle Database 12c+ (19c+ recommended for full feature support)
- Oracle SQL client: sqlcl or sqlplus
- Oracle Instant Client (for python-oracledb)

### Installation Steps

**1. Clone Repository**

```bash
git clone <repository-url>
cd oracle-table-migration
```

**2. Create Virtual Environment**

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

**3. Install Python Dependencies**

```bash
pip install -r requirements.txt
```

This installs:
- `oracledb` - Oracle database connectivity
- `jinja2` - Template engine for DDL generation
- `jsonschema` - Configuration validation

**4. Verify SQL Client Installation**

```bash
# Check for SQLcl (preferred)
which sqlcl
sqlcl --version

# Or check for SQL*Plus (fallback)
which sqlplus
sqlplus -version
```

**5. Set Up Oracle Connection**

```bash
# Standard connection
export ORACLE_CONN="username/password@hostname:1521/service_name"

# LDAP connection
export ORACLE_CONN="username/password@ldap://ldap-server:389/cn=DB,cn=OracleContext"
export USE_THIN_LDAP=true
```

### Database Prerequisites

Ensure your Oracle database user has the following privileges:

```sql
-- For discovery
GRANT SELECT ANY DICTIONARY TO migration_user;

-- For DDL operations
GRANT CREATE TABLE TO migration_user;
GRANT CREATE ANY INDEX TO migration_user;
GRANT ALTER ANY TABLE TO migration_user;

-- For data operations
GRANT SELECT, INSERT ON owner.schema TO migration_user;
```

---

## Quick Start

### Basic Workflow (All-in-One)

```bash
# 1. Activate environment
source venv/bin/activate

# 2. Discover and generate in one step
python3 src/runner.py workflow \
  --schema GD \
  --connection "nbk5k9e/***@EOMIEP01_SVC01"

# Output: output/YYYYMMDD_HHMMSS_gd/
#  - migration_config.json (configuration)
#  - GD_MY_TABLE/ (DDL scripts)
```

**What happens:**
1. Connects to database and discovers schema GD
2. Generates migration configuration JSON
3. Pauses for review (press Enter to continue)
4. Generates all DDL scripts
5. Creates timestamped output directory
6. Provides summary and next steps

### Step-by-Step Workflow

**1. Discovery**

```bash
python3 src/generate.py --discover \
  --schema GD \
  --connection "nbk5k9e/***@EOMIEP01_SVC01"

# Review generated config
cat output/YYYYMMDD_HHMMSS_gd/migration_config.json
```

**2. Review and Configure**

Edit `migration_config.json`:
- Enable/disable specific tables
- Set partition columns
- Configure interval types (HOUR/DAY/WEEK/MONTH)
- Set hash subpartition columns and counts

**3. Generate DDL**

```bash
python3 src/generate.py -c output/YYYYMMDD_HHMMSS_gd/migration_config.json
```

**4. Execute Migration**

```bash
# Deploy via runner
python3 src/runner.py deploy \
  --script output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/master1.sql \
  --connection "$ORACLE_CONN"

# Or execute directly
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/master1.sql
```

---

## Core Concepts

### Migration Lifecycle

**Phase 1: Discovery**
- Scan Oracle schema for tables
- Analyze column types, constraints, indexes
- Identify LOB storage and partitioning requirements
- Generate configuration JSON

**Phase 2: Configuration**
- Review discovered tables
- Enable/disable specific tables
- Configure partitioning strategy
- Set migration settings

**Phase 3: DDL Generation**
- Generate `_NEW` table with partitioning
- Create indexes (LOCAL for partitioned tables)
- Generate data migration scripts
- Create swap and cleanup scripts

**Phase 4: Pre-Migration Validation**
- Validate old table exists
- Check row counts and constraints
- Verify partitioning configuration
- Gather baseline statistics

**Phase 5: Data Migration**
- Create partitioned `_NEW` table
- Load initial data from old table
- Create indexes on new table
- Gather statistics on new table

**Phase 6: Incremental Migration**
- Load delta data since initial load
- Validate row counts match
- Check data integrity

**Phase 7: Zero-Downtime Swap**
- Rename old table to `_OLD`
- Rename new table to original name
- Create `_JOINED` view merging both
- Create INSTEAD OF trigger for DML

**Phase 8: Finalization**
- Drop INSTEAD OF trigger
- Drop `_JOINED` view
- Drop `_OLD` table
- Rename new table to original
- Recompile invalid objects

### Partitioning Strategies

**Range Partitioning (Time-Based)**
- Most common for time-series data
- Partition by DATE, TIMESTAMP columns
- Supports interval partitioning (auto-creation)
- Examples: daily, weekly, monthly partitions

```sql
CREATE TABLE my_table_new (
  id NUMBER,
  created_date DATE,
  data VARCHAR2(4000)
) PARTITION BY RANGE (created_date)
INTERVAL (NUMTODSINTERVAL(1, 'DAY'))
(PARTITION p_init VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD')));
```

**Range-Hash Composite (Range + Subpartition)**
- Range partitioning for time-based data
- Hash subpartitioning for workload distribution
- Use when table is too large for single partition

```sql
CREATE TABLE my_table_new (
  id NUMBER,
  user_id NUMBER,
  created_date DATE,
  data VARCHAR2(4000)
) PARTITION BY RANGE (created_date)
INTERVAL (NUMTODSINTERVAL(1, 'DAY'))
SUBPARTITION BY HASH (user_id) SUBPARTITIONS 8
(PARTITION p_init VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD')));
```

**Hash Partitioning**
- For non-time-based distributed workloads
- Even data distribution
- Good for joins and parallel operations

```sql
CREATE TABLE my_table_new (
  id NUMBER,
  user_id NUMBER,
  data VARCHAR2(4000)
) PARTITION BY HASH (user_id)
PARTITIONS 8;
```

### Zero-Downtime Pattern

The framework uses a proven zero-downtime migration pattern:

```
BEFORE: 
  MY_TABLE (non-partitioned)

DURING MIGRATION:
  MY_TABLE_NEW (partitioned, has initial load)
  MY_TABLE_OLD (original table)
  MY_TABLE_JOINED (view merging both, with INSTEAD OF trigger)

AFTER:
  MY_TABLE (renamed from _NEW, fully partitioned)
```

**View Pattern:**
```sql
CREATE VIEW MY_TABLE_JOINED AS
SELECT * FROM MY_TABLE_NEW  -- New data
UNION ALL
SELECT * FROM MY_TABLE_OLD  -- Old data not yet in new
WHERE NOT EXISTS (
  SELECT 1 FROM MY_TABLE_NEW WHERE id = MY_TABLE_OLD.id
);
```

**INSTEAD OF Trigger:**
```sql
CREATE TRIGGER TG_MY_TABLE_JOINED_IOT
INSTEAD OF INSERT ON MY_TABLE_JOINED
FOR EACH ROW
BEGIN
  INSERT INTO MY_TABLE_NEW VALUES :NEW.*;
END;
```

Benefits:
- Applications continue reading from joined view
- New INSERTs go to new partitioned table
- Both old and new data accessible
- Rollback possible by dropping view/trigger

---

## Python CLI Workflow

### Command: Discover

Scans Oracle schema and generates configuration.

```bash
python3 src/generate.py --discover \
  --schema SCHEMA_NAME \
  --connection "$ORACLE_CONN"
```

**Options:**
- `--schema` - Schema name to scan
- `--connection` - Oracle connection string
- `--include` - Table patterns to include (supports wildcards)
- `--exclude` - Table patterns to exclude
- `--output-file` - Output JSON filename (default: migration_config.json)
- `--thin-ldap` - Enable LDAP thin client mode

**Output:**
- Creates timestamped directory: `output/YYYYMMDD_HHMMSS_schema/`
- Generates `migration_config.json` with discovered tables
- Includes metadata: row counts, column types, constraints, indexes

**Example:**
```bash
python3 src/generate.py --discover \
  --schema APP_DATA_OWNER \
  --connection "system/oracle123@localhost:1521/FREEPDB1" \
  --include "AUDIT_*" "*_LOG" \
  --exclude "TEMP_*"
```

### Command: Generate

Generates DDL from configuration.

```bash
python3 src/generate.py -c path/to/migration_config.json
```

**Options:**
- `-c, --config` - Path to migration_config.json
- `--template-dir` - Template directory (default: templates/)
- `--output-dir` - Output directory (default: uses config directory)
- `--validate-only` - Validate config without generating
- `--check-database` - Validate against live database

**Generated Scripts:**

1. **10_create_table.sql** - Creates partitioned table
2. **20_data_load.sql** - Initial data load
3. **30_create_indexes.sql** - Creates LOCAL indexes
4. **35_gather_statistics.sql** - Gathers table stats
5. **40_delta_load.sql** - Incremental data load
6. **50_swap_tables.sql** - Table swap operations
7. **60_restore_grants.sql** - Restores privileges
8. **70_drop_old_table.sql** - Cleanup old table
9. **master1.sql** - Complete Phase 1 orchestration
10. **master2.sql** - Complete Phase 2 orchestration

**README.md** - Migration instructions for each table

### Command: Validate

Validates configuration against database.

```bash
python3 src/generate.py -c path/to/config.json --validate-only
python3 src/generate.py -c path/to/config.json --validate-only --check-database
```

**Validation Checks:**
- JSON structure and required fields
- Table exists in database
- Partition columns exist
- Hash subpartition columns exist
- Constraints and indexes exist
- Migration settings are valid

### Command: Workflow (All-in-One)

Single command for complete workflow.

```bash
python3 src/runner.py workflow \
  --schema SCHEMA_NAME \
  --connection "$ORACLE_CONN"
```

**Features:**
- Combines discovery and generation
- Creates timestamped output
- Interactive pauses for review
- Shows progress and summary
- Generates all DDL files

**Options:**
- `--no-pause` - Skip interactive pauses
- `--environment` - Set environment name
- `--verbose` - Show detailed output

### Command: Deploy

Execute generated DDL scripts.

```bash
python3 src/runner.py deploy \
  --script path/to/master1.sql \
  --connection "$ORACLE_CONN"
```

**Options:**
- `--script` - Path to master script
- `--connection` - Oracle connection string
- `--sql-client` - Force sqlcl or sqlplus
- `--verbose` - Show execution details

---

## PL/SQL Utilities

Located in `templates/plsql-util/`, these utilities provide database-level operations.

### unified_runner.sh

Execution wrapper that runs SQL scripts with logging and error handling.

**Usage:**
```bash
./unified_runner.sh <type> [args...]
```

**Types:**

#### 1. Validation Type
```bash
./unified_runner.sh validation <connection> <operation> [args...]
```

**Operations:**
- `check_existence` - Verify table exists
- `count_rows` - Count rows (with optional expected value)
- `check_constraints` - Check constraint status
- `check_structure` - Validate table structure
- `check_partition_dist` - Show partition distribution
- `check_sessions` - Check for active sessions

**Examples:**
```bash
# Check table exists
./unified_runner.sh validation \
  "user/pass@host:port/service" \
  check_existence SCHEMA MY_TABLE

# Count rows with expected value
./unified_runner.sh validation \
  "user/pass@host:port/service" \
  count_rows SCHEMA MY_TABLE 1000000

# Check constraint status
./unified_runner.sh validation \
  "user/pass@host:port/service" \
  check_constraints SCHEMA MY_TABLE
```

#### 2. Migration Type
```bash
./unified_runner.sh migration <mode> <owner> <table> <connection>
```

**Modes:**
- Standard migration workflows

#### 3. Workflow Type
```bash
./unified_runner.sh workflow <connection> <operation> [args...]
```

**Workflow Operations:**

**post_create** - Validate table structure after creation
```bash
./unified_runner.sh workflow "$CONN" post_create SCHEMA MY_TABLE_NEW [parallel_degree]
```

**post_data_load** - Validate data load
```bash
./unified_runner.sh workflow "$CONN" post_data_load \
  SCHEMA TARGET_TABLE SOURCE_TABLE expected_count parallel_degree
```

**pre_swap** - Pre-swap validation
```bash
./unified_runner.sh workflow "$CONN" pre_swap SCHEMA old_table new_table
```

**post_swap** - Post-swap validation
```bash
./unified_runner.sh workflow "$CONN" post_swap SCHEMA final_table old_table
```

**create_renamed_view** - Create zero-downtime view
```bash
./unified_runner.sh workflow "$CONN" create_renamed_view SCHEMA MY_TABLE
```

**finalize_swap** - Complete swap
```bash
./unified_runner.sh finalize SCHEMA MY_TABLE "$CONN"
```

**pre_create_partitions** - Pre-create future partitions
```bash
./unified_runner.sh workflow "$CONN" pre_create_partitions \
  SCHEMA MY_TABLE days_ahead
```

**add_hash_subpartitions** - Add hash subpartitions
```bash
./unified_runner.sh add_subparts \
  SCHEMA TABLE subpart_column count "$CONN"
```

#### 4. Cleanup Type
```bash
# Drop table
./unified_runner.sh cleanup "$CONN" drop SCHEMA.TABLE

# Rename table
./unified_runner.sh cleanup "$CONN" rename OLD_NAME NEW_NAME
```

### plsql-util.sql

Core utility called by unified_runner.sh with category-based operations.

**Categories:**

#### READONLY Category
Safe read-only operations using SELECT statements.

- **check_sessions** - Active session detection
- **check_existence** - Table existence verification
- **check_table_structure** - Structure validation
- **count_rows** - Row counting with comparison
- **check_constraints** - Constraint status checking
- **check_partition_dist** - Partition distribution analysis

#### WRITE Category
Safe schema modifications with error handling.

- **enable_constraints** - Enable disabled constraints (NOVALIDATE)
- **disable_constraints** - Disable enabled constraints

#### WORKFLOW Category
Multi-step workflow operations.

- **pre_swap** - Validates both old and new tables exist
- **post_swap** - Validates swap completed successfully
- **post_data_load** - Validates data load, compares row counts, gathers stats
- **post_create** - Validates structure, shows partitioning, LOB config, gathers stats
- **create_renamed_view** - Creates view + INSTEAD OF trigger for zero-downtime
- **finalize_swap** - Drops trigger, view, old table, renames new, recompiles
- **pre_create_partitions** - Creates future partitions for DAY/HOUR/MONTH intervals
- **add_hash_subpartitions** - Adds hash subpartitions online using template

#### CLEANUP Category
Table management operations.

- **drop** - Drop table with CASCADE PURGE
- **rename** - Rename table

---

## Migration Process

### Complete Production Workflow

**Phase 1: Discovery and Planning**

```bash
# Step 1: Discover schema
python3 src/generate.py --discover \
  --schema GD \
  --connection "$ORACLE_CONN"

# Review output/YYYYMMDD_HHMMSS_gd/migration_config.json
# Enable tables, set partition columns, configure intervals
```

**Phase 2: Generate DDL**

```bash
# Step 2: Generate all DDL scripts
python3 src/generate.py -c output/YYYYMMDD_HHMMSS_gd/migration_config.json

# This creates:
# - GD_TABLE1/10_create_table.sql
# - GD_TABLE1/20_data_load.sql
# - GD_TABLE1/30_create_indexes.sql
# - etc.
```

**Phase 3: Pre-Migration Validation**

```bash
cd templates/plsql-util

# Validate old table exists
./unified_runner.sh validation "$CONN" check_existence GD MY_TABLE

# Get baseline row count
./unified_runner.sh validation "$CONN" count_rows GD MY_TABLE

# Check current constraints
./unified_runner.sh validation "$CONN" check_constraints GD MY_TABLE
```

**Phase 4: Create New Table**

```bash
# Create partitioned table
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/10_create_table.sql

# Validate structure
./unified_runner.sh workflow "$CONN" post_create GD MY_TABLE_NEW
```

**Phase 5: Data Migration**

```bash
# Load initial data
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/20_data_load.sql

# Validate data load
./unified_runner.sh workflow "$CONN" post_data_load \
  GD MY_TABLE_NEW MY_TABLE 1000000 4
```

**Phase 6: Indexes and Statistics**

```bash
# Create indexes
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/30_create_indexes.sql

# Gather statistics
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/35_gather_statistics.sql
```

**Phase 7: Incremental Migration (Optional)**

```bash
# Load delta data
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/40_delta_load.sql
```

**Phase 8: Zero-Downtime Swap**

```bash
# Create view with INSTEAD OF trigger
./unified_runner.sh workflow "$CONN" create_renamed_view GD MY_TABLE

# Verify view and trigger
sqlplus "$CONN" <<EOF
SELECT COUNT(*) FROM GD.MY_TABLE_JOINED;
EOF

# Execute swap
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/50_swap_tables.sql

# Restore grants
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/60_restore_grants.sql
```

**Phase 9: Finalization**

```bash
# Finalize swap (drops view, trigger, old table)
./unified_runner.sh finalize GD MY_TABLE "$CONN"

# Post-swap validation
./unified_runner.sh workflow "$CONN" post_swap GD MY_TABLE

# Cleanup
sqlplus "$ORACLE_CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/70_drop_old_table.sql
```

**Phase 10: Validation**

```bash
# Final checks
./unified_runner.sh validation "$CONN" check_existence GD MY_TABLE
./unified_runner.sh validation "$CONN" count_rows GD MY_TABLE
./unified_runner.sh validation "$CONN" check_constraints GD MY_TABLE
./unified_runner.sh validation "$CONN" check_partition_dist GD MY_TABLE
```

---

## Advanced Operations

### Add Hash Subpartitions Online

Add hash subpartitions to existing interval-partitioned tables without downtime.

```bash
cd templates/plsql-util

./unified_runner.sh add_subparts \
  GD MY_TABLE USER_ID 8 "$CONN"

# Parameters:
# - GD: schema
# - MY_TABLE: table name
# - USER_ID: column to hash on
# - 8: number of subpartitions
# - "$CONN": connection string
```

**What it does:**
1. Validates table exists and is interval-partitioned
2. Uses `SET SUBPARTITION TEMPLATE` (Oracle 19c+ feature)
3. Applies hash subpartitioning to future partitions
4. Uses `ALTER TABLE ... MERGE PARTITIONS` to apply template

**Requirements:**
- Table must be interval-partitioned (not fixed partitions)
- Cannot be applied to existing partitions (only future ones)
- Column must exist in table

### Pre-Create Future Partitions

Create partitions in advance to avoid partition creation delays.

```bash
cd templates/plsql-util

./unified_runner.sh workflow "$CONN" pre_create_partitions \
  GD MY_TABLE 7

# Parameters:
# - GD: schema  
# - MY_TABLE: table name
# - 7: days ahead to create
```

**What it does:**
1. Detects interval type (DAY/HOUR/MONTH)
2. Gets latest partition high value
3. Calculates next N partition dates
4. Uses `ALTER TABLE ... SPLIT PARTITION` to pre-create
5. Skips if partition already exists

**Supports:**
- Hourly partitions: Pre-creates next N hours
- Daily partitions: Pre-creates next N days  
- Monthly partitions: Pre-creates next N months

### Constraint Management

Disable/Enable constraints for faster data loads.

```bash
# Disable constraints before large operations
cd templates/plsql-util
./unified_runner.sh validation "$CONN" disable_constraints GD MY_TABLE

# Perform data operations...

# Re-enable constraints
./unified_runner.sh validation "$CONN" enable_constraints GD MY_TABLE
```

**Constraint Order:**
- **Disable**: Foreign keys → Check constraints → Unique → Primary
- **Enable**: Primary → Unique → Check → Foreign keys

**Note:** Uses `ENABLE NOVALIDATE` for faster re-enable (doesn't check existing data)

### View-Based Zero-Downtime Pattern

Alternative to direct swap - allows gradual migration and rollback.

```bash
# 1. Create view showing both tables
./unified_runner.sh workflow "$CONN" create_renamed_view GD MY_TABLE

# Creates:
# - MY_TABLE_JOINED (view)
# - TG_MY_TABLE_JOINED_IOT (INSTEAD OF trigger)

# 2. Run in this state for days/weeks
# - Applications read from MY_TABLE_JOINED
# - New INSERTs go to MY_TABLE_NEW
# - Old data still in MY_TABLE_OLD

# 3. When ready, finalize
./unified_runner.sh finalize GD MY_TABLE "$CONN"

# This:
# - Drops trigger and view
# - Drops MY_TABLE_OLD
# - Renames MY_TABLE_NEW to MY_TABLE
# - Recompiles invalid objects
```

**Rollback if needed:**
```sql
-- Drop view and trigger manually
DROP TRIGGER GD.TG_MY_TABLE_JOINED_IOT;
DROP VIEW GD.MY_TABLE_JOINED;

-- Rename back
ALTER TABLE GD.MY_TABLE RENAME TO MY_TABLE_NEW;
ALTER TABLE GD.MY_TABLE_OLD RENAME TO MY_TABLE;
```

### Statistics Gathering

Critical for query performance after migration.

```bash
# Using generated script
sqlplus "$CONN" @output/YYYYMMDD_HHMMSS_gd/GD_MY_TABLE/35_gather_statistics.sql

# Or via PL/SQL utility
cd templates/plsql-util
./unified_runner.sh workflow "$CONN" post_create GD MY_TABLE_NEW 4
```

**Statistics Gathering Options:**
- `estimate_percent => AUTO_SAMPLE_SIZE` - Automatic sample size
- `method_opt => 'FOR ALL COLUMNS SIZE AUTO'` - Auto column stats
- `degree => N` - Parallel degree (4 recommended)
- `cascade => TRUE` - Include indexes

---

## Troubleshooting

### Connection Issues

**Problem:** `DPI-1047: Cannot locate a 64-bit Oracle Client library`

**Solution:**
```bash
# Use thin mode (no Oracle Client required)
python3 src/generate.py --discover \
  --schema GD \
  --connection "$CONN" \
  --thin-ldap

# Or install Oracle Instant Client
# Download from Oracle website
export LD_LIBRARY_PATH=/path/to/instantclient_19_3:$LD_LIBRARY_PATH
```

**Problem:** `DPY-4027: no configuration directory specified`

**Solution:** Use full connection string format:
```bash
# Wrong
--connection "user/pass@SERVICE_NAME"

# Correct  
--connection "user/pass@hostname:1521/service_name"

# Or LDAP
--connection "user/pass@ldap://host:389/cn=service"
```

### SQL Client Not Found

**Problem:** `ERROR: No SQL client found`

**Solution:**
```bash
# Install SQLcl (recommended)
# Download: https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/download/

# Or install SQL*Plus
# Download: https://www.oracle.com/database/technologies/oracle-database-software-downloads.html

# Add to PATH
export PATH=/path/to/sqlcl/bin:$PATH
```

### Permission Errors

**Problem:** `ORA-00942: table or view does not exist`

**Solution:** Grant appropriate privileges:
```sql
-- Grant access to target schema
GRANT SELECT ANY TABLE TO migration_user;
GRANT ALL ON owner.schema TO migration_user;
```

### Invalid Objects After Swap

**Problem:** Triggers, procedures become invalid after table swap

**Solution:** The `finalize_swap` operation automatically recompiles:
```bash
./unified_runner.sh finalize GD MY_TABLE "$CONN"
```

**Manual recompilation:**
```sql
ALTER PROCEDURE OWNER.PROC_NAME COMPILE;
ALTER TRIGGER OWNER.TRIGGER_NAME COMPILE;
```

### Partition Creation Issues

**Problem:** Partition not created or interval not working

**Solution:**
1. Check interval configuration
```sql
SELECT partitioning_type, interval 
FROM all_part_tables 
WHERE owner = 'GD' AND table_name = 'MY_TABLE';
```

2. Manually create partition
```sql
ALTER TABLE GD.MY_TABLE SPLIT PARTITION p_init 
AT (TO_DATE('2024-01-02', 'YYYY-MM-DD')) 
INTO (PARTITION p_2024_01_02, PARTITION p_future);
```

### Statistics Not Accurate

**Problem:** Queries slow after migration

**Solution:** Regather statistics:
```bash
sqlplus "$CONN" <<EOF
EXEC DBMS_STATS.GATHER_TABLE_STATS(
  ownname => 'GD',
  tabname => 'MY_TABLE',
  cascade => TRUE,
  degree => 4
);
EOF
```

---

## Best Practices

### Pre-Migration

1. **Backup**: Create full database backup before starting
2. **Test Environment**: Test migration in non-production first
3. **Baseline Metrics**: Capture baseline row counts, query times
4. **Review Config**: Carefully review `migration_config.json`
5. **Partition Strategy**: Choose interval type based on data growth

### During Migration

1. **Start with One Table**: Migrate one table to completion before others
2. **Validate After Each Step**: Don't proceed if validation fails
3. **Monitor Performance**: Watch for locks, waits during data loads
4. **Use Parallel**: Use parallel degree for large data loads
5. **Check Logs**: Review output logs after each operation

### Post-Migration

1. **Validate All Checks**: Run complete validation checklist
2. **Compare Row Counts**: Verify data completeness
3. **Query Testing**: Test representative queries
4. **Performance Tuning**: Regather statistics if needed
5. **Documentation**: Document new partition key and strategy

### Interval Partitioning

**Recommended Intervals:**
- High-volume: Hourly (`NUMTODSINTERVAL(1, 'HOUR')`)
- Medium-volume: Daily (`NUMTODSINTERVAL(1, 'DAY')`)
- Low-volume: Weekly (`NUMTODSINTERVAL(7, 'DAY')`)
- Month-end: Monthly (`INTERVAL '1' MONTH`)

### Subpartitioning

**When to use:**
- Table > 100GB per partition
- Need better parallelization
- Uneven data distribution in partition
- Many concurrent users on same partition

**How many subpartitions:**
- 8-16 is optimal for most cases
- More subpartitions = more overhead
- Less subpartitions = less parallelization benefit

### Data Migration Strategy

**Large Tables (> 100M rows):**
1. Load initial snapshot
2. Create indexes
3. Apply incremental changes over time
4. Schedule final swap during maintenance window

**Small Tables (< 1M rows):**
1. Load all at once
2. Immediate swap
3. Validate and cleanup

### Zero-Downtime Considerations

1. **View Pattern**: Use view pattern for sensitive systems
2. **Testing Period**: Run view pattern for days before finalizing
3. **Rollback Plan**: Document rollback procedure
4. **Monitoring**: Monitor for errors during view pattern phase
5. **Finalization**: Only finalize after thorough testing

---

## Reference

### Python CLI Commands

```bash
# Discovery
python3 src/generate.py --discover --schema SCHEMA --connection "$CONN"

# Generate
python3 src/generate.py -c path/to/config.json

# Validate
python3 src/generate.py -c path/to/config.json --validate-only

# Workflow (all-in-one)
python3 src/runner.py workflow --schema SCHEMA --connection "$CONN"

# Deploy
python3 src/runner.py deploy --script path/to/master1.sql --connection "$CONN"
```

### PL/SQL Utility Commands

```bash
cd templates/plsql-util

# Validation
./unified_runner.sh validation "$CONN" check_existence SCHEMA TABLE
./unified_runner.sh validation "$CONN" count_rows SCHEMA TABLE [expected]
./unified_runner.sh validation "$CONN" check_constraints SCHEMA TABLE

# Workflow
./unified_runner.sh workflow "$CONN" post_create SCHEMA TABLE [degree]
./unified_runner.sh workflow "$CONN" post_data_load SCHEMA target source count degree
./unified_runner.sh workflow "$CONN" create_renamed_view SCHEMA TABLE
./unified_runner.sh workflow "$CONN" pre_create_partitions SCHEMA TABLE days

# Finalize
./unified_runner.sh finalize SCHEMA TABLE "$CONN"

# Subpartitions
./unified_runner.sh add_subparts SCHEMA TABLE column count "$CONN"
```

### Connection String Formats

```bash
# Standard
"username/password@hostname:1521/service_name"

# LDAP
"username/password@ldap://ldap-server:389/cn=service,cn=OracleContext"

# As SYSDBA
"sys/password@hostname:1521/service_name AS SYSDBA"
```

### Output Directory Structure

```
output/
└── YYYYMMDD_HHMMSS_schema/
    ├── migration_config.json
    ├── SCHEMA_TABLE1/
    │   ├── 10_create_table.sql
    │   ├── 20_data_load.sql
    │   ├── 30_create_indexes.sql
    │   ├── 35_gather_statistics.sql
    │   ├── 40_delta_load.sql
    │   ├── 50_swap_tables.sql
    │   ├── 60_restore_grants.sql
    │   ├── 70_drop_old_table.sql
    │   ├── master1.sql
    │   └── README.md
    └── SCHEMA_TABLE2/
        └── ...
```

### Validation Checklist

Run these after each major step:

```bash
# 1. Table exists
./unified_runner.sh validation "$CONN" check_existence SCHEMA TABLE

# 2. Row count
./unified_runner.sh validation "$CONN" count_rows SCHEMA TABLE

# 3. Constraints
./unified_runner.sh validation "$CONN" check_constraints SCHEMA TABLE

# 4. Structure
./unified_runner.sh workflow "$CONN" post_create SCHEMA TABLE

# 5. Partition distribution
./unified_runner.sh validation "$CONN" check_partition_dist SCHEMA TABLE

# 6. Swap status
./unified_runner.sh workflow "$CONN" post_swap SCHEMA TABLE
```

---

## Getting Help

### Logs

All operations create detailed logs:
- `output/YYYYMMDD_HHMMSS_schema/` - Generated artifacts
- `output/validation_run_TIMESTAMP/` - Validation logs
- `output/migration_run_TIMESTAMP/` - Migration logs

### Common Issues

1. **Read CRITICAL_OPS.md** for quick command reference
2. **Check generated README.md** in output directory
3. **Review migration_config.json** for configuration errors
4. **Examine SQL output logs** for detailed error messages
5. **Run with `--verbose`** for detailed output

### Additional Resources

- `QUICKSTART.md` - Quick start guide
- `CRITICAL_OPS.md` - Critical operations reference
- `templates/README.md` - Template documentation
- `templates/plsql-util/README.md` - PL/SQL utilities

---

The Issue
The problem is with this syntax in your CREATE TABLE statement, The TABLESPACE SET clause is not valid for CREATE TABLE statements. It's only used in specific transportable tablespace operations.

ey Changes Made
Fixed LOB tablespace syntax:
Changed TABLESPACE set (IE_LOB_01, IE_LOB_02, IE_LOB_03) to TABLESPACE IE_LOB_01 and TABLESPACE IE_LOB_02
You can only specify one tablespace per LOB in CREATE TABLE
Fixed partition LOB tablespace syntax:
Changed TABLESPACE (IE_LOB_01,IE_LOB_02, IE_LOB_03) to individual TABLESPACE IE_LOB_01 and TABLESPACE IE_LOB_02
Fixed BUFFER POOL syntax:
Changed BUFFER POOL DEFAU to BUFFER POOL DEFAULT
Alternative: Using Tablespace Groups
If you want to use multiple tablespaces for LOBs, you need to create a tablespace group first:


TABLESPACE set (IE_LOB_01, IE_LOB_02, IE_LOB_03)

```sql
CREATE TABLE GD.IE_PC_OFFER_IN_NEW1
(
    TRACE_ID             VARCHAR2(36 BYTE) NOT NULL,
    SEQ_NUM_UUID         VARCHAR2(36 BYTE) NOT NULL,
    AUDIT_CREATE_DATE    TIMESTAMP(6)      NOT NULL,
    FOOD_FILECREATE_DT   TIMESTAMP(6),
    OFFER_IN             BLOB,
    SUB_OFFER_IN         BLOB
)
LOB (OFFER_IN) STORE AS SECUREFILE
(
    TABLESPACE IE_LOB_01
    ENABLE STORAGE IN ROW
    CHUNK 8192
    RETENTION
    CACHE READS
    STORAGE (INITIAL 4M NEXT 4M MINEXTENTS 2 MAXEXTENTS UNLIMITED PCTINCREASE 0 BUFFER POOL DEFAULT)
)
LOB (SUB_OFFER_IN) STORE AS SECUREFILE
(
    TABLESPACE IE_LOB_02
    ENABLE STORAGE IN ROW
    CHUNK 8192
    RETENTION
    CACHE READS
    STORAGE (INITIAL 4M NEXT 4M MINEXTENTS 2 MAXEXTENTS UNLIMITED PCTINCREASE 0 BUFFER POOL DEFAULT)
)
TABLESPACE OMIE_DATA
PARTITION BY RANGE (AUDIT_CREATE_DATE)
INTERVAL (NUMTODSINTERVAL (1, 'HOUR'))
SUBPARTITION BY HASH(TRACE_ID)
SUBPARTITIONS 24
(
    PARTITION P_PRE2020 VALUES LESS THAN (TIMESTAMP '2025-03-01 00:00:00')
    LOB (OFFER_IN) STORE AS SECUREFILE
    (
        TABLESPACE IE_LOB_01
        ENABLE STORAGE IN ROW
        CHUNK 8192
        RETENTION
        CACHE READS
    )
    LOB (SUB_OFFER_IN) STORE AS SECUREFILE
    (
        TABLESPACE IE_LOB_02
        ENABLE STORAGE IN ROW
        CHUNK 8192
        RETENTION
        CACHE READS
    )
)
NOCACHE;
```

**Version:** 1.0  
**Last Updated:** October 2024  
**Oracle Database:** 12c+ (19c+ recommended)

Alternative: Using Tablespace Groups
If you want to use multiple tablespaces for LOBs, you need to create a tablespace group first:

-- First, create a tablespace group (if it doesn't exist)
ALTER TABLESPACE IE_LOB_01 TABLESPACE GROUP LOB_GROUP;
ALTER TABLESPACE IE_LOB_02 TABLESPACE GROUP LOB_GROUP;
ALTER TABLESPACE IE_LOB_03 TABLESPACE GROUP LOB_GROUP;

-- Then use the group in your CREATE TABLE
CREATE TABLE GD.IE_PC_OFFER_IN_NEW1
(
    TRACE_ID             VARCHAR2(36 BYTE) NOT NULL,
    SEQ_NUM_UUID         VARCHAR2(36 BYTE) NOT NULL,
    AUDIT_CREATE_DATE    TIMESTAMP(6)      NOT NULL,
    FOOD_FILECREATE_DT   TIMESTAMP(6),
    OFFER_IN             BLOB,
    SUB_OFFER_IN         BLOB
)
LOB (OFFER_IN) STORE AS SECUREFILE
(
    TABLESPACE GROUP LOB_GROUP
    ENABLE STORAGE IN ROW
    CHUNK 8192
    RETENTION
    CACHE READS
    STORAGE (INITIAL 4M NEXT 4M MINEXTENTS 2 MAXEXTENTS UNLIMITED PCTINCREASE 0 BUFFER POOL DEFAULT)
)
LOB (SUB_OFFER_IN) STORE AS SECUREFILE
(
    TABLESPACE GROUP LOB_GROUP
    ENABLE STORAGE IN ROW
    CHUNK 8192
    RETENTION
    CACHE READS
    STORAGE (INITIAL 4M NEXT 4M MINEXTENTS 2 MAXEXTENTS UNLIMITED PCTINCREASE 0 BUFFER POOL DEFAULT)
)
TABLESPACE OMIE_DATA
PARTITION BY RANGE (AUDIT_CREATE_DATE)
INTERVAL (NUMTODSINTERVAL (1, 'HOUR'))
SUBPARTITION BY HASH(TRACE_ID)
SUBPARTITIONS 24
(
    PARTITION P_PRE2020 VALUES LESS THAN (TIMESTAMP '2025-03-01 00:00:00')
    LOB (OFFER_IN) STORE AS SECUREFILE
    (
        TABLESPACE GROUP LOB_GROUP
        ENABLE STORAGE IN ROW
        CHUNK 8192
        RETENTION
        CACHE READS
    )
    LOB (SUB_OFFER_IN) STORE AS SECUREFILE
    (
        TABLESPACE GROUP LOB_GROUP
        ENABLE STORAGE IN ROW
        CHUNK 8192
        RETENTION
        CACHE READS
    )
)
NOCACHE;