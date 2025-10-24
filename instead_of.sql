-- SQL*Plus commands for better script output formatting
SET ECHO ON
SET SERVEROUTPUT ON
SET FEEDBACK ON

-- =============================================================================
-- 1. INITIAL SETUP: Create a temporary table and populate it with 100 rows.
-- This follows the requested flow: create -> populate -> rename.
-- =============================================================================
PROMPT [+] 1. Creating initial table 'table_to_be_renamed'...
CREATE TABLE table_to_be_renamed (
    id INT PRIMARY KEY,
    old_data VARCHAR2(100),
    audit_create_date DATE
);

PROMPT [+] Populating 'table_to_be_renamed' with 100 rows of sample data...
BEGIN
    FOR i IN 1..100 LOOP
        INSERT INTO table_to_be_renamed (id, old_data, audit_create_date)
        VALUES (
            100 + i, 
            'Legacy Data Row ' || i,
            SYSDATE - 100 + i -- Spread dates over the last 100 days
        );
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Populated ' || SQL%ROWCOUNT || ' total rows.');
END;
/


-- =============================================================================
-- 2. RENAME to 'table_old' and apply the requested partitioning scheme.
-- Note: A simple RENAME does not change the storage characteristics.
-- To meet the partitioning requirement, we create a new, correctly partitioned
-- table and move the data. This is the architecturally correct approach.
-- =============================================================================
PROMPT [+] 2. Renaming 'table_to_be_renamed' to 'table_old_unpartitioned'...
RENAME table_to_be_renamed TO table_old_unpartitioned;

PROMPT [+] Creating correctly partitioned 'table_old'...
CREATE TABLE table_old (
    id INT PRIMARY KEY,
    old_data VARCHAR2(100),
    audit_create_date DATE NOT NULL
)
PARTITION BY RANGE (audit_create_date)
INTERVAL (NUMTODSINTERVAL(1, 'DAY'))
(
    PARTITION p_initial VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD'))
);

PROMPT [+] Migrating data to the new partitioned 'table_old'...
INSERT INTO table_old (id, old_data, audit_create_date)
SELECT id, old_data, audit_create_date FROM table_old_unpartitioned;
COMMIT;

PROMPT [+] Dropping the temporary unpartitioned table...
DROP TABLE table_old_unpartitioned;


-- =============================================================================
-- 3. CREATE 'table_new' with Interval-Hash composite partitioning.
-- =============================================================================
PROMPT [+] 3. Creating 'table_new' with Interval-Hash composite partitioning...
CREATE TABLE table_new (
    id INT PRIMARY KEY,
    trace_id VARCHAR2(50) NOT NULL,
    new_data VARCHAR2(100),
    old_id INT,
    audit_create_date DATE NOT NULL,
    CONSTRAINT fk_new_to_old FOREIGN KEY (old_id) REFERENCES table_old(id)
)
PARTITION BY RANGE (audit_create_date)
SUBPARTITION BY HASH (trace_id)
SUBPARTITIONS 4
(
    PARTITION p_initial_new VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD'))
);

-- Sequence for the primary key of table_new
CREATE SEQUENCE table_new_seq START WITH 1;


-- =============================================================================
-- 4. CREATE VIEW and INSTEAD OF TRIGGER
-- The view is named 'active_data' to avoid using the reserved word 'TABLE'.
-- =============================================================================
PROMPT [+] 4. Creating view 'active_data' and the INSTEAD OF trigger...
CREATE OR REPLACE VIEW active_data AS
SELECT 
    t_new.id,
    t_new.trace_id,
    t_new.new_data,
    t_old.id AS old_id,
    t_old.old_data,
    t_new.audit_create_date
FROM 
    table_new t_new
JOIN 
    table_old t_old ON t_new.old_id = t_old.id;
/

CREATE OR REPLACE TRIGGER trg_active_data_dml
ON active_data
INSTEAD OF INSERT OR UPDATE OR DELETE
AS
BEGIN
    -- Handle INSERT Operations
    IF INSERTING THEN
        INSERT INTO table_new (id, trace_id, new_data, old_id, audit_create_date)
        VALUES (table_new_seq.NEXTVAL, :NEW.trace_id, :NEW.new_data, :NEW.old_id, SYSDATE);
        DBMS_OUTPUT.PUT_LINE('INSTEAD OF INSERT: 1 row inserted into table_new.');

    -- Handle UPDATE Operations
    ELSIF UPDATING THEN
        UPDATE table_new
        SET
            trace_id = :NEW.trace_id,
            new_data = :NEW.new_data,
            old_id = :NEW.old_id
        WHERE id = :OLD.id; -- Use the OLD PK to identify the row
        DBMS_OUTPUT.PUT_LINE('INSTEAD OF UPDATE: 1 row updated in table_new.');

    -- Handle DELETE Operations
    ELSIF DELETING THEN
        DELETE FROM table_new
        WHERE id = :OLD.id;
        DBMS_OUTPUT.PUT_LINE('INSTEAD OF DELETE: 1 row deleted from table_new.');
    END IF;
END;
/


-- =============================================================================
-- 5. DML TESTING AND TRANSACTION CONTROL
-- =============================================================================
PROMPT [+] 5. Starting DML tests...

PROMPT --- Performing INSERT on the view ---
INSERT INTO active_data (trace_id, new_data, old_id) 
VALUES ('TRACE-ABC-123', 'First new item', 101);

PROMPT --- Performing another INSERT on the view ---
INSERT INTO active_data (trace_id, new_data, old_id) 
VALUES ('TRACE-DEF-456', 'Second new item', 102);

PROMPT [+] Current state of table_new before rollback test:
SELECT id, trace_id, new_data, old_id FROM table_new;

PROMPT [+] Setting a SAVEPOINT before further changes...
SAVEPOINT before_update_and_delete;

PROMPT --- Performing UPDATE on the view ---
UPDATE active_data SET new_data = 'Updated first item' WHERE id = 1;

PROMPT --- Performing DELETE on the view ---
DELETE FROM active_data WHERE id = 2;

PROMPT [+] State of table_new AFTER update and delete but BEFORE rollback:
SELECT id, trace_id, new_data, old_id FROM table_new;


-- =============================================================================
-- 6. DEMONSTRATE ROLLBACK
-- =============================================================================
PROMPT [+] 6. Now ROLLING BACK to the savepoint...
ROLLBACK TO before_update_and_delete;
DBMS_OUTPUT.PUT_LINE('Rollback complete.');

PROMPT [+] Final state of table_new (update and delete should be undone):
SELECT id, trace_id, new_data, old_id FROM table_new;

PROMPT [+] Final state of table_old (should be unchanged throughout):
SELECT COUNT(*) FROM table_old;


-- =============================================================================
-- 7. CLEANUP
-- =============================================================================
PROMPT [+] 7. Cleaning up all created objects...
DROP TRIGGER trg_active_data_dml;
DROP VIEW active_data;
DROP SEQUENCE table_new_seq;
DROP TABLE table_new;
DROP TABLE table_old;

PROMPT [+] Cleanup complete.