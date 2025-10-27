# Schema-Driven Architecture Flow
```
Schema → Models → Discovery → JSON → Generation → Templates → SQL
```
This document defines the **ONLY** acceptable way data flows through the system.

```
┌─────────────────────────────────────────────────────────────────┐
│  enhanced_migration_schema.json (SOURCE OF TRUTH)               │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  - Defines ALL data structures                                   │
│  - JSON Schema format with validation rules                      │
│  - Single source of truth - NEVER bypass this                    │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓ (generates via schema_to_dataclass.py)
                     │
┌─────────────────────────────────────────────────────────────────┐
│  migration_models.py (Python dataclasses)                        │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  - Auto-generated typed Python classes                           │
│  - MigrationConfig, TableConfig, CurrentState, etc.             │
│  - Methods: to_dict(), from_dict(), to_json(), from_json_file() │
│  - Type-safe with IDE support                                    │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓ (used by)
                     │
┌─────────────────────────────────────────────────────────────────┐
│  discovery_queries.py → MigrationConfig (typed)                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  1. Query Oracle database metadata                               │
│  2. Build typed dataclass objects (NOT dicts!)                   │
│  3. Return MigrationConfig object                                │
│                                                                   │
│  Example:                                                         │
│    config = MigrationConfig(                                     │
│        metadata=Metadata(...),                                   │
│        environment_config=EnvironmentConfig(...),                │
│        tables=[TableConfig(...), ...]                            │
│    )                                                              │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓ (serializes)
                     │
┌─────────────────────────────────────────────────────────────────┐
│  migration_config.json (validated JSON)                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  - JSON file written to disk                                     │
│  - Validated against enhanced_migration_schema.json              │
│  - Human-readable and editable                                   │
│  - Can be version controlled                                     │
│                                                                   │
│  Created by:                                                      │
│    config.save_to_file("migration_config.json")                 │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓ (deserializes)
                     │
┌─────────────────────────────────────────────────────────────────┐
│  generate.py → MigrationConfig.from_json_file()                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  1. Load JSON file                                               │
│  2. Deserialize to typed MigrationConfig object                  │
│  3. Validate against schema                                      │
│  4. Work with type-safe objects                                  │
│                                                                   │
│  Example:                                                         │
│    config = MigrationConfig.from_json_file("config.json")       │
│    for table in config.tables:                                   │
│        if table.enabled:                                         │
│            generate_scripts(table)  # Pass typed object!         │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓ (uses typed objects)
                     │
┌─────────────────────────────────────────────────────────────────┐
│  Templates → Render with type-safe access                        │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  - Receive typed TableConfig objects                             │
│  - Access properties with type safety                            │
│  - No dict.get() or KeyError risks                              │
│                                                                   │
│  Context passed to templates:                                    │
│    {                                                              │
│        "table": table,  # Entire typed object                    │
│        "owner": table.owner,                                     │
│        "current_state": table.current_state,                     │
│        "target_config": table.common_settings.target_config      │
│    }                                                              │
│                                                                   │
│  In Jinja2:                                                       │
│    {% for column in table.current_state.columns %}              │
│      {{ column.name }} {{ column.type }}                         │
│    {% endfor %}                                                   │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓ (produces)
                     │
┌─────────────────────────────────────────────────────────────────┐
│  master1.sql (Final DDL)                                         │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  - Complete executable SQL                                       │
│  - Ready to run: sqlplus @master1.sql                           │
│  - Zero manual intervention required                             │
│  - End-to-end table re-partitioning migration                    │
└─────────────────────────────────────────────────────────────────┘
```


## 📝 Summary

**Remember:**
1. Schema generates models
2. Models create typed objects
3. Typed objects serialize to JSON
4. JSON deserializes to typed objects
5. Templates use typed objects
6. Output is executable SQL

**The flow is:**



