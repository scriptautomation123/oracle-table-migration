-- ============================================================================
-- Logging Package - Master Install Script
-- ============================================================================
-- Purpose: Install complete logging infrastructure
-- Usage: @install_all.sql <schema_name>
-- Example: @install_all.sql HR
-- Version: 1.0
-- ============================================================================

SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

ACCEPT v_schema_name CHAR PROMPT 'Enter schema name: '

PROMPT ========================================
PROMPT Installing Logging Infrastructure
PROMPT Schema: &v_schema_name
PROMPT ========================================

-- Validate and set schema
DECLARE
    v_count NUMBER;
BEGIN
    -- Check if schema exists
    SELECT COUNT(*)
    INTO v_count
    FROM all_users
    WHERE username = UPPER('&v_schema_name');
    
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Schema &v_schema_name does not exist');
    END IF;
    
    -- Set current schema
    EXECUTE IMMEDIATE 'ALTER SESSION SET CURRENT_SCHEMA = ' || UPPER('&v_schema_name');
    
    DBMS_OUTPUT.PUT_LINE('Current schema set to: &v_schema_name');
END;
/

PROMPT
PROMPT Step 1/4: Creating table...
@@01_create_table.sql

PROMPT
PROMPT Step 2/4: Creating indexes...
@@02_create_indexes.sql

PROMPT
PROMPT Step 3/4: Creating views...
@@03_create_views.sql

PROMPT
PROMPT Step 4/4: Creating package...
@@04_logging_pkg.sql

PROMPT
PROMPT ========================================
PROMPT Grant Privileges (Optional)
PROMPT ========================================

ACCEPT v_grant_choice CHAR PROMPT 'Grant privileges to other users/roles? (Y/N): ' DEFAULT 'N'

DECLARE
    v_choice VARCHAR2(1) := UPPER('&v_grant_choice');
BEGIN
    IF v_choice = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('Proceeding with grants...');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Skipping grants - run grant_privileges_logging.sql later if needed');
    END IF;
END;
/

-- Conditional grant execution
COLUMN grant_script NEW_VALUE grant_file NOPRINT
SELECT CASE WHEN UPPER('&v_grant_choice') = 'Y' THEN '05_grant_privileges_logging.sql' ELSE 'skip_grants.sql' END AS grant_script FROM dual;

-- Create temporary skip file if needed
PROMPT Creating temporary skip file...
HOST echo "PROMPT Grants skipped" > skip_grants.sql

-- Execute grant script or skip
@@&grant_file

-- Cleanup temporary file
HOST rm -f skip_grants.sql

PROMPT
PROMPT ========================================
PROMPT Installation Complete for &v_schema_name
PROMPT ========================================
PROMPT
PROMPT Verify installation:
PROMPT   SELECT COUNT(*) FROM &v_schema_name..app_log;
PROMPT   SELECT * FROM &v_schema_name..v_app_log_summary;
PROMPT
PROMPT Test logging:
PROMPT   BEGIN
PROMPT     &v_schema_name..logging_pkg.info('TEST_PKG', 'TEST_PROC', 'Test message');
PROMPT   END;
PROMPT   /
PROMPT
PROMPT To grant privileges later:
PROMPT   @05_grant_privileges_logging.sql
PROMPT ========================================

SET VERIFY ON
