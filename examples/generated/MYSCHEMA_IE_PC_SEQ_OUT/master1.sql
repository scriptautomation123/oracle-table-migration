-- ==================================================================
-- MASTER SCRIPT 1: Structure Creation and Initial Load
-- ==================================================================
-- Table: MYSCHEMA.IE_PC_SEQ_OUT
-- Generated: 2025-10-22 01:30:55
-- ==================================================================
-- This script executes:
--   Step 10: Create new partitioned table
--   Step 20: Initial data load
--   Step 30: Create indexes
--   Step 40: Delta load (optional)
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON
SET FEEDBACK ON

WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT ================================================================
PROMPT MASTER SCRIPT 1: Structure and Initial Load
PROMPT ================================================================
PROMPT Table: MYSCHEMA.IE_PC_SEQ_OUT
PROMPT Target: MYSCHEMA.IE_PC_SEQ_OUT_NEW
PROMPT Size: 12.50 GB
PROMPT Rows: 3,200,000
PROMPT Estimated Total Time: ~2.3 hours
PROMPT ================================================================

-- Execute Step 10: Create table structure
@@ 10_create_table.sql

-- Execute Step 20: Initial data load  
@@ 20_data_load.sql

-- Execute Step 30: Create indexes
@@ 30_create_indexes.sql


PROMPT
PROMPT ================================================================
PROMPT MASTER SCRIPT 1 COMPLETE
PROMPT ================================================================
PROMPT Status: SUCCESS ✓
PROMPT Next: Review results, then run master2.sql for cutover
PROMPT ================================================================
