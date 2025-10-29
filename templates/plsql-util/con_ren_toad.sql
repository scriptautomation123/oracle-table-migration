-- ==================================================================
-- CONSTRAINT RENAME GENERATOR - OPTIMIZED VERSION 3.0
-- ==================================================================
-- Purpose: Generate SQL to rename constraints after table rename
-- Author: Database Team
-- Version: 3.0
-- Compatible: Oracle 11g+
-- ==================================================================
-- Features:
--   - Uses only ALL_* views (no DBA privileges required)
--   - Single efficient query for constraint collection
--   - Smart naming with collision detection
--   - Generates SQL only (no execution)
--   - Comprehensive validation and error handling
--   - Detailed output with rollback scripts
-- ==================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF
SET PAGESIZE 0
SET LINESIZE 300
SET FEEDBACK OFF
SET HEADING OFF
SET TRIMSPOOL ON

DECLARE
    -- ==================================================================
    -- CONFIGURATION SECTION - MODIFY THESE VALUES
    -- ==================================================================
    c_schema        CONSTANT VARCHAR2(128) := UPPER('&schema_name');        -- Schema name (will prompt)
    c_old_table     CONSTANT VARCHAR2(128) := UPPER('&old_table_name');     -- Old table name (will prompt)
    c_new_table     CONSTANT VARCHAR2(128) := UPPER('&new_table_name');     -- New table name (will prompt)
    c_prefix        VARCHAR2(128)          := UPPER('&constraint_prefix');   -- Constraint prefix (will prompt)
    
    -- ==================================================================
    -- SYSTEM CONSTANTS
    -- ==================================================================
    c_oracle_max_len CONSTANT PLS_INTEGER := 30;     -- Oracle 11g identifier limit
    c_version        CONSTANT VARCHAR2(10) := '3.0';
    c_line_width     CONSTANT PLS_INTEGER := 80;
    c_indent         CONSTANT VARCHAR2(4) := '  ';
    
    -- Constraint type constants for readability
    c_type_pk        CONSTANT CHAR(1) := 'P';
    c_type_uk        CONSTANT CHAR(1) := 'U';
    c_type_fk        CONSTANT CHAR(1) := 'R';
    c_type_check     CONSTANT CHAR(1) := 'C';
    
    -- ==================================================================
    -- TYPE DEFINITIONS
    -- ==================================================================
    TYPE t_constraint_info IS RECORD (
        constraint_name    VARCHAR2(128),
        constraint_type    CHAR(1),
        new_name          VARCHAR2(128),
        column_list       VARCHAR2(4000),
        ref_owner         VARCHAR2(128),
        ref_table         VARCHAR2(128),
        ref_constraint    VARCHAR2(128),
        delete_rule       VARCHAR2(30),
        status           VARCHAR2(30),
        deferrable       VARCHAR2(30),
        deferred         VARCHAR2(30),
        validated        VARCHAR2(30),
        generated        VARCHAR2(30),
        bad              VARCHAR2(30),
        rely             VARCHAR2(30)
    );
    
    TYPE t_constraint_array IS TABLE OF t_constraint_info INDEX BY PLS_INTEGER;
    
    TYPE t_name_tracker IS TABLE OF BOOLEAN INDEX BY VARCHAR2(128);
    
    -- ==================================================================
    -- VARIABLES
    -- ==================================================================
    v_constraints      t_constraint_array;
    v_used_names       t_name_tracker;
    v_current_time     VARCHAR2(30) := TO
