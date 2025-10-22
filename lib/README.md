# Migration Script Generator - Supporting Modules# Migration Script Generator - Supporting Modules



This directory contains the core Python modules that power the table migration framework.This directory contains the core Python modules that power the table migration framework.



## Modules## Modules



### discovery_queries.py### generate_scripts.py (Main CLI - now at project root)

Database discovery and metadata extraction from Oracle data dictionary.The main script has been moved to the project root for easier access. See `../generate_scripts.py`



**Key Features:**### discovery_queries.py

- Query `ALL_TABLES`, `ALL_TAB_PARTITIONS`, `ALL_PART_TABLES`Database discovery and metadata extraction from Oracle data dictionary.

- Extract partition/subpartition metadata

- Detect interval types (HOUR/DAY/WEEK/MONTH)**Key Features:**

- Analyze column structures and constraints- Query `ALL_TABLES`, `ALL_TAB_PARTITIONS`, `ALL_PART_TABLES`

- Extract partition/subpartition metadata

**Main Class:** `TableDiscovery`- Detect interval types (HOUR/DAY/WEEK/MONTH)

- Analyze column structures and constraints

### config_validator.py

JSON configuration validation with JSON Schema.### config_validator.py

JSON configuration validation with JSON Schema.

**Validates:**

- Schema compliance (`migration_schema.json`)**Validates:**

- Partition configuration consistency- Schema compliance (`migration_schema.json`)

- Hash subpartition settings- Partition configuration consistency

- Migration settings and safety checks- Hash subpartition settings

- Migration settings and safety checks

**Main Class:** `ConfigValidator`

### migration_validator.py

### migration_validator.pyPre-migration and post-migration validation framework.

Pre-migration and post-migration validation framework.

**Features:**

**Features:**- Pre-migration checks (prerequisites, dependencies)

- Pre-migration checks (prerequisites, dependencies)- Post-migration validation (row counts, data comparison)

- Post-migration validation (row counts, data comparison)- Performance benchmarking

- Performance benchmarking- Validation report generation

- Validation report generation

### template_filters.py

**Main Class:** `MigrationValidator`Custom Jinja2 filters for SQL generation.



### template_filters.py**Custom Filters (12 total):**

Custom Jinja2 filters for SQL generation.- `to_timestamp_format` - Convert interval types to timestamp formats

- `partition_key_expr` - Generate partition key expressions

**Custom Filters (12 total):**- `parallel_degree` - Calculate optimal parallelism

- `to_timestamp_format` - Convert interval types to timestamp formats- `estimate_duration` - Estimate migration time

- `partition_key_expr` - Generate partition key expressions- ... and 8 more

- `parallel_degree` - Calculate optimal parallelism

- `estimate_duration` - Estimate migration time### migration_schema.json

- `format_bytes` - Format byte sizesJSON Schema definition for migration configurations.

- `format_number` - Format large numbers

- `interval_to_numtodsinterval` - Generate interval expressions**Defines:**

- `generate_hash_columns` - Generate hash column lists- Required and optional fields

- `calculate_initial_partitions` - Calculate partition counts- Valid partition types and settings

- `safety_check` - Validate migration safety- Migration configuration structure

- `estimate_downtime` - Calculate expected downtime- Validation rules and constraints

- `recommend_maintenance_window` - Suggest maintenance windows

## Architecture

### migration_schema.json

JSON Schema definition for migration configurations.```

table_migration/

**Defines:**├── generate_scripts.py        # Main CLI (orchestrator)

- Required and optional fields├── lib/                        # Supporting modules (this directory)

- Valid partition types and settings│   ├── discovery_queries.py

- Migration configuration structure│   ├── config_validator.py

- Validation rules and constraints│   ├── migration_validator.py

│   ├── template_filters.py

## Architecture│   └── migration_schema.json

└── templates/                  # Jinja2 SQL templates

``````

table_migration/

├── generate_scripts.py        # Main CLI (orchestrator)## Usage from Code

├── lib/                        # Supporting modules (this directory)

│   ├── __init__.py```python

│   ├── discovery_queries.pyfrom lib.discovery_queries import TableDiscovery

│   ├── config_validator.pyfrom lib.config_validator import ConfigValidator

│   ├── migration_validator.pyfrom lib.migration_validator import MigrationValidator

│   ├── template_filters.py

│   └── migration_schema.json# Discovery

├── templates/                  # Jinja2 SQL templatesdiscovery = TableDiscovery(connection)

├── examples/                   # Example configs and outputstables = discovery.find_interval_tables(schema='MYSCHEMA')

├── output/                     # User's generated scripts

└── rollback/                   # Emergency procedures# Validation

```validator = ConfigValidator(connection, schema_file='lib/migration_schema.json')

is_valid = validator.validate_file('migration_config.json')

## Usage from Code

# Migration validation

```pythonmig_validator = MigrationValidator(connection, config)

from lib.discovery_queries import TableDiscoverymig_validator.validate_pre_migration()

from lib.config_validator import ConfigValidator```

from lib.migration_validator import MigrationValidator

from lib.template_filters import register_custom_filters## Quick Start



# DiscoverySee the main [USER_GUIDE.md](../USER_GUIDE.md) for complete workflow documentation.

discovery = TableDiscovery(connection)

tables = discovery.find_interval_tables(schema='MYSCHEMA')```bash

metadata = discovery.get_table_metadata('MYSCHEMA', 'MYTABLE')# Run from project root

cd table_migration

# Validation

validator = ConfigValidator(connection)# Discovery

is_valid = validator.validate_file('migration_config.json')python3 generate_scripts.py --discover --schema MYSCHEMA \

    --connection "user/pass@host:port/service"

# Migration validation

mig_validator = MigrationValidator(connection, config)# Generate scripts

pre_results = mig_validator.validate_pre_migration()python3 generate_scripts.py --config migration_config.json

post_results = mig_validator.validate_post_migration()```



# Template filters (automatically registered by generate_scripts.py)## How It Works

from jinja2 import Environment

env = Environment()1. Queries Oracle for all interval-partitioned tables

register_custom_filters(env)2. Extracts complete metadata (columns, indexes, LOBs, grants, constraints)

```3. Calculates optimal hash subpartitions (4-16) based on table size

4. Substitutes all template variables with actual values

## Module Dependencies5. Generates complete, ready-to-run scripts



```## Automatic Optimization

discovery_queries.py

├── oracledb (or cx_Oracle)| Table Size | Hash Subpartitions | Parallel Degree |

└── No internal dependencies|------------|-------------------|-----------------|

| > 100 GB | 16 | 8 |

config_validator.py| 50-100 GB | 12 | 4 |

├── jsonschema| 10-50 GB | 8 | 4 |

└── migration_schema.json (same directory)| < 10 GB | 4 | 2 |



migration_validator.py## Output Example

├── oracledb

└── No internal dependencies```

================================================================

template_filters.pyMigration Script Generator

├── jinja2================================================================

└── No dependencies

Found 5 interval-partitioned tables

generate_scripts.py (main - in project root)

├── discovery_queries======================================================================

├── config_validatorProcessing: MYSCHEMA.ORDERS

├── migration_validator  Size: 25.50 GB, Rows: 15,234,567

└── template_filters  Hash Subpartitions: 8, Parallel: 4

```  Partition Key: ORDER_DATE

  Primary Key: ORDER_ID

## Quick Start  Timestamp Column: LAST_UPDATE_DATE

  ✓ Generated 9 scripts + README in: 05_tables/MYSCHEMA_ORDERS

The main script `generate_scripts.py` is now at the project root for easier access.======================================================================



```bashGeneration Summary

# Run from project root================================================================

cd table_migrationTables Processed:  5

Scripts Generated: 45

# DiscoveryErrors:            0

python3 generate_scripts.py --discover --schema MYSCHEMA \================================================================

    --connection "user/pass@host:port/service"

✓ Script generation complete!

# Validate configuration```

python3 generate_scripts.py --config migration_config.json --validate-only

## Troubleshooting

# Generate scripts

python3 generate_scripts.py --config migration_config.json### Connection Issues



# Pre-migration validation```bash

python3 generate_scripts.py --config migration_config.json --validate-pre \# Install Oracle Instant Client if needed

    --connection "user/pass@host:port/service"export LD_LIBRARY_PATH=/path/to/instantclient:$LD_LIBRARY_PATH

```

# Post-migration validation

python3 generate_scripts.py --config migration_config.json --validate-post \### Permission Issues

    --connection "user/pass@host:port/service"

``````sql

-- Grant required privileges

## Module StatisticsGRANT SELECT ON ALL_TABLES TO username;

GRANT SELECT ON ALL_TAB_COLUMNS TO username;

| Module | Lines | Classes | Functions | Purpose |GRANT SELECT ON ALL_PART_TABLES TO username;

|--------|-------|---------|-----------|---------|GRANT SELECT ON ALL_INDEXES TO username;

| discovery_queries.py | 608 | 1 | 8 | Database metadata extraction |GRANT SELECT ON ALL_LOBS TO username;

| config_validator.py | 391 | 1 | 12 | JSON validation |GRANT SELECT ON ALL_TAB_PRIVS TO username;

| migration_validator.py | 1,167 | 1 | 15 | Pre/post validation |GRANT SELECT ON ALL_CONSTRAINTS TO username;

| template_filters.py | 373 | 0 | 12 | Jinja2 custom filters |GRANT SELECT ON DBA_SEGMENTS TO username;

| **Total** | **2,539** | **3** | **47** | |```



## Related Documentation### No Tables Found



- [USER_GUIDE.md](../USER_GUIDE.md) - Complete workflow guide```sql

- [IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md) - Architecture details-- Check if interval-partitioned tables exist

- [templates/README.md](../templates/README.md) - Template documentationSELECT owner, table_name, interval

- [examples/README.md](../examples/README.md) - Example configurationsFROM all_part_tables

WHERE partitioning_type = 'RANGE'

---  AND interval IS NOT NULL;

```

**Last Updated**: 2025-10-22

## Files

```
02_generator/
├── README.md (this file)
└── generate_scripts.py        (305 lines) - Complete generator
```

## Related Documentation

- **00_discovery/** - Table discovery
- **01_templates/** - Migration templates  
- **03_validation/** - Validation scripts
- **04_rollback/** - Rollback procedures
- **05_tables/** - Generated scripts (output)

---

**Last Updated**: 2025-10-22
