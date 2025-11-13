-- ============================================================================
-- Partition Swap Package
-- ============================================================================
-- Purpose: Atomic partition swap from Active → History via Staging
-- Usage: Standard user privileges only
-- Pattern: Metadata-only swap (no physical data movement)
-- Version: 1.0
-- ============================================================================

CREATE OR REPLACE PACKAGE partition_swap_pkg AS
    
    -- Main procedure: Swap oldest partition atomically
    PROCEDURE swap_oldest_partition(
        p_active_table   IN VARCHAR2,
        p_staging_table  IN VARCHAR2,
        p_history_table  IN VARCHAR2
    );
    
END partition_swap_pkg;
/

CREATE OR REPLACE PACKAGE BODY partition_swap_pkg AS
    
    -- ========================================================================
    -- Swap oldest partition: ACTIVE → STAGING → HISTORY
    -- ========================================================================
    PROCEDURE swap_oldest_partition(
        p_active_table   IN VARCHAR2,
        p_staging_table  IN VARCHAR2,
        p_history_table  IN VARCHAR2
    ) IS
        v_partition_name VARCHAR2(128);
        v_high_value CLOB;
        v_hist_partition VARCHAR2(128);
        v_staging_count NUMBER;
        v_rows_moved NUMBER;
        
    BEGIN
        logging_pkg.info('PARTITION_SWAP_PKG', 'SWAP_OLDEST_PARTITION',
            'Starting swap: ' || p_active_table || ' → ' || p_history_table);
        
        -- Validate inputs
        IF p_active_table IS NULL OR p_staging_table IS NULL OR p_history_table IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'All table parameters are required');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('Partition Swap: ' || p_active_table || ' → ' || p_history_table);
        DBMS_OUTPUT.PUT_LINE('');
        
        -- Validate staging is empty (critical for atomic swap)
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_staging_table INTO v_staging_count;
        IF v_staging_count > 0 THEN
            logging_pkg.error('PARTITION_SWAP_PKG', 'SWAP_OLDEST_PARTITION',
                'Staging table not empty: ' || v_staging_count || ' rows found',
                -20002, 'Pre-swap validation failed');
            RAISE_APPLICATION_ERROR(-20002, 
                'Staging table must be empty. Found ' || v_staging_count || ' rows');
        END IF;
        
        -- Identify oldest partition
        BEGIN
            SELECT partition_name, high_value
            INTO v_partition_name, v_high_value
            FROM all_tab_partitions
            WHERE table_owner = USER
            AND table_name = UPPER(p_active_table)
            ORDER BY partition_position
            FETCH FIRST 1 ROW ONLY;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                logging_pkg.error('PARTITION_SWAP_PKG', 'SWAP_OLDEST_PARTITION',
                    'No partitions found in ' || p_active_table,
                    -20003, 'Partition lookup failed');
                RAISE_APPLICATION_ERROR(-20003, 
                    'No partitions found in ' || p_active_table);
        END;
        
        logging_pkg.info('PARTITION_SWAP_PKG', 'SWAP_OLDEST_PARTITION',
            'Swapping partition: ' || v_partition_name);
        
        DBMS_OUTPUT.PUT_LINE('Swapping partition: ' || v_partition_name);
        
        -- Step 1: ACTIVE partition → STAGING (atomic metadata swap)
        EXECUTE IMMEDIATE 
            'ALTER TABLE ' || p_active_table || 
            ' EXCHANGE PARTITION ' || v_partition_name || 
            ' WITH TABLE ' || p_staging_table || 
            ' INCLUDING INDEXES WITHOUT VALIDATION';
        
        -- Verify rows moved to staging
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_staging_table INTO v_rows_moved;
        DBMS_OUTPUT.PUT_LINE('  → Staging: ' || v_rows_moved || ' rows');
        
        -- Step 2: Create matching partition in HISTORY
        v_hist_partition := 'P_HIST_' || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS');
        
        EXECUTE IMMEDIATE 
            'ALTER TABLE ' || p_history_table || 
            ' ADD PARTITION ' || v_hist_partition || 
            ' VALUES LESS THAN (' || v_high_value || ')';
        
        -- Step 3: STAGING → HISTORY partition (atomic metadata swap)
        EXECUTE IMMEDIATE 
            'ALTER TABLE ' || p_history_table || 
            ' EXCHANGE PARTITION ' || v_hist_partition || 
            ' WITH TABLE ' || p_staging_table || 
            ' INCLUDING INDEXES WITHOUT VALIDATION';
        
        DBMS_OUTPUT.PUT_LINE('  → History: ' || v_hist_partition);
        
        -- Step 4: Drop empty partition from ACTIVE
        EXECUTE IMMEDIATE 
            'ALTER TABLE ' || p_active_table || 
            ' DROP PARTITION ' || v_partition_name;
        
        logging_pkg.info('PARTITION_SWAP_PKG', 'SWAP_OLDEST_PARTITION',
            'SUCCESS: Moved ' || v_rows_moved || ' rows from ' || v_partition_name || ' to ' || v_hist_partition);
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Moved ' || v_rows_moved || ' rows to history');
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Log error with full context
            logging_pkg.error('PARTITION_SWAP_PKG', 'SWAP_OLDEST_PARTITION',
                'Swap failed - Table: ' || p_active_table || ', Partition: ' || v_partition_name,
                SQLCODE, SQLERRM);
            
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('ERROR during partition swap:');
            DBMS_OUTPUT.PUT_LINE('  Table: ' || p_active_table);
            DBMS_OUTPUT.PUT_LINE('  Partition: ' || v_partition_name);
            DBMS_OUTPUT.PUT_LINE('  Message: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('  SQLCODE: ' || SQLCODE);
            
            -- Re-raise to caller
            RAISE;
    END swap_oldest_partition;
    
END partition_swap_pkg;
/
