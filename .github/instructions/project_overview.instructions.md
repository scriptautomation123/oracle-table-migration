# Oracle Table Migration - Project Overview & Structure

## 🎯 **Core Purpose**
**Migrate existing partitioned Oracle tables to differently partitioned tables with zero manual intervention**

### Simple Success Definition:
```bash
# Discovery mode (generate config from database):
python3 src/generate.py --discover --schema APP_DATA_OWNER --connection "sys/oracle123@localhost:1521/freepdb1" --output-file migration_config.json

# Generation mode (create scripts from config):
python3 src/generate.py --config migration_config.json

# Execute migration:
cd output/SCHEMA_TABLE/
sqlplus user/pass @master1.sql
# ✅ Migration complete!
```

## 📊 **High-Level Architecture Diagram**

```
┌─────────────────────────────────────────────────────────────────┐
│                    ORACLE TABLE MIGRATION                       │
│                                                                │
│  [Oracle DB] ──discovery──> [Config JSON] ──templates──> [SQL] │
│                                                                │
└─────────────────────────────────────────────────────────────────┘

FLOW:
1. Oracle Database (existing partitioned tables)
2. Discovery Process (analyze schema, capture metadata)
3. Configuration JSON (typed data models) 
4. Template Engine (Jinja2 templates)
5. Generated SQL Scripts (master1.sql + individual steps)
6. Execution (run master1.sql = complete migration)
```

## 🔍 **Component Flow Diagram**

```
Entry Points:
├── src/generate.py ─────────────────┐  (UNIFIED ENTRY POINT)
├── src/generate_scripts.py ─────────┤  (Reference implementation)
└── scripts/tdd-migration-loop.sh ───┘  (Testing framework)
                                     │
                                     ▼
                          ┌─────────────────┐
                          │ Discovery Layer │
                          │                │
                          │ • TableDiscovery│
                          │ • Schema Analysis│
                          │ • Grants Capture│
                          └─────────┬───────┘
                                    │
                                    ▼
                          ┌─────────────────┐
                          │  Data Models   │
                          │                │
                          │ • MigrationConfig│
                          │ • TableConfig  │
                          │ • CurrentState │
                          │ • GrantInfo    │
                          └─────────┬───────┘
                                    │
                                    ▼
                          ┌─────────────────┐
                          │ Template Engine │
                          │                │
                          │ • Jinja2 Render│
                          │ • Custom Filters│
                          │ • Context Build │
                          └─────────┬───────┘
                                    │
                                    ▼
                          ┌─────────────────┐
                          │ Generated SQL  │
                          │                │
                          │ • master1.sql  │
                          │ • 10 scripts/table│
                          │ • Validation   │
                          └─────────────────┘
```

## 🏗️ **Directory Structure (Organized)**

### **Core Execution Files**
```
src/
├── generate.py                      # 🎯 UNIFIED MAIN ENTRY POINT
├── generate_scripts.py              # 📚 Reference implementation (complete discovery architecture)
└── schema_to_dataclass.py           # Schema to dataclass conversion utility

test/
├── runner.py                        # Development testing framework
└── migration_config.json            # 📊 MAIN CONFIG FILE (generated)
```

### **Library Components** 
```
lib/
├── discovery_queries.py             # 🔍 Database schema discovery
├── migration_models.py              # 📋 Typed data structures
├── template_filters.py              # 🎨 Jinja2 custom filters
├── config_validator.py              # ✅ Configuration validation
├── environment_config.py            # 🌍 Environment settings
└── migration_validator.py           # 🧪 Migration validation
```

### **Templates (The Heart)**
```
templates/
├── master1.sql.j2                   # 🎯 COMPLETE MIGRATION SCRIPT
├── 10_create_table.sql.j2           # Create new partitioned table  
├── 20_data_load.sql.j2              # Data migration (conditional)
├── 30_create_indexes.sql.j2         # Rebuild indexes
├── 40_delta_load.sql.j2             # Incremental loads (conditional)
├── 50_swap_tables.sql.j2            # ⚡ ATOMIC TABLE SWAP
├── 60_restore_grants.sql.j2         # Restore permissions
├── 70_drop_old_table.sql.j2         # 🗑️ SEPARATE drop script
├── dynamic_grants.sql.j2            # 🔧 Backup grants script
└── validation/*.sql                 # Validation queries
```

### **Generated Output**
```
output/
└── SCHEMA_TABLE/                    # One directory per table
    ├── master1.sql                  # 🎯 RUN THIS - complete migration
    ├── 10_create_table.sql          # Individual step scripts
    ├── 20_data_load.sql             #   (called by master1.sql)
    ├── ...                          #
    ├── 70_drop_old_table.sql        # 🗑️ Manual execution only
    ├── dynamic_grants.sql           # 🔧 Backup grants restoration
    └── README.md                    # Migration instructions
```

### **Development & Testing**
```
scripts/
├── tdd-migration-loop.sh            # 🔄 Main development testing
├── final-migration-test.sh          # 🎯 Ultimate validation
└── demo-*.sh                       # Demo scripts

test_data/
└── comprehensive_oracle_ddl.sql     # 📊 Test schema (all Oracle features)
```

## 🔄 **Key Dependencies & Call Flow**

### **1. Discovery Process**
```
generate_scripts.py
  ├── TableDiscovery (lib/discovery_queries.py)
  │   ├── Connects to Oracle database
  │   ├── Analyzes tables, constraints, indexes, grants
  │   └── Returns MigrationConfig (typed data)
  │
  └── MigrationConfig (lib/migration_models.py)
      ├── TableConfig (per table)
      ├── CurrentState (existing structure)
      ├── CommonSettings (migration parameters)
      └── GrantInfo (captured permissions)
```

### **2. Template Rendering**
```
generate_scripts.py
  ├── Jinja2 Environment Setup
  │   ├── Custom filters (lib/template_filters.py)
  │   ├── Template directory (templates/)
  │   └── Context building (typed data → dict)
  │
  └── For each table:
      ├── Load template (master1.sql.j2, etc.)
      ├── Render with table context
      └── Write to output/SCHEMA_TABLE/
```

### **3. Generated Script Structure**
```
master1.sql (The Complete Migration)
  ├── Conditional Step 00: Disable constraints (if data migration)
  ├── Always Step 10: Create new partitioned table 
  ├── Conditional Step 20: Data migration (if requested)
  ├── Always Step 30: Create indexes
  ├── Conditional Step 40: Delta loads (if requested) 
  ├── Always Step 50: ⚡ ATOMIC table swap
  ├── Always Step 60: Restore grants
  ├── Note Step 70: Drop script available separately
  └── Conditional Step 80: Enable constraints (if disabled)
```

## 🎯 **Critical Success Paths**

### **Path 1: Table Structure Only**
```
Data Migration = FALSE, Delta Load = FALSE
├── Step 10: Create new table ✓
├── Step 30: Create indexes ✓  
├── Step 50: Atomic swap ✓
├── Step 60: Restore grants ✓
└── Result: New partitioning, no data moved
```

### **Path 2: Complete Data Migration**
```
Data Migration = TRUE, Delta Load = TRUE
├── Step 00: Disable constraints ✓
├── Step 10: Create new table ✓
├── Step 20: Migrate all data ✓
├── Step 30: Create indexes ✓
├── Step 40: Delta load recent changes ✓
├── Step 50: Atomic swap ✓
├── Step 60: Restore grants ✓
├── Step 80: Enable constraints ✓
└── Result: Complete migration with all data
```

## 🚨 **Important Concepts**

### **1. Atomic Table Swap**
```sql
-- NOT a true atomic operation, but made atomic by ensuring:
-- Both renames succeed OR both fail
ALTER TABLE table RENAME TO table_old;      -- Step 1
ALTER TABLE table_new RENAME TO table;      -- Step 2
-- If Step 2 fails, rollback Step 1 immediately
```

### **2. Conditional Workflow**
Templates use `common_settings.migration_settings` flags:
- `migrate_data: true/false` → Controls Step 20
- `enable_delta_load: true/false` → Controls Step 40  
- `delta_load_interval: "last_day"/"last_hour"` → Configures Step 40

### **3. Grants Handling**
- **Discovery**: Captures grants into `config.json`
- **Restoration**: `60_restore_grants.sql` uses captured grants
- **Backup**: `dynamic_grants.sql` for manual execution if needed

### **4. Zero Manual Intervention**
The goal: `master1.sql` should run completely without user input:
- ✅ No PAUSE statements
- ✅ No manual decisions
- ✅ Complete error handling
- ✅ Validation at each step

## 🎪 **Development Workflow**

### **Daily Development**
```bash
# 1. Make changes to templates or code
# 2. Test with TDD loop
./scripts/tdd-migration-loop.sh --generate-only --verbose

# 3. Final validation
./scripts/final-migration-test.sh --connection my_db

# 4. If successful, changes are ready
```

### **Adding New Features**
1. **Update data models** (`lib/migration_models.py`)
2. **Enhance discovery** (`lib/discovery_queries.py`)  
3. **Update templates** (`templates/*.j2`)
4. **Test with TDD loop** until validation passes
5. **Update documentation** (this file)

This structure ensures the core principle: **"it should just run master1.sql, nothing else should be required"**