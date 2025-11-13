-- ============================================================================
-- Partition Swap Package - Master Install Script
-- ============================================================================
-- Purpose: Install partition swap package
-- Usage: @install_all.sql <schema_name>
-- Example: @install_all.sql HR
-- Note: Requires logging_pkg to be installed first
-- Version: 1.0
-- ============================================================================

SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

ACCEPT v_schema_name CHAR PROMPT 'Enter schema name: '

PROMPT ========================================
PROMPT Installing Partition Swap Package
PROMPT Schema: &v_schema_name
PROMPT ========================================

-- Validate and set schema
DECLARE
    v_count NUMBER;
    v_logging_pkg_count NUMBER;
BEGIN
    -- Check if schema exists
    SELECT COUNT(*)
    INTO v_count
    FROM all_users
    WHERE username = UPPER('&v_schema_name');
    
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Schema &v_schema_name does not exist');
    END IF;
    
    -- Check if logging_pkg exists (dependency)
    SELECT COUNT(*)
    INTO v_logging_pkg_count
    FROM all_objects
    WHERE owner = UPPER('&v_schema_name')
    AND object_type = 'PACKAGE'
    AND object_name = 'LOGGING_PKG';
    
    IF v_logging_pkg_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'logging_pkg not found. Install logging package first.');
    END IF;
    
    -- Set current schema
    EXECUTE IMMEDIATE 'ALTER SESSION SET CURRENT_SCHEMA = ' || UPPER('&v_schema_name');
    
    DBMS_OUTPUT.PUT_LINE('Current schema set to: &v_schema_name');
    DBMS_OUTPUT.PUT_LINE('Dependency check passed: logging_pkg found');
END;
/

PROMPT
PROMPT Step 1/1: Creating package...
@@01_partition_swap_pkg.sql

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
        DBMS_OUTPUT.PUT_LINE('Skipping grants - run 02_grant_privileges.sql later if needed');
    END IF;
END;
/

-- Conditional grant execution
COLUMN grant_script NEW_VALUE grant_file NOPRINT
SELECT CASE WHEN UPPER('&v_grant_choice') = 'Y' THEN '02_grant_privileges.sql' ELSE 'skip_grants.sql' END AS grant_script FROM dual;

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
PROMPT Test partition swap:
PROMPT   BEGIN
PROMPT     &v_schema_name..partition_swap_pkg.swap_oldest_partition(
PROMPT       p_active_table   => 'ACTIVE_TRANSACTIONS',
PROMPT       p_staging_table  => 'STAGING_TRANSACTIONS',
PROMPT       p_history_table  => 'HISTORY_TRANSACTIONS'
PROMPT     );
PROMPT   END;
PROMPT   /
PROMPT
PROMPT To grant privileges later:
PROMPT   @02_grant_privileges.sql
PROMPT ========================================

SET VERIFY ON
