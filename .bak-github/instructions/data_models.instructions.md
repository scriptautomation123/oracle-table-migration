# Data Models & Schema Instructions

## When Working with Data Models:

1. **Schema Changes**: Modify `enhanced_migration_schema.json` → Run `tools/schema_to_dataclass.py` → Update templates
2. **New Oracle Features**: Add enum values → Update dataclasses → Enhance discovery queries → Test with comprehensive DDL
3. **Template Variables**: Use dataclass fields directly - `table.current_state.partition_type`, `table.target_configuration.interval_type`
4. **Validation**: Always validate against JSON schema before generation

## Data Structure Guidelines

## Core Data Models (`lib/migration_models.py`)

### Primary Enums
```python
class PartitionType(Enum):
    NONE, RANGE, LIST, HASH, REFERENCE, SYSTEM, INTERVAL

class IntervalType(Enum): 
    HOUR, DAY, WEEK, MONTH

class SubpartitionType(Enum):
    HASH, NONE

class MigrationAction(Enum):
    CONVERT_INTERVAL_TO_INTERVAL_HASH
    ADD_INTERVAL_HASH_PARTITIONING
    ADD_INTERVAL_PARTITIONING
    ADD_HASH_SUBPARTITIONS
    CONVERT_TO_INTERVAL_HASH
```

### Key Data Structures

#### TableConfig (Main Configuration Unit)
- **enabled**: Migration flag
- **owner/table_name**: Oracle identifiers  
- **current_state**: CurrentState with partition info, columns, constraints
- **target_configuration**: TargetConfiguration with desired end state
- **migration_settings**: MigrationSettings with execution parameters
- **common_settings**: CommonSettings with shared configurations

#### CurrentState (Discovered Information)
- **partition_type**: Current partitioning (NONE, RANGE, etc.)
- **partition_keys**: List of partition column names
- **columns**: List[ColumnInfo] with full column metadata
- **constraints**: Constraint definitions with referential integrity
- **indexes**: IndexInfo with composite/function-based details
- **lob_storage**: LobStorageInfo for LOB column handling

#### TargetConfiguration (Desired End State)
- **partition_type**: Target partitioning type
- **interval_type**: For interval partitioning (DAY, MONTH, etc.)
- **subpartition_type**: HASH subpartitioning specification
- **subpartition_count**: Number of hash subpartitions

## Schema Definitions

### JSON Schema (`lib/enhanced_migration_schema.json`)
- **$schema**: Draft-07 JSON Schema compliance
- **Comprehensive validation**: All Oracle features supported
- **Required fields**: metadata, environment_config, tables
- **Nested definitions**: 20+ complex object definitions

### Generated Models (`lib/generated_models.py`)
- **Auto-generated**: From JSON schema using tools/schema_to_dataclass.py
- **Type safety**: Full dataclass implementation with enums
- **Serialization**: to_dict/from_dict methods for JSON conversion

## Database Schema Context

### Comprehensive Test Schema (10 Tables)

#### Reference Tables (Non-partitioned)
- **REGIONS**: Geographic regions with PK
- **PRODUCTS**: Product catalog with categories
- **SALES_REPS**: Sales representative information  
- **CUSTOMERS**: Customer master with FK to regions

#### Partitioned Tables
- **ORDERS**: Range partitioned by order_date (monthly)
- **SALES_TRANSACTIONS**: Interval partitioned by transaction_date (daily)
- **ORDER_DETAILS**: Composite partitioned (range by order_date, hash by order_id)
- **TRANSACTION_LOG**: Composite partitioned with multiple subpartitions
- **TEMP_CALCULATIONS**: Hash partitioned for parallel processing
- **SESSION_DATA**: List partitioned by session_type

### Constraint Patterns
- **Primary Keys**: All tables with identity columns where appropriate
- **Foreign Keys**: Full referential integrity across all tables
- **Unique Constraints**: Business rule enforcement
- **Check Constraints**: Data validation and business logic
- **Complex multi-column constraints**: Advanced validation rules

### Index Patterns  
- **Simple indexes**: Single column performance optimization
- **Composite indexes**: Multi-column query optimization
- **Function-based indexes**: UPPER(), expression-based lookups
- **Bitmap indexes**: Low-cardinality columns
- **Reverse key indexes**: Sequence-based columns

## Template Integration

### Jinja2 Filter Functions (`lib/template_filters.py`)
- **SQL formatting**: quote_filter, sql_identifier_filter
- **Data formatting**: format_size_gb_filter, format_row_count_filter  
- **Oracle-specific**: parallel_hint_filter, format_interval_filter
- **Column operations**: format_column_list_filter, match_condition_filter

### Template Variables Available
- **table**: Complete TableConfig object
- **metadata**: Migration metadata
- **environment**: Environment-specific settings
- **All dataclass fields**: Direct access to nested properties