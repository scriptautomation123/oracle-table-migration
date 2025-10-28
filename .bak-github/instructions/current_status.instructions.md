````instructions
# Current Project Status - Updated Instructions

## 🎯 **Critical Findings from Code Review & Testing**

### **Discovery Architecture Status**
- ✅ **Complete discovery implementation exists** in `src/generate_scripts.py` (reference implementation)
- ✅ **Discovery functionality restored** in `src/generate.py` (unified entry point)
- ✅ **DatabaseService with context managers** properly implemented
- ✅ **TableDiscovery class** with comprehensive Oracle metadata capture
- ✅ **Real database connection required** - no mocking allowed

### **Entry Points Clarified**
```bash
# UNIFIED MAIN ENTRY POINT (preferred)
src/generate.py

# REFERENCE IMPLEMENTATION (complete discovery architecture)
src/generate_scripts.py

# TESTING FRAMEWORK
scripts/tdd-migration-loop.sh
```

### **Correct Command Patterns**
```bash
# Discovery Mode (mandatory first step)
python3 src/generate.py --discover --schema APP_DATA_OWNER --connection "sys/oracle123@localhost:1521/freepdb1" --output-file migration_config.json

# Generation Mode (uses discovered config)
python3 src/generate.py --config migration_config.json

# Validation Mode  
python3 src/generate.py --config migration_config.json --validate-only
```

## 🔧 **Key Architecture Components**

### **Discovery Process (Real Database Required)**
1. **DatabaseService.connection()** - Context manager for Oracle connections
2. **TableDiscovery.discover_schema()** - Complete schema analysis
3. **MigrationConfig dataclass** - Typed configuration structure
4. **discovery.save_config()** - JSON serialization with validation hash

### **Template System (Jinja2 + Custom Filters)**
1. **templates/master1.sql.j2** - Complete migration workflow
2. **lib/template_filters.py** - Custom SQL generation filters
3. **Context building** - Flattens dataclass structures for templates
4. **Conditional logic** - Data migration, delta loads, constraint handling

### **Validation Framework**
1. **ConfigValidator** - JSON schema validation
2. **Database validation** - Real Oracle connection checks
3. **Discovery validation hash** - Ensures config is discovery-generated
4. **Template compatibility** - All templates work with discovered data

## 🚨 **Critical Requirements Discovered**

### **Database Connection Requirements**
- **Oracle client libraries** must be available (oracledb package)
- **Real Oracle database** required - no mocking or sample data allowed
- **SYSDBA authentication** supported for system schema discovery
- **Connection string format**: `"sys/oracle123@localhost:1521/freepdb1"`

### **Discovery-Driven Workflow (Mandatory)**
- **Config generation** must come from real database discovery
- **Pre-existing configs** not allowed without discovery validation hash
- **Schema analysis** captures all Oracle features: partitions, constraints, indexes, grants
- **Type safety** enforced through dataclasses and JSON schema validation

### **Template System Requirements**
- **master1.sql.j2** must contain complete end-to-end migration
- **Conditional logic** for data migration and delta loads
- **Atomic rename operations** implemented as transactions
- **Zero manual intervention** - scripts must run completely automated

## 📊 **Current File Organization**

### **Core Implementation Files**
```
src/
├── generate.py                    # UNIFIED ENTRY POINT ⭐
├── generate_scripts.py            # Reference implementation (complete discovery)
└── schema_to_dataclass.py         # Schema conversion utility

lib/
├── discovery_queries.py           # TableDiscovery class ⭐
├── migration_models.py            # Typed dataclasses ⭐
├── config_validator.py            # Validation framework
├── template_filters.py            # Jinja2 custom filters ⭐
└── environment_config.py          # Environment-specific settings
```

### **Testing & Validation**
```
scripts/
├── tdd-migration-loop.sh          # Development testing framework ⭐
├── final-migration-test.sh        # Ultimate validation
└── demo-*.sh                      # Demonstration scripts

test/
├── runner.py                      # Test framework
└── data/
    └── comprehensive_oracle_ddl.sql # Complete test schema ⭐
```

### **Templates & Output**
```
templates/
├── master1.sql.j2                 # Complete migration workflow ⭐
├── 10_create_table.sql.j2          # Individual step templates
├── 20_data_load.sql.j2             # ...
└── ... (other step templates)

output/                             # Generated scripts
└── SCHEMA_TABLE/                   # One directory per table
    ├── master1.sql ⭐              # MAIN EXECUTION SCRIPT
    ├── README.md                   # Instructions
    └── ... (individual steps)
```

## 🎯 **Development Workflow (Updated)**

### **1. Discovery First (Always)**
```bash
# Connect to real Oracle database and generate config
python3 src/generate.py --discover --schema SCHEMA --connection "conn_string" --output-file config.json
```

### **2. Validate Discovery**
```bash
# Validate the discovered configuration
python3 src/generate.py --config config.json --validate-only
```

### **3. Generate Scripts**
```bash
# Generate migration scripts from discovered config
python3 src/generate.py --config config.json
```

### **4. Test & Validate**
```bash
# Test with TDD framework
./scripts/tdd-migration-loop.sh --generate-only --verbose

# Final validation
./scripts/final-migration-test.sh --connection my_oracle_db
```

## 🔑 **Key Success Metrics**

### **Discovery Working When:**
- ✅ Connects to real Oracle database successfully
- ✅ Generates complete JSON config with all table metadata
- ✅ Includes discovery validation hash in config
- ✅ Captures constraints, indexes, grants, partitioning details

### **Generation Working When:**
- ✅ Templates render without errors using discovered data
- ✅ master1.sql contains complete workflow with conditional logic
- ✅ All table directories created with proper file structure
- ✅ README files generated with migration instructions

### **Templates Working When:**
- ✅ Atomic table swaps implemented correctly
- ✅ Constraint disabling/enabling logic works
- ✅ Grants restoration from captured metadata
- ✅ Drop scripts generated separately (not in master1.sql)

### **End-to-End Working When:**
- ✅ Discovery → Generation → Execution works without manual intervention
- ✅ master1.sql runs completely automated
- ✅ All data migrated correctly (if enabled)
- ✅ All constraints and indexes recreated

## 🚧 **Known Issues & Resolutions**

### **Oracle Connection Issues**
- **Problem**: libclntsh.so not found, ORA-28009 errors
- **Resolution**: Install Oracle client libraries, use proper SYSDBA authentication
- **Workaround**: Test generation mode without database connection first

### **Template Variable Issues**  
- **Problem**: Missing variables in template context
- **Resolution**: Check context building in generate.py, ensure dataclass flattening works
- **Debug**: Use --verbose flag to see template context

### **Discovery Validation**
- **Problem**: Config rejected as not discovery-generated
- **Resolution**: Always use discovery mode first, check validation hash generation
- **Override**: Use --ignore-discovery-requirement flag (NOT RECOMMENDED)

## 📚 **References for Further Context**
- `project_overview.instructions.md` - Architecture overview
- `development_workflow.instructions.md` - Detailed development process  
- `lib.instructions.md` - Library component guidelines
- `quick_reference.instructions.md` - Essential commands
- `master_instructions_simplified.instructions.md` - One-page overview

**Updated**: Based on code review, conversation history, and working implementation analysis
````