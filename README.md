# Oracle Table Migration Framework

**JSON-driven, Jinja2-powered framework for migrating Oracle tables to interval-partitioned or interval-hash-partitioned structures.**

[![Oracle](https://img.shields.io/badge/Oracle-19c%2B-red)](https://www.oracle.com/)
[![Python](https://img.shields.io/badge/Python-3.7%2B-blue)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

## Features

✅ **JSON-Driven Workflow** - Configuration-based migrations with validation  
✅ **Integrated Discovery** - Automatic schema analysis and config generation  
✅ **Flexible Partitioning** - HOUR/DAY/WEEK/MONTH intervals with hash subpartitioning  
✅ **Pre/Post Validation** - Built-in validation framework with data comparison  
✅ **Jinja2 Templates** - Powerful, customizable SQL generation  
✅ **Zero Downtime** - Supports online migrations with delta sync  
✅ **Production Ready** - Safety checks, rollback procedures, comprehensive docs  

## Quick Start

```bash
# 1. Install dependencies
pip install --user oracledb jinja2 jsonschema

# 2. Clone and navigate
cd table_migration

# 3. Discover schema and generate config
python3 generate_scripts.py --discover --schema MYSCHEMA \
    --connection "user/password@host:1521/service"

# 4. Customize migration_config.json (optional)
vim migration_config.json

# 5. Generate migration scripts
python3 generate_scripts.py --config migration_config.json

# 6. Execute migration
cd output/MYSCHEMA_TABLENAME
sqlplus user/password@host:1521/service @master1.sql
```

## Architecture

```
table_migration/
├── generate_scripts.py        # Main CLI tool
├── lib/                        # Supporting modules
│   ├── discovery_queries.py   # Schema discovery
│   ├── config_validator.py    # JSON validation
│   ├── migration_validator.py # Pre/post validation
│   ├── template_filters.py    # Jinja2 filters
│   └── migration_schema.json  # JSON schema
├── templates/                  # Jinja2 SQL templates
├── examples/                   # Example configs & outputs
│   ├── configs/               # Sample JSON configs
│   └── generated/             # Example migration scripts
├── output/                     # Your generated scripts (gitignored)
├── rollback/                   # Emergency procedures
└── requirements.txt
```

## Supported Migration Scenarios

| From | To | Interval Types | Hash Subpartitions |
|------|-----|----------------|-------------------|
| Non-partitioned | Interval | HOUR/DAY/WEEK/MONTH | Optional |
| Non-partitioned | Interval-Hash | HOUR/DAY/WEEK/MONTH | ✅ |
| Interval | Interval-Hash | HOUR/DAY/WEEK/MONTH | ✅ |
| Interval | Interval (different type) | HOUR/DAY/WEEK/MONTH | Optional |

## Workflow

### 1. Discovery Mode

Scan your schema and generate `migration_config.json`:

```bash
python3 generate_scripts.py --discover --schema HR \
    --connection "hr/hr123@localhost:1521/XEPDB1"
```

**Discovers:**
- Table metadata (sizes, row counts, columns)
- Current partition status
- Available timestamp columns (for interval partitioning)
- Available numeric columns (for hash subpartitioning)
- Intelligent defaults for partition keys

### 2. Validation Mode

Validate configuration before generating scripts:

```bash
# Schema-only validation
python3 generate_scripts.py --config migration_config.json --validate-only

# Database validation (checks actual table state)
python3 generate_scripts.py --config migration_config.json --validate-only \
    --check-database --connection "..."

# Pre-migration validation
python3 generate_scripts.py --config migration_config.json --validate-pre \
    --connection "..."
```

### 3. Generation Mode

Generate migration scripts from config:

```bash
python3 generate_scripts.py --config migration_config.json
```

**Generates for each table:**
- `10_create_table.sql` - New partitioned table DDL
- `20_data_load.sql` - Parallel data migration
- `30_create_indexes.sql` - Index creation
- `40_delta_load.sql` - Incremental sync (zero downtime)
- `50_swap_tables.sql` - Cutover (rename tables)
- `60_restore_grants.sql` - Grant restoration
- `70_drop_old_table.sql` - Cleanup
- `master1.sql` & `master2.sql` - Orchestration scripts
- `README.md` - Table-specific instructions

### 4. Execution

Execute generated scripts:

```bash
cd output/MYSCHEMA_TABLENAME

# Phase 1: Create, load, index (can run in background)
sqlplus user/password@host:1521/service @master1.sql

# Phase 2: Delta sync, cutover, grants (requires downtime)
sqlplus user/password@host:1521/service @master2.sql
```

### 5. Post-Migration Validation

Validate migration success:

```bash
python3 generate_scripts.py --config migration_config.json --validate-post \
    --connection "..."

# Compare data between old and new tables
python3 generate_scripts.py --config migration_config.json --compare-data \
    --connection "..."

# Generate comprehensive report
python3 generate_scripts.py --config migration_config.json \
    --validation-report migration_report.md --connection "..."
```

## Example Configuration

```json
{
  "tables": [
    {
      "enabled": true,
      "owner": "MYSCHEMA",
      "table_name": "ORDERS",
      "current_state": {
        "is_partitioned": false,
        "row_count": 15234567,
        "size_gb": 25.5
      },
      "target_configuration": {
        "partition_column": "ORDER_DATE",
        "interval_type": "MONTH",
        "subpartition_type": "HASH",
        "subpartition_column": "ORDER_ID",
        "subpartition_count": 8
      },
      "migration_settings": {
        "parallel_degree": 4,
        "enable_compression": true,
        "backup_old_table": true
      }
    }
  ]
}
```

## Requirements

- **Oracle Database**: 19c or higher (11g+ for basic features)
- **Python**: 3.7+
- **Python Packages**:
  - `oracledb` (or `cx_Oracle`) - Oracle database connectivity
  - `jinja2>=3.1.0` - Template engine
  - `jsonschema>=4.17.0` - JSON validation

```bash
pip install --user oracledb jinja2 jsonschema
```

## Documentation

- [USER_GUIDE.md](USER_GUIDE.md) - Complete workflow guide with examples
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) - Architecture and design
- [lib/README.md](lib/README.md) - Module documentation
- [templates/README.md](templates/README.md) - Template documentation
- [examples/README.md](examples/README.md) - Example configurations

## Safety Features

✅ **JSON Schema Validation** - Catch configuration errors early  
✅ **Pre-migration Checks** - Validate prerequisites before execution  
✅ **Dry Run Mode** - Validate without generating scripts  
✅ **Database State Checks** - Verify actual table state vs config  
✅ **Rollback Procedures** - Emergency rollback scripts  
✅ **Backup Options** - Configurable old table retention  
✅ **Parallel Execution** - Optimized for large tables  

## Performance

| Table Size | Hash Subpartitions | Parallel Degree | Est. Duration |
|------------|-------------------|-----------------|---------------|
| < 10 GB | 4 | 2 | ~15 min |
| 10-50 GB | 8 | 4 | ~1 hour |
| 50-100 GB | 12 | 4 | ~2 hours |
| > 100 GB | 16 | 8 | ~4 hours |

*Duration estimates for data load phase only*

## Contributing

This is a production framework. Contributions welcome:

1. Test in development environment first
2. Follow existing code patterns
3. Update documentation
4. Add examples for new features

## License

MIT License - See LICENSE file

## Support

- **Issues**: GitHub Issues
- **Documentation**: See docs/ directory
- **Examples**: See examples/ directory

## Credits

Built for Oracle Database administrators and developers needing automated, repeatable table partitioning migrations.

---

**Version**: 2.0 (JSON-driven workflow)  
**Last Updated**: 2025-10-22  
**Status**: Production Ready ✅
