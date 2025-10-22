-- ==================================================================
-- MASTER SCRIPT 1: Structure Creation and Initial Load
-- ==================================================================
-- Table: MYSCHEMA.IE_PC_OFFER_IN
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
PROMPT Table: MYSCHEMA.IE_PC_OFFER_IN
PROMPT Target: MYSCHEMA.IE_PC_OFFER_IN_NEW
PROMPT Size: 45.23 GB
PROMPT Rows: 12,500,000
PROMPT Estimated Total Time: ~8.5 hours
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
