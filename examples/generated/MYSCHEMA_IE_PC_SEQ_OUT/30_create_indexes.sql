-- ==================================================================
-- CREATE INDEXES: MYSCHEMA.IE_PC_SEQ_OUT_NEW
-- ==================================================================
-- Generated: 2025-10-22 01:30:55
-- Source: MYSCHEMA.IE_PC_SEQ_OUT
-- Index count: 3
-- Parallel degree: 2
-- ==================================================================

SET ECHO ON
SET TIMING ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT Step 30: Creating Indexes
PROMPT ================================================================
PROMPT Target: MYSCHEMA.IE_PC_SEQ_OUT_NEW
PROMPT Indexes to create: 3
PROMPT Estimated time: ~11 minutes
PROMPT ================================================================

-- Enable parallel DDL
ALTER SESSION FORCE PARALLEL DDL PARALLEL 2;

-- Index definitions will be generated dynamically
-- 3 index definitions to be generated

-- Reset parallel settings
ALTER SESSION FORCE PARALLEL DDL;

PROMPT ✓ Step 30 Complete: 3 index(es) created
