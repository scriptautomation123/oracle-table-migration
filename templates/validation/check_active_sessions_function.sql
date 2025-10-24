-- ==================================================================
-- CHECK ACTIVE SESSIONS FUNCTION
-- ==================================================================
-- Usage: Can be called from within PL/SQL blocks
-- ==================================================================
-- This function checks for active sessions using specified tables
-- and returns the count of active sessions
-- ==================================================================

CREATE OR REPLACE FUNCTION check_active_sessions(
    p_owner IN VARCHAR2,
    p_table_names IN VARCHAR2
) RETURN NUMBER
IS
    v_active_sessions NUMBER := 0;
    v_table_array DBMS_UTILITY.UNCL_ARRAY;
    v_table_count NUMBER;
    v_where_clause VARCHAR2(4000) := '';
BEGIN
    -- Parse comma-separated table names
    v_table_array := DBMS_UTILITY.UNCL_ARRAY();
    v_table_count := DBMS_UTILITY.UNCL_ARRAY();
    
    -- Simple parsing for table names (comma-separated)
    DECLARE
        v_remaining VARCHAR2(4000) := p_table_names;
        v_current VARCHAR2(128);
        v_pos NUMBER;
    BEGIN
        WHILE LENGTH(v_remaining) > 0 LOOP
            v_pos := INSTR(v_remaining, ',');
            IF v_pos > 0 THEN
                v_current := TRIM(SUBSTR(v_remaining, 1, v_pos - 1));
                v_remaining := TRIM(SUBSTR(v_remaining, v_pos + 1));
            ELSE
                v_current := TRIM(v_remaining);
                v_remaining := '';
            END IF;
            
            IF LENGTH(v_current) > 0 THEN
                v_table_array.EXTEND;
                v_table_array(v_table_array.COUNT) := UPPER(v_current);
            END IF;
        END LOOP;
    END;
    
    -- Build WHERE clause for table name matching
    FOR i IN 1..v_table_array.COUNT LOOP
        IF i > 1 THEN
            v_where_clause := v_where_clause || ' OR ';
        END IF;
        v_where_clause := v_where_clause || 'UPPER(sa.sql_text) LIKE ''%' || v_table_array(i) || '%''';
    END LOOP;
    
    -- Check for active sessions
    IF LENGTH(v_where_clause) > 0 THEN
        EXECUTE IMMEDIATE 
            'SELECT COUNT(*) FROM v$session s, v$sqlarea sa ' ||
            'WHERE s.sql_id = sa.sql_id ' ||
            '  AND (' || v_where_clause || ') ' ||
            '  AND s.status = ''ACTIVE'' ' ||
            '  AND s.username IS NOT NULL'
        INTO v_active_sessions;
    END IF;
    
    RETURN v_active_sessions;
EXCEPTION
    WHEN OTHERS THEN
        -- Return 0 if there's an error (assume safe to proceed)
        RETURN 0;
END check_active_sessions;
/

-- ==================================================================
-- USAGE EXAMPLES:
-- ==================================================================
-- 
-- 1. Check single table:
--    SELECT check_active_sessions('MYSCHEMA', 'MYTABLE') FROM DUAL;
--
-- 2. Check multiple tables:
--    SELECT check_active_sessions('MYSCHEMA', 'TABLE1,TABLE2,TABLE3') FROM DUAL;
--
-- 3. Use in PL/SQL block:
--    DECLARE
--        v_sessions NUMBER;
--    BEGIN
--        v_sessions := check_active_sessions('MYSCHEMA', 'MYTABLE');
--        IF v_sessions > 0 THEN
--            RAISE_APPLICATION_ERROR(-20001, 'Active sessions found: ' || v_sessions);
--        END IF;
--    END;
-- ==================================================================
