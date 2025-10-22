-- ==================================================================
-- ENABLE CONSTRAINTS (Generic)
-- ==================================================================
-- Purpose: Re-enable all constraints on a table after data load
-- Usage: @validation/enable_constraints.sql <owner> <table_name>
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT Re-enabling Constraints
PROMPT ================================================================
PROMPT Table: &1.&2
PROMPT ================================================================

DECLARE
    v_constraint_count NUMBER := 0;
    v_failed_count NUMBER := 0;
BEGIN
    FOR c IN (
        SELECT constraint_name, constraint_type
        FROM all_constraints
        WHERE owner = UPPER('&1')
          AND table_name = UPPER('&2')
          AND constraint_type IN ('U', 'P', 'R', 'C')
          AND status = 'DISABLED'
        ORDER BY 
            CASE constraint_type
                WHEN 'P' THEN 1  -- Primary key first
                WHEN 'U' THEN 2  -- Unique
                WHEN 'C' THEN 3  -- Check
                WHEN 'R' THEN 4  -- Foreign keys last
            END
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'ALTER TABLE &1.&2 ENABLE NOVALIDATE CONSTRAINT ' || c.constraint_name;
            v_constraint_count := v_constraint_count + 1;
            DBMS_OUTPUT.PUT_LINE('  ✓ Enabled ' || c.constraint_name);
        EXCEPTION
            WHEN OTHERS THEN
                v_failed_count := v_failed_count + 1;
                DBMS_OUTPUT.PUT_LINE('  ✗ Failed to enable ' || c.constraint_name || ': ' || SQLERRM);
        END;
    END LOOP;
    
    IF v_constraint_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('✓ Re-enabled ' || v_constraint_count || ' constraint(s)');
        IF v_failed_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('✗ Failed to enable ' || v_failed_count || ' constraint(s)');
            DBMS_OUTPUT.PUT_LINE('  Manual intervention may be required');
        END IF;
    ELSE
        DBMS_OUTPUT.PUT_LINE('  No disabled constraints found');
    END IF;
END;
/

PROMPT
PROMPT ================================================================
PROMPT Constraint Enable Complete
PROMPT ================================================================
