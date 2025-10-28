# Oracle 19c LOB Syntax Research Documentation

## Overview
This document contains comprehensive research findings on Oracle 19c LOB (Large Object) syntax, specifically addressing the `ORA-02538: invalid TABLESPACE SET clause` error and correct syntax for CREATE TABLE statements with LOB columns.

## Error Analysis

### ORA-02538: invalid TABLESPACE SET clause

**Cause:** The `TABLESPACE SET` clause was used in a context where it's not applicable.

**Root Cause:** The `TABLESPACE SET` clause is **specifically designed for Oracle Sharding environments only** and is **NOT valid** in standard CREATE TABLE statements.

## Oracle 19c Official Documentation Findings

### 1. TABLESPACE SET Clause Limitations

According to Oracle 19c official documentation:

- `TABLESPACE SET` clause is **exclusively for sharded tables**
- It's **NOT valid** in standard `CREATE TABLE` statements
- Using it in non-sharded environments causes `ORA-02538: invalid TABLESPACE SET clause`
- The clause is only applicable when creating sharded tables with the `SHARDED` keyword

### 2. Correct LOB Syntax for Oracle 19c

#### Single Tablespace per LOB (Standard Approach)

**Syntax:**
```sql
CREATE TABLE schema.table_name
(
    column1 datatype,
    column2 datatype,
    lob_column BLOB
)
LOB (lob_column) STORE AS SECUREFILE
(
    TABLESPACE tablespace_name
    ENABLE STORAGE IN ROW
    CHUNK chunk_size
    RETENTION
    CACHE READS
    STORAGE (storage_clause)
)
TABLESPACE main_tablespace;
```

**Complete Example:**
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

### 3. Tablespace Groups for Load Balancing

Oracle 19c supports **TABLESPACE GROUP** for LOBs, which allows load balancing across multiple tablespaces.

#### Step 1: Create Tablespace Group
```sql
-- Create tablespace group
ALTER TABLESPACE IE_LOB_01 TABLESPACE GROUP LOB_GROUP;
ALTER TABLESPACE IE_LOB_02 TABLESPACE GROUP LOB_GROUP;
ALTER TABLESPACE IE_LOB_03 TABLESPACE GROUP LOB_GROUP;
```

#### Step 2: Use Group in CREATE TABLE
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

## Common Syntax Errors and Corrections

### Error 1: Comma-Separated Tablespaces
**Incorrect:**
```sql
TABLESPACE IE_LOB_01, IE_LOB_02, IE_LOB_03
```

**Correct:**
```sql
TABLESPACE IE_LOB_01
-- OR
TABLESPACE GROUP LOB_GROUP
```

### Error 2: TABLESPACE SET in Non-Sharded Environment
**Incorrect:**
```sql
TABLESPACE SET (IE_LOB_01, IE_LOB_02, IE_LOB_03)
```

**Correct:**
```sql
TABLESPACE IE_LOB_01
-- OR
TABLESPACE GROUP LOB_GROUP
```

### Error 3: BUFFER POOL Syntax
**Incorrect:**
```sql
BUFFER POOL DEFAU
```

**Correct:**
```sql
BUFFER POOL DEFAULT
```

## Key Oracle 19c Syntax Rules

1. **Single Tablespace per LOB**: Each LOB column can specify only ONE tablespace
2. **Tablespace Groups**: Must be created first using `ALTER TABLESPACE ... TABLESPACE GROUP`
3. **No Comma-Separated Tablespaces**: Oracle does not support comma-separated multiple tablespaces in LOB definitions
4. **TABLESPACE SET**: Only valid for sharded tables with `SHARDED` keyword
5. **Partition LOBs**: Each partition can have its own LOB tablespace specification

## Oracle 19c Documentation References

### Official Documentation Links
1. **ORA-02538 Error Documentation**: 
   - [Oracle Error Help - ORA-02538](https://docs.oracle.com/en/error-help/db/ora-02538/)

2. **CREATE TABLE Statement**: 
   - [Oracle 19c SQL Reference - CREATE TABLE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-TABLE.html)

3. **LOB Storage Documentation**: 
   - [Oracle 19c LOB Storage](https://docs.oracle.com/en/database/oracle/oracle-database/19/adlob/LOB-storage.html)

4. **TABLESPACE SET Documentation**: 
   - [Oracle 19c CREATE TABLESPACE SET](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-TABLESPACE-SET.html)

5. **Managing Tablespaces**: 
   - [Oracle 19c Managing Tablespaces](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-tablespaces.html)

## Recommendations

### For Standard Tables (Non-Sharded)
- Use **single tablespace per LOB** for simplicity
- Specify one tablespace per LOB column
- Use `TABLESPACE tablespace_name` syntax

### For Load Balancing Requirements
- Create **tablespace groups** first
- Use `TABLESPACE GROUP group_name` syntax
- Assign multiple tablespaces to the group

### For Sharded Tables
- Use `CREATE SHARDED TABLE` syntax
- Use `TABLESPACE SET` clause only in sharded context
- Follow Oracle Sharding documentation

## Testing and Validation

### Test Single Tablespace Approach
```sql
-- Test basic LOB creation
CREATE TABLE test_lob_single (
    id NUMBER,
    data BLOB
)
LOB (data) STORE AS SECUREFILE (
    TABLESPACE IE_LOB_01
    ENABLE STORAGE IN ROW
    CHUNK 8192
    RETENTION
    CACHE READS
);
```

### Test Tablespace Group Approach
```sql
-- Create group
ALTER TABLESPACE IE_LOB_01 TABLESPACE GROUP TEST_GROUP;
ALTER TABLESPACE IE_LOB_02 TABLESPACE GROUP TEST_GROUP;

-- Test LOB with group
CREATE TABLE test_lob_group (
    id NUMBER,
    data BLOB
)
LOB (data) STORE AS SECUREFILE (
    TABLESPACE GROUP TEST_GROUP
    ENABLE STORAGE IN ROW
    CHUNK 8192
    RETENTION
    CACHE READS
);
```

## Summary

The `ORA-02538: invalid TABLESPACE SET clause` error occurs because:

1. **`TABLESPACE SET` is only for sharded tables**
2. **Comma-separated tablespaces are not supported**
3. **Each LOB can specify only one tablespace or one tablespace group**
4. **Tablespace groups must be created first**

The corrected syntax provided above will resolve the error and provide proper LOB storage configuration for Oracle 19c databases.

---

**Document Version**: 1.0  
**Oracle Version**: 19c  
**Last Updated**: 2025-01-28  
**Research Sources**: Oracle Official Documentation, Oracle Error Help, Oracle SQL Reference
