# Project Structure - Visual Guide

## 🎯 **The Big Picture**

```
ORACLE DATABASE
       ↓
[Discovery Process] ───→ migration_config.json
       ↓
[Template Engine] ───→ SQL Scripts
       ↓
master1.sql ───→ COMPLETE MIGRATION
```

## 📁 **File Organization (Clean & Simplified)**

```
📦 oracle-table-migration/
│
├── 🎯 **MAIN ENTRY POINT**
│   ├── src/generate.py                  # 🎯 SINGLE ENTRY POINT
│   ├── README.md                        # Main project readme
│   └── requirements.txt                 # Python dependencies
│
├── 📚 **CORE LIBRARIES** (lib/)
│   ├── discovery_queries.py             # Database analysis
│   ├── migration_models.py              # Data structures  
│   ├── template_filters.py              # Jinja2 filters
│   └── config_validator.py              # Validation logic
│
├── 🎨 **TEMPLATES** (templates/)
│   ├── master1.sql.j2                   # 🎯 COMPLETE MIGRATION
│   ├── 10_create_table.sql.j2           # Create new table
│   ├── 20_data_load.sql.j2              # Data migration
│   ├── 40_delta_load.sql.j2             # Incremental loads
│   ├── 50_swap_tables.sql.j2            # ⚡ ATOMIC SWAP
│   ├── 60_restore_grants.sql.j2         # Restore permissions
│   ├── 70_drop_old_table.sql.j2         # Drop script (separate)
│   └── dynamic_grants.sql.j2            # Backup grants
│
├── 🧪 **TESTING & DEVELOPMENT**
│   ├── scripts/tdd-migration-loop.sh    # Development testing
│   ├── scripts/final-migration-test.sh  # Ultimate validation
│   ├── test/data/comprehensive_oracle_ddl.sql  # Test schema
│   └── test/runner.py                   # Test automation
│
├── 📋 **EXAMPLES & SAMPLES**
│   ├── examples/configs/                # Sample configurations
│   └── examples/generated/              # Sample outputs
│
├── 📤 **OUTPUT** (output/ - auto-generated)
│   └── SCHEMA_TABLE/                    # Generated per table
│       ├── master1.sql                  # 🎯 RUN THIS
│       ├── 10_create_table.sql          # Individual steps
│       ├── ...                          # (called by master1.sql)
│       ├── 70_drop_old_table.sql        # Manual execution only
│       └── dynamic_grants.sql           # Backup grants
│
└── 📖 **DOCUMENTATION**
    ├── docs/                            # User documentation
    └── .github/instructions/            # Development instructions
```

## 🔄 **Call Flow (Simplified)**

```
1. USER RUNS:
   python src/generate.py --config examples/configs/migration_config.json

2. DISCOVERY:
   lib/discovery_queries.py → Analyzes Oracle database
   lib/migration_models.py → Creates typed data structures

3. TEMPLATE RENDERING:
   templates/*.j2 → Rendered with Jinja2
   lib/template_filters.py → Custom filters applied

4. OUTPUT GENERATION:
   output/SCHEMA_TABLE/master1.sql → Complete migration
   output/SCHEMA_TABLE/*.sql → Individual steps

5. EXECUTION:
   sqlplus user/pass @output/SCHEMA_TABLE/master1.sql → Complete migration
```

## 🎯 **Key Files by Purpose**

### **Creating Migrations**
```
src/generate.py                      # Generate migration scripts
examples/configs/migration_config.json    # Sample configuration
templates/master1.sql.j2             # Main migration template
```

### **Testing Changes**
```
scripts/tdd-migration-loop.sh              # Development testing
scripts/final-migration-test.sh            # Final validation
test/data/comprehensive_oracle_ddl.sql     # Test schema
```

### **Understanding Structure**
```
.github/instructions/master_instructions_simplified.instructions.md
.github/instructions/project_overview.instructions.md
.github/instructions/development_workflow.instructions.md
```

### **Daily Development**
```
lib/migration_models.py       # Data structures
lib/discovery_queries.py      # Database analysis
templates/master1.sql.j2      # Migration logic
```

## 🚨 **Common Confusion Points**

### **❓ "Which file should I edit?"**
- **Templates** (`templates/*.j2`) - To change generated SQL
- **Data Models** (`lib/migration_models.py`) - To add new configuration options
- **Discovery** (`lib/discovery_queries.py`) - To capture new Oracle features

### **❓ "How do I test my changes?"**
```bash
./scripts/tdd-migration-loop.sh --generate-only --verbose
```

### **❓ "Which script do I run?"**
- **Development**: `python src/generate.py --config examples/configs/migration_config.json`
- **Testing**: `./scripts/tdd-migration-loop.sh --generate-only --verbose`
- **Final**: `./scripts/final-migration-test.sh --connection db`

### **❓ "What does master1.sql do?"**
It's the complete migration script that:
1. Creates new partitioned table
2. Migrates data (if requested)
3. Rebuilds indexes
4. Performs atomic table swap
5. Restores grants
6. Validates everything

## 🎪 **Remember**
- **One principle**: "it should just run master1.sql, nothing else should be required"
- **One config**: `migration_config.json`
- **One output**: `master1.sql` (per table)
- **One goal**: Zero manual intervention migrations