-- ===================================================================
-- EXAMPLE: View and Trigger for Table with 2 BLOB JSON Columns
-- ===================================================================
-- Scenario: EMPLOYEES table with employee_id, name, and 2 BLOB JSON columns
-- ===================================================================

-- ===================================================================
-- 1. EXAMPLE TABLE STRUCTURE
-- ===================================================================

-- Original table structure (before migration)
CREATE TABLE EMPLOYEES (
    employee_id NUMBER PRIMARY KEY,
    first_name VARCHAR2(50),
    last_name VARCHAR2(50),
    department_id NUMBER,
    employee_data BLOB,        -- JSON data as BLOB
    preferences BLOB           -- JSON preferences as BLOB
);

-- After migration, we have:
-- EMPLOYEES_OLD (original data)
-- EMPLOYEES_NEW (new structure, possibly with different JSON schema)

-- ===================================================================
-- 2. EXAMPLE VIEW DEFINITION
-- ===================================================================

CREATE OR REPLACE VIEW EMPLOYEES AS
SELECT 
    employee_id,
    first_name,
    last_name,
    department_id,
    employee_data,
    preferences
FROM EMPLOYEES_OLD
UNION ALL
SELECT 
    employee_id,
    first_name,
    last_name,
    department_id,
    employee_data,
    preferences
FROM EMPLOYEES_NEW;

-- ===================================================================
-- 3. EXAMPLE TRIGGER FOR BLOB JSON COLUMNS
-- ===================================================================

CREATE OR REPLACE TRIGGER TRG_EMPLOYEES_MIGRATION_WRITABLE
INSTEAD OF INSERT OR UPDATE OR DELETE ON EMPLOYEES
FOR EACH ROW
DECLARE
    v_count NUMBER;
    v_error_msg VARCHAR2(4000);
    v_record_exists_old NUMBER;
    v_record_exists_new NUMBER;
    v_json_valid BOOLEAN;
    v_employee_data_json VARCHAR2(4000);
    v_preferences_json VARCHAR2(4000);
BEGIN
    -- Begin transaction
    SAVEPOINT sp_employees_migration;
    
    BEGIN
        IF INSERTING THEN
            -- Validate JSON data in BLOB columns
            IF :NEW.employee_data IS NOT NULL THEN
                BEGIN
                    -- Convert BLOB to VARCHAR2 for JSON validation
                    v_employee_data_json := UTL_RAW.CAST_TO_VARCHAR2(:NEW.employee_data);
                    
                    -- Validate JSON format (Oracle 12c+)
                    SELECT JSON_VALID(v_employee_data_json) INTO v_json_valid FROM DUAL;
                    
                    IF NOT v_json_valid THEN
                        RAISE_APPLICATION_ERROR(-20001, 'Invalid JSON format in employee_data column');
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20001, 'Error validating employee_data JSON: ' || SQLERRM);
                END;
            END IF;
            
            IF :NEW.preferences IS NOT NULL THEN
                BEGIN
                    -- Convert BLOB to VARCHAR2 for JSON validation
                    v_preferences_json := UTL_RAW.CAST_TO_VARCHAR2(:NEW.preferences);
                    
                    -- Validate JSON format
                    SELECT JSON_VALID(v_preferences_json) INTO v_json_valid FROM DUAL;
                    
                    IF NOT v_json_valid THEN
                        RAISE_APPLICATION_ERROR(-20002, 'Invalid JSON format in preferences column');
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20002, 'Error validating preferences JSON: ' || SQLERRM);
                END;
            END IF;
            
            -- Check referential integrity for department_id
            IF :NEW.department_id IS NOT NULL THEN
                SELECT COUNT(*) INTO v_count 
                FROM DEPARTMENTS 
                WHERE department_id = :NEW.department_id;
                
                IF v_count = 0 THEN
                    RAISE_APPLICATION_ERROR(-20003, 'Department does not exist: ' || :NEW.department_id);
                END IF;
            END IF;
            
            -- Insert only into NEW table
            INSERT INTO EMPLOYEES_NEW (
                employee_id,
                first_name,
                last_name,
                department_id,
                employee_data,
                preferences
            ) VALUES (
                :NEW.employee_id,
                :NEW.first_name,
                :NEW.last_name,
                :NEW.department_id,
                :NEW.employee_data,
                :NEW.preferences
            );
            
        ELSIF UPDATING THEN
            -- Validate JSON data in BLOB columns if they're being updated
            IF :NEW.employee_data IS NOT NULL AND :NEW.employee_data != :OLD.employee_data THEN
                BEGIN
                    v_employee_data_json := UTL_RAW.CAST_TO_VARCHAR2(:NEW.employee_data);
                    SELECT JSON_VALID(v_employee_data_json) INTO v_json_valid FROM DUAL;
                    
                    IF NOT v_json_valid THEN
                        RAISE_APPLICATION_ERROR(-20001, 'Invalid JSON format in employee_data column');
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20001, 'Error validating employee_data JSON: ' || SQLERRM);
                END;
            END IF;
            
            IF :NEW.preferences IS NOT NULL AND :NEW.preferences != :OLD.preferences THEN
                BEGIN
                    v_preferences_json := UTL_RAW.CAST_TO_VARCHAR2(:NEW.preferences);
                    SELECT JSON_VALID(v_preferences_json) INTO v_json_valid FROM DUAL;
                    
                    IF NOT v_json_valid THEN
                        RAISE_APPLICATION_ERROR(-20002, 'Invalid JSON format in preferences column');
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20002, 'Error validating preferences JSON: ' || SQLERRM);
                END;
            END IF;
            
            -- Check referential integrity for department_id if it's being updated
            IF :NEW.department_id != :OLD.department_id AND :NEW.department_id IS NOT NULL THEN
                SELECT COUNT(*) INTO v_count 
                FROM DEPARTMENTS 
                WHERE department_id = :NEW.department_id;
                
                IF v_count = 0 THEN
                    RAISE_APPLICATION_ERROR(-20003, 'Department does not exist: ' || :NEW.department_id);
                END IF;
            END IF;
            
            -- Check if record exists in NEW table
            SELECT COUNT(*) INTO v_record_exists_new 
            FROM EMPLOYEES_NEW
            WHERE employee_id = :OLD.employee_id;
            
            -- Check if record exists in OLD table
            SELECT COUNT(*) INTO v_record_exists_old 
            FROM EMPLOYEES_OLD
            WHERE employee_id = :OLD.employee_id;
            
            IF v_record_exists_new > 0 THEN
                -- Update record in NEW table
                UPDATE EMPLOYEES_NEW
                SET first_name = :NEW.first_name,
                    last_name = :NEW.last_name,
                    department_id = :NEW.department_id,
                    employee_data = :NEW.employee_data,
                    preferences = :NEW.preferences
                WHERE employee_id = :OLD.employee_id;
                
            ELSIF v_record_exists_old > 0 THEN
                -- Move record from OLD to NEW table
                INSERT INTO EMPLOYEES_NEW (
                    employee_id,
                    first_name,
                    last_name,
                    department_id,
                    employee_data,
                    preferences
                ) VALUES (
                    :NEW.employee_id,
                    :NEW.first_name,
                    :NEW.last_name,
                    :NEW.department_id,
                    :NEW.employee_data,
                    :NEW.preferences
                );
            ELSE
                RAISE_APPLICATION_ERROR(-20004, 'Record not found for update: ' || :OLD.employee_id);
            END IF;
            
        ELSIF DELETING THEN
            -- Check if record exists in NEW table
            SELECT COUNT(*) INTO v_record_exists_new 
            FROM EMPLOYEES_NEW
            WHERE employee_id = :OLD.employee_id;
            
            -- Check if record exists in OLD table
            SELECT COUNT(*) INTO v_record_exists_old 
            FROM EMPLOYEES_OLD
            WHERE employee_id = :OLD.employee_id;
            
            IF v_record_exists_new > 0 THEN
                -- Delete from NEW table only
                DELETE FROM EMPLOYEES_NEW
                WHERE employee_id = :OLD.employee_id;
                
            ELSIF v_record_exists_old > 0 THEN
                -- Cannot delete from OLD table during migration
                RAISE_APPLICATION_ERROR(-20005, 'Cannot delete from OLD table during migration: ' || :OLD.employee_id);
            ELSE
                RAISE_APPLICATION_ERROR(-20006, 'Record not found for deletion: ' || :OLD.employee_id);
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
-- 4. EXAMPLE USAGE WITH BLOB JSON DATA
-- ===================================================================

-- Example of inserting data with JSON BLOB columns
INSERT INTO EMPLOYEES (
    employee_id,
    first_name,
    last_name,
    department_id,
    employee_data,
    preferences
) VALUES (
    1001,
    'John',
    'Doe',
    10,
    UTL_RAW.CAST_TO_RAW('{"skills": ["Java", "Python"], "experience": 5, "certifications": ["OCP", "AWS"]}'),
    UTL_RAW.CAST_TO_RAW('{"theme": "dark", "notifications": true, "language": "en"}')
);

-- Example of updating JSON data
UPDATE EMPLOYEES 
SET employee_data = UTL_RAW.CAST_TO_RAW('{"skills": ["Java", "Python", "Oracle"], "experience": 6, "certifications": ["OCP", "AWS", "Kubernetes"]}'),
    preferences = UTL_RAW.CAST_TO_RAW('{"theme": "light", "notifications": false, "language": "en"}')
WHERE employee_id = 1001;

-- Example of querying JSON data from the view
SELECT 
    employee_id,
    first_name,
    last_name,
    UTL_RAW.CAST_TO_VARCHAR2(employee_data) as employee_data_json,
    UTL_RAW.CAST_TO_VARCHAR2(preferences) as preferences_json
FROM EMPLOYEES
WHERE employee_id = 1001;

-- ===================================================================
-- 5. ENHANCED TRIGGER WITH JSON SCHEMA VALIDATION
-- ===================================================================

CREATE OR REPLACE TRIGGER TRG_EMPLOYEES_MIGRATION_WRITABLE_ENHANCED
INSTEAD OF INSERT OR UPDATE OR DELETE ON EMPLOYEES
FOR EACH ROW
DECLARE
    v_count NUMBER;
    v_error_msg VARCHAR2(4000);
    v_record_exists_old NUMBER;
    v_record_exists_new NUMBER;
    v_json_valid BOOLEAN;
    v_employee_data_json VARCHAR2(4000);
    v_preferences_json VARCHAR2(4000);
    v_skills_array JSON_ARRAY_T;
    v_theme_value VARCHAR2(100);
BEGIN
    -- Begin transaction
    SAVEPOINT sp_employees_migration;
    
    BEGIN
        IF INSERTING THEN
            -- Enhanced JSON validation with schema checking
            IF :NEW.employee_data IS NOT NULL THEN
                BEGIN
                    v_employee_data_json := UTL_RAW.CAST_TO_VARCHAR2(:NEW.employee_data);
                    SELECT JSON_VALID(v_employee_data_json) INTO v_json_valid FROM DUAL;
                    
                    IF NOT v_json_valid THEN
                        RAISE_APPLICATION_ERROR(-20001, 'Invalid JSON format in employee_data column');
                    END IF;
                    
                    -- Validate JSON schema (check for required fields)
                    v_skills_array := JSON_ARRAY_T(v_employee_data_json, '$.skills');
                    IF v_skills_array IS NULL THEN
                        RAISE_APPLICATION_ERROR(-20001, 'Missing required field: skills in employee_data');
                    END IF;
                    
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20001, 'Error validating employee_data JSON: ' || SQLERRM);
                END;
            END IF;
            
            IF :NEW.preferences IS NOT NULL THEN
                BEGIN
                    v_preferences_json := UTL_RAW.CAST_TO_VARCHAR2(:NEW.preferences);
                    SELECT JSON_VALID(v_preferences_json) INTO v_json_valid FROM DUAL;
                    
                    IF NOT v_json_valid THEN
                        RAISE_APPLICATION_ERROR(-20002, 'Invalid JSON format in preferences column');
                    END IF;
                    
                    -- Validate JSON schema (check for required fields)
                    v_theme_value := JSON_VALUE(v_preferences_json, '$.theme');
                    IF v_theme_value IS NULL THEN
                        RAISE_APPLICATION_ERROR(-20002, 'Missing required field: theme in preferences');
                    END IF;
                    
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20002, 'Error validating preferences JSON: ' || SQLERRM);
                END;
            END IF;
            
            -- Rest of the INSERT logic remains the same...
            -- (Same as the previous trigger)
            
        ELSIF UPDATING THEN
            -- Enhanced JSON validation for updates
            IF :NEW.employee_data IS NOT NULL AND :NEW.employee_data != :OLD.employee_data THEN
                BEGIN
                    v_employee_data_json := UTL_RAW.CAST_TO_VARCHAR2(:NEW.employee_data);
                    SELECT JSON_VALID(v_employee_data_json) INTO v_json_valid FROM DUAL;
                    
                    IF NOT v_json_valid THEN
                        RAISE_APPLICATION_ERROR(-20001, 'Invalid JSON format in employee_data column');
                    END IF;
                    
                    -- Validate JSON schema
                    v_skills_array := JSON_ARRAY_T(v_employee_data_json, '$.skills');
                    IF v_skills_array IS NULL THEN
                        RAISE_APPLICATION_ERROR(-20001, 'Missing required field: skills in employee_data');
                    END IF;
                    
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20001, 'Error validating employee_data JSON: ' || SQLERRM);
                END;
            END IF;
            
            IF :NEW.preferences IS NOT NULL AND :NEW.preferences != :OLD.preferences THEN
                BEGIN
                    v_preferences_json := UTL_RAW.CAST_TO_VARCHAR2(:NEW.preferences);
                    SELECT JSON_VALID(v_preferences_json) INTO v_json_valid FROM DUAL;
                    
                    IF NOT v_json_valid THEN
                        RAISE_APPLICATION_ERROR(-20002, 'Invalid JSON format in preferences column');
                    END IF;
                    
                    -- Validate JSON schema
                    v_theme_value := JSON_VALUE(v_preferences_json, '$.theme');
                    IF v_theme_value IS NULL THEN
                        RAISE_APPLICATION_ERROR(-20002, 'Missing required field: theme in preferences');
                    END IF;
                    
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20002, 'Error validating preferences JSON: ' || SQLERRM);
                END;
            END IF;
            
            -- Rest of the UPDATE logic remains the same...
            -- (Same as the previous trigger)
            
        ELSIF DELETING THEN
            -- DELETE logic remains the same...
            -- (Same as the previous trigger)
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
-- 6. EXAMPLE QUERIES WITH JSON FUNCTIONS
-- ===================================================================

-- Query employees with specific skills
SELECT 
    employee_id,
    first_name,
    last_name,
    JSON_VALUE(UTL_RAW.CAST_TO_VARCHAR2(employee_data), '$.skills[0]') as first_skill,
    JSON_VALUE(UTL_RAW.CAST_TO_VARCHAR2(preferences), '$.theme') as theme
FROM EMPLOYEES
WHERE JSON_EXISTS(UTL_RAW.CAST_TO_VARCHAR2(employee_data), '$.skills[*]?(@ == "Java")');

-- Query employees with dark theme preference
SELECT 
    employee_id,
    first_name,
    last_name,
    JSON_VALUE(UTL_RAW.CAST_TO_VARCHAR2(preferences), '$.theme') as theme
FROM EMPLOYEES
WHERE JSON_VALUE(UTL_RAW.CAST_TO_VARCHAR2(preferences), '$.theme') = 'dark';

-- Query employees with more than 3 skills
SELECT 
    employee_id,
    first_name,
    last_name,
    JSON_QUERY(UTL_RAW.CAST_TO_VARCHAR2(employee_data), '$.skills') as skills
FROM EMPLOYEES
WHERE JSON_ARRAY_LENGTH(JSON_QUERY(UTL_RAW.CAST_TO_VARCHAR2(employee_data), '$.skills')) > 3;

-- ===================================================================
-- END OF EXAMPLE
-- ===================================================================
