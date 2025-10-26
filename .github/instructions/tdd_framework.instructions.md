# TDD Framework Instructions

## Development Workflow - ALWAYS Follow This Process:

1. **Before ANY code changes**: Run `./scripts/tdd-migration-loop.sh --validate-only`
2. **During development**: Use `./scripts/tdd-migration-loop.sh --generate-only --verbose` for rapid iteration
3. **After changes**: Run full TDD loop with `--connection` parameter
4. **Before committing**: Execute `./scripts/final-migration-test.sh` to ensure master1.sql completeness

## Testing Protocol

## Core TDD Workflow (`scripts/tdd-migration-loop.sh`)

### 7-Phase TDD Loop for Re-Partitioning Testing
1. **Drop Phase**: Clean table removal with dependency handling
2. **Create Phase**: Deploy comprehensive DDL with constraints/indexes  
3. **Load Phase**: Insert test data maintaining referential integrity
4. **Discover Phase**: Generate schema discovery JSON configuration
5. **Generate Phase**: Create re-partitioning scripts from templates
6. **Validate Phase**: Execute and verify generated master1.sql scripts
7. **Report Phase**: Detailed success/failure analysis with JSON output

### Re-Partitioning Workflow Steps Tested:
- ✅ Step 10: Create partitioned `table_new` 
- ✅ Step 20: Data migration with constraint disabling/enabling (if requested)
- ✅ Step 40: Delta load configurable by partition key (if requested)
- ✅ Step 50: Atomic table rename operations: `table → table_old; table_new → table`
- ✅ Step 60: Restore grants (dynamic_grants.sql as backup)
- ✅ Step 70: Drop old table (generate separate SQL, not part of master1.sql)
- ✅ Final: Complete validation and reporting

### Key Options & Features
```bash
--connection CONN_NAME      # SQLcl named connection
--subset TABLE_PATTERN      # Test specific tables (e.g., "SALES_*")
--iterations N              # Run N TDD cycles
--generate-only             # Skip DB operations, only generate scripts
--continue-on-error         # Don't stop on phase failures
--verbose                   # Detailed output and logging
```

## Validation Framework

### Final Migration Test (`scripts/final-migration-test.sh`)
**Critical validation**: Ensures master1.sql contains EVERYTHING for complete migration

#### Test Flow
1. Create comprehensive test schema (10 tables, constraints, indexes)
2. Generate migration scripts using current configuration  
3. Execute ONLY master1.sql for each table
4. Validate complete success with zero manual intervention
5. Report gaps requiring master1.sql template enhancement

#### Success Criteria
- ✅ Generate JSON config successfully
- ✅ Create DDL scripts from templates
- ✅ All master1.sql scripts execute without error
- ✅ Create `table_new` with different partitioning strategy
- ✅ Data migration completeness (row counts match exactly) if requested
- ✅ Constraint preservation (PK, FK, UK, CK all enabled)
- ✅ Index recreation (simple, composite, function-based)
- ✅ Atomic table renames work correctly
- ✅ Referential integrity preserved (FK relationships work)
- ✅ Grants handled properly (captured in config, restored as needed)
- ✅ Delta loads configurable by partition key (last day/hour)
- ✅ No manual intervention required

### Test Statistics & Monitoring
```bash
declare -A STATS
STATS[tables_migrated]=0
STATS[master_scripts_executed]=0
STATS[validation_errors]=0
STATS[total_errors]=0
```

## Demo & Documentation Scripts

### Demo Scripts
- **demo-tdd-loop.sh**: Shows TDD workflow capabilities and options
- **demo-final-test.sh**: Demonstrates ultimate validation framework
- Both provide help text, workflow explanation, success criteria

### Test Data Management
- **test_data/comprehensive_oracle_ddl.sql**: Complete Oracle feature set
- **test_runner.py**: Python test automation with color output and logging
- **Validation templates**: `/templates/validation/` directory

## Integration Points

### Database Integration
- SQLcl connection management with saved profiles
- Oracle feature detection and constraint validation
- Multi-environment support (dev, test, prod tablespaces)

### Script Generation Integration  
- Templates enhanced with constraint handling
- master1.sql.j2 contains steps 00-80 for complete migration
- Error handling and rollback capability

### Continuous Integration Ready
- Structured JSON output for CI/CD consumption
- Exit codes for pipeline integration
- Automated report generation
- Background process support for long-running operations