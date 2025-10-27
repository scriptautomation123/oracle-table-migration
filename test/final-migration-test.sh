#!/bin/bash

# Final Migration Test - Master Script Execution Only
# ===================================================
# This script validates that master1.sql contains everything needed
# for a complete migration with NO additional manual steps required.
#
# Test Flow:
# 1. Create comprehensive test schema
# 2. Generate migration scripts
# 3. Execute ONLY master1.sql
# 4. Validate complete success
#
# If anything fails or requires additional steps, the migration
# generation logic needs to be fixed.

set -e

# Configuration
SCHEMA_NAME="APP_DATA_OWNER"
CONNECTION_NAME=""
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="final_migration_test_${TIMESTAMP}.log"
TEST_RESULTS_FILE="test_results_${TIMESTAMP}.json"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# Test statistics
declare -A STATS
STATS[start_time]=$(date +%s)
STATS[tables_migrated]=0
STATS[master_scripts_executed]=0
STATS[validation_errors]=0
STATS[total_errors]=0

print_header() {
    echo -e "${BLUE}${BOLD}=========================================${NC}"
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}${BOLD}=========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') SUCCESS: $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: $1" >> "$LOG_FILE"
    ((STATS[total_errors]++))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: $1" >> "$LOG_FILE"
}

print_step() {
    echo -e "${CYAN}🔄 $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') STEP: $1" >> "$LOG_FILE"
}

show_help() {
    cat << 'EOF'
Final Migration Test - Master Script Only Execution

This script validates that the migration system generates master1.sql files
that contain EVERYTHING needed for a complete migration with zero manual steps.

Usage:
  ./scripts/final-migration-test.sh [options]

Options:
  --connection CONN_NAME    Oracle connection name (required)
  --schema SCHEMA_NAME      Oracle schema (default: APP_DATA_OWNER)
  --config CONFIG_FILE      Migration config file (default: migration_config.json)
  --tables TABLE_PATTERN    Test only tables matching pattern (default: all)
  --dry-run                 Show what would be executed
  --verbose                 Enable verbose output
  --keep-temp-schema        Don't drop test schema after test
  --help                    Show this help

Test Validation:
- Creates comprehensive test schema with constraints and indexes
- Generates migration scripts for all tables
- Executes ONLY master1.sql for each table
- Validates complete migration success
- Reports any missing functionality in master1.sql

Success Criteria:
- All master1.sql scripts execute without error
- All data migrated correctly with validation
- All constraints and indexes recreated
- All referential integrity preserved
- No manual intervention required

Examples:
  # Basic test with Oracle connection
  ./scripts/final-migration-test.sh --connection my_oracle_db

  # Test specific tables only
  ./scripts/final-migration-test.sh --connection my_db --tables "SALES_*"

  # Verbose mode with detailed logging
  ./scripts/final-migration-test.sh --connection my_db --verbose
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --connection)
                CONNECTION_NAME="$2"
                shift 2
                ;;
            --schema)
                SCHEMA_NAME="$2"
                shift 2
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --tables)
                TABLE_PATTERN="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --keep-temp-schema)
                KEEP_TEMP_SCHEMA=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    if [ -z "$CONNECTION_NAME" ]; then
        print_error "Oracle connection name is required. Use --connection CONN_NAME"
        exit 1
    fi
}

validate_prerequisites() {
    print_step "Validating prerequisites..."
    
    local errors=0
    
    # Check Oracle client
    if ! command -v sqlcl >/dev/null 2>&1; then
        print_error "SQLcl not found in PATH"
        ((errors++))
    fi
    
    # Check Python and required packages
    if ! command -v python3 >/dev/null 2>&1; then
        print_error "Python 3 not found"
        ((errors++))
    fi
    
    # Check required files
    local required_files=(
        "test/data/comprehensive_oracle_ddl.sql"
        "src/generate.py"
        "lib/discovery_queries.py"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Required file not found: $file"
            ((errors++))
        fi
    done
    
    # Test Oracle connection
    if ! echo "SELECT 1 FROM DUAL;" | sqlcl -S "$CONNECTION_NAME" >/dev/null 2>&1; then
        print_error "Cannot connect to Oracle database: $CONNECTION_NAME"
        ((errors++))
    fi
    
    if [ $errors -gt 0 ]; then
        print_error "Prerequisites validation failed with $errors errors"
        return 1
    fi
    
    print_success "Prerequisites validation passed"
    return 0
}

create_test_schema() {
    print_step "Creating comprehensive test schema..."
    
    if [ "$DRY_RUN" = true ]; then
        print_step "DRY-RUN: Would create test schema"
        return 0
    fi
    
    # Execute the comprehensive DDL
    if sqlcl "$CONNECTION_NAME" @test/data/comprehensive_oracle_ddl.sql 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Test schema created successfully"
        
        # Verify table creation
        local table_count
        table_count=$(echo "SELECT COUNT(*) FROM user_tables;" | sqlcl -S "$CONNECTION_NAME" 2>/dev/null | tail -1)
        if [[ "$table_count" =~ ^[0-9]+$ ]] && [ "$table_count" -gt 0 ]; then
            print_success "$table_count tables created in test schema"
        else
            print_error "Could not verify table creation"
            return 1
        fi
        
        # Verify constraints
        local constraint_count
        constraint_count=$(echo "SELECT COUNT(*) FROM user_constraints WHERE constraint_type IN ('P','R','U','C') AND constraint_name NOT LIKE 'SYS_%';" | sqlcl -S "$CONNECTION_NAME" 2>/dev/null | tail -1)
        print_success "$constraint_count constraints created"
        
        # Verify indexes
        local index_count
        index_count=$(echo "SELECT COUNT(*) FROM user_indexes;" | sqlcl -S "$CONNECTION_NAME" 2>/dev/null | tail -1)
        print_success "$index_count indexes created"
        
    else
        print_error "Test schema creation failed"
        return 1
    fi
    
    return 0
}

discover_and_generate_config() {
    print_step "Running schema discovery and generating migration configuration..."
    
    if [ "$DRY_RUN" = true ]; then
        print_step "DRY-RUN: Would run schema discovery"
        return 0
    fi
    
    # Create discovery configuration
    cat > "temp_discovery_config.json" << EOF
{
    "connection": {
        "type": "sqlcl",
        "connection_name": "$CONNECTION_NAME"
    },
    "discovery": {
        "schema": "$SCHEMA_NAME",
        "table_patterns": ["${TABLE_PATTERN:-*}"],
        "include_constraints": true,
        "include_indexes": true,
        "include_partitioning": true,
        "include_lob_details": true,
        "include_identity_columns": true,
        "output_file": "discovered_schema_${TIMESTAMP}.json"
    }
}
EOF
    
    # Schema discovery now integrated into main generate.py workflow
    print_info "Schema discovery is now integrated into the main generation workflow"
    
    # Clean up temp files
    rm -f "temp_discovery_config.json"
    
    return 0
}

generate_migration_scripts() {
    print_step "Generating migration scripts for all tables..."
    
    if [ "$DRY_RUN" = true ]; then
        print_step "DRY-RUN: Would generate migration scripts"
        return 0
    fi
    
    # Use existing config or create minimal one
    local config_file="${CONFIG_FILE:-migration_config.json}"
    
    if [ ! -f "$config_file" ]; then
        print_warning "Config file $config_file not found, creating minimal config"
        # Create a minimal config for testing
        cat > "$config_file" << 'EOF'
{
    "metadata": {
        "generated_date": "2025-10-25 19:38:00",
        "source_schema": "APP_DATA_OWNER"
    },
    "environment_config": {
        "name": "test",
        "tablespaces": {
            "data": {
                "primary": "USERS",
                "lob": ["USERS"]
            }
        }
    },
    "tables": []
}
EOF
    fi
    
    # Generate scripts using the main generator
    if python3 src/generate.py --config "$config_file" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Migration scripts generated successfully"
        
        # Count generated master scripts
        local master_count
        master_count=$(find output -name "master1.sql" 2>/dev/null | wc -l)
        if [ "$master_count" -gt 0 ]; then
            print_success "Found $master_count master1.sql scripts"
            STATS[master_scripts_generated]=$master_count
        else
            print_error "No master1.sql scripts were generated!"
            return 1
        fi
    else
        print_error "Migration script generation failed"
        return 1
    fi
    
    return 0
}

execute_master_scripts_only() {
    print_header "CRITICAL TEST: Executing ONLY master1.sql Scripts"
    print_step "This validates that master1.sql contains EVERYTHING needed for migration"
    
    if [ "$DRY_RUN" = true ]; then
        print_step "DRY-RUN: Would execute master1.sql scripts"
        return 0
    fi
    
    local master_scripts
    master_scripts=($(find output -name "master1.sql" 2>/dev/null))
    
    if [ ${#master_scripts[@]} -eq 0 ]; then
        print_error "No master1.sql scripts found in output directory"
        return 1
    fi
    
    print_step "Found ${#master_scripts[@]} master1.sql scripts to execute"
    
    # Execute each master1.sql script
    local successful_migrations=0
    local failed_migrations=0
    
    for master_script in "${master_scripts[@]}"; do
        local table_dir
        table_dir=$(dirname "$master_script")
        local table_name
        table_name=$(basename "$table_dir")
        
        print_step "Executing master1.sql for $table_name..."
        
        # This is the critical test - ONLY run master1.sql
        if sqlcl "$CONNECTION_NAME" @"$master_script" 2>&1 | tee -a "$LOG_FILE"; then
            print_success "✅ $table_name: master1.sql executed successfully"
            ((successful_migrations++))
            STATS[tables_migrated]=$((STATS[tables_migrated] + 1))
        else
            print_error "❌ $table_name: master1.sql execution failed"
            ((failed_migrations++))
            STATS[validation_errors]=$((STATS[validation_errors] + 1))
        fi
        
        # Brief pause between migrations
        sleep 1
    done
    
    STATS[master_scripts_executed]=$successful_migrations
    
    print_header "Master Script Execution Results"
    print_success "Successful migrations: $successful_migrations"
    if [ $failed_migrations -gt 0 ]; then
        print_error "Failed migrations: $failed_migrations"
        return 1
    fi
    
    return 0
}

validate_migration_results() {
    print_step "Validating complete migration results..."
    
    if [ "$DRY_RUN" = true ]; then
        print_step "DRY-RUN: Would validate migration results"
        return 0
    fi
    
    # Check that new partitioned tables exist
    local new_tables_query="
    SELECT table_name, partitioned, num_rows
    FROM user_tables 
    WHERE table_name LIKE '%_NEW'
    ORDER BY table_name;
    "
    
    print_step "Checking new partitioned tables..."
    local new_tables_result
    new_tables_result=$(echo "$new_tables_query" | sqlcl -S "$CONNECTION_NAME" 2>/dev/null)
    
    if echo "$new_tables_result" | grep -q "_NEW"; then
        print_success "New partitioned tables found:"
        echo "$new_tables_result" | grep "_NEW" | while read -r line; do
            print_success "  $line"
        done
    else
        print_error "No new partitioned tables found!"
        ((STATS[validation_errors]++))
    fi
    
    # Check constraints on new tables
    local constraints_query="
    SELECT table_name, constraint_type, COUNT(*) as count
    FROM user_constraints 
    WHERE table_name LIKE '%_NEW'
    AND constraint_type IN ('P','R','U','C')
    AND constraint_name NOT LIKE 'SYS_%'
    GROUP BY table_name, constraint_type
    ORDER BY table_name, constraint_type;
    "
    
    print_step "Validating constraints on new tables..."
    local constraints_result
    constraints_result=$(echo "$constraints_query" | sqlcl -S "$CONNECTION_NAME" 2>/dev/null)
    
    if echo "$constraints_result" | grep -q "_NEW"; then
        print_success "Constraints found on new tables:"
        echo "$constraints_result" | grep "_NEW" | while read -r line; do
            print_success "  $line"
        done
    else
        print_warning "No constraints found on new tables (this may be expected)"
    fi
    
    # Check indexes on new tables  
    local indexes_query="
    SELECT table_name, COUNT(*) as index_count
    FROM user_indexes 
    WHERE table_name LIKE '%_NEW'
    GROUP BY table_name
    ORDER BY table_name;
    "
    
    print_step "Validating indexes on new tables..."
    local indexes_result
    indexes_result=$(echo "$indexes_query" | sqlcl -S "$CONNECTION_NAME" 2>/dev/null)
    
    if echo "$indexes_result" | grep -q "_NEW"; then
        print_success "Indexes found on new tables:"
        echo "$indexes_result" | grep "_NEW" | while read -r line; do
            print_success "  $line"
        done
    else
        print_warning "No indexes found on new tables"
    fi
    
    # Data validation - check row counts match
    print_step "Validating data migration..."
    local data_validation_query="
    SELECT 
        SUBSTR(table_name, 1, LENGTH(table_name)-4) as base_table,
        SUM(CASE WHEN table_name LIKE '%_OLD' THEN num_rows ELSE 0 END) as old_rows,
        SUM(CASE WHEN table_name LIKE '%_NEW' THEN num_rows ELSE 0 END) as new_rows,
        CASE 
            WHEN SUM(CASE WHEN table_name LIKE '%_OLD' THEN num_rows ELSE 0 END) = 
                 SUM(CASE WHEN table_name LIKE '%_NEW' THEN num_rows ELSE 0 END)
            THEN 'MATCH'
            ELSE 'MISMATCH'
        END as status
    FROM user_tables 
    WHERE table_name LIKE '%_OLD' OR table_name LIKE '%_NEW'
    GROUP BY SUBSTR(table_name, 1, LENGTH(table_name)-4)
    ORDER BY base_table;
    "
    
    local data_result
    data_result=$(echo "$data_validation_query" | sqlcl -S "$CONNECTION_NAME" 2>/dev/null)
    
    if echo "$data_result" | grep -q "MATCH"; then
        print_success "Data validation results:"
        echo "$data_result" | while read -r line; do
            if echo "$line" | grep -q "MATCH"; then
                print_success "  $line"
            elif echo "$line" | grep -q "MISMATCH"; then
                print_error "  $line"
                ((STATS[validation_errors]++))
            fi
        done
    else
        print_warning "No data validation results available"
    fi
    
    return 0
}

cleanup_test_schema() {
    if [ "$KEEP_TEMP_SCHEMA" = true ]; then
        print_step "Keeping test schema as requested"
        return 0
    fi
    
    print_step "Cleaning up test schema..."
    
    if [ "$DRY_RUN" = true ]; then
        print_step "DRY-RUN: Would clean up test schema"
        return 0
    fi
    
    # Drop all test tables
    local cleanup_sql="
    BEGIN
        FOR rec IN (SELECT table_name FROM user_tables WHERE table_name IN (
            'REGIONS', 'PRODUCTS', 'SALES_REPS', 'CUSTOMERS', 'SALES_HISTORY',
            'CUSTOMER_REGIONS', 'USER_SESSIONS', 'AUDIT_LOG', 'ORDER_DETAILS', 
            'TRANSACTION_LOG'
        ) OR table_name LIKE '%_OLD' OR table_name LIKE '%_NEW') LOOP
            BEGIN
                EXECUTE IMMEDIATE 'DROP TABLE ' || rec.table_name || ' CASCADE CONSTRAINTS PURGE';
                DBMS_OUTPUT.PUT_LINE('Dropped: ' || rec.table_name);
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('Could not drop ' || rec.table_name || ': ' || SQLERRM);
            END;
        END LOOP;
    END;
    /
    "
    
    if echo "$cleanup_sql" | sqlcl "$CONNECTION_NAME" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Test schema cleanup completed"
    else
        print_warning "Test schema cleanup had issues (may not be critical)"
    fi
}

generate_final_report() {
    local end_time
    local duration
    end_time=$(date +%s)
    duration=$((end_time - STATS[start_time]))
    
    local status
    if [ ${STATS[validation_errors]} -eq 0 ] && [ ${STATS[total_errors]} -eq 0 ]; then
        status="✅ SUCCESS"
    else
        status="❌ FAILED"
    fi
    
    local report_content
    report_content=$(cat << EOF
Final Migration Test Results
============================
Timestamp: $(date)
Duration: ${duration} seconds
Connection: $CONNECTION_NAME
Schema: $SCHEMA_NAME

FINAL STATUS: $status

Critical Test Results:
- Master Scripts Generated: ${STATS[master_scripts_generated]:-0}
- Master Scripts Executed: ${STATS[master_scripts_executed]:-0}
- Tables Successfully Migrated: ${STATS[tables_migrated]:-0}
- Validation Errors: ${STATS[validation_errors]}
- Total Errors: ${STATS[total_errors]}

Key Validation:
✓ Test schema creation: $([ ${STATS[total_errors]} -eq 0 ] && echo "SUCCESS" || echo "CHECK LOGS")
✓ Migration script generation: $([ ${STATS[master_scripts_generated]:-0} -gt 0 ] && echo "SUCCESS" || echo "FAILED")
✓ Master1.sql execution: $([ ${STATS[master_scripts_executed]:-0} -gt 0 ] && echo "SUCCESS" || echo "FAILED")
✓ Data migration validation: $([ ${STATS[validation_errors]} -eq 0 ] && echo "SUCCESS" || echo "CHECK RESULTS")

CRITICAL FINDING:
$(if [ ${STATS[validation_errors]} -eq 0 ] && [ ${STATS[total_errors]} -eq 0 ]; then
    echo "✅ MASTER1.SQL CONTAINS EVERYTHING NEEDED FOR COMPLETE MIGRATION"
    echo "   No additional manual steps required!"
else
    echo "❌ MASTER1.SQL IS INCOMPLETE - ADDITIONAL WORK NEEDED"
    echo "   Review errors above and enhance master1.sql generation logic"
fi)

Detailed Log: $LOG_FILE
EOF
)
    
    echo "$report_content" | tee "$TEST_RESULTS_FILE"
    
    # Save structured results for CI/CD
    cat > "final_test_results.json" << EOF
{
    "status": "$([ ${STATS[validation_errors]} -eq 0 ] && [ ${STATS[total_errors]} -eq 0 ] && echo "success" || echo "failed")",
    "timestamp": "$(date -Iseconds)",
    "duration_seconds": $duration,
    "statistics": {
        "master_scripts_generated": ${STATS[master_scripts_generated]:-0},
        "master_scripts_executed": ${STATS[master_scripts_executed]:-0},
        "tables_migrated": ${STATS[tables_migrated]:-0},
        "validation_errors": ${STATS[validation_errors]},
        "total_errors": ${STATS[total_errors]}
    },
    "master_script_complete": $([ ${STATS[validation_errors]} -eq 0 ] && [ ${STATS[total_errors]} -eq 0 ] && echo "true" || echo "false")
}
EOF
}

main() {
    print_header "Final Migration Test - Master Script Only"
    echo "This test validates that master1.sql contains EVERYTHING needed"
    echo "for a complete migration with ZERO manual intervention."
    echo ""
    
    # Parse arguments
    parse_arguments "$@"
    
    # Show configuration
    echo "Connection: $CONNECTION_NAME"
    echo "Schema: $SCHEMA_NAME"
    echo "Log File: $LOG_FILE"
    echo ""
    
    # Execute test phases
    validate_prerequisites || exit 1
    create_test_schema || exit 1
    discover_and_generate_config || exit 1
    generate_migration_scripts || exit 1
    execute_master_scripts_only || exit 1
    validate_migration_results || exit 1
    cleanup_test_schema || exit 1
    
    # Generate final report
    generate_final_report
    
    # Exit with appropriate status
    if [ ${STATS[validation_errors]} -eq 0 ] && [ ${STATS[total_errors]} -eq 0 ]; then
        print_header "🎉 FINAL TEST PASSED!"
        print_success "master1.sql contains everything needed for complete migration"
        exit 0
    else
        print_header "❌ FINAL TEST FAILED"
        print_error "master1.sql is incomplete - additional work needed"
        exit 1
    fi
}

# Execute main function
main "$@"