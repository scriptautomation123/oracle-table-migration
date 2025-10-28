# Schema-Driven Architecture - Strict Guidelines

## 🎯 Core Principle: Single Source of Truth

**RULE #1**: `lib/enhanced_migration_schema.json` is the ONLY source of truth for all data structures.

**RULE #2**: All code must be generated from or validated against the schema.

**RULE #3**: Never manually create data structures that aren't in the schema.

## 📊 Architecture Flow (Strictly Enforced)

```
┌─────────────────────────────────────────────────────────────────┐
│  enhanced_migration_schema.json (SOURCE OF TRUTH)               │
│  - Defines all data structures                                   │
│  - Contains type definitions, constraints, descriptions          │
│  - JSON Schema format for validation                             │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ├─────────────────────────────────────────────┐
                     ▼                                             ▼
    ┌────────────────────────────────┐          ┌─────────────────────────────┐
    │  schema_to_dataclass.py        │          │  ConfigValidator           │
    │  (CODE GENERATION)             │          │  (RUNTIME VALIDATION)      │
    │                                │          │                            │
    │  Generates →                   │          │  Validates JSON against    │
    │  lib/migration_models.py       │          │  the schema                │
    └────────────────┬───────────────┘          └──────────┬─────────────────┘
                     │                                      │
                     ▼                                      │
    ┌────────────────────────────────┐                     │
    │  migration_models.py           │                     │
    │  (TYPED DATACLASSES)           │                     │
    │                                │◄────────────────────┘
    │  - MigrationConfig             │
    │  - TableConfig                 │
    │  - CurrentState                │
    │  - ColumnInfo                  │
    │  - IndexInfo, etc.             │
    │                                │
    │  Methods:                      │
    │  - to_dict() → JSON            │
    │  - from_dict() → Objects       │
    │  - to_json() → String          │
    │  - from_json_file() → Objects  │
    └────────────────┬───────────────┘
                     │
                     ├──────────────────────────────────────────┐
                     ▼                                          ▼
    ┌────────────────────────────────┐      ┌──────────────────────────────┐
    │  discovery_queries.py          │      │  generate.py                 │
    │  (DISCOVERY MODE)              │      │  (GENERATION MODE)           │
    │                                │      │                              │
    │  1. Query Oracle DB            │      │  1. Load JSON config         │
    │  2. Build typed objects        │      │  2. Deserialize to objects   │
    │  3. Return MigrationConfig     │      │  3. Pass objects to templates│
    │  4. Serialize to JSON          │      │  4. Generate DDL             │
    └────────────────────────────────┘      └──────────────────────────────┘
```

## 🔄 Complete Workflow (Schema-Driven)

### **Step 0: Schema Updates (When Needed)**

```bash
# 1. Update the schema
vim lib/enhanced_migration_schema.json

# 2. Regenerate dataclasses from schema
python src/schema_to_dataclass.py

# 3. This updates lib/migration_models.py automatically
```

### **Step 1: Discovery (Creates Typed Config)**

```bash
python src/generate.py --discover \
  --schema APP_DATA_OWNER \
  --connection "user/pass@host:port/service"
```

**What happens internally:**
```python
# lib/discovery_queries.py
def discover_schema() -> MigrationConfig:
    # 1. Query database
    raw_data = query_oracle_metadata()
    
    # 2. Build typed dataclass objects (NOT dicts!)
    metadata = Metadata(...)
    env_config = EnvironmentConfig(...)
    table_configs = [TableConfig(...), ...]
    
    # 3. Create typed MigrationConfig
    config = MigrationConfig(
        metadata=metadata,
        environment_config=env_config,
        tables=table_configs
    )
    
    # 4. Serialize to JSON (validates against schema)
    config.save_to_file("migration_config.json")
    
    return config  # Returns typed object
```

**Output**: `migration_config.json` ✅ **Validated against schema**

### **Step 2: Validation (Schema-Based)**

```bash
python src/generate.py --config migration_config.json --validate-only
```

**What happens internally:**
```python
# lib/config_validator.py
def validate_config(config_dict: Dict) -> bool:
    # 1. Load schema
    schema = load_json("lib/enhanced_migration_schema.json")
    
    # 2. JSONSchema validation
    validate(config_dict, schema)  # Throws if invalid
    
    # 3. Business logic validation using typed models
    migration_config = MigrationConfig.from_dict(config_dict)
    
    # Now validate with type safety
    for table in migration_config.tables:
        if table.enabled:
            assert table.current_state.partition_column is not None
            # etc.
    
    return True
```

### **Step 3: Generation (Uses Typed Objects)**

```bash
python src/generate.py --config migration_config.json
```

**What happens internally (SHOULD BE):**
```python
# src/generate.py
def generate_scripts(config_file: str):
    # ❌ WRONG (Current approach):
    config_dict = json.load(config_file)
    for table_dict in config_dict["tables"]:
        context = _prepare_template_context(table_dict)  # Works with dicts
    
    # ✅ RIGHT (Schema-driven approach):
    config = MigrationConfig.from_json_file(config_file)  # Load as typed object
    
    for table in config.tables:  # Iterate typed objects
        if not table.enabled:
            continue
        
        # Pass typed objects to templates (with type safety!)
        context = {
            "table": table,  # Pass the whole typed object
            "owner": table.owner,  # Type-safe access
            "table_name": table.table_name,
            "current_state": table.current_state,  # Typed CurrentState object
            "target_config": table.common_settings.target_configuration,
            # ... all type-safe
        }
        
        template.render(context)
```

## 🎯 Enforcement Rules

### **Rule 1: No Manual Dict Construction**

❌ **WRONG:**
```python
config = {
    "metadata": {
        "generated_date": "2024-01-01",
        "source_schema": "MY_SCHEMA"
    },
    "tables": [...]
}
```

✅ **RIGHT:**
```python
from lib.migration_models import Metadata, MigrationConfig

metadata = Metadata(
    generated_date="2024-01-01",
    source_schema="MY_SCHEMA",
    ...
)

config = MigrationConfig(
    metadata=metadata,
    tables=[...]
)
```

### **Rule 2: Always Use Typed Objects Internally**

❌ **WRONG:**
```python
def process_table(table_dict: Dict[str, Any]):
    table_name = table_dict.get("table_name")  # Untyped, can be None
    owner = table_dict.get("owner")  # Runtime error if missing
```

✅ **RIGHT:**
```python
def process_table(table: TableConfig):
    table_name = table.table_name  # Type-safe, IDE autocomplete
    owner = table.owner  # Guaranteed to exist per schema
```

### **Rule 3: Serialization/Deserialization Only at Boundaries**

**Boundaries:**
- File I/O (reading/writing JSON)
- Network (API calls)
- Database storage

**Example:**
```python
# Boundary: Load from file → Typed object
config = MigrationConfig.from_json_file("config.json")

# Internal: Work with typed objects only
for table in config.tables:
    process_table(table)  # Pass typed object

# Boundary: Save to file → JSON
config.save_to_file("output.json")
```

### **Rule 4: Template Context Uses Typed Objects**

❌ **WRONG (Current):**
```python
context = {
    "owner": table_dict.get("owner"),
    "table_name": table_dict.get("table_name"),
    "columns": table_dict.get("current_state", {}).get("columns", []),
}
```

✅ **RIGHT (Should be):**
```python
context = {
    "table": table,  # Pass whole typed object
    "owner": table.owner,
    "table_name": table.table_name,
    "columns": table.current_state.columns,  # Type-safe access
    "indexes": table.current_state.indexes,
    "target_config": table.common_settings.target_configuration,
}
```

**In Jinja2 templates:**
```jinja2
{# Access typed object properties directly #}
CREATE TABLE {{ table.owner }}.{{ table.common_settings.new_table_name }}
(
  {% for column in table.current_state.columns %}
    {{ column.name }} {{ column.type }}
    {%- if column.nullable == 'N' %} NOT NULL{% endif %}
    {%- if column.default %} DEFAULT {{ column.default }}{% endif %}
    {%- if not loop.last %},{% endif %}
  {% endfor %}
)
```

## 📝 Required Changes for Strict Schema-Driven

### **Change 1: Update generate.py to use typed objects**

**File:** `src/generate.py`

**Current (lines 533-568):**
```python
def _prepare_template_context(self, table_config: Dict[str, Any]) -> Dict[str, Any]:
    """Prepare template context"""
    owner = table_config.get("owner")
    table_name = table_config.get("table_name")
    target_config = table_config.get("target_configuration", {})
    # ... lots of dict.get() calls
```

**Should be:**
```python
from lib.migration_models import TableConfig

def _prepare_template_context(self, table: TableConfig) -> Dict[str, Any]:
    """Prepare template context with typed objects"""
    return {
        "table": table,  # Pass entire typed object
        "owner": table.owner,
        "table_name": table.table_name,
        "new_table_name": table.common_settings.new_table_name,
        "old_table_name": table.common_settings.old_table_name,
        "current_state": table.current_state,
        "target_configuration": table.common_settings.target_configuration,
        "migration_settings": table.common_settings.migration_settings,
        # All type-safe!
    }
```

### **Change 2: Load config as typed object in generate.py**

**File:** `src/generate.py`

**Current (line 404, 430):**
```python
config_data = config_service.load_config(self.config.config_file)
# Returns Dict[str, Any]
```

**Should be:**
```python
from lib.migration_models import MigrationConfig

# In ConfigService.load_config():
def load_config(self, config_file: str) -> MigrationConfig:
    """Load configuration as typed object"""
    return MigrationConfig.from_json_file(config_file)
```

### **Change 3: Update all template contexts**

**Files:** 
- `templates/master1.sql.j2`
- `templates/10_create_table.sql.j2`
- All other templates

**Current:**
```jinja2
{% for col_dict in columns %}
  {{ col_dict.name }} {{ col_dict.type }}
{% endfor %}
```

**Should be:**
```jinja2
{% for column in table.current_state.columns %}
  {{ column.name }} {{ column.type }}
  {%- if column.is_identity %}
    GENERATED {{ column.identity_generation }} AS IDENTITY
  {%- endif %}
{% endfor %}
```

## ✅ Benefits of Strict Schema-Driven Architecture

1. **Type Safety**: Catch errors at development time, not runtime
2. **IDE Support**: Autocomplete, refactoring, go-to-definition
3. **Maintainability**: Single source of truth for all structures
4. **Validation**: Automatic validation against schema
5. **Documentation**: Schema serves as living documentation
6. **Refactoring**: Change schema → regenerate → update code
7. **Consistency**: Impossible to have mismatched structures

## 🔍 Verification Checklist

- [ ] Schema defines all data structures
- [ ] Dataclasses generated from schema
- [ ] Discovery returns typed objects
- [ ] Generation loads typed objects
- [ ] Templates receive typed objects
- [ ] No manual dict construction
- [ ] All validation uses schema
- [ ] JSON only at boundaries

## 🚀 Implementation Priority

1. **High Priority**: Update `src/generate.py` to use `MigrationConfig.from_json_file()`
2. **High Priority**: Update `_prepare_template_context()` to accept `TableConfig` typed object
3. **Medium Priority**: Update templates to access typed object properties
4. **Medium Priority**: Update `ConfigService.load_config()` to return typed object
5. **Low Priority**: Add strict type checking with `mypy`

---

**Remember:** If it's not in the schema, it doesn't exist!
