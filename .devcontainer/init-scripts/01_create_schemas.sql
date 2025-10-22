-- ============================================================================
-- Create Test Schema and Role for Migration Framework Testing
-- ============================================================================
-- Purpose: Set up HR schema (owns all tables) and HR_APP role (access only)
-- Run as: SYSTEM or SYSDBA
-- ============================================================================
-- Design: Single schema approach for cleaner testing
--   - HR schema owns all tables (both partitioned and non-partitioned)
--   - HR_APP is a role (NOT a user) with SELECT, INSERT, UPDATE, DELETE, EXECUTE
--   - HR_APP_USER connects with HR_APP role for testing
-- ============================================================================

WHENEVER SQLERROR CONTINUE
SET ECHO ON
SET SERVEROUTPUT ON

-- Connect to the pluggable database (scripts run as SYS in FREE instance by default)
ALTER SESSION SET CONTAINER=FREEPDB1;

PROMPT ========================================================================
PROMPT Setting up HR Schema (Table Owner)
PROMPT ========================================================================

-- HR schema is created automatically by docker-compose
-- Ensure HR has necessary privileges for partitioning and testing

GRANT CREATE TABLE TO hr;
GRANT CREATE VIEW TO hr;
GRANT CREATE SEQUENCE TO hr;
GRANT CREATE SYNONYM TO hr;
GRANT CREATE PROCEDURE TO hr;
GRANT CREATE TRIGGER TO hr;
GRANT UNLIMITED TABLESPACE TO hr;

-- Grant system privileges needed for partition operations
GRANT SELECT_CATALOG_ROLE TO hr;
GRANT SELECT ANY DICTIONARY TO hr;

PROMPT ✓ HR schema configured

PROMPT ========================================================================
PROMPT Creating HR_APP Role (Access Control)
PROMPT ========================================================================

-- Create role for application access
DROP ROLE hr_app CASCADE;
CREATE ROLE hr_app;

PROMPT ✓ HR_APP role created

PROMPT ========================================================================
PROMPT Creating HR_APP_USER (Application Connection)
PROMPT ========================================================================

-- Create user for application to connect (uses HR_APP role)
CREATE USER hr_app_user IDENTIFIED BY hrapp123
DEFAULT TABLESPACE users
TEMPORARY TABLESPACE temp
QUOTA 0 ON users;  -- No quota - cannot own objects

-- Grant basic privileges
GRANT CONNECT TO hr_app_user;
GRANT CREATE SESSION TO hr_app_user;

-- Grant HR_APP role
GRANT hr_app TO hr_app_user;

-- Make HR_APP the default role
ALTER USER hr_app_user DEFAULT ROLE hr_app;

PROMPT ✓ HR_APP_USER created

PROMPT ========================================================================
PROMPT Granting HR_APP Role Privileges on HR Schema
PROMPT ========================================================================

-- Grant object privileges on all current and future HR objects
-- This will be supplemented by explicit grants after table creation

BEGIN
    -- Grant on existing tables (if any)
    FOR t IN (SELECT table_name FROM all_tables WHERE owner = 'HR') LOOP
        EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, UPDATE, DELETE ON HR.' || t.table_name || ' TO hr_app';
    END LOOP;
    
    -- Grant on existing sequences (if any)
    FOR s IN (SELECT sequence_name FROM all_sequences WHERE sequence_owner = 'HR') LOOP
        EXECUTE IMMEDIATE 'GRANT SELECT ON HR.' || s.sequence_name || ' TO hr_app';
    END LOOP;
    
    -- Grant on existing procedures (if any)
    FOR p IN (SELECT object_name FROM all_objects WHERE owner = 'HR' AND object_type IN ('PROCEDURE', 'FUNCTION', 'PACKAGE')) LOOP
        EXECUTE IMMEDIATE 'GRANT EXECUTE ON HR.' || p.object_name || ' TO hr_app';
    END LOOP;
END;
/

PROMPT ✓ Object-level privileges granted to HR_APP role

PROMPT ========================================================================
PROMPT Schema Setup Complete
PROMPT ========================================================================
PROMPT 
PROMPT Database Structure:
PROMPT   - HR schema: Owns all tables (both test scenarios)
PROMPT   - HR_APP role: Has SELECT, INSERT, UPDATE, DELETE, EXECUTE on HR objects
PROMPT   - HR_APP_USER: Connects using HR_APP role (no ownership)
PROMPT
PROMPT Connections:
PROMPT   - Table Owner: hr/hr123@oracle:1521/FREEPDB1
PROMPT   - Application:  hr_app_user/hrapp123@oracle:1521/FREEPDB1
PROMPT
PROMPT All tables will be created under HR schema.
PROMPT HR_APP_USER can access via: SELECT * FROM HR.EMPLOYEES
PROMPT
PROMPT Next: Run table creation scripts (all as HR user)
PROMPT ========================================================================

EXIT;
