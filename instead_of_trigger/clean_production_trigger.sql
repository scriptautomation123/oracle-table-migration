-- ===================================================================
-- CLEAN PRODUCTION TRIGGER - INSTEAD OF TRIGGER PATTERN
-- ===================================================================
-- Focus: Core functionality only - what INSTEAD OF triggers should do
-- Pattern: Read from both tables, write to NEW table only
-- ===================================================================

CREATE OR REPLACE TRIGGER TRG_EMPLOYEES_MIGRATION_WRITABLE
INSTEAD OF INSERT OR UPDATE OR DELETE ON EMPLOYEES
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    IF INSERTING THEN
        -- Insert only into NEW table
        INSERT INTO EMPLOYEES_NEW (
            employee_id, first_name, last_name, department_id,
            employee_data, preferences, created_date, updated_date
        ) VALUES (
            :NEW.employee_id, :NEW.first_name, :NEW.last_name, :NEW.department_id,
            :NEW.employee_data, :NEW.preferences, SYSTIMESTAMP, SYSTIMESTAMP
        );
        
    ELSIF UPDATING THEN
        -- Check if record exists in NEW table
        SELECT COUNT(*) INTO v_count 
        FROM EMPLOYEES_NEW 
        WHERE employee_id = :OLD.employee_id;
        
        IF v_count > 0 THEN
            -- Update record in NEW table
            UPDATE EMPLOYEES_NEW
            SET first_name = :NEW.first_name,
                last_name = :NEW.last_name,
                department_id = :NEW.department_id,
                employee_data = :NEW.employee_data,
                preferences = :NEW.preferences,
                updated_date = SYSTIMESTAMP
            WHERE employee_id = :OLD.employee_id;
        ELSE
            -- Record doesn't exist in NEW table, create it
            INSERT INTO EMPLOYEES_NEW (
                employee_id, first_name, last_name, department_id,
                employee_data, preferences, created_date, updated_date
            ) VALUES (
                :NEW.employee_id, :NEW.first_name, :NEW.last_name, :NEW.department_id,
                :NEW.employee_data, :NEW.preferences, SYSTIMESTAMP, SYSTIMESTAMP
            );
        END IF;
        
    ELSIF DELETING THEN
        -- Delete only from NEW table
        DELETE FROM EMPLOYEES_NEW
        WHERE employee_id = :OLD.employee_id;
    END IF;
END;
/

-- ===================================================================
-- USAGE EXAMPLES
-- ===================================================================

-- Example 1: Insert new record
/*
INSERT INTO EMPLOYEES (employee_id, first_name, last_name, department_id, employee_data, preferences)
VALUES (1001, 'John', 'Doe', 10, 
        UTL_RAW.CAST_TO_RAW('{"skills": ["Java", "Oracle"]}'),
        UTL_RAW.CAST_TO_RAW('{"theme": "dark"}'));
*/

-- Example 2: Update existing record
/*
UPDATE EMPLOYEES 
SET first_name = 'Jane', last_name = 'Smith'
WHERE employee_id = 1001;
*/

-- Example 3: Delete record
/*
DELETE FROM EMPLOYEES WHERE employee_id = 1001;
*/

-- Example 4: Query the view (reads from both tables)
/*
SELECT employee_id, first_name, last_name 
FROM EMPLOYEES 
WHERE department_id = 10;
*/
