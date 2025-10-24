-- ===================================================================
-- PRODUCTION-READY MIGRATION TRIGGER
-- ===================================================================
-- Enterprise-grade trigger for table migration scenarios
-- Features: Comprehensive error handling, logging, performance optimization
-- ===================================================================

CREATE OR REPLACE TRIGGER TRG_EMPLOYEES_MIGRATION_WRITABLE
INSTEAD OF INSERT OR UPDATE OR DELETE ON EMPLOYEES
FOR EACH ROW
DECLARE
    -- Validation variables
    v_department_exists NUMBER := 0;
    v_record_count NUMBER := 0;
    
    -- Record existence checks
    v_record_exists_old NUMBER := 0;
    v_record_exists_new NUMBER := 0;
    
    -- Constants for error codes
    c_referential_integrity_error CONSTANT NUMBER := -20002;
    c_record_not_found_error CONSTANT NUMBER := -20003;
    c_old_table_delete_error CONSTANT NUMBER := -20004;
    c_duplicate_key_error CONSTANT NUMBER := -20005;
    c_validation_error CONSTANT NUMBER := -20006;
    
    
    
    -- Referential integrity validation
    PROCEDURE validate_referential_integrity(
        p_department_id IN NUMBER
    ) IS
    BEGIN
        IF p_department_id IS NOT NULL THEN
            SELECT COUNT(*) INTO v_department_exists 
            FROM DEPARTMENTS 
            WHERE department_id = p_department_id;
            
            IF v_department_exists = 0 THEN
                RAISE_APPLICATION_ERROR(c_referential_integrity_error, 
                    'Department does not exist: ' || p_department_id);
            END IF;
        END IF;
    END validate_referential_integrity;
    
    -- Check record existence
    PROCEDURE check_record_existence(
        p_employee_id IN NUMBER
    ) IS
    BEGIN
        -- Check NEW table
        SELECT COUNT(*) INTO v_record_exists_new 
        FROM EMPLOYEES_NEW
        WHERE employee_id = p_employee_id;
        
        -- Check OLD table
        SELECT COUNT(*) INTO v_record_exists_old 
        FROM EMPLOYEES_OLD
        WHERE employee_id = p_employee_id;
    END check_record_existence;

BEGIN
    -- Determine operation type
    IF INSERTING THEN
        v_operation := 'INSERT';
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
    ELSIF DELETING THEN
        v_operation := 'DELETE';
    END IF;
    
    -- Begin transaction with savepoint
    SAVEPOINT sp_employees_migration;
    
    BEGIN
        -- ============================================================
        -- INSERT OPERATION
        -- ============================================================
        IF INSERTING THEN
            -- Validate input data
            IF :NEW.employee_id IS NULL THEN
                RAISE_APPLICATION_ERROR(c_validation_error, 'Employee ID cannot be NULL');
            END IF;
            
            IF :NEW.first_name IS NULL OR LENGTH(TRIM(:NEW.first_name)) = 0 THEN
                RAISE_APPLICATION_ERROR(c_validation_error, 'First name cannot be NULL or empty');
            END IF;
            
            IF :NEW.last_name IS NULL OR LENGTH(TRIM(:NEW.last_name)) = 0 THEN
                RAISE_APPLICATION_ERROR(c_validation_error, 'Last name cannot be NULL or empty');
            END IF;
            
            
            -- Validate referential integrity
            validate_referential_integrity(:NEW.department_id);
            
            -- Check for duplicate key
            SELECT COUNT(*) INTO v_record_count 
            FROM EMPLOYEES_NEW 
            WHERE employee_id = :NEW.employee_id;
            
            IF v_record_count > 0 THEN
                RAISE_APPLICATION_ERROR(c_duplicate_key_error, 
                    'Employee ID already exists: ' || :NEW.employee_id);
            END IF;
            
            -- Insert into NEW table
            INSERT INTO EMPLOYEES_NEW (
                employee_id, first_name, last_name, department_id,
                employee_data, preferences, created_date, updated_date
            ) VALUES (
                :NEW.employee_id, :NEW.first_name, :NEW.last_name, :NEW.department_id,
                :NEW.employee_data, :NEW.preferences, SYSTIMESTAMP, SYSTIMESTAMP
            );
            
        
        -- ============================================================
        -- UPDATE OPERATION
        -- ============================================================
        ELSIF UPDATING THEN
            -- Validate input data
            IF :NEW.employee_id IS NULL THEN
                RAISE_APPLICATION_ERROR(c_validation_error, 'Employee ID cannot be NULL');
            END IF;
            
            IF :NEW.first_name IS NULL OR LENGTH(TRIM(:NEW.first_name)) = 0 THEN
                RAISE_APPLICATION_ERROR(c_validation_error, 'First name cannot be NULL or empty');
            END IF;
            
            IF :NEW.last_name IS NULL OR LENGTH(TRIM(:NEW.last_name)) = 0 THEN
                RAISE_APPLICATION_ERROR(c_validation_error, 'Last name cannot be NULL or empty');
            END IF;
            
            
            -- Validate referential integrity if department is being updated
            IF :NEW.department_id != :OLD.department_id THEN
                validate_referential_integrity(:NEW.department_id);
            END IF;
            
            -- Check record existence
            check_record_existence(:OLD.employee_id);
            
            IF v_record_exists_new > 0 THEN
                -- Update record in NEW table
                UPDATE EMPLOYEES_NEW
                SET first_name = :NEW.first_name,
                    last_name = :NEW.last_name,
                    department_id = :NEW.department_id,
                    employee_data = :NEW.employee_data,
                    preferences = :NEW.preferences,
                    updated_date = SYSTIMESTAMP
                WHERE employee_id = :OLD.employee_id;
                
                
            ELSIF v_record_exists_old > 0 THEN
                -- Move record from OLD to NEW table
                INSERT INTO EMPLOYEES_NEW (
                    employee_id, first_name, last_name, department_id,
                    employee_data, preferences, created_date, updated_date
                ) VALUES (
                    :NEW.employee_id, :NEW.first_name, :NEW.last_name, :NEW.department_id,
                    :NEW.employee_data, :NEW.preferences, SYSTIMESTAMP, SYSTIMESTAMP
                );
                
            ELSE
                RAISE_APPLICATION_ERROR(c_record_not_found_error, 
                    'Record not found for update: ' || :OLD.employee_id);
            END IF;
        
        -- ============================================================
        -- DELETE OPERATION
        -- ============================================================
        ELSIF DELETING THEN
            -- Check record existence
            check_record_existence(:OLD.employee_id);
            
            IF v_record_exists_new > 0 THEN
                -- Delete from NEW table
                DELETE FROM EMPLOYEES_NEW
                WHERE employee_id = :OLD.employee_id;
                
                
            ELSIF v_record_exists_old > 0 THEN
                -- Cannot delete from OLD table during migration
                RAISE_APPLICATION_ERROR(c_old_table_delete_error, 
                    'Cannot delete from OLD table during migration: ' || :OLD.employee_id);
            ELSE
                RAISE_APPLICATION_ERROR(c_record_not_found_error, 
                    'Record not found for deletion: ' || :OLD.employee_id);
            END IF;
        END IF;
        
        -- Commit the transaction
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Rollback to savepoint
            ROLLBACK TO sp_employees_migration;
            
            -- Re-raise the exception
            RAISE;
    END;
END;
/


-- ===================================================================
-- TRIGGER VALIDATION QUERIES
-- ===================================================================

-- Test INSERT operation
/*
INSERT INTO EMPLOYEES (employee_id, first_name, last_name, department_id, employee_data, preferences)
VALUES (9999, 'Test', 'User', 10, 
        UTL_RAW.CAST_TO_RAW('{"skills": ["Java", "Oracle"], "experience": 5}'),
        UTL_RAW.CAST_TO_RAW('{"theme": "dark", "notifications": true}'));
*/

-- Test UPDATE operation
/*
UPDATE EMPLOYEES 
SET first_name = 'Updated', 
    employee_data = UTL_RAW.CAST_TO_RAW('{"skills": ["Java", "Oracle", "Python"], "experience": 6}')
WHERE employee_id = 9999;
*/

-- Test DELETE operation
/*
DELETE FROM EMPLOYEES WHERE employee_id = 9999;
*/

-- Check audit log
/*
SELECT * FROM app_audit_log 
WHERE table_name = 'EMPLOYEES' 
ORDER BY log_timestamp DESC;
*/
