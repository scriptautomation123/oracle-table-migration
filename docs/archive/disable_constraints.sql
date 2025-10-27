-- ==================================================================
-- DISABLE CONSTRAINTS (Generic)
-- ==================================================================
-- Purpose: Disable all constraints on a table for performance optimization
-- Usage: @validation/disable_constraints.sql <owner> <table_name>
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT Disabling Constraints
PROMPT ================================================================
PROMPT Table: &1.&2
PROMPT ================================================================

DECLARE
    v_constraint_count NUMBER := 0;
BEGIN
    FOR c IN (
        SELECT constraint_name, constraint_type
        FROM all_constraints
        WHERE owner = UPPER('&1')
          AND table_name = UPPER('&2')
          AND constraint_type IN ('U', 'P', 'R', 'C')
          AND status = 'ENABLED'
        ORDER BY 
            CASE constraint_type
                WHEN 'R' THEN 1  -- Foreign keys first
                WHEN 'C' THEN 2  -- Check constraints
                WHEN 'U' THEN 3  -- Unique
                WHEN 'P' THEN 4  -- Primary key last
            END
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'ALTER TABLE &1.&2 DISABLE CONSTRAINT ' || c.constraint_name;
            v_constraint_count := v_constraint_count + 1;
            DBMS_OUTPUT.PUT_LINE('  Disabled ' || 
                CASE c.constraint_type
                    WHEN 'P' THEN 'PRIMARY KEY'
                    WHEN 'U' THEN 'UNIQUE'
                    WHEN 'R' THEN 'FOREIGN KEY'
                    WHEN 'C' THEN 'CHECK'
                END || ': ' || c.constraint_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('  WARNING: Could not disable ' || c.constraint_name || ': ' || SQLERRM);
        END;
    END LOOP;
    
    IF v_constraint_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('  No constraints to disable');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ Disabled ' || v_constraint_count || ' constraint(s)');
    END IF;
END;
/

PROMPT
PROMPT ================================================================
PROMPT Constraint Disable Complete
PROMPT ================================================================
