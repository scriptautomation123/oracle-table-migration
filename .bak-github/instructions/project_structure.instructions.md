# Project Structure Instructions

## When Adding/Modifying Components:

1. **New Oracle Features**: Add to `test/data/comprehensive_oracle_ddl.sql` → Update `lib/discovery_queries.py` → Enhance templates
2. **Script Generation Changes**: Modify `src/generate.py` → Update `templates/master1.sql.j2` → Test with TDD loop
3. **New Validation**: Add to `scripts/final-migration-test.sh` → Create demo script → Update success criteria
4. **Template Changes**: Always ensure `templates/master1.sql.j2` contains complete workflow

## Architecture Guidelines

## Core Architecture

### Primary Entry Point
- **src/generate.py**: Unified migration script generator (consolidates all previous generate_*.py scripts)

### Support Libraries (lib/)
- **discovery_queries.py**: Schema discovery with constraint/index detection
- **migration_models.py**: Type-safe dataclasses for all migration entities  
- **config_validator.py**: JSON schema validation with database checks
- **template_filters.py**: Jinja2 custom filters for SQL generation

### Testing Framework (test/)
- **test/runner.py**: Automated test runner with comprehensive Oracle schema testing
- **test/data/comprehensive_oracle_ddl.sql**: Complete test schema

### Examples and Samples (examples/)
- **examples/configs/**: Sample migration configuration files
- **examples/generated/**: Example generated outputs for reference

### Template System (`/templates/`)
- **master1.sql.j2**: Complete end-to-end migration (steps 00-80)
- **master2.sql.j2**: Alternative master script
- **Individual steps**: 10_create_table.sql.j2 through 70_drop_old_table.sql.j2
- **POC templates**: `/poc/` directory
- **Validation templates**: `/validation/` directory

### Test Framework (`/scripts/`)
- **tdd-migration-loop.sh**: Complete TDD automation (7-phase workflow)
- **final-migration-test.sh**: Ultimate validation ensuring master1.sql completeness
- **demo-*.sh**: Demonstration scripts showing capabilities
- **vscode-settings-manager.sh**: VS Code configuration management

## Dependencies & Integrations

### Python Dependencies
- **Jinja2**: Template engine for SQL generation
- **cx_Oracle/oracledb**: Database connectivity
- **jsonschema**: Configuration validation
- **dataclasses**: Type safety and serialization

### Oracle Features Supported
- **Partitioning**: Range, List, Hash, Interval, Composite
- **Constraints**: PK, FK, UK, CK with full referential integrity
- **Indexes**: Simple, composite, function-based, bitmap
- **Advanced**: Identity columns, LOB storage, parallel operations

### File Relationships
```
src/generate.py → lib/migration_models.py → templates/master1.sql.j2
test/runner.py → test/data/comprehensive_oracle_ddl.sql
scripts/tdd-migration-loop.sh → src/generate.py
scripts/final-migration-test.sh → validates master1.sql completeness
```

## Critical Success Path
1. **test/data/comprehensive_oracle_ddl.sql** provides complete test schema
2. **scripts/tdd-migration-loop.sh** enables iterative development
3. **src/generate.py** generates constraint-aware migrations
4. **templates/master1.sql.j2** contains ALL migration steps in single script
5. **scripts/final-migration-test.sh** validates zero-manual-intervention requirement