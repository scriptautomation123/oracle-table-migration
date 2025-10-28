# Master Development Instructions - Simplified & Organized

## 🎯 **The One Thing You Need to Know**
**"It should just run master1.sql, nothing else should be required"**

This is the ONLY principle that matters. Everything else supports this goal.

## 📚 **Quick Navigation**
- **Need to understand the project?** → Read `project_overview.instructions.md`
- **Adding new features?** → Read `development_workflow.instructions.md`
- **Testing changes?** → Read `tdd_framework.instructions.md`
- **Need specific commands?** → Read `quick_reference.instructions.md`

## 🚀 **Essential Commands (Copy & Paste)**

### **Discovery Mode (Generate Config)**
```bash
python3 src/generate.py --discover --schema APP_DATA_OWNER --connection "sys/oracle123@localhost:1521/freepdb1" --output-file migration_config.json
```

### **Generation Mode (Create Scripts)**
```bash
python3 src/generate.py --config migration_config.json
```

### **Test Your Changes**
```bash
./scripts/tdd-migration-loop.sh --generate-only --verbose
```

### **Final Validation**
```bash
./scripts/final-migration-test.sh --connection my_oracle_db
```

## 🎯 **What This Tool Does (Simple)**

```
INPUT:  Existing partitioned Oracle table
OUTPUT: master1.sql (runs complete re-partitioning migration)

GOAL:   Zero manual intervention
```

## 🔄 **The Migration Process (Simple)**

```
1. Analyze existing table structure
2. Generate configuration (JSON)
3. Create SQL scripts from templates
4. Execute master1.sql
5. ✅ Migration complete
```

## 📁 **File Organization (Simple)**

### **Files You Touch Daily**
```
src/generate.py                       # UNIFIED main entry point
templates/master1.sql.j2              # The complete migration template
lib/migration_models.py               # Data structures  
lib/discovery_queries.py              # Database analysis
src/generate_scripts.py               # Reference implementation (complete discovery architecture)
```

### **Files You Generate**
```
migration_config.json                 # Configuration
output/SCHEMA_TABLE/master1.sql       # The complete migration
```

### **Files You Test With**
```
scripts/tdd-migration-loop.sh         # Development testing
test_data/comprehensive_oracle_ddl.sql # Test schema
```

## 🎪 **Development Rules**

### **Rule 1: Always Test**
Never commit without running:
```bash
./scripts/tdd-migration-loop.sh --generate-only --verbose
```

### **Rule 2: Templates Are Everything**
- All SQL generation happens in `templates/`
- Never manually edit generated SQL in `output/`
- Fix templates, not output

### **Rule 3: Master1.sql Is King**
- Must contain complete migration workflow
- Must run with zero manual intervention
- Must handle all error cases

### **Rule 4: Follow the Pattern**
When adding features:
1. Update data models (`lib/migration_models.py`)
2. Update discovery (`lib/discovery_queries.py`)
3. Update templates (`templates/*.j2`)
4. Test until TDD loop passes
5. Update documentation

## 🚨 **When Things Break**

### **Template Errors**
```bash
# Error: template rendering failed
# Fix: Check template syntax and variable names
python3 generate_scripts.py --config migration_config.json --validate-only
```

### **Database Connection Issues**
```bash
# Error: cannot connect to Oracle
# Fix: Check connection details or test without DB
./scripts/tdd-migration-loop.sh --generate-only  # Skips DB operations
```

### **Migration Failures**
```bash
# Error: master1.sql failed
# Fix: Check individual step scripts and templates
cd output/SCHEMA_TABLE/
ls -la *.sql  # Review individual steps
```

## 🎯 **Success Metrics**

### **You Know It's Working When:**
- ✅ `python3 src/generate.py --config migration_config.json` runs without errors
- ✅ Discovery mode generates complete JSON from real database: `python3 src/generate.py --discover --schema SCHEMA --connection "conn_string"`
- ✅ `master1.sql` contains complete workflow with conditional logic
- ✅ Atomic table swaps work correctly (rename transactions)
- ✅ No manual intervention required
- ✅ All data migrated (if requested)
- ✅ All constraints and indexes recreated

### **You Know You Need to Fix Something When:**
- ❌ Template rendering errors
- ❌ Missing steps in master1.sql
- ❌ Manual intervention required
- ❌ Data loss or constraint violations
- ❌ Grants not restored

## 📖 **Related Documentation**
- `project_overview.instructions.md` - Complete architecture & diagrams
- `development_workflow.instructions.md` - Detailed development process
- `tdd_framework.instructions.md` - Testing procedures
- `quick_reference.instructions.md` - Command reference

**Remember: The goal is simple - run master1.sql and get a complete, error-free migration.**