-- ==================================================================
-- VALIDATE TABLE STRUCTURE
-- ==================================================================
-- Usage: @validation/validate_table_structure.sql <owner> <table_name>
-- ==================================================================
-- Accepts: &1 = owner, &2 = table_name
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE owner = '&1'
DEFINE table_name = '&2'

PROMPT =============================================================
PROMPT Validating table structure for &owner..&table_name
PROMPT =============================================================

DECLARE
    v_table_exists NUMBER;
    v_partitioned VARCHAR2(3);
    v_part_type VARCHAR2(30);
    v_subpart_type VARCHAR2(30);
    v_interval VARCHAR2(1000);
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM all_tables
    WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name');
    
    IF v_table_exists = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Table was not created successfully!');
        RAISE_APPLICATION_ERROR(-20001, 'Table creation failed');
    END IF;
    
    SELECT partitioned INTO v_partitioned
    FROM all_tables
    WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name');
    
    DBMS_OUTPUT.PUT_LINE('Table Name: ' || '&owner.' || '.' || '&table_name.');
    DBMS_OUTPUT.PUT_LINE('Partitioned: ' || v_partitioned);
    
    IF v_partitioned = 'YES' THEN
        SELECT partitioning_type, subpartitioning_type, NVL(interval, 'N/A')
        INTO v_part_type, v_subpart_type, v_interval
        FROM all_part_tables
        WHERE owner = UPPER('&owner') AND table_name = UPPER('&table_name');
        
        DBMS_OUTPUT.PUT_LINE('Partition Type: ' || v_part_type);
        DBMS_OUTPUT.PUT_LINE('Subpartition Type: ' || NVL(v_subpart_type, 'NONE'));
        DBMS_OUTPUT.PUT_LINE('Interval: ' || v_interval);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('✓ Table created and verified successfully!');
END;
/

PROMPT =============================================================
PROMPT Validation complete
PROMPT =============================================================
