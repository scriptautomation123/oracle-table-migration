# Development Workflow - Step by Step

## 🎯 **Before You Start**
**Principle**: "it should just run master1.sql, nothing else should be required"

## 🔄 **Daily Development Cycle**

### **Step 1: Make Your Changes**
Common change types:

#### **Adding New Oracle Features**
```bash
# 1. Update test schema
vim test/data/comprehensive_oracle_ddl.sql

# 2. Enhance discovery
vim lib/discovery_queries.py

# 3. Update data models
vim lib/migration_models.py

# 4. Update templates
vim templates/master1.sql.j2
vim templates/10_create_table.sql.j2  # etc.

# 5. Test discovery with real database
python3 src/generate.py --discover --schema APP_DATA_OWNER --connection "conn_string"
```

#### **Fixing Migration Issues**
```bash
# 1. Identify the problem step
cd output/SCHEMA_TABLE/
cat master1.sql  # Find which step fails

# 2. Fix the template
vim templates/50_swap_tables.sql.j2  # example

# 3. Test the fix
./scripts/tdd-migration-loop.sh --generate-only --verbose
```

### **Step 2: Test Your Changes**
```bash
# Quick test (no database needed)
./scripts/tdd-migration-loop.sh --generate-only --verbose

# Full test (with database)
./scripts/tdd-migration-loop.sh --connection my_oracle_db --verbose

# Ultimate test
./scripts/final-migration-test.sh --connection my_oracle_db
```

### **Step 3: Validate Results**
Look for these success indicators:
- ✅ Templates render without errors
- ✅ master1.sql contains all required steps
- ✅ Conditional logic works (data migration optional)
- ✅ Atomic swaps implemented correctly
- ✅ Grants captured and restored

### **Step 4: Document Changes**
```bash
# Update relevant instruction files
vim .github/instructions/project_overview.instructions.md
vim .github/instructions/quick_reference.instructions.md
```

## 🔧 **Common Development Tasks**

### **Task: Add New Template Filter**
```bash
# 1. Add filter function
vim lib/template_filters.py

# 2. Register the filter
# (add to register_custom_filters function)

# 3. Use in templates
vim templates/master1.sql.j2
# Example: {{ some_value | your_new_filter }}

# 4. Test
./scripts/tdd-migration-loop.sh --generate-only
```

### **Task: Add New Migration Setting**
```bash
# 1. Update data model
vim lib/migration_models.py
# Add field to MigrationSettings class

# 2. Update discovery (if needed)
vim lib/discovery_queries.py

# 3. Update templates to use new setting
vim templates/master1.sql.j2
# Example: {% if common_settings.migration_settings.your_new_setting %}

# 4. Test with discovery first, then generation
python3 src/generate.py --discover --schema SCHEMA --connection "conn_string"
python3 src/generate.py --config migration_config.json
```

### **Task: Fix Atomic Swap Logic**
```bash
# 1. Update the swap template
vim templates/50_swap_tables.sql.j2

# 2. Test the specific template
python3 generate_scripts.py --config migration_config.json
cd output/SCHEMA_TABLE/
cat 50_swap_tables.sql  # Review generated SQL

# 3. Test full workflow
./scripts/tdd-migration-loop.sh --generate-only --verbose
```

### **Task: Add Grants Handling**
```bash
# 1. Update discovery to capture grants
vim lib/discovery_queries.py
# Enhance _get_table_grants method

# 2. Update data models
vim lib/migration_models.py  
# Add grants fields to CurrentState

# 3. Update templates
vim templates/60_restore_grants.sql.j2
vim templates/dynamic_grants.sql.j2

# 4. Test grants capture with real database discovery
python3 src/generate.py --discover --schema SCHEMA --connection "conn_string" --output-file test_grants_config.json
grep -A5 -B5 "grants" test_grants_config.json
```

## 🧪 **Testing Strategies**

### **Development Testing (Fast)**
```bash
# No database needed - tests template rendering
./scripts/tdd-migration-loop.sh --generate-only --verbose
```

### **Integration Testing (Medium)**
```bash
# With database - tests discovery and generation
./scripts/tdd-migration-loop.sh --connection my_oracle_db --verbose
```

### **Full Validation (Thorough)**
```bash
# Tests complete master1.sql execution
./scripts/final-migration-test.sh --connection my_oracle_db --verbose
```

### **Specific Table Testing**
```bash
# Test only certain tables
./scripts/tdd-migration-loop.sh --subset 'APP_*' --iterations 3
```

## 🚨 **Troubleshooting Guide**

### **Problem: Template Rendering Errors**
```bash
# Check template syntax
python3 -c "
from jinja2 import Template
with open('templates/master1.sql.j2') as f:
    template = Template(f.read())
print('Template syntax OK')
"

# Check variable availability
python3 generate_scripts.py --config migration_config.json --validate-only
```

### **Problem: Missing Variables in Templates**
```bash
# Check what's in the template context
vim generate_scripts.py
# Look at _build_template_context method
# Ensure all template variables are included
```

### **Problem: Generated SQL Has Errors**
```bash
# Check individual step templates
cd templates/
ls -la *.j2

# Test specific template
python3 generate_scripts.py --config migration_config.json
cd output/SCHEMA_TABLE/
cat 50_swap_tables.sql  # Check generated SQL
```

### **Problem: Database Connection Issues**
```bash
# Test without database
./scripts/tdd-migration-loop.sh --generate-only

# Check connection details
grep -A5 -B5 "connection" migration_config.json
```

## 📋 **Code Review Checklist**

Before committing changes:

### **Templates**
- [ ] All templates render without errors
- [ ] master1.sql contains complete workflow
- [ ] Conditional logic implemented correctly
- [ ] No hardcoded values (use variables)
- [ ] Error handling included

### **Data Models**
- [ ] New fields have defaults
- [ ] Type annotations correct
- [ ] Dataclass decorators applied
- [ ] Import statements updated

### **Discovery Logic**
- [ ] SQL queries are safe (no injection)
- [ ] Error handling for missing data
- [ ] Type conversion handled
- [ ] Connection cleanup included

### **Testing**
- [ ] TDD loop passes
- [ ] Final validation passes
- [ ] No regression in existing functionality
- [ ] Edge cases considered

### **Documentation**
- [ ] README updated if needed
- [ ] Instruction files updated
- [ ] Comments added to complex code
- [ ] Examples provided

## 🎯 **Success Criteria**

Your changes are ready when:
1. **Generate**: `python3 generate_scripts.py --config migration_config.json` succeeds
2. **Validate**: All templates render without errors
3. **Test**: TDD loop passes completely
4. **Execute**: master1.sql runs with zero manual intervention
5. **Verify**: All migration steps complete successfully

Remember: Every change should bring us closer to the goal of **zero manual intervention** in table re-partitioning migrations.