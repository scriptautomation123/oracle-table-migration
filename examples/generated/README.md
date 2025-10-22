# Generated Scripts Directory

This directory will contain generated migration scripts when you run the script generator.

## How to Generate Scripts

1. **Using a config file:**

   ```bash
   python3 generate_scripts.py --config examples/configs/config_nonpartitioned_to_interval_hash.json
   ```

2. **Using discovery mode:**

   ```bash
   python3 generate_scripts.py \
       --discover \
       --schema MYSCHEMA \
       --connection "user/pass@host:1521/service"
   ```

## Generated Structure

Each table migration will create a subdirectory with the following scripts:

```
<SCHEMA>_<TABLE_NAME>/
├── 10_create_table.sql       # Create new partitioned table
├── 20_data_load.sql          # Initial data load
├── 30_create_indexes.sql     # Recreate indexes
├── 40_delta_load.sql         # Load changes since initial load
├── 50_swap_tables.sql        # Rename tables (final switch)
├── 60_restore_grants.sql     # Restore privileges
├── 70_drop_old_table.sql     # Drop old table
├── master1.sql               # Execute scripts 10-40
├── master2.sql               # Execute scripts 50-70
└── README.md                 # Table-specific documentation
```

## Example Configurations

See the `examples/configs/` directory for sample configuration files:

- `config_nonpartitioned_to_interval_hash.json` - Add partitioning to non-partitioned table
- `config_interval_to_interval_hash.json` - Add hash subpartitioning to interval-partitioned table

## Note

This directory is excluded from version control (`.gitignore`). Generated scripts should be customized and tested in your environment before production use.
