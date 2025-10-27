-- ==================================================================
-- CHECK ACTIVE SESSIONS USING TABLES
-- ==================================================================
-- Usage: @validation/check_active_sessions.sql <owner> <table_name1> [table_name2] [table_name3] ...
-- ==================================================================
-- Accepts: &1 = owner, &2 = table_name1, &3 = table_name2, etc.
-- ==================================================================
-- This script checks for active sessions that are using the specified tables
-- and raises an error if any are found, preventing unsafe operations
-- ==================================================================
SET SERVEROUTPUT ON
SET VERIFY OFF

DEFINE owner = '&1'
DEFINE table_name1 = '&2'
DEFINE table_name2 = '&3'
DEFINE table_name3 = '&4'

PROMPT =============================================================
PROMPT Checking for active sessions using tables
PROMPT Owner: &owner
PROMPT Tables: &table_name1 &table_name2 &table_name3
PROMPT =============================================================

DECLARE
    v_active_sessions NUMBER := 0;
    v_session_details VARCHAR2(4000) := '';
    v_table_list VARCHAR2(1000) := '';
    v_session_info VARCHAR2(4000);
BEGIN
    -- Build table list for display
    v_table_list := UPPER('&table_name1');
    IF '&table_name2' IS NOT NULL AND '&table_name2' != '' THEN
        v_table_list := v_table_list || ', ' || UPPER('&table_name2');
    END IF;
    IF '&table_name3' IS NOT NULL AND '&table_name3' != '' THEN
        v_table_list := v_table_list || ', ' || UPPER('&table_name3');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('Checking for active sessions using tables: ' || v_table_list);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Check for active sessions using the tables
    SELECT COUNT(*) INTO v_active_sessions
    FROM v$session s, v$sqlarea sa
    WHERE s.sql_id = sa.sql_id
      AND (
          UPPER(sa.sql_text) LIKE '%' || UPPER('&table_name1') || '%'
          OR ('&table_name2' IS NOT NULL AND '&table_name2' != '' AND UPPER(sa.sql_text) LIKE '%' || UPPER('&table_name2') || '%')
          OR ('&table_name3' IS NOT NULL AND '&table_name3' != '' AND UPPER(sa.sql_text) LIKE '%' || UPPER('&table_name3') || '%')
      )
      AND s.status = 'ACTIVE'
      AND s.username IS NOT NULL;
    
    IF v_active_sessions > 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Found ' || v_active_sessions || ' active session(s) using the tables');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Active session details:');
        
        -- Get detailed session information
        FOR session_rec IN (
            SELECT s.sid, s.serial#, s.username, s.program, s.machine, s.status,
                   sa.sql_text, s.logon_time
            FROM v$session s, v$sqlarea sa
            WHERE s.sql_id = sa.sql_id
              AND (
                  UPPER(sa.sql_text) LIKE '%' || UPPER('&table_name1') || '%'
                  OR ('&table_name2' IS NOT NULL AND '&table_name2' != '' AND UPPER(sa.sql_text) LIKE '%' || UPPER('&table_name2') || '%')
                  OR ('&table_name3' IS NOT NULL AND '&table_name3' != '' AND UPPER(sa.sql_text) LIKE '%' || UPPER('&table_name3') || '%')
              )
              AND s.status = 'ACTIVE'
              AND s.username IS NOT NULL
            ORDER BY s.logon_time
        ) LOOP
            v_session_info := '  SID: ' || session_rec.sid || 
                            ', Serial#: ' || session_rec.serial# ||
                            ', User: ' || NVL(session_rec.username, 'UNKNOWN') ||
                            ', Program: ' || NVL(session_rec.program, 'UNKNOWN') ||
                            ', Machine: ' || NVL(session_rec.machine, 'UNKNOWN') ||
                            ', Status: ' || session_rec.status;
            DBMS_OUTPUT.PUT_LINE(v_session_info);
            
            -- Show first 100 characters of SQL text
            IF LENGTH(session_rec.sql_text) > 100 THEN
                DBMS_OUTPUT.PUT_LINE('    SQL: ' || SUBSTR(session_rec.sql_text, 1, 100) || '...');
            ELSE
                DBMS_OUTPUT.PUT_LINE('    SQL: ' || session_rec.sql_text);
            END IF;
            DBMS_OUTPUT.PUT_LINE('');
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('RECOMMENDATION: Wait for these sessions to complete before proceeding');
        DBMS_OUTPUT.PUT_LINE('or terminate them if they are safe to stop.');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('To terminate a session (use with caution):');
        DBMS_OUTPUT.PUT_LINE('  ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE;');
        DBMS_OUTPUT.PUT_LINE('');
        
        RAISE_APPLICATION_ERROR(-20001, 
            'Cannot proceed: ' || v_active_sessions || 
            ' active session(s) are using the tables. Please wait for sessions to complete or terminate them safely.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ No active sessions found using the specified tables');
        DBMS_OUTPUT.PUT_LINE('✓ Safe to proceed with table operations');
    END IF;
END;
/

PROMPT =============================================================
PROMPT Active session check complete
PROMPT =============================================================
