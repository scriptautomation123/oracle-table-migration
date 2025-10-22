# Migration Script Templates

## Overview

This directory contains **9 parameterized SQL script templates** plus **2 master orchestration scripts** for migrating Oracle 19c tables from INTERVAL partitioning to INTERVAL-HASH partitioning.

These templates will be used by the script generator in Phase 3 to create per-table migration scripts.

## Template Structure

### Numbered Scripts (10-70)

| Script | Purpose | Duration | Rollback Safe |
|--------|---------|----------|---------------|
| `10_create_table.sql` | Create new INTERVAL-HASH partitioned table | 1-5 min | ✓ Yes |
| `20_data_load.sql` | Initial bulk data load with parallel INSERT | Variable* | ✓ Yes |
| `30_create_indexes.sql` | Rebuild all indexes on new table | Variable** | ✓ Yes |
| `40_delta_load.sql` | Incremental sync using timestamp-based MERGE | 5-30 min | ✓ Yes |
| `50_swap_tables.sql` | Rename tables (cutover point) | < 1 min | ⚠ Partial*** |
| `60_restore_grants.sql` | Restore privileges and synonyms | 1-5 min | ✓ Yes |
| `70_drop_old_table.sql` | Drop old table (after validation) | 1-5 min | ✗ No |

\* Data load: ~8 GB/hour (conservative estimate)  
\** Index creation: ~0.75 hours per index  
\*** Swap is fast but requires both tables to exist for rollback

### Master Scripts

| Script | Purpose | Executes Steps |
|--------|---------|----------------|
| `master1.sql` | Pre-migration setup and validation | 10, 20, 30 |
| `master2.sql` | Cutover and finalization | 40, 50, 60 |

## Template Variables

All templates use **double-brace notation** for variable substitution:

```sql
{{VARIABLE_NAME}}
```

### Common Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{OWNER}}` | Table owner/schema | `MYSCHEMA` |
| `{{TABLE_NAME}}` | Original table name | `IE_PC_OFFER_IN` |
| `{{NEW_TABLE_NAME}}` | New table name | `IE_PC_OFFER_IN_NEW` |
| `{{OLD_TABLE_NAME}}` | Old table after swap | `IE_PC_OFFER_IN_OLD` |
| `{{TABLESPACE}}` | Tablespace name | `USERS` |
| `{{PARALLEL_DEGREE}}` | Parallel DML/DDL degree | `4`, `8`, `16` |

### Structure Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{COLUMN_DEFINITIONS}}` | DDL column definitions | `ID NUMBER(10), NAME VARCHAR2(100), ...` |
| `{{COLUMN_LIST}}` | Comma-separated columns | `ID, NAME, CREATE_DATE, BLOB_DATA` |
| `{{PARTITION_KEY}}` | Partition key column | `AUDIT_CREATE_DATE` |
| `{{PRIMARY_KEY}}` | Primary key column(s) | `ID` |
| `{{TIMESTAMP_COLUMN}}` | Audit timestamp column | `LAST_UPDATE_DATE` |

### Partitioning Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{INTERVAL_CLAUSE}}` | Interval definition | `NUMTOYMINTERVAL(1,'MONTH')` |
| `{{HASH_SUBPARTS}}` | Number of hash subpartitions | `4`, `8`, `12`, `16` |
| `{{INITIAL_PARTITION_VALUE}}` | Initial partition high value | `TO_DATE('2024-01-01', 'YYYY-MM-DD')` |

### Complex Variables

| Variable | Description | Format |
|----------|-------------|--------|
| `{{LOB_STORAGE_CLAUSES}}` | LOB storage specifications | `LOB (BLOB_COL) STORE AS SECUREFILE ...` |
| `{{INDEX_DEFINITIONS}}` | All CREATE INDEX statements | Multiple CREATE INDEX commands |
| `{{GRANT_STATEMENTS}}` | All GRANT statements | Multiple GRANT commands |
| `{{UPDATE_SET_CLAUSE}}` | MERGE UPDATE clause | `col1 = src.col1, col2 = src.col2, ...` |
| `{{PRIMARY_KEY_MATCH_CONDITION}}` | JOIN condition for MERGE | `tgt.id = src.id` |
| `{{CUTOFF_TIMESTAMP}}` | Delta load cutoff time | `2025-10-21 14:30:00` |
| `{{SCRIPT_DIR}}` | Path to numbered scripts | `/path/to/scripts` |
| `{{TIMESTAMP}}` | Current timestamp for logs | `20251021_143000` |

## Template Features

### Safety Features

All templates include:

✅ **Pre-validation checks** - Verify prerequisites before execution  
✅ **Error handling** - PL/SQL exception handling with rollback  
✅ **Progress tracking** - Detailed DBMS_OUTPUT logging  
✅ **Row count verification** - Compare source vs target after each step  
✅ **Duration tracking** - Measure execution time for each operation  
✅ **Rollback guidance** - Clear instructions for reverting changes  

### User Confirmations

Critical operations require explicit confirmation:

- **Step 50 (Swap)**: Type `YES` to proceed with table swap
- **Step 70 (Drop)**: Type `DELETE` to permanently drop old table

### Parallel Execution

Templates support parallel DML/DDL:

```sql
ALTER SESSION ENABLE PARALLEL DML;
INSERT /*+ APPEND PARALLEL({{PARALLEL_DEGREE}}) */ INTO ...
```

Recommended parallel degrees:
- Small tables (< 10 GB): 4
- Medium tables (10-50 GB): 8
- Large tables (> 50 GB): 12-16

### LOB Handling

Templates preserve LOB storage settings:

```sql
LOB ({{LOB_COLUMN}}) STORE AS SECUREFILE (
    TABLESPACE {{LOB_TABLESPACE}}
    ENABLE STORAGE IN ROW
    CHUNK {{CHUNK_SIZE}}
    RETENTION
    CACHE
    COMPRESS HIGH
    DEDUPLICATE
)
```

### Index Types Supported

- **B-tree indexes** (regular and unique)
- **Bitmap indexes** (marked for special handling)
- **Function-based indexes** (expression preserved)
- **Partitioned/Local indexes** (automatically local on new table)
- **Global indexes** (converted to local when appropriate)

## Script Execution Order

### Phase 1: Setup (Master1)

```
10_create_table.sql       → Create INTERVAL-HASH table
20_data_load.sql          → Bulk load all data
30_create_indexes.sql     → Rebuild indexes
```

**Safe to run multiple times** - Steps 10-30 can be re-run without affecting source table

### Phase 2: Cutover (Master2)

```
40_delta_load.sql         → Sync recent changes
50_swap_tables.sql        → Swap table names (CUTOVER!)
60_restore_grants.sql     → Restore privileges
```

**Critical section** - Step 50 is the point of no return (without manual intervention)

### Phase 3: Cleanup (Manual)

```
70_drop_old_table.sql     → Drop old table (after validation period)
```

**Destructive** - Only run after 24-48 hours of production validation

## Template Customization

### Example: Custom Delta Load Logic

For tables without timestamp columns, modify `40_delta_load.sql`:

```sql
-- Replace timestamp-based filter with sequence-based
WHERE {{SEQUENCE_COLUMN}} > {{LAST_SYNCED_SEQUENCE}}
```

### Example: Additional Validation

Add custom validation to any template:

```sql
-- Add after standard checks
DECLARE
    v_custom_check NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_custom_check
    FROM {{OWNER}}.{{TABLE_NAME}}
    WHERE your_business_rule_check;
    
    IF v_custom_check > 0 THEN
        RAISE_APPLICATION_ERROR(-20999, 'Business rule validation failed');
    END IF;
END;
/
```

### Example: Extended Logging

Enhance logging in master scripts:

```sql
-- Add to master1.sql or master2.sql
SPOOL APPEND audit_log.txt
-- Your logging here
SPOOL OFF
```

## Error Handling Patterns

### Automatic Rollback

```sql
BEGIN
    -- Critical operation
    EXECUTE IMMEDIATE 'ALTER TABLE ...';
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/
```

### Manual Rollback

If migration fails at step 50 or later:

```sql
-- Restore original state
ALTER TABLE {{OWNER}}.{{TABLE_NAME}} RENAME TO {{TABLE_NAME}}_TEMP;
ALTER TABLE {{OWNER}}.{{OLD_TABLE_NAME}} RENAME TO {{TABLE_NAME}};
ALTER TABLE {{OWNER}}.{{TABLE_NAME}}_TEMP RENAME TO {{OLD_TABLE_NAME}};
```

## Logging

All master scripts create detailed log files:

```
master1_migration_{{TABLE_NAME}}_{{TIMESTAMP}}.log
master2_migration_{{TABLE_NAME}}_{{TIMESTAMP}}.log
```

Log contents:
- Execution timestamps for each step
- Row counts before/after each operation
- Index creation progress
- Error messages and stack traces
- Validation results
- Performance metrics

## Performance Tuning

### Parallel Degree Selection

```sql
-- Calculate based on table size
PARALLEL_DEGREE = CASE 
    WHEN size_gb > 100 THEN 16
    WHEN size_gb > 50  THEN 12
    WHEN size_gb > 10  THEN 8
    ELSE 4
END
```

### Hash Subpartition Count

```sql
-- Calculate based on table size
HASH_SUBPARTS = CASE 
    WHEN size_gb > 100 THEN 16
    WHEN size_gb > 50  THEN 12
    WHEN size_gb > 10  THEN 8
    ELSE 4
END
```

### Data Load Optimization

- Use `/*+ APPEND */` hint for direct-path inserts
- Order by partition key for efficient partition creation
- Disable constraints during load
- Gather statistics after load

## Troubleshooting

### Template Variable Not Replaced

**Symptom**: `{{VARIABLE}}` appears in generated script

**Solution**: Check script generator has mapping for that variable

### Row Count Mismatch

**Symptom**: Source and target have different row counts

**Solution**: 
1. Check for active writes during migration
2. Run `40_delta_load.sql` again
3. Verify timestamp column is correctly set

### Index Creation Fails

**Symptom**: `ORA-01408: such column list already indexed`

**Solution**: Check for duplicate index definitions in template

### ORA-14006: Invalid Partition Name

**Symptom**: Partition name violates naming rules

**Solution**: Ensure partition names are <= 30 characters

## Next Steps

After reviewing templates:

1. **Understand variable mapping** - Know what each `{{VARIABLE}}` represents
2. **Review safety features** - Understand validation and rollback points
3. **Proceed to Phase 3** - Script generator in `../02_generator/`
4. **Test on non-production** - Always test templates on dev/test first

## Related Documentation

- **Discovery Phase**: `../00_discovery/README.md` - Table identification
- **Script Generator**: `../02_generator/README.md` - Automated script creation
- **Validation**: `../03_validation/README.md` - Pre/post-migration checks
- **Main Plan**: `../PLAN.md` - Complete migration framework
