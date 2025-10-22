# DDL Format Quick Reference

## Complete DDL Structure (With LOBs)

```sql
CREATE TABLE "SCHEMA"."TABLE_NAME"
(
    COLUMN1         VARCHAR2(36 BYTE),
    COLUMN2         VARCHAR2(8 BYTE),
    DATE_COLUMN     TIMESTAMP(6) DEFAULT SYSTIMESTAMP,
    LOB_COLUMN1     CLOB,
    LOB_COLUMN2     CLOB
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
PARTITION BY RANGE (DATE_COLUMN)
INTERVAL (NUMTODSINTERVAL(1,'DAY'))
SUBPARTITION BY HASH (COLUMN1)
SUBPARTITION TEMPLATE
(
    SUBPARTITION sp0
        LOB (LOB_COLUMN1) STORE AS lob1_seg_0 (TABLESPACE GD_LOB_01),
        LOB (LOB_COLUMN2) STORE AS lob2_seg_0 (TABLESPACE GD_LOB_02),
    SUBPARTITION sp1
        LOB (LOB_COLUMN1) STORE AS lob1_seg_1 (TABLESPACE GD_LOB_02),
        LOB (LOB_COLUMN2) STORE AS lob2_seg_1 (TABLESPACE GD_LOB_03)
)
(
    PARTITION p_seed VALUES LESS THAN (DATE '2025-01-01')
)
ENABLE ROW MOVEMENT;
```

## Complete DDL Structure (Without LOBs)

```sql
CREATE TABLE "SCHEMA"."TABLE_NAME"
(
    COLUMN1         VARCHAR2(36 BYTE),
    COLUMN2         VARCHAR2(8 BYTE),
    DATE_COLUMN     TIMESTAMP(6) DEFAULT SYSTIMESTAMP,
    NUMERIC_COLUMN  NUMBER(10)
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
PARTITION BY RANGE (DATE_COLUMN)
INTERVAL (NUMTODSINTERVAL(1,'DAY'))
SUBPARTITION BY HASH (COLUMN1)
SUBPARTITIONS 2
(
    PARTITION p_seed VALUES LESS THAN (DATE '2025-01-01')
)
ENABLE ROW MOVEMENT;
```

## Clause Order Reference

| # | Clause | Required | Notes |
|---|--------|----------|-------|
| 1 | CREATE TABLE | Yes | Schema.table_name |
| 2 | Column definitions | Yes | In COLUMN_ID order |
| 3 | COMPRESS FOR | Conditional | If source has compression |
| 4 | TABLESPACE | Yes | Primary data tablespace |
| 5 | PCTFREE | Conditional | If set in source |
| 6 | INITRANS | Conditional | If set in source |
| 7 | MAXTRANS | Conditional | If set in source |
| 8 | STORAGE (...) | Conditional | If INITIAL/NEXT/BUFFER_POOL set |
| 9 | PARTITION BY RANGE | Yes | For interval partitioning |
| 10 | INTERVAL (...) | Yes | Automatic partition creation |
| 11 | SUBPARTITION BY HASH | Yes | For hash subpartitioning |
| 12 | SUBPARTITION TEMPLATE | Conditional | Only if LOBs exist |
| 13 | SUBPARTITIONS n | Conditional | Only if NO LOBs |
| 14 | (PARTITION ...) | Yes | Initial/seed partition |
| 15 | ENABLE ROW MOVEMENT | Yes | Required for interval |

## LOB Distribution Pattern

For `n` subpartitions and 4 LOB tablespaces:

```
sp0 → *_01
sp1 → *_02
sp2 → *_03
sp3 → *_04
sp4 → *_01  (wraps around)
sp5 → *_02
...
```

Formula: `tablespace_suffix = (subpartition_index % 4) + 1`

## Segment Naming Pattern

```
{base_segment_name}_{subpartition_index}
```

Examples:
- smg3_logging_data_0
- smg3_logging_data_1
- filtration_json_data_0
- filtration_json_data_1

## Common Patterns

### Interval Types
```sql
-- Hourly
INTERVAL (NUMTODSINTERVAL(1,'HOUR'))

-- Daily
INTERVAL (NUMTODSINTERVAL(1,'DAY'))

-- Monthly
INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
```

### Subpartition Counts
Recommended: Powers of 2 (2, 4, 8, 16, 32, 64, 128, 256)

### Storage Sizes
```sql
STORAGE (
    INITIAL 10240M    -- 10 GB
    NEXT 10240M       -- 10 GB
    BUFFER_POOL DEFAULT
)
```

## Validation Queries

### Check Tablespaces
```sql
SELECT tablespace_name 
FROM dba_tablespaces 
WHERE tablespace_name LIKE 'GD_LOB%' 
   OR tablespace_name LIKE 'OMIE_DATA%'
ORDER BY tablespace_name;
```

### Check LOB Distribution
```sql
SELECT 
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
    l.tablespace_name;
```

### Check Partitioning
```sql
SELECT 
    table_name,
    partitioning_type,
    subpartitioning_type,
    partition_count,
    def_subpartition_count,
    interval
FROM 
    all_part_tables
WHERE 
    owner = 'YOUR_SCHEMA'
    AND table_name = 'YOUR_TABLE';
```
