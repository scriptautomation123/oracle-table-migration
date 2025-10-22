-- ==================================================================
-- CREATE INDEXES: MYSCHEMA.IE_PC_OFFER_IN_NEW
-- ==================================================================
-- Generated: 2025-10-22 01:30:55
-- Source: MYSCHEMA.IE_PC_OFFER_IN
-- Index count: 5
-- Parallel degree: 4
-- ==================================================================

SET ECHO ON
SET TIMING ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT Step 30: Creating Indexes
PROMPT ================================================================
PROMPT Target: MYSCHEMA.IE_PC_OFFER_IN_NEW
PROMPT Indexes to create: 5
PROMPT Estimated time: ~40 minutes
PROMPT ================================================================

-- Enable parallel DDL
ALTER SESSION FORCE PARALLEL DDL PARALLEL 4;

-- Index definitions will be generated dynamically
-- 5 index definitions to be generated

-- Reset parallel settings
ALTER SESSION FORCE PARALLEL DDL;

PROMPT ✓ Step 30 Complete: 5 index(es) created
