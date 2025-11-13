-- ============================================================================
-- HR Demo Schema Setup Script
-- ============================================================================
-- Purpose: Create HR schema with Oracle sample HR objects, roles, and grants
-- Usage: sqlplus / as sysdba @HR_demo_schema.sql
-- Note: Drops and recreates users and roles if they exist
-- ============================================================================

SET ECHO ON
SET VERIFY OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR CONTINUE

-- ============================================================================
-- Drop existing users and roles
-- ============================================================================

PROMPT ==========================================
PROMPT Cleaning up existing users and roles
PROMPT ==========================================

BEGIN
    -- Drop users
    FOR r IN (SELECT username FROM all_users WHERE username IN ('HR_OWNER', 'HR_APP')) LOOP
        EXECUTE IMMEDIATE 'DROP USER ' || r.username || ' CASCADE';
        DBMS_OUTPUT.PUT_LINE('Dropped user: ' || r.username);
    END LOOP;
    
    -- Drop roles
    FOR r IN (SELECT role FROM session_roles WHERE role IN ('HR_OWNER_EXEC_ROLE', 'HR_OWNER_SEL_ROLE', 'HR_OWNER_DML_ROLE')
              UNION
              SELECT granted_role FROM user_role_privs WHERE granted_role IN ('HR_OWNER_EXEC_ROLE', 'HR_OWNER_SEL_ROLE', 'HR_OWNER_DML_ROLE')) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP ROLE ' || r.role;
            DBMS_OUTPUT.PUT_LINE('Dropped role: ' || r.role);
        EXCEPTION
            WHEN OTHERS THEN
                NULL; -- Role may not exist
        END;
    END LOOP;
END;
/

-- ============================================================================
-- Create users
-- ============================================================================

PROMPT
PROMPT ==========================================
PROMPT Creating users
PROMPT ==========================================

CREATE USER hr_owner IDENTIFIED BY oracle123
    DEFAULT TABLESPACE users
    TEMPORARY TABLESPACE temp
    QUOTA UNLIMITED ON users;

CREATE USER hr_app IDENTIFIED BY oracle123
    DEFAULT TABLESPACE users
    TEMPORARY TABLESPACE temp;

-- Grant basic privileges to hr_owner
GRANT CREATE SESSION TO hr_owner;
GRANT CREATE TABLE TO hr_owner;
GRANT CREATE VIEW TO hr_owner;
GRANT CREATE SEQUENCE TO hr_owner;
GRANT CREATE PROCEDURE TO hr_owner;
GRANT CREATE TRIGGER TO hr_owner;
GRANT CREATE SYNONYM TO hr_owner;

-- Grant basic privileges to hr_app
GRANT CREATE SESSION TO hr_app;

PROMPT Created users: hr_owner, hr_app

-- ============================================================================
-- Create HR schema objects (Oracle sample HR schema)
-- ============================================================================

PROMPT
PROMPT ==========================================
PROMPT Creating HR schema objects
PROMPT ==========================================
PROMPT NOTE: The following creates objects in hr_owner schema
PROMPT       Ensure you are connected with appropriate privileges

-- Set current schema to hr_owner
ALTER SESSION SET CURRENT_SCHEMA = hr_owner;

-- Regions table
CREATE TABLE regions (
    region_id    NUMBER CONSTRAINT region_id_nn NOT NULL,
    region_name  VARCHAR2(25),
    CONSTRAINT reg_id_pk PRIMARY KEY (region_id)
);

-- Countries table
CREATE TABLE countries (
    country_id   CHAR(2) CONSTRAINT country_id_nn NOT NULL,
    country_name VARCHAR2(40),
    region_id    NUMBER,
    CONSTRAINT country_c_id_pk PRIMARY KEY (country_id),
    CONSTRAINT countr_reg_fk FOREIGN KEY (region_id) REFERENCES regions(region_id)
);

-- Locations table
CREATE TABLE locations (
    location_id    NUMBER(4) CONSTRAINT location_id_nn NOT NULL,
    street_address VARCHAR2(40),
    postal_code    VARCHAR2(12),
    city           VARCHAR2(30) CONSTRAINT loc_city_nn NOT NULL,
    state_province VARCHAR2(25),
    country_id     CHAR(2),
    CONSTRAINT loc_id_pk PRIMARY KEY (location_id),
    CONSTRAINT loc_c_id_fk FOREIGN KEY (country_id) REFERENCES countries(country_id)
);

-- Departments table
CREATE TABLE departments (
    department_id   NUMBER(4) CONSTRAINT department_id_nn NOT NULL,
    department_name VARCHAR2(30) CONSTRAINT dept_name_nn NOT NULL,
    manager_id      NUMBER(6),
    location_id     NUMBER(4),
    CONSTRAINT dept_id_pk PRIMARY KEY (department_id),
    CONSTRAINT dept_loc_fk FOREIGN KEY (location_id) REFERENCES locations(location_id)
);

-- Jobs table
CREATE TABLE jobs (
    job_id     VARCHAR2(10) CONSTRAINT job_id_nn NOT NULL,
    job_title  VARCHAR2(35) CONSTRAINT job_title_nn NOT NULL,
    min_salary NUMBER(6),
    max_salary NUMBER(6),
    CONSTRAINT job_id_pk PRIMARY KEY(job_id)
);

-- Employees table
CREATE TABLE employees (
    employee_id    NUMBER(6) CONSTRAINT employee_id_nn NOT NULL,
    first_name     VARCHAR2(20),
    last_name      VARCHAR2(25) CONSTRAINT emp_last_name_nn NOT NULL,
    email          VARCHAR2(25) CONSTRAINT emp_email_nn NOT NULL,
    phone_number   VARCHAR2(20),
    hire_date      DATE CONSTRAINT emp_hire_date_nn NOT NULL,
    job_id         VARCHAR2(10) CONSTRAINT emp_job_nn NOT NULL,
    salary         NUMBER(8,2),
    commission_pct NUMBER(2,2),
    manager_id     NUMBER(6),
    department_id  NUMBER(4),
    CONSTRAINT emp_emp_id_pk PRIMARY KEY (employee_id),
    CONSTRAINT emp_email_uk UNIQUE (email),
    CONSTRAINT emp_dept_fk FOREIGN KEY (department_id) REFERENCES departments(department_id),
    CONSTRAINT emp_job_fk FOREIGN KEY (job_id) REFERENCES jobs(job_id),
    CONSTRAINT emp_manager_fk FOREIGN KEY (manager_id) REFERENCES employees(employee_id)
);

-- Add foreign key to departments (manager_id)
ALTER TABLE departments ADD (
    CONSTRAINT dept_mgr_fk FOREIGN KEY (manager_id) REFERENCES employees(employee_id)
);

-- Job history table
CREATE TABLE job_history (
    employee_id   NUMBER(6) CONSTRAINT jhist_employee_nn NOT NULL,
    start_date    DATE CONSTRAINT jhist_start_date_nn NOT NULL,
    end_date      DATE CONSTRAINT jhist_end_date_nn NOT NULL,
    job_id        VARCHAR2(10) CONSTRAINT jhist_job_nn NOT NULL,
    department_id NUMBER(4),
    CONSTRAINT jhist_date_interval CHECK (end_date > start_date),
    CONSTRAINT jhist_emp_id_st_date_pk PRIMARY KEY (employee_id, start_date),
    CONSTRAINT jhist_job_fk FOREIGN KEY (job_id) REFERENCES jobs(job_id),
    CONSTRAINT jhist_emp_fk FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    CONSTRAINT jhist_dept_fk FOREIGN KEY (department_id) REFERENCES departments(department_id)
);

-- Sequences
CREATE SEQUENCE locations_seq START WITH 3300 INCREMENT BY 100 NOCACHE;
CREATE SEQUENCE departments_seq START WITH 280 INCREMENT BY 10 NOCACHE;
CREATE SEQUENCE employees_seq START WITH 207 INCREMENT BY 1 NOCACHE;

-- Sample view
CREATE OR REPLACE VIEW emp_details_view AS
SELECT e.employee_id,
       e.first_name,
       e.last_name,
       e.salary,
       e.email,
       e.hire_date,
       j.job_title,
       d.department_name,
       l.city,
       l.state_province,
       c.country_name,
       r.region_name
FROM employees e
JOIN departments d ON e.department_id = d.department_id
JOIN jobs j ON e.job_id = j.job_id
JOIN locations l ON d.location_id = l.location_id
JOIN countries c ON l.country_id = c.country_id
JOIN regions r ON c.region_id = r.region_id;

-- Sample package
CREATE OR REPLACE PACKAGE emp_mgmt AS
    PROCEDURE hire_employee(
        p_first_name   VARCHAR2,
        p_last_name    VARCHAR2,
        p_email        VARCHAR2,
        p_phone_number VARCHAR2,
        p_hire_date    DATE,
        p_job_id       VARCHAR2,
        p_salary       NUMBER,
        p_manager_id   NUMBER,
        p_department_id NUMBER
    );
    
    FUNCTION get_employee_count(p_department_id NUMBER) RETURN NUMBER;
END emp_mgmt;
/

CREATE OR REPLACE PACKAGE BODY emp_mgmt AS
    PROCEDURE hire_employee(
        p_first_name   VARCHAR2,
        p_last_name    VARCHAR2,
        p_email        VARCHAR2,
        p_phone_number VARCHAR2,
        p_hire_date    DATE,
        p_job_id       VARCHAR2,
        p_salary       NUMBER,
        p_manager_id   NUMBER,
        p_department_id NUMBER
    ) IS
        v_emp_id NUMBER;
    BEGIN
        SELECT employees_seq.NEXTVAL INTO v_emp_id FROM dual;
        
        INSERT INTO employees (
            employee_id, first_name, last_name, email, phone_number,
            hire_date, job_id, salary, manager_id, department_id
        ) VALUES (
            v_emp_id, p_first_name, p_last_name, p_email, p_phone_number,
            p_hire_date, p_job_id, p_salary, p_manager_id, p_department_id
        );
        
        COMMIT;
    END hire_employee;
    
    FUNCTION get_employee_count(p_department_id NUMBER) RETURN NUMBER IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM employees
        WHERE department_id = p_department_id;
        
        RETURN v_count;
    END get_employee_count;
END emp_mgmt;
/

-- Insert sample data
INSERT INTO regions VALUES (1, 'Europe');
INSERT INTO regions VALUES (2, 'Americas');
INSERT INTO regions VALUES (3, 'Asia');
INSERT INTO regions VALUES (4, 'Middle East and Africa');

INSERT INTO countries VALUES ('US', 'United States of America', 2);
INSERT INTO countries VALUES ('CA', 'Canada', 2);
INSERT INTO countries VALUES ('UK', 'United Kingdom', 1);
INSERT INTO countries VALUES ('DE', 'Germany', 1);

INSERT INTO locations VALUES (1400, '2014 Jabberwocky Rd', '26192', 'Southlake', 'Texas', 'US');
INSERT INTO locations VALUES (1500, '2011 Interiors Blvd', '99236', 'South San Francisco', 'California', 'US');
INSERT INTO locations VALUES (1700, '2004 Charade Rd', '98199', 'Seattle', 'Washington', 'US');

INSERT INTO jobs VALUES ('AD_PRES', 'President', 20080, 40000);
INSERT INTO jobs VALUES ('AD_VP', 'Administration Vice President', 15000, 30000);
INSERT INTO jobs VALUES ('IT_PROG', 'Programmer', 4000, 10000);
INSERT INTO jobs VALUES ('ST_CLERK', 'Stock Clerk', 2008, 5000);

INSERT INTO departments VALUES (10, 'Administration', NULL, 1700);
INSERT INTO departments VALUES (20, 'Marketing', NULL, 1400);
INSERT INTO departments VALUES (60, 'IT', NULL, 1400);
INSERT INTO departments VALUES (90, 'Executive', NULL, 1700);

INSERT INTO employees VALUES (100, 'Steven', 'King', 'SKING', '515.123.4567', DATE '1987-06-17', 'AD_PRES', 24000, NULL, NULL, 90);
INSERT INTO employees VALUES (101, 'Neena', 'Kochhar', 'NKOCHHAR', '515.123.4568', DATE '1989-09-21', 'AD_VP', 17000, NULL, 100, 90);
INSERT INTO employees VALUES (103, 'Alexander', 'Hunold', 'AHUNOLD', '590.423.4567', DATE '1990-01-03', 'IT_PROG', 9000, NULL, 101, 60);
INSERT INTO employees VALUES (104, 'Bruce', 'Ernst', 'BERNST', '590.423.4568', DATE '1991-05-21', 'IT_PROG', 6000, NULL, 103, 60);

UPDATE departments SET manager_id = 100 WHERE department_id = 90;
UPDATE departments SET manager_id = 101 WHERE department_id = 60;

COMMIT;

PROMPT HR schema objects created successfully

-- ============================================================================
-- Create roles and grant privileges
-- ============================================================================

PROMPT
PROMPT ==========================================
PROMPT Creating roles and granting privileges
PROMPT ==========================================
PROMPT NOTE: The following requires SYSDBA or DBA role
PROMPT       Script will fail if privileges are insufficient

-- Create roles (requires SYSDBA or DBA role)
CREATE ROLE hr_owner_exec_role;
CREATE ROLE hr_owner_sel_role;
CREATE ROLE hr_owner_dml_role;

PROMPT Created roles: hr_owner_exec_role, hr_owner_sel_role, hr_owner_dml_role

-- Grant privileges on tables and views
DECLARE
    v_sql VARCHAR2(1000);
BEGIN
    -- SELECT grants on all tables and views
    FOR r IN (
        SELECT object_name, object_type
        FROM all_objects
        WHERE owner = 'HR_OWNER'
        AND object_type IN ('TABLE', 'VIEW')
        ORDER BY object_name
    ) LOOP
        v_sql := 'GRANT SELECT ON hr_owner.' || r.object_name || ' TO hr_owner_sel_role';
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('SELECT granted on ' || r.object_type || ': ' || r.object_name);
    END LOOP;
    
    -- DML grants on all tables
    FOR r IN (
        SELECT table_name
        FROM all_tables
        WHERE owner = 'HR_OWNER'
        ORDER BY table_name
    ) LOOP
        v_sql := 'GRANT SELECT, INSERT, UPDATE, DELETE ON hr_owner.' || r.table_name || ' TO hr_owner_dml_role';
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('DML granted on table: ' || r.table_name);
    END LOOP;
    
    -- EXECUTE grants on all packages and procedures
    FOR r IN (
        SELECT object_name, object_type
        FROM all_objects
        WHERE owner = 'HR_OWNER'
        AND object_type IN ('PACKAGE', 'PROCEDURE', 'FUNCTION')
        ORDER BY object_name
    ) LOOP
        v_sql := 'GRANT EXECUTE ON hr_owner.' || r.object_name || ' TO hr_owner_exec_role';
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('EXECUTE granted on ' || r.object_type || ': ' || r.object_name);
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('All privileges granted successfully');
END;
/

-- Grant roles to hr_app
GRANT hr_owner_dml_role TO hr_app;
GRANT hr_owner_exec_role TO hr_app;

PROMPT Roles granted to hr_app: hr_owner_dml_role, hr_owner_exec_role

-- ============================================================================
-- Summary
-- ============================================================================

PROMPT
PROMPT ==========================================
PROMPT Setup Complete
PROMPT ==========================================
PROMPT
PROMPT Users Created:
PROMPT   - hr_owner (password: oracle123) - Schema owner
PROMPT   - hr_app   (password: oracle123) - Application user
PROMPT
PROMPT Roles Created:
PROMPT   - hr_owner_sel_role  (SELECT on tables/views)
PROMPT   - hr_owner_dml_role  (SELECT, INSERT, UPDATE, DELETE on tables)
PROMPT   - hr_owner_exec_role (EXECUTE on packages/procedures)
PROMPT
PROMPT Role Grants to hr_app:
PROMPT   - hr_owner_dml_role
PROMPT   - hr_owner_exec_role
PROMPT
PROMPT Objects Created in hr_owner:
PROMPT   - 7 tables (regions, countries, locations, departments, jobs, employees, job_history)
PROMPT   - 3 sequences
PROMPT   - 1 view (emp_details_view)
PROMPT   - 1 package (emp_mgmt)
PROMPT   - Sample data loaded
PROMPT
PROMPT Test connection:
PROMPT   sqlplus hr_owner/oracle123
PROMPT   sqlplus hr_app/oracle123
PROMPT
PROMPT ==========================================

SET ECHO OFF