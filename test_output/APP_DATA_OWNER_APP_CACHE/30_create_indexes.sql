-- ==================================================================
-- CREATE INDEXES: APP_DATA_OWNER.APP_CACHE_NEW
-- ==================================================================
-- Generated: 2025-10-25 16:33:49
-- Source: APP_DATA_OWNER.APP_CACHE
-- Index count: 1
-- Parallel degree: 4
-- ==================================================================

SET ECHO ON
SET TIMING ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT Step 30: Creating Indexes
PROMPT ================================================================
PROMPT Target: APP_DATA_OWNER.APP_CACHE_NEW
PROMPT Indexes to create: 1
PROMPT Estimated time: < 1 minute
PROMPT ================================================================

-- Store original parallel settings
VARIABLE v_original_parallel_degree NUMBER
VARIABLE v_original_parallel_policy VARCHAR2(20)

BEGIN
    -- Store current parallel degree
    SELECT value INTO :v_original_parallel_degree 
    FROM v$parameter 
    WHERE name = 'parallel_degree';
    
    -- Store current parallel policy
    SELECT value INTO :v_original_parallel_policy 
    FROM v$parameter 
    WHERE name = 'parallel_degree_policy';
    
    DBMS_OUTPUT.PUT_LINE('Original parallel degree: ' || :v_original_parallel_degree);
    DBMS_OUTPUT.PUT_LINE('Original parallel policy: ' || :v_original_parallel_policy);
END;
/

-- Set parallel DDL for index creation only
ALTER SESSION FORCE PARALLEL DDL PARALLEL 4;
-- Index: SYS_C008304 (NORMAL)
PROMPT Creating index SYS_C008304_NEW...
CREATE UNIQUE INDEX "APP_DATA_OWNER"."SYS_C008304_NEW"
ON "APP_DATA_OWNER"."APP_CACHE_NEW" (CACHE_KEY)TABLESPACE USERSPCTFREE 10INITRANS 2MAXTRANS 255NOPARALLEL;
-- Restore original parallel settings
BEGIN
    DBMS_OUTPUT.PUT_LINE('Restoring original parallel settings...');
    DBMS_OUTPUT.PUT_LINE('Restoring parallel degree: ' || :v_original_parallel_degree);
    DBMS_OUTPUT.PUT_LINE('Restoring parallel policy: ' || :v_original_parallel_policy);
END;
/

-- Restore original parallel degree
ALTER SESSION FORCE PARALLEL DDL PARALLEL :v_original_parallel_degree;

-- Restore original parallel policy
ALTER SESSION SET PARALLEL_DEGREE_POLICY = :v_original_parallel_policy;

PROMPT ✓ Step 30 Complete: 1 index(es) created