-- ==================================================================
-- CHECK IF TABLE EXISTS
-- ==================================================================
-- Usage: @validation/check_table_exists.sql <owner> <table_name>
-- ==================================================================
-- Accepts: &1 = owner, &2 = table_name
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE owner = '&1'
DEFINE table_name = '&2'

PROMPT =============================================================
PROMPT Checking if table &owner..&table_name exists
PROMPT =============================================================

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM all_tables
    WHERE owner = UPPER('&owner')
      AND table_name = UPPER('&table_name');
    
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: Table &owner..&table_name already exists!');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('To drop the existing table manually, run:');
        DBMS_OUTPUT.PUT_LINE('  DROP TABLE &owner..&table_name PURGE;');
        DBMS_OUTPUT.PUT_LINE('');
        RAISE_APPLICATION_ERROR(-20001, 'Table &owner..&table_name already exists. Drop it manually before proceeding.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ Table &owner..&table_name does not exist - proceeding with creation');
    END IF;
END;
/

PROMPT =============================================================
PROMPT Table existence check complete
PROMPT =============================================================
