# Table Migration Writable View Framework - Complete Guide

## Overview
This framework creates writable views for table migration scenarios where you have:
- `table_old` - Original table with existing data
- `table_new` - New table structure with migrated data
- `table` - Writable view that reads from both but writes only to `table_new`

## Migration Scenario
```
Original: TABLE_NAME
After Migration: TABLE_NAME_OLD + TABLE_NAME_NEW
Writable View: TABLE_NAME (reads from both, writes to NEW only)
```

## Key Features

### 1. **Dual Table Support**
- Reads from both `table_old` and `table_new` using UNION ALL
- Writes only to `table_new` table
- Maintains data consistency during migration

### 2. **Smart Write Operations**
- **INSERT**: Only inserts into `table_new`
- **UPDATE**: Updates `table_new` if record exists, moves from `table_old` if needed
- **DELETE**: Deletes from `table_new` only, preserves `table_old` data

### 3. **Referential Integrity**
- Enforces foreign key constraints
- Validates referential integrity before operations
- Handles cascade operations properly

### 4. **Transaction Management**
- Uses savepoints for complex operations
- Proper rollback on errors
- Maintains data consistency

## Usage Examples

### 1. Single Table Migration
```sql
-- Create migration writable view for EMPLOYEES table
BEGIN
    DBMS_OUTPUT.PUT_LINE(create_migration_writable_view(
        'EMPLOYEES',     -- Base table name
        'HR',           -- Schema owner
        '_OLD',         -- Old table suffix
        '_NEW',         -- New table suffix
        TRUE            -- Enforce referential integrity
    ));
END;
/
```

### 2. Batch Migration
```sql
-- Create migration writable views for all tables
BEGIN
    create_all_migration_writable_views(
        'HR',           -- Schema name
        '_OLD',         -- Old table suffix
        '_NEW',         -- New table suffix
        TRUE            -- Enforce referential integrity
    );
END;
/
```

### 3. Check Migration Status
```sql
-- Check status of all migration tables
BEGIN
    check_migration_status('HR', '_OLD', '_NEW');
END;
/
```

## How It Works

### 1. **View Creation**
The framework creates a view that unions data from both tables:
```sql
CREATE OR REPLACE VIEW EMPLOYEES AS
SELECT employee_id, first_name, last_name, department_id
FROM EMPLOYEES_OLD
UNION ALL
SELECT employee_id, first_name, last_name, department_id
FROM EMPLOYEES_NEW;
```

### 2. **Writable Trigger Logic**

#### INSERT Operation
```sql
IF INSERTING THEN
    -- Insert only into NEW table
    INSERT INTO EMPLOYEES_NEW (employee_id, first_name, last_name, department_id)
    VALUES (:NEW.employee_id, :NEW.first_name, :NEW.last_name, :NEW.department_id);
END IF;
```

#### UPDATE Operation
```sql
IF UPDATING THEN
    -- Check if record exists in NEW table
    SELECT COUNT(*) INTO v_record_exists_new 
    FROM EMPLOYEES_NEW
    WHERE employee_id = :OLD.employee_id;
    
    IF v_record_exists_new > 0 THEN
        -- Update record in NEW table
        UPDATE EMPLOYEES_NEW
        SET first_name = :NEW.first_name,
            last_name = :NEW.last_name,
            department_id = :NEW.department_id
        WHERE employee_id = :OLD.employee_id;
    ELSIF v_record_exists_old > 0 THEN
        -- Move record from OLD to NEW table
        INSERT INTO EMPLOYEES_NEW (employee_id, first_name, last_name, department_id)
        VALUES (:NEW.employee_id, :NEW.first_name, :NEW.last_name, :NEW.department_id);
    END IF;
END IF;
```

#### DELETE Operation
```sql
IF DELETING THEN
    -- Check if record exists in NEW table
    SELECT COUNT(*) INTO v_record_exists_new 
    FROM EMPLOYEES_NEW
    WHERE employee_id = :OLD.employee_id;
    
    IF v_record_exists_new > 0 THEN
        -- Delete from NEW table only
        DELETE FROM EMPLOYEES_NEW
        WHERE employee_id = :OLD.employee_id;
    ELSE
        -- Cannot delete from OLD table during migration
        RAISE_APPLICATION_ERROR(-20004, 'Cannot delete from OLD table during migration');
    END IF;
END IF;
```

## Advanced Scenarios

### 1. **Complex Migration with Referential Integrity**

#### Multi-Table Migration
```sql
-- Migrate related tables
BEGIN
    -- Create migration views for related tables
    DBMS_OUTPUT.PUT_LINE(create_migration_writable_view('DEPARTMENTS', 'HR', '_OLD', '_NEW', TRUE));
    DBMS_OUTPUT.PUT_LINE(create_migration_writable_view('EMPLOYEES', 'HR', '_OLD', '_NEW', TRUE));
    DBMS_OUTPUT.PUT_LINE(create_migration_writable_view('JOB_HISTORY', 'HR', '_OLD', '_NEW', TRUE));
END;
/
```

#### Referential Integrity Enforcement
```sql
-- The framework automatically enforces referential integrity
-- For example, when updating EMPLOYEES.department_id:
-- 1. Checks if new department exists in DEPARTMENTS_NEW
-- 2. Validates foreign key constraint
-- 3. Prevents orphaned records
```

### 2. **Data Consistency During Migration**

#### Transaction Management
```sql
-- Each operation is wrapped in a transaction with savepoints
SAVEPOINT sp_employees_migration;

BEGIN
    -- Perform operation
    IF INSERTING THEN
        INSERT INTO EMPLOYEES_NEW VALUES (...);
    END IF;
    
    -- Commit if successful
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Rollback to savepoint
        ROLLBACK TO sp_employees_migration;
        RAISE;
END;
```

### 3. **Performance Optimization**

#### Index Management
```sql
-- Ensure proper indexes on NEW tables
CREATE INDEX idx_employees_new_id ON EMPLOYEES_NEW(employee_id);
CREATE INDEX idx_employees_new_dept ON EMPLOYEES_NEW(department_id);

-- Monitor performance
SELECT * FROM v$sql WHERE sql_text LIKE '%EMPLOYEES_NEW%';
```

## Best Practices

### 1. **Migration Planning**
- **Plan the migration sequence** - Start with parent tables, then child tables
- **Test thoroughly** - Use test environments before production
- **Monitor performance** - Watch for performance impacts during migration

### 2. **Data Consistency**
- **Validate data integrity** - Ensure OLD and NEW tables are consistent
- **Handle conflicts** - Plan for data conflicts between OLD and NEW tables
- **Maintain referential integrity** - Use the framework's built-in checks

### 3. **Performance Considerations**
- **Index optimization** - Ensure proper indexes on NEW tables
- **Batch operations** - Consider batch processing for large datasets
- **Monitoring** - Monitor trigger performance and execution time

### 4. **Error Handling**
- **Comprehensive logging** - Log all operations for debugging
- **Error recovery** - Plan for error recovery scenarios
- **Rollback procedures** - Have rollback procedures ready

## Troubleshooting

### Common Issues

#### 1. **Duplicate Key Violations**
```sql
-- Problem: Record exists in both OLD and NEW tables
-- Solution: The framework handles this by checking both tables
-- and updating the NEW table or moving from OLD to NEW
```

#### 2. **Referential Integrity Violations**
```sql
-- Problem: Foreign key constraint violations
-- Solution: The framework validates referential integrity before operations
-- and prevents orphaned records
```

#### 3. **Performance Issues**
```sql
-- Problem: Slow trigger execution
-- Solution: Optimize indexes, monitor execution plans, consider batch operations
```

### Debug Mode
```sql
-- Enable debug output
SET SERVEROUTPUT ON SIZE 1000000

-- Check migration status
BEGIN
    check_migration_status('HR', '_OLD', '_NEW');
END;
/

-- Monitor trigger execution
SELECT * FROM all_triggers WHERE trigger_name LIKE '%MIGRATION_WRITABLE%';
```

## Migration Workflow

### 1. **Pre-Migration Setup**
```sql
-- 1. Create NEW tables with new structure
CREATE TABLE EMPLOYEES_NEW AS SELECT * FROM EMPLOYEES WHERE 1=0;

-- 2. Migrate data to NEW tables
INSERT INTO EMPLOYEES_NEW SELECT * FROM EMPLOYEES;

-- 3. Rename original table to OLD
ALTER TABLE EMPLOYEES RENAME TO EMPLOYEES_OLD;
```

### 2. **Create Migration Views**
```sql
-- 4. Create migration writable views
BEGIN
    DBMS_OUTPUT.PUT_LINE(create_migration_writable_view('EMPLOYEES', 'HR', '_OLD', '_NEW', TRUE));
END;
/
```

### 3. **Application Testing**
```sql
-- 5. Test applications with migration views
-- Applications continue to work with original table name
-- All writes go to NEW table, reads come from both
```

### 4. **Migration Completion**
```sql
-- 6. When migration is complete, drop migration views
BEGIN
    cleanup_migration_views('HR', '_OLD', '_NEW');
END;
/

-- 7. Rename NEW table to original name
ALTER TABLE EMPLOYEES_NEW RENAME TO EMPLOYEES;

-- 8. Drop OLD table (after backup)
DROP TABLE EMPLOYEES_OLD;
```

## Monitoring and Maintenance

### 1. **Status Monitoring**
```sql
-- Check migration status regularly
BEGIN
    check_migration_status('HR', '_OLD', '_NEW');
END;
/
```

### 2. **Performance Monitoring**
```sql
-- Monitor trigger performance
SELECT trigger_name, status, trigger_type
FROM all_triggers
WHERE trigger_name LIKE '%MIGRATION_WRITABLE%';

-- Monitor view usage
SELECT * FROM v$sql WHERE sql_text LIKE '%EMPLOYEES%';
```

### 3. **Data Consistency Checks**
```sql
-- Verify data consistency between OLD and NEW tables
SELECT COUNT(*) FROM EMPLOYEES_OLD;
SELECT COUNT(*) FROM EMPLOYEES_NEW;
SELECT COUNT(*) FROM EMPLOYEES; -- Should equal OLD + NEW
```

## Support and Maintenance

### 1. **Regular Maintenance**
- Monitor migration status
- Check data consistency
- Optimize performance
- Update documentation

### 2. **Error Recovery**
- Have rollback procedures ready
- Maintain backups of OLD tables
- Document recovery procedures
- Test recovery scenarios

### 3. **Documentation**
- Document migration procedures
- Maintain change logs
- Update user guides
- Record lessons learned
