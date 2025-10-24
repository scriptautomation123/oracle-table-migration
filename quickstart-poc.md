# POC Generation Quickstart

## Prerequisites
```bash
pip install -r requirements.txt
```

## Usage

### 1. Schema-Only POC
```bash
python refactored_generate_poc.py \
  --schema-config examples/poc-schema.json \
  --schema-connection "user/password@host:port/service"
```

### 2. POC with Data Sampling
```bash
python refactored_generate_poc.py \
  --schema-config examples/poc-schema.json \
  --data-config examples/poc-data.json \
  --schema-connection "user/password@host:port/service" \
  --data-connection "user/password@host:port/service"
```

### 3. Execute POC Test
```bash
python refactored_generate_poc.py \
  --poc-config poc_output/poc-config.json \
  --target-connection "user/password@host:port/service"
```

## Configuration Files

### Schema Config (`examples/poc-schema.json`)
```json
{
  "source_schema": "SOURCE_SCHEMA",
  "target_schema": "TARGET_SCHEMA", 
  "include_patterns": ["TABLE_PREFIX%"],
  "exclude_patterns": ["TEMP%", "BACKUP%"],
  "cleanup_existing": true
}
```

### Data Config (`examples/poc-data.json`)
```json
{
  "sample_percentage": 10,
  "sample_strategy": "random",
  "preserve_referential_integrity": true
}
```

## Output Structure
```
poc_output/
├── poc-config.json          # Generated POC configuration
├── 01_cleanup_target.sql    # Cleanup scripts
├── 02_create_schema.sql     # Schema creation
├── 03_load_sample_data.sql  # Data loading (if sampled)
├── 04_create_constraints.sql
├── 05_create_indexes.sql
├── 06_run_migration.sql
├── 07_validate_results.sql
└── 08_cleanup.sql
```

## Options
- `--output-dir`: Output directory (default: poc_output)
- `--template-dir`: Template directory (default: templates)
- `--execute`: Execute POC test cycle

## Examples
See `examples/` directory for sample configurations.
