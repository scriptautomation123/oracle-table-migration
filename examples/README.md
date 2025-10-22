# Examples

This directory contains example configurations and sample generated outputs to help you understand the migration framework.

## Structure

```
examples/
├── configs/           # Example JSON configurations (input)
│   ├── config_interval_to_interval_hash.json
│   └── config_nonpartitioned_to_interval_hash.json
└── generated/         # Placeholder for testing (use output/ for real work)
    └── README.md
```

## Using Examples

### 1. Review Example Configs

```bash
# View example configurations
cat configs/config_interval_to_interval_hash.json
cat configs/config_nonpartitioned_to_interval_hash.json
```

These show:
- How to configure interval types (HOUR/DAY/WEEK/MONTH)
- Hash subpartition settings
- Table-specific customization
- Migration settings

### 2. Understand Generated Output

When you generate scripts, they will be created in `../output/` with this structure:

- `10_create_table.sql` - CREATE TABLE with partitioning
- `20_data_load.sql` - Parallel data load
- `30_create_indexes.sql` - Index creation
- `40_delta_load.sql` - Incremental changes
- `50_swap_tables.sql` - Table rename (cutover)
- `60_restore_grants.sql` - Grant restoration
- `70_drop_old_table.sql` - Old table cleanup
- `master1.sql` & `master2.sql` - Orchestration scripts
- `README.md` - Table-specific documentation

### 3. Create Your Own Config

```bash
# Start with discovery (from project root)
cd ..
python3 generate_scripts.py --discover --schema YOUR_SCHEMA \
    --connection "user/pass@host:port/service"

# Edit the generated config
vim migration_config.json

# Use example configs as reference
```

## Example Scenarios

### Example 1: Interval to Interval-Hash

**File**: `configs/config_interval_to_interval_hash.json`

**Scenario**: Table already has MONTH interval partitioning, add 8 hash subpartitions

**Key Settings**:
```json
{
  "current_state": {
    "is_partitioned": true,
    "is_interval": true
  },
  "target_configuration": {
    "interval_type": "MONTH",
    "subpartition_type": "HASH",
    "subpartition_count": 8
  }
}
```

**Use case**: Improve parallelism on large interval-partitioned tables

---

### Example 2: Non-Partitioned to Interval-Hash

**File**: `configs/config_nonpartitioned_to_interval_hash.json`

**Scenario**: Convert non-partitioned table to DAY interval with 4 hash subpartitions

**Key Settings**:
```json
{
  "current_state": {
    "is_partitioned": false
  },
  "target_configuration": {
    "interval_type": "DAY",
    "subpartition_type": "HASH",
    "subpartition_count": 4
  }
}
```

**Use case**: Partition growing tables for better manageability

---

## Tips

1. **Copy and modify**: Start with example configs and customize
2. **Review generated scripts**: Understand what will be created before execution
3. **Test in dev first**: Always test with similar data volumes
4. **Adjust settings**: Modify parallel degree, hash counts based on your environment

## Your Actual Work

**Your generated scripts go in `output/`** (not in examples/)

The `output/` directory is gitignored so your actual migration scripts stay local.

## Related Documentation

- [QUICKSTART.md](../QUICKSTART.md) - Quick start guide (5 minutes)
- [USER_GUIDE.md](../docs/USER_GUIDE.md) - Complete workflow guide
- [README.md](../docs/README.md) - Project overview
- [lib/README.md](../lib/README.md) - Module documentation
