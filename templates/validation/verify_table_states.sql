-- ==================================================================
-- VERIFY TABLE STATES
-- ==================================================================
-- Usage: @validation/verify_table_states.sql <owner> <table_name1> [table_name2] [table_name3]
-- ==================================================================
-- This script verifies the current state of specified tables by showing:
-- 1. Table existence
-- 2. Partitioning status
-- 3. Table status
-- 4. Basic table properties
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE owner = '&1'
DEFINE table_name1 = '&2'
DEFINE table_name2 = '&3'
DEFINE table_name3 = '&4'

PROMPT =============================================================
PROMPT VERIFY TABLE STATES
PROMPT =============================================================
PROMPT Owner: &owner
PROMPT Tables: &table_name1 &table_name2 &table_name3
PROMPT =============================================================

DECLARE
    v_table_count NUMBER := 0;
    v_table_exists NUMBER;
    v_table_list VARCHAR2(1000) := '';
BEGIN
    -- Build table list for display
    v_table_list := UPPER('&table_name1');
    IF '&table_name2' IS NOT NULL AND '&table_name2' != '' THEN
        v_table_list := v_table_list || ', ' || UPPER('&table_name2');
    END IF;
    IF '&table_name3' IS NOT NULL AND '&table_name3' != '' THEN
        v_table_list := v_table_list || ', ' || UPPER('&table_name3');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('Verifying table states for: ' || v_table_list);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Check each table exists and get count
    FOR table_rec IN (
        SELECT table_name, partitioned, status, num_rows, last_analyzed
        FROM all_tables
        WHERE owner = UPPER('&owner')
          AND table_name IN (
              UPPER('&table_name1'),
              CASE WHEN '&table_name2' IS NOT NULL AND '&table_name2' != '' THEN UPPER('&table_name2') END,
              CASE WHEN '&table_name3' IS NOT NULL AND '&table_name3' != '' THEN UPPER('&table_name3') END
          )
        ORDER BY table_name
    ) LOOP
        v_table_count := v_table_count + 1;
        DBMS_OUTPUT.PUT_LINE('Table: ' || table_rec.table_name);
        DBMS_OUTPUT.PUT_LINE('  Partitioned: ' || table_rec.partitioned);
        DBMS_OUTPUT.PUT_LINE('  Status: ' || table_rec.status);
        DBMS_OUTPUT.PUT_LINE('  Rows: ' || NVL(TO_CHAR(table_rec.num_rows), 'Not analyzed'));
        DBMS_OUTPUT.PUT_LINE('  Last Analyzed: ' || NVL(TO_CHAR(table_rec.last_analyzed, 'YYYY-MM-DD HH24:MI:SS'), 'Never'));
        DBMS_OUTPUT.PUT_LINE('');
    END LOOP;
    
    -- Check for missing tables
    IF v_table_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('⚠ No tables found matching the specified criteria');
    ELSIF v_table_count < 
        CASE 
            WHEN '&table_name3' IS NOT NULL AND '&table_name3' != '' THEN 3
            WHEN '&table_name2' IS NOT NULL AND '&table_name2' != '' THEN 2
            ELSE 1
        END THEN
        DBMS_OUTPUT.PUT_LINE('⚠ Some tables were not found');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ All specified tables found');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=============================================================');
    DBMS_OUTPUT.PUT_LINE('Table state verification complete');
    DBMS_OUTPUT.PUT_LINE('=============================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FATAL ERROR in table state verification: ' || SQLERRM);
        RAISE;
END;
/

-- Display table information in a formatted way
PROMPT =============================================================
PROMPT TABLE STATE SUMMARY
PROMPT =============================================================

SELECT 
    table_name,
    partitioned,
    status,
    NVL(TO_CHAR(num_rows), 'Not analyzed') as row_count,
    NVL(TO_CHAR(last_analyzed, 'YYYY-MM-DD HH24:MI:SS'), 'Never') as last_analyzed
FROM all_tables
WHERE owner = UPPER('&owner')
  AND table_name IN (
      UPPER('&table_name1'),
      CASE WHEN '&table_name2' IS NOT NULL AND '&table_name2' != '' THEN UPPER('&table_name2') END,
      CASE WHEN '&table_name3' IS NOT NULL AND '&table_name3' != '' THEN UPPER('&table_name3') END
  )
ORDER BY table_name;

PROMPT =============================================================
PROMPT Table state verification complete
PROMPT =============================================================
