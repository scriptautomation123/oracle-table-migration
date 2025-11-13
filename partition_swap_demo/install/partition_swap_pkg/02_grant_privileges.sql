-- ============================================================================
-- Partition Swap Package - Grant Privileges
-- ============================================================================
-- Purpose: Grant execute privilege on partition_swap_pkg
-- Usage: Run after installing partition_swap_pkg
-- ============================================================================

SET VERIFY OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

ACCEPT v_schema_owner CHAR PROMPT 'Enter schema owner (e.g., HR): '
ACCEPT v_grantee CHAR PROMPT 'Enter user/role to grant privileges (e.g., APP_USER or PUBLIC): '

PROMPT ========================================
PROMPT Granting Privileges
PROMPT From: &v_schema_owner
PROMPT To: &v_grantee
PROMPT ========================================

-- Grant execute on package
GRANT EXECUTE ON &v_schema_owner.partition_swap_pkg TO &v_grantee;

PROMPT
PROMPT ========================================
PROMPT Grants Complete
PROMPT ========================================
PROMPT
PROMPT Usage from &v_grantee:
PROMPT   BEGIN
PROMPT     &v_schema_owner.partition_swap_pkg.swap_oldest_partition(
PROMPT       p_active_table   => 'ACTIVE_TRANSACTIONS',
PROMPT       p_staging_table  => 'STAGING_TRANSACTIONS',
PROMPT       p_history_table  => 'HISTORY_TRANSACTIONS'
PROMPT     );
PROMPT   END;
PROMPT   /
PROMPT ========================================

SET VERIFY ON
