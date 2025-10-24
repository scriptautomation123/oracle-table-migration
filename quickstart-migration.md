# Migration Script Generator Quickstart

## Prerequisites
```bash
pip install -r requirements.txt
```

## Usage

### 1. Discovery Mode
```bash
python3 refactored_generate_scripts.py \
  --discover \
  --schema SOURCE_SCHEMA \
  --connection "user/password@host:port/service" \
  --include "TABLE_PREFIX%" \
  --exclude "TEMP%" "BACKUP%"
```

### 2. Validation Mode
```bash
python3 refactored_generate_scripts.py \
  --config migration_config.json \
  --validate-only \
  --check-database \
  --connection "user/password@host:port/service"
```

### 3. Generation Mode
```bash
python3 refactored_generate_scripts.py \
  --config migration_config.json \
  --connection "user/password@host:port/service" \
  --output-dir output
```

## Configuration File

### Migration Config (`migration_config.json`)
```json
{
  "metadata": {
    "schema": "SOURCE_SCHEMA",
    "total_tables_found": 25,
    "tables_selected_for_migration": 10
  },
  "tables": [
    {
      "owner": "SOURCE_SCHEMA",
      "table_name": "TABLE_NAME",
      "enabled": true,
      "target_configuration": {
        "partition_column": "CREATED_DATE",
        "interval_type": "DAY",
        "hash_subpartition_column": "ID",
        "hash_subpartition_count": 16
      }
    }
  ]
}
```

## Output Structure
```bash
output/
├── SOURCE_SCHEMA_TABLE_NAME/
│   ├── 10_create_table.sql      # Table creation
│   ├── 20_data_load.sql         # Data loading
│   ├── 30_create_indexes.sql    # Index creation
│   ├── 40_delta_load.sql        # Delta loading
│   ├── 50_swap_tables.sql       # Table swap
│   ├── 60_restore_grants.sql    # Grant restoration
│   ├── 70_drop_old_table.sql    # Cleanup
│   ├── master1.sql              # Phase 1 execution
│   ├── master2.sql              # Phase 2 execution
│   └── README.md                # Execution instructions
```

## Options
- `--template-dir`: Template directory (default: templates)
- `--output-dir`: Output directory (default: output)
- `--output-file`: Config output file (default: migration_config.json)
- `--environment`: Environment name for discovery
- `--include`: Table name patterns to include
- `--exclude`: Table name patterns to exclude

## Workflow
1. **Discovery**: Scan schema and generate configuration
2. **Review**: Edit configuration file to enable/disable tables
3. **Validate**: Check configuration against database
4. **Generate**: Create migration scripts
5. **Execute**: Run scripts in two phases

## Examples
See `examples/` directory for sample configurations.



```sql
-- Set your block size here (most Oracle DBs use 8192 bytes = 8KB)
DEFINE block_size = 8192
DEFINE schema_owner = 'YOUR_SCHEMA_NAME'

SELECT
    obj.segment_name,
    obj.segment_type,
    ROUND(SUM(obj.blocks * &block_size) / (1024*1024*1024), 3) AS spaceused_gb
FROM
    (
        SELECT 
            t.table_name AS segment_name,
            'TABLE' AS segment_type,
            NVL(t.blocks,0) AS blocks
        FROM all_tables t
        WHERE t.owner = UPPER('&schema_owner')
        
        UNION ALL
        
        SELECT 
            s.segment_name,
            'INDEX' AS segment_type,
            NVL(s.blocks,0) AS blocks
        FROM all_segments s
        WHERE s.owner = UPPER('&schema_owner')
        AND s.segment_type = 'INDEX'
        
        UNION ALL
        
        SELECT 
            s.segment_name,
            'LOB' AS segment_type,
            NVL(s.blocks,0) AS blocks
        FROM all_segments s
        WHERE s.owner = UPPER('&schema_owner')
        AND s.segment_type = 'LOBSEGMENT'
    ) obj
GROUP BY
    obj.segment_name, obj.segment_type
ORDER BY
    obj.segment_name, obj.segment_type;
```