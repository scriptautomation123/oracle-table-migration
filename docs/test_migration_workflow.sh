#!/bin/bash
# ==================================================================
# End-to-End Migration Test Workflow
# ==================================================================
# Complete automated test of the migration system:
# 1. Cleanup existing tables (backup or drop)
# 2. Create comprehensive test schema
# 3. Generate partition data (2 days ahead worth of partitions)
# 4. Discover schema and generate migration config
# 5. Generate migration DDL from config
# 6. Execute migration (create table_NEW)
# 7. Run master1.sql for each table
# 8. Compare table vs table_OLD for unexpected differences
# 9. Validate partition creation and data distribution
# ==================================================================

set -e  # Exit on error

# ==================================================================
# Configuration
# ==================================================================
SCHEMA_USER="${SCHEMA_USER:-APP_DATA_OWNER}"
SCHEMA_PASS="${SCHEMA_PASS:-your_password}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-1521}"
DB_SERVICE="${DB_SERVICE:-ORCLPDB1}"
DB_CONNECTION="//${DB_HOST}:${DB_PORT}/${DB_SERVICE}"
FULL_CONNECTION="${SCHEMA_USER}/${SCHEMA_PASS}@${DB_CONNECTION}"

# Python script paths
PROJECT_ROOT="/home/swapa/code/oracle-table-migration"
GENERATE_SCRIPT="${PROJECT_ROOT}/src/generate.py"

# Output directories
OUTPUT_DIR="${PROJECT_ROOT}/test_output/run_$(date +%Y%m%d_%H%M%S)"
CONFIG_FILE="${OUTPUT_DIR}/migration_config.json"
DDL_DIR="${OUTPUT_DIR}/generated_ddl"
LOG_FILE="${OUTPUT_DIR}/test_workflow.log"

# Migration action: "backup" (default) or "drop"
ACTION="${ACTION:-backup}"

# Create output directory
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${DDL_DIR}"

# ==================================================================
# Logging Functions
# ==================================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

log_step() {
    echo "" | tee -a "${LOG_FILE}"
    echo "==========================================================" | tee -a "${LOG_FILE}"
    echo "$*" | tee -a "${LOG_FILE}"
    echo "==========================================================" | tee -a "${LOG_FILE}"
}

log_error() {
    echo "[ERROR] $*" | tee -a "${LOG_FILE}" >&2
}

# ==================================================================
# Step 1: Cleanup and Create Test Schema
# ==================================================================
step1_create_schema() {
    log_step "Step 1: Cleanup and Create Test Schema"
    
    log "Cleaning up existing tables and creating fresh schema..."
    cd "${PROJECT_ROOT}/test/data"
    
    SCHEMA_USER="${SCHEMA_USER}" \
    SCHEMA_PASS="${SCHEMA_PASS}" \
    DB_HOST="${DB_HOST}" \
    DB_PORT="${DB_PORT}" \
    DB_SERVICE="${DB_SERVICE}" \
    ACTION="${ACTION}" \
    ./cleanup_wrapper.sh rebuild
    
    log "✓ Schema created successfully"
}

# ==================================================================
# Step 2: Generate Partition Data (2 days ahead)
# ==================================================================
step2_generate_partition_data() {
    log_step "Step 2: Generate Partition Data (2 days ahead)"
    
    log "Creating SQL script to generate future partitions..."
    
    cat > "${OUTPUT_DIR}/generate_partitions.sql" <<'EOF'
-- Generate partition data for 2 days ahead
-- Creates data to ensure partitions exist for interval partitioned tables
SET SERVEROUTPUT ON

DECLARE
    v_days_ahead NUMBER := 2;
    v_current_time TIMESTAMP := SYSTIMESTAMP;
    v_target_time TIMESTAMP;
    v_hours_to_generate NUMBER;
    v_insert_count NUMBER := 0;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('Generating partition data for ' || v_days_ahead || ' days ahead');
    DBMS_OUTPUT.PUT_LINE('Current time: ' || TO_CHAR(v_current_time, 'YYYY-MM-DD HH24:MI:SS'));
    
    -- Calculate how many hours to generate
    -- If we're partitioning by hour, generate 48 hours (2 days)
    -- If we're partitioning by day, generate 2 partitions
    v_hours_to_generate := v_days_ahead * 24;
    
    DBMS_OUTPUT.PUT_LINE('Will generate ' || v_hours_to_generate || ' hours of data');
    DBMS_OUTPUT.PUT_LINE(' ');
    
    -- Generate data for AUDIT_LOG (INTERVAL partitioned by MONTH)
    DBMS_OUTPUT.PUT_LINE('--- AUDIT_LOG (Interval: 1 MONTH) ---');
    FOR i IN 0..v_days_ahead LOOP
        v_target_time := v_current_time + INTERVAL '1' DAY * i;
        
        INSERT INTO AUDIT_LOG (TABLE_NAME, OPERATION, USER_NAME, TIMESTAMP_CREATED)
        VALUES ('TEST_TABLE', 'INSERT', 'TEST_USER', v_target_time);
        
        v_insert_count := v_insert_count + 1;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Inserted ' || v_insert_count || ' test records');
    
    -- Generate data for TRANSACTION_LOG (INTERVAL partitioned by DAY)
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE('--- TRANSACTION_LOG (Interval: 1 DAY) ---');
    v_insert_count := 0;
    FOR i IN 0..v_days_ahead LOOP
        v_target_time := v_current_time + INTERVAL '1' DAY * i;
        
        INSERT INTO TRANSACTION_LOG (TRANSACTION_DATE, ACCOUNT_ID, TRANSACTION_TYPE, AMOUNT)
        VALUES (v_target_time, 100000 + i, 'TEST_TRANSACTION', 100.00 + i);
        
        v_insert_count := v_insert_count + 1;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Inserted ' || v_insert_count || ' test records');
    
    -- Rollback to not leave test data
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE('Rolling back transactions (partitions created, data removed)...');
    ROLLBACK;
    
    DBMS_OUTPUT.PUT_LINE('✓ Partition generation complete');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/

-- Verify partitions were created
SET HEADING ON FEEDBACK ON
SELECT 'Partition verification:' as info FROM dual;

SELECT table_name, partition_name, high_value
FROM user_tab_partitions
WHERE table_name IN ('AUDIT_LOG', 'TRANSACTION_LOG')
ORDER BY table_name, partition_position;
EOF

    log "Executing partition generation script..."
    sqlplus -S "${FULL_CONNECTION}" @"${OUTPUT_DIR}/generate_partitions.sql" | tee -a "${LOG_FILE}"
    
    log "✓ Partition data generated"
}

# ==================================================================
# Step 3: Discover Schema and Generate Config
# ==================================================================
step3_discover_schema() {
    log_step "Step 3: Discover Schema and Generate Migration Config"
    
    log "Running schema discovery..."
    log "Command: python3 ${GENERATE_SCRIPT} --discover --schema ${SCHEMA_USER} --connection \"${FULL_CONNECTION}\" --output-file \"${CONFIG_FILE}\""
    
    cd "${PROJECT_ROOT}"
    python3 "${GENERATE_SCRIPT}" \
        --discover \
        --schema "${SCHEMA_USER}" \
        --connection "${FULL_CONNECTION}" \
        --output-file "${CONFIG_FILE}" \
        2>&1 | tee -a "${LOG_FILE}"
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_error "Config file not generated: ${CONFIG_FILE}"
        exit 1
    fi
    
    log "✓ Config generated: ${CONFIG_FILE}"
    log "Tables discovered: $(jq -r '.tables | length' "${CONFIG_FILE}")"
}

# ==================================================================
# Step 4: Generate Migration DDL
# ==================================================================
step4_generate_ddl() {
    log_step "Step 4: Generate Migration DDL from Config"
    
    log "Generating migration DDL..."
    log "Command: python3 ${GENERATE_SCRIPT} --config \"${CONFIG_FILE}\" --output-dir \"${DDL_DIR}\""
    
    cd "${PROJECT_ROOT}"
    python3 "${GENERATE_SCRIPT}" \
        --config "${CONFIG_FILE}" \
        --output-dir "${DDL_DIR}" \
        2>&1 | tee -a "${LOG_FILE}"
    
    if [[ ! -d "${DDL_DIR}" ]] || [[ -z "$(ls -A ${DDL_DIR})" ]]; then
        log_error "DDL not generated in: ${DDL_DIR}"
        exit 1
    fi
    
    log "✓ DDL generated in: ${DDL_DIR}"
    log "Generated files: $(ls -1 ${DDL_DIR} | wc -l)"
}

# ==================================================================
# Step 5: Execute Migration (Create table_NEW)
# ==================================================================
step5_execute_migration() {
    log_step "Step 5: Execute Migration Scripts"
    
    log "Finding master1.sql files..."
    local master_scripts=$(find "${DDL_DIR}" -name "master1.sql" -type f)
    
    if [[ -z "$master_scripts" ]]; then
        log_error "No master1.sql files found in ${DDL_DIR}"
        exit 1
    fi
    
    log "Found $(echo "$master_scripts" | wc -l) master1.sql file(s)"
    
    # Execute each master1.sql
    while IFS= read -r script; do
        local table_dir=$(dirname "$script")
        local table_name=$(basename "$table_dir")
        
        log " "
        log "Executing migration for: ${table_name}"
        log "Script: ${script}"
        
        cd "$table_dir"
        sqlplus "${FULL_CONNECTION}" @master1.sql 2>&1 | tee -a "${LOG_FILE}"
        
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            log_error "Migration failed for ${table_name}"
            exit 1
        fi
        
        log "✓ Migration completed for ${table_name}"
        
    done <<< "$master_scripts"
    
    log " "
    log "✓ All migrations executed successfully"
}

# ==================================================================
# Step 6: Compare Tables (table vs table_OLD)
# ==================================================================
step6_compare_tables() {
    log_step "Step 6: Compare Original vs New Tables"
    
    log "Generating comparison script..."
    
    cat > "${OUTPUT_DIR}/compare_tables.sql" <<'EOF'
SET PAGESIZE 1000 LINESIZE 200
SET HEADING ON FEEDBACK ON

PROMPT ==========================================
PROMPT Table Comparison Report
PROMPT ==========================================

-- Compare row counts
SELECT 
    t1.table_name || ' (original)' as table_name,
    t1.num_rows
FROM user_tables t1
WHERE t1.table_name IN (
    SELECT REPLACE(table_name, '_NEW', '') 
    FROM user_tables 
    WHERE table_name LIKE '%\_NEW' ESCAPE '\'
)
UNION ALL
SELECT 
    t2.table_name || ' (new)' as table_name,
    t2.num_rows
FROM user_tables t2
WHERE t2.table_name LIKE '%\_NEW' ESCAPE '\'
ORDER BY 1;

-- Compare partition counts
PROMPT
PROMPT Partition Count Comparison:
PROMPT ==========================================

SELECT 
    REPLACE(table_name, '_NEW', '') as base_table,
    COUNT(CASE WHEN table_name NOT LIKE '%\_NEW' ESCAPE '\' THEN 1 END) as original_partitions,
    COUNT(CASE WHEN table_name LIKE '%\_NEW' ESCAPE '\' THEN 1 END) as new_partitions
FROM user_tab_partitions
WHERE table_name IN (
    SELECT table_name FROM user_tables WHERE table_name LIKE '%\_NEW' ESCAPE '\'
    UNION
    SELECT REPLACE(table_name, '_NEW', '') FROM user_tables WHERE table_name LIKE '%\_NEW' ESCAPE '\'
)
GROUP BY REPLACE(table_name, '_NEW', '')
ORDER BY 1;

-- Compare constraint counts
PROMPT
PROMPT Constraint Count Comparison:
PROMPT ==========================================

SELECT 
    REPLACE(table_name, '_NEW', '') as base_table,
    COUNT(CASE WHEN table_name NOT LIKE '%\_NEW' ESCAPE '\' THEN 1 END) as original_constraints,
    COUNT(CASE WHEN table_name LIKE '%\_NEW' ESCAPE '\' THEN 1 END) as new_constraints
FROM user_constraints
WHERE table_name IN (
    SELECT table_name FROM user_tables WHERE table_name LIKE '%\_NEW' ESCAPE '\'
    UNION
    SELECT REPLACE(table_name, '_NEW', '') FROM user_tables WHERE table_name LIKE '%\_NEW' ESCAPE '\'
)
GROUP BY REPLACE(table_name, '_NEW', '')
ORDER BY 1;

-- Compare index counts
PROMPT
PROMPT Index Count Comparison:
PROMPT ==========================================

SELECT 
    REPLACE(table_name, '_NEW', '') as base_table,
    COUNT(CASE WHEN table_name NOT LIKE '%\_NEW' ESCAPE '\' THEN 1 END) as original_indexes,
    COUNT(CASE WHEN table_name LIKE '%\_NEW' ESCAPE '\' THEN 1 END) as new_indexes
FROM user_indexes
WHERE table_name IN (
    SELECT table_name FROM user_tables WHERE table_name LIKE '%\_NEW' ESCAPE '\'
    UNION
    SELECT REPLACE(table_name, '_NEW', '') FROM user_tables WHERE table_name LIKE '%\_NEW' ESCAPE '\'
)
GROUP BY REPLACE(table_name, '_NEW', '')
ORDER BY 1;
EOF

    log "Running comparison..."
    sqlplus -S "${FULL_CONNECTION}" @"${OUTPUT_DIR}/compare_tables.sql" | tee -a "${LOG_FILE}"
    
    log "✓ Comparison complete"
}

# ==================================================================
# Step 7: Final Validation
# ==================================================================
step7_final_validation() {
    log_step "Step 7: Final Validation"
    
    log "Running final validation checks..."
    
    cat > "${OUTPUT_DIR}/final_validation.sql" <<'EOF'
SET SERVEROUTPUT ON
DECLARE
    v_new_table_count NUMBER;
    v_errors NUMBER := 0;
BEGIN
    -- Check if _NEW tables were created
    SELECT COUNT(*) INTO v_new_table_count
    FROM user_tables
    WHERE table_name LIKE '%\_NEW' ESCAPE '\';
    
    DBMS_OUTPUT.PUT_LINE('New tables created: ' || v_new_table_count);
    
    IF v_new_table_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: No _NEW tables found!');
        v_errors := v_errors + 1;
    END IF;
    
    -- Check for invalid objects
    FOR rec IN (
        SELECT object_name, object_type, status
        FROM user_objects
        WHERE status = 'INVALID'
        AND object_name LIKE '%\_NEW' ESCAPE '\'
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('ERROR: Invalid object - ' || rec.object_type || ': ' || rec.object_name);
        v_errors := v_errors + 1;
    END LOOP;
    
    -- Summary
    DBMS_OUTPUT.PUT_LINE(' ');
    IF v_errors = 0 THEN
        DBMS_OUTPUT.PUT_LINE('✓ All validation checks passed!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ Validation failed with ' || v_errors || ' error(s)');
        RAISE_APPLICATION_ERROR(-20001, 'Validation failed');
    END IF;
END;
/
EOF

    sqlplus -S "${FULL_CONNECTION}" @"${OUTPUT_DIR}/final_validation.sql" | tee -a "${LOG_FILE}"
    
    log "✓ Final validation complete"
}

# ==================================================================
# Main Execution
# ==================================================================
main() {
    log_step "Starting End-to-End Migration Test Workflow"
    log "Schema: ${SCHEMA_USER}"
    log "Database: ${DB_CONNECTION}"
    log "Output: ${OUTPUT_DIR}"
    log "Action: ${ACTION}"
    
    step1_create_schema
    step2_generate_partition_data
    step3_discover_schema
    step4_generate_ddl
    step5_execute_migration
    step6_compare_tables
    step7_final_validation
    
    log_step "✓ End-to-End Test Workflow Complete!"
    log "Results saved to: ${OUTPUT_DIR}"
    log "Log file: ${LOG_FILE}"
}

# Run main workflow
main "$@"
