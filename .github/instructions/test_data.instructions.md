# Test Data Instructions

## When Working on Test Data (`/test_data/` directory):

### Comprehensive Oracle DDL (Critical File):
- **test_data/comprehensive_oracle_ddl.sql**: Complete Oracle feature set test schema
- This file defines the canonical test case for all migration scenarios
- Must include every Oracle feature the system should support

### Test Schema Development Workflow:
1. **Add new Oracle feature** to comprehensive_oracle_ddl.sql
2. **Include full constraints**: PK, FK, UK, CK with referential integrity
3. **Add various index types**: Simple, composite, function-based, bitmap
4. **Test all partition types**: Range, List, Hash, Interval, Composite
5. **Validate with TDD loop**: Ensure discovery and generation work correctly

### Test Schema Structure (10 Tables):
- **4 Reference tables**: REGIONS, PRODUCTS, SALES_REPS, CUSTOMERS
- **6 Partitioned tables**: Various partition strategies for comprehensive testing
- **Full referential integrity**: FK relationships across all tables
- **Sample data**: Sufficient for testing migration scenarios

### Oracle Feature Coverage:
- **Partitioning**: All types including composite partitioning
- **Constraints**: Complete constraint matrix with complex relationships
- **Indexes**: All index types including function-based and bitmap
- **Identity columns**: Where appropriate for primary keys
- **LOB storage**: For testing large object migration
- **Advanced features**: Parallel settings, storage parameters

### Test Data Best Practices:
- Use realistic data volumes for performance testing
- Include edge cases: NULL values, boundary conditions
- Maintain referential integrity across all test data
- Use meaningful business names for better readability
- Include data distribution patterns for partition testing

### Adding New Test Scenarios:
1. **Identify Oracle feature gap** in current test schema
2. **Add table or modify existing** with new feature
3. **Update constraints and indexes** to exercise feature
4. **Add sample data** that tests the feature thoroughly
5. **Run TDD loop** to ensure discovery and generation work
6. **Update final validation** if new checks are needed