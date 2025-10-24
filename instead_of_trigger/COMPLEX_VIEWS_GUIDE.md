# Complex Writable Views Framework - Advanced Guide

## Overview
This framework handles complex scenarios including multi-table joins, referential integrity enforcement, and transaction management for writable views.

## Key Features

### 1. Multi-Table Join Support
- Handles views with multiple base tables
- Manages complex relationships between tables
- Supports different join types (INNER, LEFT, RIGHT, FULL)

### 2. Referential Integrity Enforcement
- Automatic foreign key constraint checking
- Cascade delete/update handling
- Referential integrity violation prevention

### 3. Transaction Management
- Savepoint management
- Rollback capabilities
- Transaction isolation

### 4. Conflict Resolution
- Duplicate key handling
- Constraint violation resolution
- Data consistency maintenance

## Usage Examples

### 1. Simple Multi-Table View
```sql
-- View: EMPLOYEE_DEPT_VIEW (joins EMPLOYEES and DEPARTMENTS)
BEGIN
    DBMS_OUTPUT.PUT_LINE(make_complex_view_writable(
        'EMPLOYEE_DEPT_VIEW', 
        'HR', 
        'EMPLOYEES',  -- Primary table
        'DEPARTMENTS', -- Join table
        TRUE          -- Enforce referential integrity
    ));
END;
/
```

### 2. Complex Multi-Table View
```sql
-- View with multiple joins: EMPLOYEE_DEPT_LOCATION_VIEW
BEGIN
    DBMS_OUTPUT.PUT_LINE(make_multi_table_view_writable(
        'EMPLOYEE_DEPT_LOCATION_VIEW',
        'HR',
        '{"primary":"EMPLOYEES","joins":["DEPARTMENTS","LOCATIONS"]}',
        TRUE
    ));
END;
/
```

### 3. Referential Integrity Enforcement
```sql
-- Check referential integrity before operations
BEGIN
    enforce_referential_integrity(
        'EMPLOYEES', 
        'HR', 
        'INSERT', 
        '123'  -- Department ID to check
    );
END;
/
```

## Advanced Scenarios

### 1. Handling Referential Integrity Violations

#### Insert Operation with FK Check
```sql
CREATE OR REPLACE TRIGGER trg_employee_view_writable
INSTEAD OF INSERT ON EMPLOYEE_DEPT_VIEW
FOR EACH ROW
DECLARE
    v_dept_count NUMBER;
    v_location_count NUMBER;
BEGIN
    -- Check if department exists
    SELECT COUNT(*) INTO v_dept_count 
    FROM DEPARTMENTS 
    WHERE DEPARTMENT_ID = :NEW.DEPARTMENT_ID;
    
    IF v_dept_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Department does not exist');
    END IF;
    
    -- Check if location exists
    SELECT COUNT(*) INTO v_location_count 
    FROM LOCATIONS 
    WHERE LOCATION_ID = :NEW.LOCATION_ID;
    
    IF v_location_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Location does not exist');
    END IF;
    
    -- Insert into primary table
    INSERT INTO EMPLOYEES (EMPLOYEE_ID, FIRST_NAME, LAST_NAME, DEPARTMENT_ID, LOCATION_ID)
    VALUES (:NEW.EMPLOYEE_ID, :NEW.FIRST_NAME, :NEW.LAST_NAME, :NEW.DEPARTMENT_ID, :NEW.LOCATION_ID);
END;
/
```

#### Update Operation with FK Check
```sql
CREATE OR REPLACE TRIGGER trg_employee_view_update
INSTEAD OF UPDATE ON EMPLOYEE_DEPT_VIEW
FOR EACH ROW
DECLARE
    v_dept_count NUMBER;
BEGIN
    -- Check if new department exists
    IF :NEW.DEPARTMENT_ID != :OLD.DEPARTMENT_ID THEN
        SELECT COUNT(*) INTO v_dept_count 
        FROM DEPARTMENTS 
        WHERE DEPARTMENT_ID = :NEW.DEPARTMENT_ID;
        
        IF v_dept_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'New department does not exist');
        END IF;
    END IF;
    
    -- Update primary table
    UPDATE EMPLOYEES 
    SET FIRST_NAME = :NEW.FIRST_NAME,
        LAST_NAME = :NEW.LAST_NAME,
        DEPARTMENT_ID = :NEW.DEPARTMENT_ID
    WHERE EMPLOYEE_ID = :OLD.EMPLOYEE_ID;
END;
/
```

#### Delete Operation with Dependency Check
```sql
CREATE OR REPLACE TRIGGER trg_employee_view_delete
INSTEAD OF DELETE ON EMPLOYEE_DEPT_VIEW
FOR EACH ROW
DECLARE
    v_dependent_count NUMBER;
BEGIN
    -- Check for dependent records
    SELECT COUNT(*) INTO v_dependent_count 
    FROM EMPLOYEES 
    WHERE MANAGER_ID = :OLD.EMPLOYEE_ID;
    
    IF v_dependent_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Cannot delete: Employee has subordinates');
    END IF;
    
    -- Delete from primary table
    DELETE FROM EMPLOYEES WHERE EMPLOYEE_ID = :OLD.EMPLOYEE_ID;
END;
/
```

### 2. Transaction Management

#### Savepoint Management
```sql
CREATE OR REPLACE TRIGGER trg_complex_view_writable
INSTEAD OF INSERT OR UPDATE OR DELETE ON COMPLEX_VIEW
FOR EACH ROW
DECLARE
    v_success BOOLEAN := TRUE;
BEGIN
    -- Create savepoint
    SAVEPOINT sp_complex_view;
    
    BEGIN
        IF INSERTING THEN
            -- Insert logic with referential integrity checks
            INSERT INTO PRIMARY_TABLE VALUES (...);
            
        ELSIF UPDATING THEN
            -- Update logic with referential integrity checks
            UPDATE PRIMARY_TABLE SET ... WHERE ...;
            
        ELSIF DELETING THEN
            -- Delete logic with dependency checks
            DELETE FROM PRIMARY_TABLE WHERE ...;
        END IF;
        
        -- Commit if successful
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Rollback to savepoint
            ROLLBACK TO sp_complex_view;
            v_success := FALSE;
            RAISE;
    END;
END;
/
```

### 3. Conflict Resolution Strategies

#### Duplicate Key Resolution
```sql
CREATE OR REPLACE TRIGGER trg_duplicate_key_resolution
INSTEAD OF INSERT ON MY_VIEW
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    -- Check for duplicate key
    SELECT COUNT(*) INTO v_count 
    FROM PRIMARY_TABLE 
    WHERE PRIMARY_KEY = :NEW.PRIMARY_KEY;
    
    IF v_count > 0 THEN
        -- Update existing record instead of inserting
        UPDATE PRIMARY_TABLE 
        SET COLUMN1 = :NEW.COLUMN1,
            COLUMN2 = :NEW.COLUMN2
        WHERE PRIMARY_KEY = :NEW.PRIMARY_KEY;
    ELSE
        -- Insert new record
        INSERT INTO PRIMARY_TABLE VALUES (...);
    END IF;
END;
/
```

#### Constraint Violation Resolution
```sql
CREATE OR REPLACE TRIGGER trg_constraint_resolution
INSTEAD OF INSERT ON MY_VIEW
FOR EACH ROW
DECLARE
    v_constraint_violation EXCEPTION;
BEGIN
    BEGIN
        -- Try to insert
        INSERT INTO PRIMARY_TABLE VALUES (...);
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Check if it's a constraint violation
            IF SQLCODE = -2290 THEN -- Check constraint violation
                -- Apply default values
                INSERT INTO PRIMARY_TABLE VALUES (
                    :NEW.PRIMARY_KEY,
                    :NEW.COLUMN1,
                    'DEFAULT_VALUE',  -- Apply default
                    :NEW.COLUMN3
                );
            ELSE
                -- Re-raise other exceptions
                RAISE;
            END IF;
    END;
END;
/
```

## Best Practices

### 1. Design Considerations
- **Primary Table Selection**: Choose the most appropriate table as primary
- **Join Strategy**: Understand the join types and their implications
- **Constraint Handling**: Plan for constraint violations and resolution

### 2. Performance Optimization
- **Index Usage**: Ensure proper indexes on join columns
- **Query Optimization**: Optimize the view definition
- **Trigger Efficiency**: Keep trigger logic simple and efficient

### 3. Error Handling
- **Specific Error Messages**: Provide clear, actionable error messages
- **Logging**: Log all operations for debugging
- **Rollback Strategy**: Implement proper rollback mechanisms

### 4. Testing
- **Unit Testing**: Test each operation individually
- **Integration Testing**: Test complex scenarios
- **Performance Testing**: Monitor performance impact

## Common Patterns

### 1. Master-Detail Relationships
```sql
-- Handle master-detail views
CREATE OR REPLACE TRIGGER trg_master_detail_writable
INSTEAD OF INSERT ON MASTER_DETAIL_VIEW
FOR EACH ROW
BEGIN
    -- Insert master record first
    INSERT INTO MASTER_TABLE VALUES (...);
    
    -- Then insert detail records
    INSERT INTO DETAIL_TABLE VALUES (...);
END;
/
```

### 2. Hierarchical Data
```sql
-- Handle hierarchical views
CREATE OR REPLACE TRIGGER trg_hierarchical_writable
INSTEAD OF INSERT ON HIERARCHICAL_VIEW
FOR EACH ROW
DECLARE
    v_parent_exists NUMBER;
BEGIN
    -- Check if parent exists
    SELECT COUNT(*) INTO v_parent_exists 
    FROM HIERARCHICAL_TABLE 
    WHERE PARENT_ID = :NEW.PARENT_ID;
    
    IF v_parent_exists = 0 AND :NEW.PARENT_ID IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Parent record does not exist');
    END IF;
    
    -- Insert record
    INSERT INTO HIERARCHICAL_TABLE VALUES (...);
END;
/
```

### 3. Audit Trail
```sql
-- Add audit trail to writable views
CREATE OR REPLACE TRIGGER trg_audit_trail
INSTEAD OF INSERT OR UPDATE OR DELETE ON AUDITABLE_VIEW
FOR EACH ROW
BEGIN
    -- Log the operation
    INSERT INTO AUDIT_LOG (
        TABLE_NAME, 
        OPERATION, 
        USER_NAME, 
        TIMESTAMP, 
        OLD_VALUES, 
        NEW_VALUES
    ) VALUES (
        'AUDITABLE_VIEW',
        CASE 
            WHEN INSERTING THEN 'INSERT'
            WHEN UPDATING THEN 'UPDATE'
            WHEN DELETING THEN 'DELETE'
        END,
        USER,
        SYSTIMESTAMP,
        CASE WHEN DELETING OR UPDATING THEN :OLD.COLUMN_NAME END,
        CASE WHEN INSERTING OR UPDATING THEN :NEW.COLUMN_NAME END
    );
    
    -- Perform the actual operation
    IF INSERTING THEN
        INSERT INTO PRIMARY_TABLE VALUES (...);
    ELSIF UPDATING THEN
        UPDATE PRIMARY_TABLE SET ... WHERE ...;
    ELSIF DELETING THEN
        DELETE FROM PRIMARY_TABLE WHERE ...;
    END IF;
END;
/
```

## Troubleshooting

### Common Issues

1. **Referential Integrity Violations**
   - Check foreign key constraints
   - Verify referenced records exist
   - Handle cascade operations properly

2. **Transaction Deadlocks**
   - Implement proper locking strategy
   - Use savepoints for complex operations
   - Monitor transaction isolation levels

3. **Performance Issues**
   - Optimize view definitions
   - Add proper indexes
   - Monitor trigger execution time

4. **Constraint Violations**
   - Implement proper validation
   - Handle constraint violations gracefully
   - Apply appropriate resolution strategies

## Support and Maintenance

### Monitoring
- Monitor trigger execution
- Track performance metrics
- Log error conditions

### Maintenance
- Regular performance tuning
- Constraint validation
- Error log analysis

### Documentation
- Document complex view logic
- Maintain change logs
- Update user guides
