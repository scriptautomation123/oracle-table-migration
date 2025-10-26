# Library Instructions

## When Working on Library Code (`/lib/` directory):

### Core Library Components:
- **migration_models.py**: Type-safe dataclasses - the foundation of the system (enums, dataclasses with type hints)
- **discovery_queries.py**: Schema discovery with complete Oracle metadata capture (TableDiscovery class)
- **config_validator.py**: JSON schema validation with database checks (ConfigValidator class)
- **template_filters.py**: Jinja2 custom filters for SQL generation (get_template_filters(), register_custom_filters())
- **environment_config.py**: Environment-specific settings (tablespaces, parallel, subpartitioning defaults)

### Development Workflow for Library Changes:
1. **Schema changes**: Update `enhanced_migration_schema.json` first
2. **Regenerate models**: Run `tools/schema_to_dataclass.py`
3. **Update discovery**: Enhance `discovery_queries.py` for new features
4. **Test thoroughly**: Run TDD loop with comprehensive DDL
5. **Validate templates**: Ensure all templates can access new properties

### Data Model Guidelines:
- Use Python dataclasses with type hints
- Implement enums for constrained values
- Provide serialization methods (to_dict/from_dict)
- Validate all inputs using JSON schema
- Support all Oracle partition types and constraint combinations

### Discovery Query Patterns:
- Always use parameterized queries to prevent SQL injection (bind variables)
- Validate Oracle identifiers before use (proper schema.table patterns)
- Handle all Oracle constraint types: PK, FK, UK, CK with _get_constraint_info()
- Detect composite and function-based indexes with _get_index_details()
- Discover referential integrity relationships with _get_referential_integrity()
- Capture grants with _get_table_grants()
- Support all Oracle partitioning: RANGE, LIST, HASH, INTERVAL, COMPOSITE
- Use context managers for database connections (DatabaseService.connection())

### Template Filter Development:
- Create reusable filters for common SQL patterns
- Handle NULL values gracefully
- Provide meaningful error messages
- Test with all supported data types
- Document filter parameters and examples

### Error Handling:
- Use custom exception classes
- Provide actionable error messages
- Include context information for debugging
- Validate prerequisites before operations
- Implement proper logging throughout