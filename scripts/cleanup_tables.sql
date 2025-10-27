-- ==========================================
-- Generic Table Cleanup Script
-- ==========================================
-- Purpose: DROP, BACKUP (rename), or SKIP a single table
-- Usage:
--   Interactive: @cleanup_tables.sql TABLE_NAME
--   With action: DEFINE cleanup_action=D; @cleanup_tables.sql TABLE_NAME
--   From wrapper: echo "B" | sqlplus ... @cleanup_tables.sql TABLE_NAME
--
-- Parameters:
--   &1 = Table name (required)
--   cleanup_action = D (DROP), B (BACKUP/rename), S (SKIP) - default: S
--
-- Examples:
--   @cleanup_tables.sql SALES_HISTORY
--   echo "D" | sqlplus ... @cleanup_tables.sql CUSTOMER_REGIONS
--   
-- For multiple tables, call this script multiple times:
--   for table in SALES_HISTORY CUSTOMER_REGIONS; do
--     echo "D" | sqlplus ... @cleanup_tables.sql $table
--   done
-- ==========================================
SET SERVEROUTPUT ON
SET VERIFY OFF

-- Prompt for action if not already defined
PROMPT =========================================================
PROMPT Generic Table Cleanup Script
PROMPT =========================================================
PROMPT Options:
PROMPT   D = DROP all tables (permanent deletion)
PROMPT   B = BACKUP (rename to table_OLD, table_OLD1, etc.)
PROMPT   S = SKIP (preserve existing tables)
PROMPT =========================================================
ACCEPT cleanup_action CHAR DEFAULT 'S' PROMPT 'Choose action [D/B/S] (default: S): '

DECLARE
    v_action VARCHAR2(1) := UPPER('&cleanup_action');
    v_table_exists NUMBER;
    v_backup_name VARCHAR2(128);
    v_counter NUMBER;
    v_max_retries CONSTANT NUMBER := 20;
    v_table_name VARCHAR2(128) := UPPER(TRIM('&1'));
    
BEGIN
    -- Validate table name provided
    IF v_table_name IS NULL OR LENGTH(v_table_name) = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: No table name specified');
        DBMS_OUTPUT.PUT_LINE('Usage: @cleanup_tables.sql TABLE_NAME');
        RETURN;
    END IF;
    
    -- Validate action
    IF v_action NOT IN ('D', 'B', 'S') THEN
        DBMS_OUTPUT.PUT_LINE('Invalid action: ' || v_action || ' - defaulting to SKIP');
        v_action := 'S';
    END IF;
    
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE('Processing table: ' || v_table_name);
    DBMS_OUTPUT.PUT_LINE('Selected action: ' || 
        CASE v_action 
            WHEN 'D' THEN 'DROP (permanent deletion)'
            WHEN 'B' THEN 'BACKUP (rename with version suffix)'
            WHEN 'S' THEN 'SKIP (preserve existing table)'
        END);
    DBMS_OUTPUT.PUT_LINE('=========================================================');
    
    IF v_action = 'S' THEN
        DBMS_OUTPUT.PUT_LINE('Skipping cleanup - table will be preserved if it exists');
        DBMS_OUTPUT.PUT_LINE(' ');
        RETURN;
    END IF;
    
    -- Check if table exists
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables
    WHERE table_name = v_table_name;
    
    IF v_table_exists = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Table ' || v_table_name || ' does not exist - nothing to do');
        DBMS_OUTPUT.PUT_LINE(' ');
        RETURN;
    END IF;
    
    -- DROP action
    IF v_action = 'D' THEN
        EXECUTE IMMEDIATE 'DROP TABLE ' || v_table_name || ' CASCADE CONSTRAINTS PURGE';
        DBMS_OUTPUT.PUT_LINE('✓ Dropped: ' || v_table_name);
        
    -- BACKUP action (rename with smart versioning)
    ELSIF v_action = 'B' THEN
        v_counter := 0;
        v_backup_name := v_table_name || '_OLD';
        
        -- Find available backup name (table_OLD, table_OLD1, table_OLD2, etc.)
        LOOP
            SELECT COUNT(*) INTO v_table_exists
            FROM user_tables
            WHERE table_name = v_backup_name;
            
            EXIT WHEN v_table_exists = 0;
            
            v_counter := v_counter + 1;
            v_backup_name := v_table_name || '_OLD' || v_counter;
            
            IF v_counter > v_max_retries THEN
                RAISE_APPLICATION_ERROR(-20001, 
                    'Too many backup versions exist for ' || v_table_name || 
                    ' (max: ' || v_max_retries || ')');
            END IF;
        END LOOP;
        
        -- Rename table to backup name
        EXECUTE IMMEDIATE 'RENAME ' || v_table_name || ' TO ' || v_backup_name;
        DBMS_OUTPUT.PUT_LINE('✓ Backed up: ' || v_table_name || ' → ' || v_backup_name);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE(' ');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Fatal error in cleanup: ' || SQLERRM);
        RAISE;
END;
/

SET VERIFY ON
