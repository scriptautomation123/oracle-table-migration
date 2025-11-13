-- ============================================================================
-- Logging Package - Grant Privileges
-- ============================================================================
-- Purpose: Grant privileges for logging package usage
-- Usage: Run after install_all.sql
-- ============================================================================

SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

ACCEPT v_schema_owner CHAR PROMPT 'Enter logging schema owner (e.g., HR): '
ACCEPT v_grantee CHAR PROMPT 'Enter user/role to grant privileges (e.g., APP_USER or PUBLIC): '

PROMPT ========================================
PROMPT Granting Privileges
PROMPT From: &v_schema_owner
PROMPT To: &v_grantee
PROMPT ========================================

-- Grant execute on package (main requirement)
GRANT EXECUTE ON &v_schema_owner.logging_pkg TO &v_grantee;

-- Grant select on views (for monitoring)
GRANT SELECT ON &v_schema_owner.v_app_log_recent TO &v_grantee;
GRANT SELECT ON &v_schema_owner.v_app_log_errors TO &v_grantee;
GRANT SELECT ON &v_schema_owner.v_app_log_summary TO &v_grantee;

-- Optional: Grant select on table (for advanced queries)
-- GRANT SELECT ON &v_schema_owner.app_log TO &v_grantee;

PROMPT
PROMPT ========================================
PROMPT Grants Complete
PROMPT ========================================
PROMPT
PROMPT Usage from &v_grantee:
PROMPT   BEGIN
PROMPT     &v_schema_owner..logging_pkg.info('PKG_NAME', 'PROC_NAME', 'Message');
PROMPT   END;
PROMPT   /
PROMPT
PROMPT Query logs:
PROMPT   SELECT * FROM &v_schema_owner.v_app_log_recent;
PROMPT ========================================

SET VERIFY ON
