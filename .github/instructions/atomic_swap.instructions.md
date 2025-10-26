````instructions
# Atomic Table Swap Instructions

## Critical Understanding: No Built-in "Atomic Swap"

There is **no such thing as built-in atomic table swap** in Oracle. The atomicity comes from the transaction model:

### How Atomic Rename Operations Work
```sql
-- This sequence is atomic - all succeed or all fail
BEGIN
    -- Step 1: Rename current table to backup
    EXECUTE IMMEDIATE 'ALTER TABLE ' || table_name || ' RENAME TO ' || table_name || '_OLD';
    
    -- Step 2: Rename new table to current name  
    EXECUTE IMMEDIATE 'ALTER TABLE ' || table_name || '_NEW RENAME TO ' || table_name;
    
    -- If both succeed, commit
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        -- If either fails, rollback everything
        ROLLBACK;
        RAISE;
END;
```

### The Atomicity Guarantee
- **All renames work**: Transaction succeeds, applications see new table immediately
- **Any rename fails**: Transaction rolls back, applications continue with original table
- **No partial state**: Never have missing tables or naming conflicts

## Implementation in Templates

### Step 50: Atomic Table Swap (`50_swap_tables.sql.j2`)
```sql
-- ==================================================================
-- STEP 50: ATOMIC TABLE RENAME OPERATIONS
-- ==================================================================
-- This makes the migration atomic - all renames work or all fail
-- Applications experience zero downtime during the switch

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT Performing atomic table rename operations...

BEGIN
    -- Atomic rename sequence
    DBMS_OUTPUT.PUT_LINE('Renaming {{ owner }}.{{ table_name }} to {{ owner }}.{{ table_name }}_OLD');
    EXECUTE IMMEDIATE 'ALTER TABLE {{ owner }}.{{ table_name }} RENAME TO {{ table_name }}_OLD';
    
    DBMS_OUTPUT.PUT_LINE('Renaming {{ owner }}.{{ new_table_name }} to {{ owner }}.{{ table_name }}');
    EXECUTE IMMEDIATE 'ALTER TABLE {{ owner }}.{{ new_table_name }} RENAME TO {{ table_name }}';
    
    DBMS_OUTPUT.PUT_LINE('Atomic rename operations completed successfully ✓');
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Atomic rename failed - rolling back ✗');
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/

-- Validate the swap was successful
SELECT 'Current active table: ' || table_name as validation
FROM user_tables 
WHERE table_name IN ('{{ table_name }}', '{{ table_name }}_OLD')
AND table_name NOT LIKE '%_OLD%'
ORDER BY created DESC
FETCH FIRST 1 ROW ONLY;
```

## Post-Swap Validation Requirements

### Check for Invalidations
After rename operations, check for:
- **Invalid objects**: Views, procedures, functions referencing old table name
- **Broken foreign keys**: References that might be disrupted
- **Lost grants**: Privileges that need restoration

### Validation Queries
```sql
-- Check for invalid objects
SELECT object_name, object_type, status
FROM user_objects 
WHERE status = 'INVALID'
AND last_ddl_time >= SYSDATE - 1/24; -- Last hour

-- Check foreign key constraints
SELECT constraint_name, status, validated
FROM user_constraints
WHERE constraint_type = 'R'
AND table_name = '{{ table_name }}';

-- Check grants on new table
SELECT grantee, privilege, grantable
FROM user_tab_privs
WHERE table_name = '{{ table_name }}';
```

## Error Handling Strategy

### Before Rename Operations
1. **Validate prerequisites**: Both tables exist, no active transactions
2. **Check dependencies**: No DDL locks on either table
3. **Backup metadata**: Save current grants, constraints, dependencies

### During Rename Operations  
1. **Single transaction**: All renames in one BEGIN/END block
2. **Immediate rollback**: On any error, restore original state
3. **Clear error messages**: Report exactly what failed and why

### After Rename Operations
1. **Validate success**: Confirm tables renamed correctly
2. **Check invalidations**: Identify and recompile invalid objects
3. **Restore grants**: Apply captured grants to new table name
4. **Test connectivity**: Verify applications can access renamed table

## Integration with master1.sql

The atomic swap is **Step 50** in the master1.sql workflow:
- **Step 10**: Create `table_new` with different partitioning
- **Step 20**: Migrate data (optional)
- **Step 30-35**: Create indexes
- **Step 40**: Delta loads (optional)
- **Step 50**: **ATOMIC RENAME OPERATIONS** ← Critical step
- **Step 60**: Restore grants
- **Step 70**: Generate drop script (separate from master1.sql)
- **Step 80**: Final validation

## Critical Success Criteria

- ✅ All rename operations succeed or all fail (true atomicity)
- ✅ Applications experience minimal/zero downtime  
- ✅ No intermediate states with missing or conflicting table names
- ✅ Proper error handling with clear rollback procedures
- ✅ Post-swap validation confirms successful migration
- ✅ Invalid objects identified and addressed
- ✅ Grants preserved across rename operations
````