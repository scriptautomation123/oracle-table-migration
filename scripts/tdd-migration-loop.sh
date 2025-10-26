#!/bin/bash

# Oracle Table Migration Test-Driven Development Loop
# ===================================================
# 
# This script creates a complete TDD workflow for your Oracle migration project:
# 1. Drops all test tables cleanly
# 2. Creates tables with comprehensive constraints, indexes, and referential integrity
# 3. Loads realistic test data
# 4. Runs the migration script generation
# 5. Provides detailed success/error reporting
# 6. Supports iterative development with quick feedback
#
# Usage:
#   ./scripts/tdd-migration-loop.sh [options]
#
# Options:
#   --schema SCHEMA_NAME    Oracle schema to test against (default: APP_DATA_OWNER)
#   --connection CONN_NAME  Oracle connection name (from sqlcl connections)
#   --subset TABLE_PATTERN  Test only tables matching pattern (e.g., "SALES_*")
#   --skip-drop             Skip table drop phase
#   --skip-create           Skip table creation phase  
#   --skip-data             Skip data loading phase
#   --skip-generate         Skip script generation phase
#   --generate-only         Only run script generation (implies all other skips)
#   --verbose               Enable verbose output
#   --dry-run               Show what would be executed without running
#   --iterations N          Run N iterations of the full loop (default: 1)
#   --continue-on-error     Continue to next phase even if current phase fails
#   --report-file FILE      Save detailed report to file
#   --config-file FILE      Use specific migration config file
#   --discover-only         Only run schema discovery and exit
#   --validate-only         Only validate existing configuration
#   --help                  Show this help message

set -e  # Exit on error (unless --continue-on-error is specified)

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Default configuration
SCHEMA_NAME="APP_DATA_OWNER"
CONNECTION_NAME=""
TABLE_PATTERN="*"
SKIP_DROP=false
SKIP_CREATE=false
SKIP_DATA=false
SKIP_GENERATE=false
GENERATE_ONLY=false
VERBOSE=false
DRY_RUN=false
ITERATIONS=1
CONTINUE_ON_ERROR=false
REPORT_FILE=""
CONFIG_FILE="migration_config.json"
DISCOVER_ONLY=false
VALIDATE_ONLY=false

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DDL_FILE="$PROJECT_ROOT/test/data/comprehensive_oracle_ddl.sql"
DISCOVERY_CONFIG="$PROJECT_ROOT/schema_discovery_config.json"
GENERATE_SCRIPT="$PROJECT_ROOT/src/generate.py"
POC_SCRIPT="$PROJECT_ROOT/generate_poc.py"
OUTPUT_DIR="$PROJECT_ROOT/output"
DISCOVERY_OUTPUT="$PROJECT_ROOT/discovery_output"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$PROJECT_ROOT/tdd_migration_${TIMESTAMP}.log"

# Statistics tracking
declare -A STATS
STATS[iterations_completed]=0
STATS[tables_dropped]=0
STATS[tables_created]=0
STATS[tables_loaded]=0
STATS[scripts_generated]=0
STATS[errors_encountered]=0
STATS[start_time]=$(date +%s)

# Function definitions
print_header() {
    echo -e "${BLUE}${BOLD}===========================================${NC}"
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}${BOLD}===========================================${NC}"
}

print_subheader() {
    echo -e "${CYAN}${BOLD}--- $1 ---${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    log_message "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    log_message "ERROR: $1"
    ((STATS[errors_encountered]++))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log_message "WARNING: $1"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
    if [ "$VERBOSE" = true ]; then
        log_message "INFO: $1"
    fi
}

print_step() {
    echo -e "${PURPLE}🔄 $1${NC}"
    log_message "STEP: $1"
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

show_help() {
    cat << 'EOF'
Oracle Table Migration Test-Driven Development Loop

This script provides a complete TDD workflow for Oracle migration development:
- Drops existing test tables cleanly
- Creates comprehensive test schema with constraints and indexes  
- Loads realistic test data
- Runs migration script generation
- Provides detailed reporting and error handling
- Supports iterative development cycles

Usage:
  ./scripts/tdd-migration-loop.sh [options]

Options:
  --schema SCHEMA_NAME      Oracle schema (default: APP_DATA_OWNER)
  --connection CONN_NAME    Oracle connection name from sqlcl
  --subset TABLE_PATTERN    Test only tables matching pattern
  --skip-drop              Skip table drop phase
  --skip-create            Skip table creation phase
  --skip-data              Skip data loading phase
  --skip-generate          Skip script generation phase
  --generate-only          Only run script generation
  --verbose                Enable verbose output
  --dry-run               Show commands without executing
  --iterations N           Run N complete iterations
  --continue-on-error      Continue on phase failures
  --report-file FILE       Save detailed report
  --config-file FILE       Use specific config file
  --discover-only          Only run schema discovery
  --validate-only          Only validate configuration
  --help                   Show this help

Examples:
  # Basic usage - full TDD loop
  ./scripts/tdd-migration-loop.sh --connection my_oracle_db

  # Test only SALES tables with verbose output
  ./scripts/tdd-migration-loop.sh --subset "SALES_*" --verbose

  # Run 5 iterations for stress testing
  ./scripts/tdd-migration-loop.sh --iterations 5 --continue-on-error

  # Development mode - skip drops, just generate
  ./scripts/tdd-migration-loop.sh --skip-drop --skip-data --generate-only

  # Discovery only mode
  ./scripts/tdd-migration-loop.sh --discover-only --connection my_db

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --schema)
                SCHEMA_NAME="$2"
                shift 2
                ;;
            --connection)
                CONNECTION_NAME="$2"
                shift 2
                ;;
            --subset)
                TABLE_PATTERN="$2"
                shift 2
                ;;
            --skip-drop)
                SKIP_DROP=true
                shift
                ;;
            --skip-create)
                SKIP_CREATE=true
                shift
                ;;
            --skip-data)
                SKIP_DATA=true
                shift
                ;;
            --skip-generate)
                SKIP_GENERATE=true
                shift
                ;;
            --generate-only)
                GENERATE_ONLY=true
                SKIP_DROP=true
                SKIP_CREATE=true
                SKIP_DATA=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --iterations)
                ITERATIONS="$2"
                shift 2
                ;;
            --continue-on-error)
                CONTINUE_ON_ERROR=true
                set +e  # Don't exit on error
                shift
                ;;
            --report-file)
                REPORT_FILE="$2"
                shift 2
                ;;
            --config-file)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --discover-only)
                DISCOVER_ONLY=true
                shift
                ;;
            --validate-only)
                VALIDATE_ONLY=true
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
}

validate_environment() {
    print_step "Validating environment and dependencies"
    
    local errors=0
    
    # Check for required files
    if [ ! -f "$DDL_FILE" ]; then
        print_error "DDL file not found: $DDL_FILE"
        ((errors++))
    fi
    
    if [ ! -f "$GENERATE_SCRIPT" ]; then
        print_error "Generate script not found: $GENERATE_SCRIPT"
        ((errors++))
    fi
    
    # Check Python environment
    if ! command -v python3 >/dev/null 2>&1; then
        print_error "Python 3 not found in PATH"
        ((errors++))
    else
        print_info "Python 3 found: $(python3 --version)"
    fi
    
    # Check Oracle client
    if command -v sqlplus >/dev/null 2>&1; then
        print_info "Oracle SQLPlus found"
    elif command -v sqlcl >/dev/null 2>&1; then
        print_info "Oracle SQLcl found"
    else
        print_warning "No Oracle client (sqlplus/sqlcl) found in PATH"
    fi
    
    # Check required Python packages
    local python_packages=("jinja2" "oracledb")
    for package in "${python_packages[@]}"; do
        if python3 -c "import $package" 2>/dev/null; then
            print_info "Python package '$package' available"
        else
            print_warning "Python package '$package' not found"
        fi
    done
    
    # Create necessary directories
    mkdir -p "$OUTPUT_DIR" "$DISCOVERY_OUTPUT" "$(dirname "$LOG_FILE")"
    
    if [ $errors -gt 0 ]; then
        print_error "Environment validation failed with $errors errors"
        return 1
    fi
    
    print_success "Environment validation completed"
    return 0
}

check_oracle_connection() {
    if [ -z "$CONNECTION_NAME" ]; then
        print_warning "No Oracle connection specified. Some operations may fail."
        return 0
    fi
    
    print_step "Testing Oracle connection: $CONNECTION_NAME"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY-RUN: Would test connection to $CONNECTION_NAME"
        return 0
    fi
    
    # Try to list connections first
    if command -v sqlcl >/dev/null 2>&1; then
        local connection_test
        connection_test=$(echo "show connections" | sqlcl /nolog 2>/dev/null)
        if echo "$connection_test" | grep -q "$CONNECTION_NAME"; then
            print_success "Connection '$CONNECTION_NAME' found in sqlcl"
            return 0
        else
            print_warning "Connection '$CONNECTION_NAME' not found in sqlcl connections"
            return 1
        fi
    else
        print_warning "SQLcl not available for connection testing"
        return 1
    fi
}

drop_test_tables() {
    if [ "$SKIP_DROP" = true ]; then
        print_info "Skipping table drop phase"
        return 0
    fi
    
    print_subheader "Phase 1: Dropping Test Tables"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY-RUN: Would drop tables matching pattern '$TABLE_PATTERN'"
        return 0
    fi
    
    # Extract drop statements from DDL file
    local drop_section
    drop_section=$(sed -n '/DROP TABLES/,/END;/p' "$DDL_FILE")
    
    if [ -n "$drop_section" ]; then
        print_step "Executing table drops..."
        if [ -n "$CONNECTION_NAME" ] && command -v sqlcl >/dev/null 2>&1; then
            echo "$drop_section" | sqlcl "$CONNECTION_NAME" 2>&1 | tee -a "$LOG_FILE"
            if [ ${PIPESTATUS[1]} -eq 0 ]; then
                print_success "Tables dropped successfully"
                STATS[tables_dropped]=$((STATS[tables_dropped] + 1))
            else
                print_error "Table drop failed"
                return 1
            fi
        else
            print_warning "No Oracle connection available - cannot drop tables"
        fi
    else
        print_warning "No drop statements found in DDL file"
    fi
    
    return 0
}

create_test_tables() {
    if [ "$SKIP_CREATE" = true ]; then
        print_info "Skipping table creation phase"
        return 0
    fi
    
    print_subheader "Phase 2: Creating Test Tables with Comprehensive Constraints"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY-RUN: Would create tables from $DDL_FILE"
        return 0
    fi
    
    print_step "Executing comprehensive DDL with constraints, indexes, and referential integrity..."
    
    if [ -n "$CONNECTION_NAME" ] && command -v sqlcl >/dev/null 2>&1; then
        # Execute the full DDL file
        if sqlcl "$CONNECTION_NAME" @"$DDL_FILE" 2>&1 | tee -a "$LOG_FILE"; then
            print_success "Tables created with full constraints and referential integrity"
            STATS[tables_created]=$((STATS[tables_created] + 1))
            
            # Verify table creation
            local table_count
            table_count=$(echo "SELECT COUNT(*) FROM user_tables;" | sqlcl -S "$CONNECTION_NAME" 2>/dev/null | tail -1)
            if [[ "$table_count" =~ ^[0-9]+$ ]] && [ "$table_count" -gt 0 ]; then
                print_success "$table_count tables verified in schema"
            else
                print_warning "Could not verify table count"
            fi
            
            # Show constraint summary
            print_info "Gathering constraint statistics..."
            local constraint_summary
            constraint_summary=$(cat << 'SQL' | sqlcl -S "$CONNECTION_NAME" 2>/dev/null
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT 'Primary Keys: ' || COUNT(*) FROM user_constraints WHERE constraint_type = 'P';
SELECT 'Foreign Keys: ' || COUNT(*) FROM user_constraints WHERE constraint_type = 'R';
SELECT 'Check Constraints: ' || COUNT(*) FROM user_constraints WHERE constraint_type = 'C' AND constraint_name NOT LIKE 'SYS_%';
SELECT 'Unique Constraints: ' || COUNT(*) FROM user_constraints WHERE constraint_type = 'U';
SELECT 'Total Indexes: ' || COUNT(*) FROM user_indexes;
SQL
)
            echo "$constraint_summary" | while read -r line; do
                print_info "$line"
            done
            
        else
            print_error "Table creation failed"
            return 1
        fi
    else
        print_warning "No Oracle connection available - cannot create tables"
        return 1
    fi
    
    return 0
}

load_test_data() {
    if [ "$SKIP_DATA" = true ]; then
        print_info "Skipping data loading phase"
        return 0
    fi
    
    print_subheader "Phase 3: Loading Realistic Test Data"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY-RUN: Would load test data into tables"
        return 0
    fi
    
    print_step "Test data is included in the DDL file - already loaded during creation"
    
    if [ -n "$CONNECTION_NAME" ] && command -v sqlcl >/dev/null 2>&1; then
        # Verify data was loaded by checking row counts
        local data_verification
        data_verification=$(cat << 'SQL' | sqlcl -S "$CONNECTION_NAME" 2>/dev/null
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT table_name || ': ' || NVL(num_rows, 0) || ' rows' 
FROM user_tables 
WHERE table_name IN ('REGIONS', 'PRODUCTS', 'SALES_REPS', 'CUSTOMERS', 'SALES_HISTORY', 
                     'CUSTOMER_REGIONS', 'USER_SESSIONS', 'AUDIT_LOG', 'ORDER_DETAILS', 'TRANSACTION_LOG')
ORDER BY table_name;
SQL
)
        
        if [ -n "$data_verification" ]; then
            print_success "Data verification:"
            echo "$data_verification" | while read -r line; do
                print_info "  $line"
            done
            STATS[tables_loaded]=$((STATS[tables_loaded] + 1))
        else
            print_warning "Could not verify data loading"
        fi
        
        # Gather table statistics for optimizer
        print_step "Gathering table statistics for query optimizer..."
        if echo "EXEC DBMS_STATS.GATHER_SCHEMA_STATS('$SCHEMA_NAME');" | sqlcl -S "$CONNECTION_NAME" >/dev/null 2>&1; then
            print_success "Table statistics gathered"
        else
            print_warning "Could not gather table statistics"
        fi
    else
        print_warning "No Oracle connection available - cannot verify data"
    fi
    
    return 0
}

run_schema_discovery() {
    print_subheader "Phase 4: Running Schema Discovery"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY-RUN: Would run schema discovery"
        return 0
    fi
    
    print_step "Discovering table structures, constraints, and metadata..."
    
    # Prepare discovery configuration if needed
    local discovery_config="$DISCOVERY_CONFIG"
    if [ ! -f "$discovery_config" ]; then
        print_step "Creating schema discovery configuration..."
        cat > "$discovery_config" << EOF
{
    "connection": {
        "type": "sqlcl",
        "connection_name": "$CONNECTION_NAME"
    },
    "discovery": {
        "schema": "$SCHEMA_NAME",
        "table_patterns": ["$TABLE_PATTERN"],
        "include_constraints": true,
        "include_indexes": true,
        "include_partitioning": true,
        "include_lob_details": true,
        "include_identity_columns": true,
        "output_file": "$DISCOVERY_OUTPUT/discovered_schema_${TIMESTAMP}.json"
    },
    "analysis": {
        "recommend_partitioning": true,
        "size_thresholds": {
            "small_table_mb": 100,
            "large_table_gb": 10
        }
    }
}
EOF
        print_info "Created discovery config: $discovery_config"
    fi
    
    # Schema discovery is now integrated into the main generation workflow
    print_info "Schema discovery is now integrated into the main generation workflow"
    
    return 0
}

generate_migration_scripts() {
    if [ "$SKIP_GENERATE" = true ]; then
        print_info "Skipping script generation phase"
        return 0
    fi
    
    print_subheader "Phase 5: Generating Migration Scripts"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY-RUN: Would generate migration scripts using $CONFIG_FILE"
        return 0
    fi
    
    # Check if config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Migration config file not found: $CONFIG_FILE"
        return 1
    fi
    
    print_step "Generating migration scripts from configuration..."
    
    # Run the main generation script
    local generate_cmd="cd '$PROJECT_ROOT' && python3 '$GENERATE_SCRIPT' --config '$CONFIG_FILE'"
    
    if [ "$VERBOSE" = true ]; then
        generate_cmd="$generate_cmd --verbose"
    fi
    
    if [ -n "$TABLE_PATTERN" ] && [ "$TABLE_PATTERN" != "*" ]; then
        generate_cmd="$generate_cmd --tables '$TABLE_PATTERN'"
    fi
    
    if eval "$generate_cmd" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Migration scripts generated successfully"
        STATS[scripts_generated]=$((STATS[scripts_generated] + 1))
        
        # Count generated files
        local output_count
        output_count=$(find "$OUTPUT_DIR" -name "*.sql" -newer "$LOG_FILE" 2>/dev/null | wc -l)
        if [ "$output_count" -gt 0 ]; then
            print_success "$output_count SQL files generated in $OUTPUT_DIR"
        fi
        
        # Show generated directory structure
        if [ "$VERBOSE" = true ]; then
            print_info "Generated output structure:"
            find "$OUTPUT_DIR" -name "*.sql" -newer "$LOG_FILE" 2>/dev/null | head -10 | while read -r file; do
                local size
                size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                print_info "  $(basename "$file") (${size} bytes)"
            done
        fi
    else
        print_error "Migration script generation failed"
        return 1
    fi
    
    return 0
}

validate_generated_scripts() {
    print_subheader "Phase 6: Validating Generated Scripts"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY-RUN: Would validate generated scripts"
        return 0
    fi
    
    local validation_errors=0
    
    # Check for common SQL syntax issues
    find "$OUTPUT_DIR" -name "*.sql" -newer "$LOG_FILE" 2>/dev/null | while read -r sql_file; do
        print_step "Validating $(basename "$sql_file")..."
        
        # Basic syntax checks
        if grep -q "CREATE TABLE" "$sql_file" && ! grep -q ";" "$sql_file"; then
            print_warning "$(basename "$sql_file"): Missing semicolons detected"
        fi
        
        if grep -q "PARTITION BY" "$sql_file"; then
            print_info "$(basename "$sql_file"): Contains partitioning DDL"
        fi
        
        if grep -q "CONSTRAINT" "$sql_file"; then
            print_info "$(basename "$sql_file"): Contains constraints"
        fi
        
        # Check file size
        local file_size
        file_size=$(stat -c%s "$sql_file" 2>/dev/null || echo "0")
        if [ "$file_size" -lt 100 ]; then
            print_warning "$(basename "$sql_file"): File seems too small ($file_size bytes)"
        fi
    done
    
    print_success "Script validation completed"
    return 0
}

run_poc_tests() {
    print_subheader "Phase 7: Running POC Tests (Optional)"
    
    if [ ! -f "$POC_SCRIPT" ]; then
        print_info "POC script not found - skipping POC tests"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY-RUN: Would run POC tests"
        return 0
    fi
    
    print_step "Running proof-of-concept tests..."
    
    if cd "$PROJECT_ROOT" && python3 "$POC_SCRIPT" --sample-size 100 2>&1 | tee -a "$LOG_FILE"; then
        print_success "POC tests completed"
    else
        print_warning "POC tests encountered issues"
    fi
    
    return 0
}

generate_report() {
    local report_content
    local end_time
    local duration
    end_time=$(date +%s)
    duration=$((end_time - STATS[start_time]))
    
    STATS[end_time]=$end_time
    STATS[duration_seconds]=$duration
    
    report_content=$(cat << EOF
Oracle Table Migration TDD Loop Report
=====================================
Generated: $(date)
Duration: ${duration} seconds ($(date -d@${duration} -u +%H:%M:%S))

Configuration:
- Schema: $SCHEMA_NAME
- Connection: ${CONNECTION_NAME:-"Not specified"}
- Table Pattern: $TABLE_PATTERN
- Config File: $CONFIG_FILE
- Iterations: $ITERATIONS

Execution Statistics:
- Iterations Completed: ${STATS[iterations_completed]}
- Tables Dropped: ${STATS[tables_dropped]}
- Tables Created: ${STATS[tables_created]}
- Tables Loaded: ${STATS[tables_loaded]}
- Scripts Generated: ${STATS[scripts_generated]}
- Errors Encountered: ${STATS[errors_encountered]}

Phases Executed:
- Drop Tables: $([ "$SKIP_DROP" = true ] && echo "SKIPPED" || echo "EXECUTED")
- Create Tables: $([ "$SKIP_CREATE" = true ] && echo "SKIPPED" || echo "EXECUTED")
- Load Data: $([ "$SKIP_DATA" = true ] && echo "SKIPPED" || echo "EXECUTED")
- Generate Scripts: $([ "$SKIP_GENERATE" = true ] && echo "SKIPPED" || echo "EXECUTED")

Files Generated:
$(find "$OUTPUT_DIR" -name "*.sql" -newer "$LOG_FILE" 2>/dev/null | wc -l) SQL files in $OUTPUT_DIR

Log File: $LOG_FILE

Status: $([ ${STATS[errors_encountered]} -eq 0 ] && echo "SUCCESS" || echo "COMPLETED WITH ${STATS[errors_encountered]} ERRORS")
EOF
)
    
    if [ -n "$REPORT_FILE" ]; then
        echo "$report_content" > "$REPORT_FILE"
        print_success "Detailed report saved to: $REPORT_FILE"
    fi
    
    # Always show summary
    print_header "TDD Loop Summary"
    echo "$report_content"
}

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Show configuration
    print_header "Oracle Table Migration TDD Loop"
    echo "Schema: $SCHEMA_NAME"
    echo "Connection: ${CONNECTION_NAME:-"Not specified"}"
    echo "Table Pattern: $TABLE_PATTERN"
    echo "Iterations: $ITERATIONS"
    echo "Log File: $LOG_FILE"
    echo ""
    
    # Handle special modes
    if [ "$VALIDATE_ONLY" = true ]; then
        validate_environment
        exit $?
    fi
    
    if [ "$DISCOVER_ONLY" = true ]; then
        validate_environment || exit 1
        check_oracle_connection || exit 1
        run_schema_discovery
        exit $?
    fi
    
    # Main TDD loop
    validate_environment || exit 1
    check_oracle_connection || { 
        if [ "$CONTINUE_ON_ERROR" = false ]; then exit 1; fi 
    }
    
    for ((iteration=1; iteration<=ITERATIONS; iteration++)); do
        if [ "$ITERATIONS" -gt 1 ]; then
            print_header "TDD Iteration $iteration of $ITERATIONS"
        fi
        
        # Execute phases
        local phase_errors=0
        
        drop_test_tables || ((phase_errors++))
        create_test_tables || ((phase_errors++))
        load_test_data || ((phase_errors++))
        run_schema_discovery || ((phase_errors++))
        generate_migration_scripts || ((phase_errors++))
        validate_generated_scripts || ((phase_errors++))
        run_poc_tests || ((phase_errors++))
        
        STATS[iterations_completed]=$iteration
        
        if [ $phase_errors -gt 0 ]; then
            print_warning "Iteration $iteration completed with $phase_errors phase errors"
            if [ "$CONTINUE_ON_ERROR" = false ]; then
                break
            fi
        else
            print_success "Iteration $iteration completed successfully"
        fi
        
        # Brief pause between iterations
        if [ $iteration -lt "$ITERATIONS" ]; then
            print_info "Pausing 2 seconds before next iteration..."
            sleep 2
        fi
    done
    
    # Generate final report
    generate_report
    
    # Exit with appropriate code
    if [ ${STATS[errors_encountered]} -eq 0 ]; then
        print_success "TDD Loop completed successfully!"
        exit 0
    else
        print_error "TDD Loop completed with ${STATS[errors_encountered]} errors"
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"