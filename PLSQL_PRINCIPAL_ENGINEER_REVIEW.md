# PL/SQL Code Review - Principal Engineer Assessment

**Reviewer:** Principal Engineer  
**Date:** 2025-10-28  
**Scope:** Comprehensive review of PL/SQL utilities and migration templates  
**Focus Areas:** Safety, Clarity, Ease of Use, Syntax, INSTEAD OF Trigger Implementation

---

## Executive Summary

### Overall Assessment: **GOOD with Critical Issues to Address**

The PL/SQL codebase demonstrates solid engineering practices with well-structured utilities and thoughtful migration workflows. However, several **critical safety issues** require immediate attention, particularly around SQL injection vulnerabilities, error handling patterns, and the INSTEAD OF trigger implementation.

**Rating Breakdown:**
- **Safety:** ⚠️ 6/10 - Critical SQL injection vulnerabilities identified
- **Clarity:** ✅ 8/10 - Well-organized with good documentation
- **Ease of Use:** ✅ 8/10 - Good parameterization and error messages
- **Syntax:** ✅ 9/10 - Modern PL/SQL practices, minor improvements needed
- **INSTEAD OF Trigger:** ⚠️ 5/10 - Significant issues requiring redesign

---

## Critical Issues (Must Fix Immediately)

### 🔴 CRITICAL #1: SQL Injection Vulnerabilities

**Location:** `plsql-util.sql` lines 94, 316, 528-532, 545-549, and multiple other locations

**Issue:** Dynamic SQL construction using concatenated user inputs without proper sanitization.

**Example:**
```sql
-- Line 94 - VULNERABLE
EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || UPPER('&arg3') || '.' || UPPER('&arg4') INTO v_count;

-- Line 316 - VULNERABLE  
EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || UPPER('&arg3') || '.' || v_target INTO v_target_count;

-- Lines 528-532 - HIGHLY VULNERABLE
EXECUTE IMMEDIATE 'CREATE OR REPLACE VIEW ' || v_schema || '.' || v_view_name || ' AS
    SELECT * FROM ' || v_schema || '.' || v_new_table || ' UNION ALL
    SELECT ' || REPLACE(v_cols, v_new_table || '.', '') || ' FROM ' || v_schema || '.' || v_old_table || '
    WHERE NOT EXISTS (SELECT 1 FROM ' || v_schema || '.' || v_new_table || ' WHERE ' || 
    SUBSTR(v_cols, 1, INSTR(v_cols, ',') - 1) || ' = ' || v_old_table || '.' || 
    SUBSTR(v_cols, 1, INSTR(v_cols, ',') - 1) || ')';
```

**Risk:** An attacker could inject malicious SQL by providing crafted table/schema names like:
```
schema_name = "EVIL_USER; DROP TABLE IMPORTANT_DATA; --"
```

**Recommendation:**
```sql
-- SAFE: Use DBMS_ASSERT to validate identifiers
v_schema := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER('&arg3'));
v_table := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER('&arg4'));

-- SAFE: Use bind variables where possible
EXECUTE IMMEDIATE 
    'SELECT COUNT(*) FROM ' || v_schema || '.' || v_table 
    INTO v_count;

-- SAFE: Quote identifiers properly
EXECUTE IMMEDIATE 
    'SELECT COUNT(*) FROM ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || 
    '.' || DBMS_ASSERT.ENQUOTE_NAME(v_table) 
    INTO v_count;
```

**Priority:** 🔴 IMMEDIATE - This is a security vulnerability

---

### 🔴 CRITICAL #2: INSTEAD OF Trigger - Broken Implementation

**Location:** `plsql-util.sql` lines 459-554 (CREATE_RENAMED_VIEW operation)

**Issues:**

#### Issue 2a: Invalid Trigger Syntax
```sql
-- Line 549 - SYNTAX ERROR
INSERT INTO ' || v_schema || '.' || v_new_table || ' VALUES :NEW.*;
--                                                           ^^^^^^
-- :NEW.* is not valid syntax in Oracle
```

**Correct Syntax:**
```sql
-- Must explicitly list columns or use dynamic SQL to construct the INSERT
INSERT INTO ' || v_schema || '.' || v_new_table || ' 
VALUES (:NEW.col1, :NEW.col2, :NEW.col3, ...);
```

#### Issue 2b: View Definition is Overcomplicated and Fragile
```sql
-- Lines 527-532 - Complex and error-prone
EXECUTE IMMEDIATE 'CREATE OR REPLACE VIEW ' || v_schema || '.' || v_view_name || ' AS
    SELECT * FROM ' || v_schema || '.' || v_new_table || ' UNION ALL
    SELECT ' || REPLACE(v_cols, v_new_table || '.', '') || ' FROM ' || v_schema || '.' || v_old_table || '
    WHERE NOT EXISTS (SELECT 1 FROM ' || v_schema || '.' || v_new_table || ' WHERE ' || 
    SUBSTR(v_cols, 1, INSTR(v_cols, ',') - 1) || ' = ' || v_old_table || '.' || 
    SUBSTR(v_cols, 1, INSTR(v_cols, ',') - 1) || ')';
```

**Problems:**
1. Assumes first column is the join key (fragile)
2. SUBSTR logic will fail if there's no comma (single column table)
3. No consideration for data type compatibility between tables
4. String manipulation of `v_cols` is error-prone
5. Performance concerns with NOT EXISTS on every row

#### Issue 2c: Missing Primary Key Detection
The view attempts to deduplicate using the first column, but doesn't verify:
- Is it a primary key?
- Is it unique?
- Is it NOT NULL?
- Can it be used for comparison?

**Recommendation - Complete Redesign:**

```sql
-- STEP 1: Detect primary key columns
DECLARE
    v_pk_cols VARCHAR2(4000);
    v_col_count NUMBER;
BEGIN
    -- Get primary key columns
    SELECT LISTAGG(cc.column_name, ', ') WITHIN GROUP (ORDER BY cc.position)
    INTO v_pk_cols
    FROM all_constraints c
    JOIN all_cons_columns cc ON c.constraint_name = cc.constraint_name 
        AND c.owner = cc.owner
    WHERE c.owner = v_schema 
        AND c.table_name = v_new_table
        AND c.constraint_type = 'P';
    
    IF v_pk_cols IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 
            'Cannot create INSTEAD OF trigger view: Table ' || 
            v_new_table || ' has no primary key');
    END IF;
    
    -- Build proper join condition
    v_join_condition := build_join_condition(v_pk_cols);
    
    -- Create view with proper join
    EXECUTE IMMEDIATE 
        'CREATE OR REPLACE VIEW ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema) || 
        '.' || DBMS_ASSERT.ENQUOTE_NAME(v_view_name) || ' AS ' ||
        'SELECT n.* FROM ' || v_new_table || ' n ' ||
        'UNION ALL ' ||
        'SELECT o.* FROM ' || v_old_table || ' o ' ||
        'WHERE NOT EXISTS ( ' ||
        '  SELECT 1 FROM ' || v_new_table || ' n2 ' ||
        '  WHERE ' || v_join_condition ||
        ')';
END;
```

#### Issue 2d: Trigger Doesn't Handle UPDATE or DELETE
```sql
-- Line 546 - Only handles INSERT
INSTEAD OF INSERT ON ' || v_schema || '.' || v_view_name
```

**Question:** What happens if users try to UPDATE or DELETE through the view?
- **Current behavior:** Runtime error (not allowed)
- **Expected behavior:** Should either handle gracefully or document restriction

**Recommendation:**
```sql
-- Option 1: Support all DML
CREATE OR REPLACE TRIGGER tg_view_iot
    INSTEAD OF INSERT OR UPDATE OR DELETE ON view_name
    FOR EACH ROW
BEGIN
    IF INSERTING THEN
        -- Insert logic
    ELSIF UPDATING THEN
        -- Update logic (update in NEW table if exists, else update OLD table)
    ELSIF DELETING THEN
        -- Delete logic (delete from both tables)
    END IF;
END;

-- Option 2: Raise clear errors for unsupported operations
CREATE OR REPLACE TRIGGER tg_view_iot
    INSTEAD OF UPDATE OR DELETE ON view_name
    FOR EACH ROW
BEGIN
    RAISE_APPLICATION_ERROR(-20001, 
        'UPDATE and DELETE not supported on migration view. Use direct table access.');
END;
```

---

### 🟡 CRITICAL #3: Error Handling - Silent Failures

**Location:** Multiple locations throughout `plsql-util.sql`

**Issue:** Error handling blocks that suppress errors without proper logging.

**Examples:**
```sql
-- Lines 523, 540 - Silent exception handling
EXCEPTION WHEN OTHERS THEN NULL;
END;

-- Lines 787-795 - Catches errors but continues
EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%already exists%' OR SQLERRM LIKE '%does not exist%' THEN
        DBMS_OUTPUT.PUT_LINE('  - Skipped: ...');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  ✗ Error creating partition for ...');
    END IF;
END;
```

**Problems:**
1. `EXCEPTION WHEN OTHERS THEN NULL` completely hides errors
2. Users won't know why operations failed
3. Difficult to debug issues
4. Could mask serious problems

**Recommendation:**
```sql
-- BETTER: Log the error even if continuing
BEGIN
    EXECUTE IMMEDIATE 'DROP VIEW ' || v_schema || '.' || v_view_name;
    DBMS_OUTPUT.PUT_LINE('  ✓ Dropped existing view');
EXCEPTION 
    WHEN OTHERS THEN
        IF SQLCODE = -942 THEN  -- Table or view does not exist
            DBMS_OUTPUT.PUT_LINE('  ℹ View does not exist (OK)');
        ELSE
            DBMS_OUTPUT.PUT_LINE('  ⚠ Warning: ' || SQLERRM);
        END IF;
END;

-- BEST: Use specific exception handling
BEGIN
    EXECUTE IMMEDIATE 'DROP VIEW ' || v_schema || '.' || v_view_name;
    DBMS_OUTPUT.PUT_LINE('  ✓ Dropped existing view');
EXCEPTION 
    WHEN NO_DATA_FOUND THEN
        NULL;  -- Expected, continue
    WHEN OTHERS THEN
        IF SQLCODE = -942 THEN
            NULL;  -- View doesn't exist, that's OK
        ELSE
            RAISE;  -- Re-raise unexpected errors
        END IF;
END;
```

---

## High-Priority Issues

### 🟡 HIGH #1: Atomic Swap Implementation - Not Actually Atomic

**Location:** `50_swap_tables.sql.j2` lines 26-97

**Issue:** The comment claims "Atomic table swap" but Oracle DDL operations auto-commit, so the rename operations are NOT atomic in the traditional ACID sense.

**Current Code:**
```sql
-- Line 55: Misleading comment
DBMS_OUTPUT.PUT_LINE('NOTE: Oracle DDL auto-commits, but we make this atomic by ensuring both renames succeed or both fail');

-- Lines 59-67: First rename (auto-commits)
EXECUTE IMMEDIATE 'ALTER TABLE {{ owner }}.{{ table_name }} RENAME TO {{ old_table_name }}';

-- Lines 72-96: Second rename (auto-commits) with rollback attempt
EXECUTE IMMEDIATE 'ALTER TABLE {{ owner }}.{{ new_table_name }} RENAME TO {{ table_name }}';
EXCEPTION
    WHEN OTHERS THEN
        -- Try to rollback by reversing first rename
        EXECUTE IMMEDIATE 'ALTER TABLE {{ owner }}.{{ old_table_name }} RENAME TO {{ table_name }}';
```

**Problems:**
1. There's a time window between the two renames where the table name doesn't exist
2. If Step 2 fails, the compensating rollback could also fail (due to locks, permissions, etc.)
3. Not truly atomic - there's a race condition
4. If rollback fails, you're in an inconsistent state requiring manual intervention

**Reality Check:**
- Oracle DDL is NOT transactional
- Each ALTER TABLE RENAME is a separate transaction that commits immediately
- Between Step 1 and Step 2, queries to `table_name` will fail with "table or view does not exist"

**Recommendation:**

**Option A: Accept Non-Atomicity and Document It**
```sql
-- Be honest about limitations
DBMS_OUTPUT.PUT_LINE('NOTE: Oracle DDL auto-commits. There will be a brief window');
DBMS_OUTPUT.PUT_LINE('where ' || table_name || ' is unavailable. Applications should');
DBMS_OUTPUT.PUT_LINE('use connection retry logic or be prepared for brief downtime.');
```

**Option B: Use Application-Level Lock (Better)**
```sql
-- Acquire exclusive lock before swap to prevent concurrent access
BEGIN
    -- Lock both tables
    LOCK TABLE {{ owner }}.{{ table_name }} IN EXCLUSIVE MODE NOWAIT;
    LOCK TABLE {{ owner }}.{{ new_table_name }} IN EXCLUSIVE MODE NOWAIT;
    
    -- Now perform renames with minimal risk
    -- Applications will queue on lock, not see missing table
    EXECUTE IMMEDIATE 'ALTER TABLE {{ owner }}.{{ table_name }} RENAME TO {{ old_table_name }}';
    EXECUTE IMMEDIATE 'ALTER TABLE {{ owner }}.{{ new_table_name }} RENAME TO {{ table_name }}';
    
    -- Locks released implicitly after DDL
    DBMS_OUTPUT.PUT_LINE('✓ Swap complete');
EXCEPTION
    WHEN TIMEOUT_ON_RESOURCE OR RESOURCE_BUSY THEN
        RAISE_APPLICATION_ERROR(-20001, 'Cannot acquire lock - active sessions exist');
END;
```

**Option C: Use Edition-Based Redefinition (Best for Zero Downtime)**
```sql
-- Use Oracle's edition-based redefinition feature for truly atomic swap
-- This requires setup but provides genuine zero-downtime migration
```

---

### 🟡 HIGH #2: Missing Input Validation

**Location:** Throughout `plsql-util.sql`

**Issue:** Script substitution variables are used directly without validation.

**Examples:**
```sql
-- Lines 17-23: Direct substitution without validation
DEFINE category = '&1'
DEFINE operation = '&2'
DEFINE arg3 = '&3'
-- ... used later without any validation

-- Line 34: Direct use in CASE statement
CASE UPPER('&category')
```

**Problems:**
1. Empty strings could cause unexpected behavior
2. Special characters could break SQL
3. No type checking (e.g., expecting number but getting string)
4. SQL*Plus substitution variables are processed before PL/SQL, so no runtime validation

**Recommendation:**
```sql
-- Add validation block at the start
DECLARE
    v_category VARCHAR2(100) := UPPER(NVL('&category', 'INVALID'));
    v_operation VARCHAR2(100) := UPPER(NVL('&operation', 'INVALID'));
    v_arg3 VARCHAR2(100) := '&arg3';
BEGIN
    -- Validate category
    IF v_category NOT IN ('READONLY', 'WRITE', 'WORKFLOW', 'CLEANUP') THEN
        RAISE_APPLICATION_ERROR(-20001, 
            'Invalid category: ' || v_category || '. ' ||
            'Valid: READONLY, WRITE, WORKFLOW, CLEANUP');
    END IF;
    
    -- Validate operation exists
    IF v_operation IS NULL OR v_operation = '' THEN
        RAISE_APPLICATION_ERROR(-20002, 'Operation cannot be empty');
    END IF;
    
    -- Validate required arguments
    IF v_arg3 IS NULL OR v_arg3 = '' THEN
        RAISE_APPLICATION_ERROR(-20003, 'Schema name (arg3) is required');
    END IF;
    
    -- Continue with validated inputs
    ...
END;
```

---

### 🟡 HIGH #3: Lack of Transaction Control Documentation

**Location:** `20_data_load.sql.j2`, `40_delta_load.sql.j2`

**Issue:** Large data operations without clear commit strategy or recovery points.

**Example:**
```sql
-- 20_data_load.sql.j2 line 73: Enables parallel DML but no commit strategy documented
ALTER SESSION ENABLE PARALLEL DML;

-- No COMMIT statements visible in the excerpt
-- What happens if load fails mid-way?
```

**Problems:**
1. Large INSERT operations without intermediate commits could:
   - Fill up undo tablespace
   - Create long-running transactions that block other operations
   - Make recovery difficult if failure occurs
2. No documentation of rollback strategy
3. No restart capability from partial failures

**Recommendation:**
```sql
-- Document transaction strategy
PROMPT ================================================================
PROMPT TRANSACTION STRATEGY
PROMPT ================================================================
PROMPT This load will use:
PROMPT   - INSERT /*+ APPEND */ for direct path load (minimal undo)
PROMPT   - NOLOGGING mode for performance (requires backup after)
PROMPT   - Single transaction (all-or-nothing)
PROMPT
PROMPT In case of failure:
PROMPT   - Transaction will rollback automatically
PROMPT   - Target table will be truncated (empty)
PROMPT   - Re-run this script to retry
PROMPT ================================================================

-- For very large tables, consider batch processing
DECLARE
    v_batch_size CONSTANT NUMBER := 100000;
    v_total_rows NUMBER := 0;
BEGIN
    FOR batch IN (
        SELECT /*+ PARALLEL({{ target_configuration.parallel_degree }}) */
               ROWID as rid, 
               MOD(ROWNUM, v_batch_size) as batch_num
        FROM {{ owner }}.{{ table_name }}
    ) LOOP
        -- Process in batches with commits
        IF MOD(batch.batch_num, v_batch_size) = 0 THEN
            COMMIT; -- Commit every batch
            DBMS_OUTPUT.PUT_LINE('Processed: ' || v_total_rows || ' rows');
        END IF;
    END LOOP;
    
    COMMIT; -- Final commit
END;
```

---

## Medium-Priority Issues

### 🟢 MEDIUM #1: Hardcoded Magic Numbers

**Location:** Multiple files

**Examples:**
```sql
-- plsql-util.sql line 143: Hardcoded 10
FETCH FIRST 10 ROWS ONLY

-- plsql-util.sql line 669: Hardcoded 2
v_days_ahead NUMBER := TO_NUMBER(NVL('&arg5', '2'));

-- plsql-util.sql line 812: Hardcoded 8
v_subpart_count NUMBER := TO_NUMBER(NVL('&arg6', '8'));
```

**Recommendation:**
```sql
-- Define constants at package level or script beginning
DECLARE
    C_MAX_PARTITION_DISPLAY CONSTANT NUMBER := 10;
    C_DEFAULT_PRECREATE_DAYS CONSTANT NUMBER := 2;
    C_DEFAULT_HASH_SUBPARTS CONSTANT NUMBER := 8;
BEGIN
    -- Use constants
    FETCH FIRST C_MAX_PARTITION_DISPLAY ROWS ONLY;
    v_days_ahead := TO_NUMBER(NVL('&arg5', C_DEFAULT_PRECREATE_DAYS));
END;
```

---

### 🟢 MEDIUM #2: Inconsistent Error Codes

**Location:** `50_swap_tables.sql.j2`

**Issue:** Error codes are not systematically organized.

```sql
-- Line 42: -20001
RAISE_APPLICATION_ERROR(-20001, 'Original table not found');

-- Line 51: -20002  
RAISE_APPLICATION_ERROR(-20002, 'New table not found');

-- Line 66: -20003
RAISE_APPLICATION_ERROR(-20003, v_error_message);

-- Line 93: -20005
RAISE_APPLICATION_ERROR(-20005, 'Atomic swap failed...');
-- Skipped -20004!
```

**Recommendation:**
```sql
-- Define error code constants
DECLARE
    -- Error code range: -20000 to -20999
    ERR_TABLE_NOT_FOUND    CONSTANT NUMBER := -20001;
    ERR_PREREQUISITE_FAIL  CONSTANT NUMBER := -20002;
    ERR_RENAME_FAILED      CONSTANT NUMBER := -20003;
    ERR_ROLLBACK_FAILED    CONSTANT NUMBER := -20004;
    ERR_VALIDATION_FAILED  CONSTANT NUMBER := -20005;
BEGIN
    RAISE_APPLICATION_ERROR(ERR_TABLE_NOT_FOUND, 'Table not found: ' || v_table_name);
END;

-- Or create error code reference document
```

---

### 🟢 MEDIUM #3: Performance - Missing Hints

**Location:** Query optimizations throughout

**Example:**
```sql
-- plsql-util.sql lines 43-50: V$SESSION query without hints
SELECT COUNT(*) as cnt
FROM v$session s, v$sqlarea sa
WHERE s.sql_id = sa.sql_id
  AND UPPER(sa.sql_text) LIKE '%' || UPPER('&arg3') || '%'
  AND s.status = 'ACTIVE'
```

**Recommendation:**
```sql
-- Add optimizer hints for better performance
SELECT /*+ INDEX(s SYS_SESSION_PK) USE_HASH(sa) */ 
       COUNT(*) as cnt
FROM v$session s, v$sqlarea sa  
WHERE s.sql_id = sa.sql_id
  AND UPPER(sa.sql_text) LIKE '%' || UPPER('&arg3') || '%'
  AND s.status = 'ACTIVE';
```

---

## Positive Aspects (Well Done!)

### ✅ Excellent Code Organization

The categorical structure in `plsql-util.sql` is excellent:
```sql
CASE UPPER('&category')
    WHEN 'READONLY' THEN
        -- Safe read-only operations
    WHEN 'WRITE' THEN
        -- Data modifications
    WHEN 'WORKFLOW' THEN
        -- Multi-step operations
    WHEN 'CLEANUP' THEN
        -- Cleanup operations
END CASE;
```

**Benefits:**
- Clear separation of concerns
- Easy to understand what operations are safe
- Good security model (restrict WRITE/CLEANUP in production)
- Scalable architecture

---

### ✅ Good Use of DBMS_OUTPUT

Comprehensive progress reporting throughout:
```sql
DBMS_OUTPUT.PUT_LINE('✓ Statistics gathered successfully');
DBMS_OUTPUT.PUT_LINE('  Duration: ' || TO_CHAR(EXTRACT(SECOND FROM v_duration), '999.99') || ' seconds');
```

**Benefits:**
- Users can track progress
- Easy debugging
- Professional appearance with Unicode symbols (✓, ✗, ⚠)

---

### ✅ Pre and Post Validation Checks

Good validation patterns:
```sql
-- Pre-swap validation
SELECT COUNT(*) INTO v_original_exists
FROM all_tables 
WHERE owner = '{{ owner }}' AND table_name = '{{ table_name }}';

IF v_original_exists = 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Original table not found');
END IF;
```

**Benefits:**
- Fail fast with clear errors
- Prevents partial operations
- Easier troubleshooting

---

### ✅ Comprehensive Statistics Gathering

Good use of DBMS_STATS:
```sql
DBMS_STATS.GATHER_TABLE_STATS(
    ownname => UPPER('&arg3'),
    tabname => UPPER('&arg4'),
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    method_opt => 'FOR ALL COLUMNS SIZE AUTO',
    degree => v_parallel,
    cascade => TRUE
);
```

**Benefits:**
- Uses modern AUTO settings
- Respects parallelism
- Cascades to indexes

---

## Detailed Recommendations

### 1. Security Hardening (Priority: CRITICAL)

**Action Items:**
1. [ ] Add DBMS_ASSERT validation to all dynamic SQL
2. [ ] Create whitelist validation for schema/table names
3. [ ] Implement prepared statements where possible
4. [ ] Add SQL injection tests to test suite
5. [ ] Review all EXECUTE IMMEDIATE statements

**Code Example:**
```sql
CREATE OR REPLACE FUNCTION validate_identifier(p_name VARCHAR2) 
    RETURN VARCHAR2 IS
BEGIN
    RETURN DBMS_ASSERT.SIMPLE_SQL_NAME(p_name);
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 
            'Invalid identifier: ' || p_name || '. ' ||
            'Only alphanumeric and underscore allowed.');
END;
```

---

### 2. INSTEAD OF Trigger Redesign (Priority: CRITICAL)

**Action Items:**
1. [ ] Redesign to detect primary key columns
2. [ ] Fix :NEW.* syntax error
3. [ ] Add support for UPDATE and DELETE or document restrictions
4. [ ] Add data type compatibility checks
5. [ ] Improve error messages for edge cases
6. [ ] Add performance tuning (indexes on join columns)

**Proposed New Design:**
```sql
CREATE OR REPLACE PROCEDURE create_migration_view(
    p_schema IN VARCHAR2,
    p_table IN VARCHAR2
) IS
    v_pk_cols VARCHAR2(4000);
    v_all_cols VARCHAR2(4000);
    v_insert_cols VARCHAR2(4000);
    v_new_vals VARCHAR2(4000);
    v_join_condition VARCHAR2(4000);
BEGIN
    -- Validate inputs
    v_schema := DBMS_ASSERT.SIMPLE_SQL_NAME(p_schema);
    v_table := DBMS_ASSERT.SIMPLE_SQL_NAME(p_table);
    
    -- Get PK columns
    SELECT LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY position)
    INTO v_pk_cols
    FROM all_cons_columns
    WHERE owner = v_schema 
        AND constraint_name = (
            SELECT constraint_name 
            FROM all_constraints
            WHERE owner = v_schema 
                AND table_name = v_table || '_NEW'
                AND constraint_type = 'P'
        );
    
    IF v_pk_cols IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 
            'Table must have a primary key for migration view');
    END IF;
    
    -- Build column lists
    SELECT 
        LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY column_id),
        LISTAGG(':NEW.' || column_name, ', ') WITHIN GROUP (ORDER BY column_id)
    INTO v_insert_cols, v_new_vals
    FROM all_tab_columns
    WHERE owner = v_schema 
        AND table_name = v_table || '_NEW';
    
    -- Build join condition for deduplication
    v_join_condition := build_pk_join_condition(v_pk_cols);
    
    -- Create view
    EXECUTE IMMEDIATE 
        'CREATE OR REPLACE VIEW ' || v_schema || '.' || v_table || '_JOINED AS ' ||
        'SELECT ' || v_insert_cols || ' FROM ' || v_table || '_NEW ' ||
        'UNION ALL ' ||
        'SELECT ' || v_insert_cols || ' FROM ' || v_table || '_OLD o ' ||
        'WHERE NOT EXISTS ( ' ||
        '    SELECT 1 FROM ' || v_table || '_NEW n ' ||
        '    WHERE ' || v_join_condition ||
        ')';
    
    -- Create trigger with proper syntax
    EXECUTE IMMEDIATE 
        'CREATE OR REPLACE TRIGGER tg_' || v_table || '_migration_iot ' ||
        'INSTEAD OF INSERT ON ' || v_schema || '.' || v_table || '_JOINED ' ||
        'FOR EACH ROW ' ||
        'BEGIN ' ||
        '    INSERT INTO ' || v_schema || '.' || v_table || '_NEW ' ||
        '    (' || v_insert_cols || ') ' ||
        '    VALUES (' || v_new_vals || '); ' ||
        'END;';
        
    DBMS_OUTPUT.PUT_LINE('✓ Migration view and trigger created successfully');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Failed to create migration view: ' || SQLERRM);
        RAISE;
END;
```

---

### 3. Error Handling Standards (Priority: HIGH)

**Action Items:**
1. [ ] Create error handling guidelines document
2. [ ] Replace all `EXCEPTION WHEN OTHERS THEN NULL`
3. [ ] Add logging infrastructure
4. [ ] Implement error code registry
5. [ ] Add retry logic for transient failures

**Error Handling Template:**
```sql
-- Standard error handling pattern
BEGIN
    -- Operation
    ...
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Handle expected case
        DBMS_OUTPUT.PUT_LINE('ℹ No data found (expected)');
    WHEN DUP_VAL_ON_INDEX THEN
        -- Handle duplicate
        DBMS_OUTPUT.PUT_LINE('⚠ Duplicate value, skipping');
    WHEN OTHERS THEN
        -- Log unexpected error
        log_error(
            p_procedure => 'create_renamed_view',
            p_error_code => SQLCODE,
            p_error_msg => SQLERRM,
            p_context => 'Creating view: ' || v_view_name
        );
        -- Re-raise for caller to handle
        RAISE;
END;
```

---

### 4. Testing Strategy (Priority: HIGH)

**Recommended Tests:**

1. **Unit Tests:**
```sql
-- Test SQL injection protection
BEGIN
    -- Should fail with proper error
    validate_identifier('EVIL_USER; DROP TABLE;--');
    -- Should never reach here
    RAISE_APPLICATION_ERROR(-20001, 'SQL injection protection failed!');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%Invalid identifier%' THEN
            DBMS_OUTPUT.PUT_LINE('✓ SQL injection test PASSED');
        ELSE
            RAISE;
        END IF;
END;
```

2. **Integration Tests:**
```sql
-- Test INSTEAD OF trigger
BEGIN
    -- Create test tables
    create_test_tables();
    
    -- Create migration view
    create_migration_view('TEST_SCHEMA', 'TEST_TABLE');
    
    -- Test INSERT through view
    INSERT INTO test_schema.test_table_joined VALUES (...);
    
    -- Verify data in NEW table
    verify_data_in_new_table();
    
    -- Cleanup
    drop_test_tables();
    
    DBMS_OUTPUT.PUT_LINE('✓ INSTEAD OF trigger test PASSED');
END;
```

3. **Performance Tests:**
```sql
-- Test parallel load performance
-- Test partition pruning
-- Test index usage
```

---

### 5. Documentation Improvements (Priority: MEDIUM)

**Action Items:**
1. [ ] Add header comments to all major procedures
2. [ ] Document all parameters and return values
3. [ ] Create runbook for common scenarios
4. [ ] Add troubleshooting guide
5. [ ] Document error codes

**Documentation Template:**
```sql
-- ==================================================================
-- PROCEDURE: create_renamed_view
-- ==================================================================
-- PURPOSE:
--   Creates a view that combines data from OLD and NEW tables during
--   migration, with an INSTEAD OF trigger to redirect inserts to NEW table
--
-- PARAMETERS:
--   p_schema    - Schema name (validated with DBMS_ASSERT)
--   p_table     - Base table name without _NEW/_OLD suffix
--
-- REQUIREMENTS:
--   - Both {table}_NEW and {table}_OLD must exist
--   - {table}_NEW must have a primary key
--   - User must have CREATE VIEW and CREATE TRIGGER privileges
--
-- CREATES:
--   - View: {schema}.{table}_JOINED
--   - Trigger: {schema}.TG_{table}_MIGRATION_IOT
--
-- EXAMPLE:
--   BEGIN
--       create_renamed_view('MY_SCHEMA', 'ORDERS');
--   END;
--
-- ERROR CODES:
--   -20001: Table missing or no primary key
--   -20002: Permission denied
--   -20003: View creation failed
--
-- AUTHOR: [Name]
-- DATE: [Date]
-- VERSION: 1.0
-- ==================================================================
```

---

## Summary of Action Items

### Immediate (Next Sprint):
1. 🔴 Fix SQL injection vulnerabilities (CRITICAL)
2. 🔴 Redesign INSTEAD OF trigger implementation (CRITICAL)
3. 🔴 Review and fix all silent error handling (CRITICAL)
4. 🟡 Add input validation for all parameters (HIGH)
5. 🟡 Document transaction control strategy (HIGH)

### Short-term (Next Month):
6. 🟡 Implement proper error code registry (HIGH)
7. 🟡 Add comprehensive unit tests (HIGH)
8. 🟢 Refactor hardcoded constants (MEDIUM)
9. 🟢 Add optimizer hints where needed (MEDIUM)
10. 🟢 Improve documentation (MEDIUM)

### Long-term (Next Quarter):
11. Consider packaging utilities into a proper PL/SQL package
12. Implement centralized logging framework
13. Add monitoring and alerting integration
14. Performance tuning and optimization
15. Create migration playbook and runbook

---

## Conclusion

This codebase shows solid engineering practices and thoughtful design, particularly in the organization and validation patterns. However, **critical security vulnerabilities** around SQL injection and the **broken INSTEAD OF trigger implementation** require immediate attention before this can be used in production.

**Recommendation:** 
- **DO NOT deploy** the INSTEAD OF trigger functionality until redesigned
- **IMMEDIATELY address** SQL injection vulnerabilities
- **IMPLEMENT** comprehensive testing before production use
- **DOCUMENT** all limitations clearly (especially the "atomic" swap)

With these fixes, this will be a robust, production-ready migration utility.

---

**Questions for Team Discussion:**
1. What is the expected use case for the INSTEAD OF trigger view? (This will help guide the redesign)
2. Are there existing security review processes we should integrate with?
3. What is the acceptable downtime window for table swaps?
4. Do we need to support Edition-Based Redefinition for zero-downtime?
5. What logging/monitoring infrastructure exists that we should integrate with?

---

*Review completed by Principal Engineer*  
*For questions or clarifications, please reach out to the architecture team*
