# LOB Storage Configuration Guide

## Overview

This guide explains how LOB (Large Object) columns are distributed across tablespaces when creating interval-hash partitioned tables.

## LOB Storage Strategy

### Subpartition Template Approach

When a table has LOB columns and uses hash subpartitioning, the system creates a **SUBPARTITION TEMPLATE** that:

1. **Distributes LOB segments across multiple tablespaces** for I/O parallelism
2. **Associates each LOB with a unique segment name** per subpartition
3. **Rotates through available tablespaces** (typically 4: _01, _02, _03, _04)

### Example DDL Structure

```sql
CREATE TABLE "SCHEMA"."TABLE_NAME"
(
    TRACE_ID            VARCHAR2(36 BYTE),
    ALIAS               VARCHAR2(8 BYTE),
    AUDIT_CREATE_DATE   TIMESTAMP(6) DEFAULT SYSTIMESTAMP,
    SMG3_LOGGING_DATA   CLOB,
    FILTRATION_JSON_DATA CLOB
)
COMPRESS FOR OLTP
TABLESPACE OMIE_DATA_01
PCTFREE 10
INITRANS 1
MAXTRANS 255
STORAGE (
    INITIAL 10240M
    NEXT 10240M
    BUFFER_POOL DEFAULT
)
PARTITION BY RANGE (AUDIT_CREATE_DATE)
INTERVAL (NUMTODSINTERVAL(1,'DAY'))
SUBPARTITION BY HASH (TRACE_ID)
SUBPARTITION TEMPLATE
(
    SUBPARTITION sp0
        LOB (SMG3_LOGGING_DATA) STORE AS smg3_logging_data_1 (TABLESPACE GD_LOB_03),
        LOB (FILTRATION_JSON_DATA) STORE AS smg3_data_2 (TABLESPACE GD_LOB_04),
    SUBPARTITION sp1
        LOB (SMG3_LOGGING_DATA) STORE AS smg3_logging_data_3 (TABLESPACE GD_LOB_04),
        LOB (FILTRATION_JSON_DATA) STORE AS smg3_data_4 (TABLESPACE GD_LOB_03)
)
(
    PARTITION p_seed VALUES LESS THAN (DATE '2025-01-01')
)
ENABLE ROW MOVEMENT;
```

## Configuration Requirements

### LOB Storage Metadata

In the JSON configuration, ensure LOB storage is properly captured:

```json
{
  "lob_storage": [
    {
      "column_name": "SMG3_LOGGING_DATA",
      "segment_name": "smg3_logging_data",
      "tablespace_name": "GD_LOB",
      "securefile": "YES",
      "compression": "ENABLED",
      "deduplication": "DISABLED",
      "in_row": "NO",
      "chunk": 8192,
      "cache": "YES"
    },
    {
      "column_name": "FILTRATION_JSON_DATA",
      "segment_name": "smg3_data",
      "tablespace_name": "GD_LOB",
      "securefile": "YES",
      "compression": "ENABLED",
      "deduplication": "DISABLED",
      "in_row": "NO",
      "chunk": 8192,
      "cache": "YES"
    }
  ]
}
```

### Tablespace Naming Convention

The system expects LOB tablespaces to follow the pattern:

- **Base name**: `GD_LOB` (from configuration)
- **Numbered suffixes**: `_01`, `_02`, `_03`, `_04`

Full names: `GD_LOB_01`, `GD_LOB_02`, `GD_LOB_03`, `GD_LOB_04`

## Template Logic

### Subpartition Distribution

For each subpartition (sp0, sp1, sp2, ...), LOB segments are assigned tablespaces using round-robin:

```
Subpartition sp0 → Tablespace _01
Subpartition sp1 → Tablespace _02
Subpartition sp2 → Tablespace _03
Subpartition sp3 → Tablespace _04
Subpartition sp4 → Tablespace _01 (wraps around)
...
```

Formula: `tablespace_suffix = (subpartition_index % 4) + 1`

### Segment Naming

Each LOB segment gets a unique name per subpartition:

```
{base_segment_name}_{subpartition_index}
```

Example:
- `smg3_logging_data_0` for sp0
- `smg3_logging_data_1` for sp1
- `smg3_logging_data_2` for sp2

## Non-LOB Tables

For tables **without LOB columns**, the generated DDL will:

1. **Omit SUBPARTITION TEMPLATE** clause
2. Use simple `SUBPARTITIONS n` syntax
3. Store all data in the primary tablespace

Example:
```sql
PARTITION BY RANGE (AUDIT_CREATE_DATE)
INTERVAL (NUMTODSINTERVAL(1,'DAY'))
SUBPARTITION BY HASH (TRACE_ID)
SUBPARTITIONS 2
(
    PARTITION p_seed VALUES LESS THAN (DATE '2025-01-01')
)
```

## Best Practices

### 1. Tablespace Pre-Creation

Before migration, ensure all LOB tablespaces exist:

```sql
-- Check existing tablespaces
SELECT tablespace_name 
FROM dba_tablespaces 
WHERE tablespace_name LIKE 'GD_LOB%'
ORDER BY tablespace_name;

-- Create if missing
CREATE TABLESPACE GD_LOB_01 DATAFILE SIZE 10G AUTOEXTEND ON;
CREATE TABLESPACE GD_LOB_02 DATAFILE SIZE 10G AUTOEXTEND ON;
CREATE TABLESPACE GD_LOB_03 DATAFILE SIZE 10G AUTOEXTEND ON;
CREATE TABLESPACE GD_LOB_04 DATAFILE SIZE 10G AUTOEXTEND ON;
```

### 2. I/O Distribution

Place each LOB tablespace on separate storage volumes for optimal I/O:

- `GD_LOB_01` → Volume 1
- `GD_LOB_02` → Volume 2
- `GD_LOB_03` → Volume 3
- `GD_LOB_04` → Volume 4

### 3. Monitoring

After migration, verify LOB segment distribution:

```sql
SELECT 
    l.table_name,
    l.column_name,
    l.segment_name,
    l.tablespace_name,
    s.bytes/1024/1024 as size_mb
FROM 
    dba_lobs l
    JOIN dba_segments s ON (l.segment_name = s.segment_name)
WHERE 
    l.owner = 'YOUR_SCHEMA'
    AND l.table_name = 'YOUR_TABLE'
ORDER BY 
    l.tablespace_name, l.column_name;
```

## Troubleshooting

### Issue: Tablespace Not Found

**Error**: `ORA-00959: tablespace 'GD_LOB_01' does not exist`

**Solution**: Create missing tablespaces before running migration scripts.

### Issue: LOB Not in Template

**Symptom**: LOBs stored in default tablespace instead of dedicated LOB tablespaces.

**Solution**: Ensure `lob_storage` array is populated in JSON configuration with proper `tablespace_name` values.

### Issue: Segment Name Collision

**Error**: `ORA-00955: name is already used by an existing object`

**Solution**: Drop old segments or use different segment names in configuration.

## References

- Oracle Documentation: [LOB Storage](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-TABLE.html#GUID-F9CE0CC3-13AE-4744-A43C-EAC7A71AAAB6)
- Oracle Documentation: [Partitioned Tables and Indexes](https://docs.oracle.com/en/database/oracle/oracle-database/19/vldbg/partition-create-tables-indexes.html)
