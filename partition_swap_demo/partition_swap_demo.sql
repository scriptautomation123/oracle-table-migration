-- ============================================================================
-- Partition Swap Demo: Active → Staging → History
-- ============================================================================
-- This script demonstrates the complete partition swap workflow
-- Run this AFTER partition_swap_setup.sql
-- ============================================================================

SET ECHO ON
SET SERVEROUTPUT ON
SET TIMING ON
SET LINESIZE 200
SET PAGESIZE 100

PROMPT ========================================
PROMPT Step 1: Identify Oldest Partition
PROMPT ========================================

-- Find the oldest partition in ACTIVE_TRANSACTIONS
SELECT 
    partition_name,
    partition_position,
    high_value,
    num_rows,
    blocks
FROM user_tab_partitions
WHERE table_name = 'ACTIVE_TRANSACTIONS'
ORDER BY partition_position
FETCH FIRST 1 ROW ONLY;

-- Store partition name for swap
VARIABLE v_partition_name VARCHAR2(128);

BEGIN
    SELECT partition_name
    INTO :v_partition_name
    FROM user_tab_partitions
    WHERE table_name = 'ACTIVE_TRANSACTIONS'
    ORDER BY partition_position
    FETCH FIRST 1 ROW ONLY;
    
    DBMS_OUTPUT.PUT_LINE('Selected partition: ' || :v_partition_name);
END;
/

PROMPT ========================================
PROMPT Step 2: Pre-Swap Validation
PROMPT ========================================

-- Validate data integrity before swap
DECLARE
    v_active_count NUMBER;
    v_staging_count NUMBER;
    v_history_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_active_count FROM active_transactions;
    SELECT COUNT(*) INTO v_staging_count FROM staging_transactions;
    SELECT COUNT(*) INTO v_history_count FROM history_transactions;
    
    DBMS_OUTPUT.PUT_LINE('PRE-SWAP COUNTS:');
    DBMS_OUTPUT.PUT_LINE('  Active:  ' || v_active_count || ' rows');
    DBMS_OUTPUT.PUT_LINE('  Staging: ' || v_staging_count || ' rows');
    DBMS_OUTPUT.PUT_LINE('  History: ' || v_history_count || ' rows');
    
    -- Staging must be empty
    IF v_staging_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Staging table must be empty before swap!');
    END IF;
END;
/

PROMPT ========================================
PROMPT Step 3: Swap ACTIVE Partition → STAGING
PROMPT ========================================

-- This is an atomic metadata operation (no data movement)
-- Local indexes are maintained automatically

BEGIN
    DBMS_OUTPUT.PUT_LINE('Swapping partition ' || :v_partition_name || ' from ACTIVE to STAGING...');
    
    EXECUTE IMMEDIATE 
        'ALTER TABLE active_transactions ' ||
        'EXCHANGE PARTITION ' || :v_partition_name || ' ' ||
        'WITH TABLE staging_transactions ' ||
        'INCLUDING INDEXES ' ||
        'WITHOUT VALIDATION ' ||
        'UPDATE GLOBAL INDEXES';
    
    DBMS_OUTPUT.PUT_LINE('✓ Swap complete (ACTIVE → STAGING)');
END;
/

PROMPT ========================================
PROMPT Step 4: Verify Post-Swap State
PROMPT ========================================

-- Check row counts after first swap
DECLARE
    v_active_count NUMBER;
    v_staging_count NUMBER;
    v_partition_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_active_count FROM active_transactions;
    SELECT COUNT(*) INTO v_staging_count FROM staging_transactions;
    
    -- Count rows in swapped partition (should be 0 in ACTIVE now)
    EXECUTE IMMEDIATE 
        'SELECT COUNT(*) FROM active_transactions PARTITION (' || :v_partition_name || ')'
        INTO v_partition_count;
    
    DBMS_OUTPUT.PUT_LINE('POST-SWAP COUNTS:');
    DBMS_OUTPUT.PUT_LINE('  Active:  ' || v_active_count || ' rows');
    DBMS_OUTPUT.PUT_LINE('  Staging: ' || v_staging_count || ' rows (moved from ACTIVE)');
    DBMS_OUTPUT.PUT_LINE('  Swapped partition in ACTIVE: ' || v_partition_count || ' rows (empty)');
    
    IF v_partition_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Swapped partition should be empty in ACTIVE!');
    END IF;
END;
/

-- Show partition structure
SELECT 'ACTIVE' as source, partition_name, num_rows
FROM user_tab_partitions
WHERE table_name = 'ACTIVE_TRANSACTIONS'
AND partition_name = :v_partition_name;

-- Show index status
SELECT index_name, status, tablespace_name
FROM user_indexes
WHERE table_name = 'STAGING_TRANSACTIONS';

PROMPT ========================================
PROMPT Step 5: Swap STAGING → HISTORY Partition
PROMPT ========================================

-- Create a matching partition in HISTORY to swap with STAGING
DECLARE
    v_high_value CLOB;
    v_hist_partition VARCHAR2(128);
BEGIN
    -- Get high value from original partition
    SELECT high_value
    INTO v_high_value
    FROM user_tab_partitions
    WHERE table_name = 'ACTIVE_TRANSACTIONS'
    AND partition_name = :v_partition_name;
    
    -- Generate history partition name
    v_hist_partition := 'P_HIST_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISS');
    
    DBMS_OUTPUT.PUT_LINE('Creating partition in HISTORY: ' || v_hist_partition);
    
    -- Add partition to HISTORY with same high value
    EXECUTE IMMEDIATE 
        'ALTER TABLE history_transactions ' ||
        'ADD PARTITION ' || v_hist_partition || ' ' ||
        'VALUES LESS THAN (' || v_high_value || ')';
    
    DBMS_OUTPUT.PUT_LINE('✓ Partition created in HISTORY');
    
    -- Swap STAGING → HISTORY partition
    DBMS_OUTPUT.PUT_LINE('Swapping STAGING → HISTORY partition ' || v_hist_partition || '...');
    
    EXECUTE IMMEDIATE 
        'ALTER TABLE history_transactions ' ||
        'EXCHANGE PARTITION ' || v_hist_partition || ' ' ||
        'WITH TABLE staging_transactions ' ||
        'INCLUDING INDEXES ' ||
        'WITHOUT VALIDATION ' ||
        'UPDATE GLOBAL INDEXES';
    
    DBMS_OUTPUT.PUT_LINE('✓ Swap complete (STAGING → HISTORY)');
    
    -- Store for verification
    :v_partition_name := v_hist_partition;
END;
/

PROMPT ========================================
PROMPT Step 6: Final Verification
PROMPT ========================================

-- Check final row counts
DECLARE
    v_active_count NUMBER;
    v_staging_count NUMBER;
    v_history_count NUMBER;
    v_history_partition_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_active_count FROM active_transactions;
    SELECT COUNT(*) INTO v_staging_count FROM staging_transactions;
    SELECT COUNT(*) INTO v_history_count FROM history_transactions;
    
    -- Count rows in history partition
    EXECUTE IMMEDIATE 
        'SELECT COUNT(*) FROM history_transactions PARTITION (' || :v_partition_name || ')'
        INTO v_history_partition_count;
    
    DBMS_OUTPUT.PUT_LINE('FINAL COUNTS:');
    DBMS_OUTPUT.PUT_LINE('  Active:  ' || v_active_count || ' rows (partition removed)');
    DBMS_OUTPUT.PUT_LINE('  Staging: ' || v_staging_count || ' rows (empty again)');
    DBMS_OUTPUT.PUT_LINE('  History: ' || v_history_count || ' rows (partition added)');
    DBMS_OUTPUT.PUT_LINE('  History partition: ' || v_history_partition_count || ' rows');
    
    IF v_staging_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Staging should be empty after swap!');
    END IF;
    
    IF v_history_partition_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'History partition should have data!');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('✓ All validations passed!');
END;
/

PROMPT ========================================
PROMPT Step 7: Cleanup Empty Partition
PROMPT ========================================

-- Drop the now-empty partition from ACTIVE
DECLARE
    v_original_partition VARCHAR2(128);
BEGIN
    -- Get the original partition name (stored at beginning)
    SELECT partition_name
    INTO v_original_partition
    FROM user_tab_partitions
    WHERE table_name = 'ACTIVE_TRANSACTIONS'
    ORDER BY partition_position
    FETCH FIRST 1 ROW ONLY;
    
    DBMS_OUTPUT.PUT_LINE('Dropping empty partition: ' || v_original_partition);
    
    EXECUTE IMMEDIATE 
        'ALTER TABLE active_transactions DROP PARTITION ' || v_original_partition || ' ' ||
        'UPDATE GLOBAL INDEXES';
    
    DBMS_OUTPUT.PUT_LINE('✓ Empty partition dropped from ACTIVE');
END;
/

PROMPT ========================================
PROMPT Final State Summary
PROMPT ========================================

-- Partition counts
SELECT 'ACTIVE' as table_name, COUNT(*) as partition_count
FROM user_tab_partitions
WHERE table_name = 'ACTIVE_TRANSACTIONS'
UNION ALL
SELECT 'HISTORY', COUNT(*)
FROM user_tab_partitions
WHERE table_name = 'HISTORY_TRANSACTIONS';

-- Row counts per table
SELECT 'ACTIVE' as table_name, COUNT(*) as row_count
FROM active_transactions
UNION ALL
SELECT 'STAGING', COUNT(*)
FROM staging_transactions
UNION ALL
SELECT 'HISTORY', COUNT(*)
FROM history_transactions;

-- Index status verification
SELECT 
    table_name,
    index_name,
    status,
    partitioned
FROM user_indexes
WHERE table_name IN ('ACTIVE_TRANSACTIONS', 'STAGING_TRANSACTIONS', 'HISTORY_TRANSACTIONS')
ORDER BY table_name, index_name;

-- Show history partitions
SELECT 
    partition_name,
    high_value,
    num_rows,
    blocks
FROM user_tab_partitions
WHERE table_name = 'HISTORY_TRANSACTIONS'
ORDER BY partition_position DESC;

PROMPT ========================================
PROMPT Partition Swap Demo Complete!
PROMPT ========================================
PROMPT
PROMPT Summary:
PROMPT   ✓ Partition swapped from ACTIVE to STAGING
PROMPT   ✓ Data moved from STAGING to HISTORY
PROMPT   ✓ Empty partition dropped from ACTIVE
PROMPT   ✓ All indexes remain LOCAL and VALID
PROMPT   ✓ No data physically moved (metadata only)
PROMPT
PROMPT Key Benefits:
PROMPT   - Atomic operations (no data corruption risk)
PROMPT   - Fast (metadata-only, no row movement)
PROMPT   - Indexes maintained automatically
PROMPT   - Zero downtime for application
PROMPT
PROMPT Production Notes:
PROMPT   1. Always validate staging is empty before swap
PROMPT   2. Use UPDATE GLOBAL INDEXES to avoid rebuilds
PROMPT   3. Test swap in non-production first
PROMPT   4. Monitor tablespace for dropped partitions
PROMPT   5. Schedule during low-activity windows
PROMPT ========================================
