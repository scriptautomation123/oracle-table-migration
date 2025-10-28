# Configuration Instructions

## When Modifying Configurations:

1. **VS Code Settings**: Always test changes with `./scripts/check-vscode.sh`
2. **Oracle Connections**: Use SQLcl named connections, validate with `--connection` parameter
3. **Schema Changes**: Update `comprehensive_oracle_ddl.sql` first, then run TDD loop
4. **Environment Settings**: Modify `lib/environment_config.py` for tablespace/parallel changes
5. **Grants Management**: Ensure grants captured in config.json during generation, create dynamic_grants.sql as backup

## Configuration Guidelines

## VS Code Settings Management

### Current Configuration
- **Workspace settings**: `.vscode/settings.json` - file exclusions, extension management
- **Extensions config**: `.vscode/extensions.json` - 4 recommended, 29 unwanted
- **Recommended extensions**: trunk.io, github.copilot, github.copilot-chat, maciejdems.add-to-gitignore

### Management Scripts
- **check-vscode.sh**: Quick config overview
- **vscode-settings-manager.sh**: Comprehensive analysis and backup
- **disable-unwanted-extensions.sh**: Bulk extension disable with confirmation
- **dev-tools.sh**: Master development tools script (trunk, yaml, config management)

## Oracle Configuration

### Connection Management
- Uses SQLcl named connections: `sqlcl /nolog; conn user/pass@host:port/service; save connection name`
- Connection validation in scripts via `--connection` parameter
- Database service protocol abstraction in generate_scripts.py

### Environment Configuration (`lib/environment_config.py`)
```python
@dataclass
class EnvironmentConfig:
    name: str
    data_tablespaces: DataTablespaces
    subpartition_defaults: SubpartitionDefaults
    parallel_defaults: ParallelDefaults
```

### Schema Configuration (`migration_config.json`)
- **Metadata**: generated_date, source_schema, environment, discovery_criteria
- **Tables array**: Complete table configurations with current_state, target_configuration
- **Environment-specific**: tablespace mappings, parallel settings, subpartition counts
- **Grants capture**: Table privileges, column privileges, role grants captured during generation
- **Grant scripts**: Generate `dynamic_grants.sql` as backup restoration script

## Test Configuration

### Comprehensive DDL Schema (`test_data/comprehensive_oracle_ddl.sql`)
- **10 test tables**: REGIONS, PRODUCTS, SALES_REPS, CUSTOMERS, ORDERS, ORDER_DETAILS, SALES_TRANSACTIONS, TRANSACTION_LOG, TEMP_CALCULATIONS, SESSION_DATA
- **All partition types**: Range, List, Hash, Interval, Composite
- **Full constraints**: 25+ constraint definitions with referential integrity
- **Advanced indexes**: Function-based, composite, bitmap, reverse key

### TDD Configuration
- **Schema name**: APP_DATA_OWNER (configurable)
- **Connection**: Named SQLcl connections
- **Iterations**: Configurable loop count for stress testing
- **Validation**: Multi-level error checking and reporting
- **Output**: Structured JSON reports and detailed logs

## Key Configuration Files
- `migration_config.json`: Main migration configuration
- `schema_discovery_config.json`: Discovery parameters
- `requirements.txt`: Python dependencies
- `lib/enhanced_migration_schema.json`: Complete JSON schema
- `.context/`: Context files for development reference