# Validation Script Best Practices

## 🎯 **Exception Handling Patterns**

### **✅ Recommended Pattern: External Exception Handling**

```sql
-- In templates, wrap validation calls with proper exception handling
BEGIN
    @validation/swap_constraint_validation.sql {{ owner }} {{ table_name }} {{ v_auto_enable_constraints }}
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Constraint validation failed: ' || SQLERRM);
        -- Handle the error appropriately for your context
        RAISE_APPLICATION_ERROR(-20004, 'Constraint validation failed: ' || SQLERRM);
END;
```

### **❌ Anti-Pattern: Internal Exception Handling**

```sql
-- DON'T do this in validation scripts
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
        RAISE;  -- This forces caller to handle exceptions
END;
```

## 🔧 **Best Practices for Validation Scripts**

### **1. Return Status, Don't Raise Exceptions**

**✅ Good:**
```sql
-- Validation script returns status via DBMS_OUTPUT
DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - All constraints enabled');
DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: FAILED - Disabled constraints found');
```

**❌ Bad:**
```sql
-- Validation script raises exceptions
RAISE_APPLICATION_ERROR(-20004, 'Cannot proceed with swap');
```

### **2. Provide Clear Status Messages**

```sql
-- Use consistent status message format
DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - [description]');
DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: FAILED - [description]');
DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: ERROR - [error details]');
```

### **3. Let Caller Handle Exceptions**

```sql
-- Template handles exceptions based on context
BEGIN
    @validation/swap_constraint_validation.sql {{ owner }} {{ table_name }} {{ v_auto_enable_constraints }}
EXCEPTION
    WHEN OTHERS THEN
        -- Template decides how to handle the error
        IF {{ migration_settings.continue_on_validation_failure | default(false) }} THEN
            DBMS_OUTPUT.PUT_LINE('Warning: Validation failed, continuing...');
        ELSE
            RAISE_APPLICATION_ERROR(-20004, 'Validation failed: ' || SQLERRM);
        END IF;
END;
```

## 📋 **Validation Script Design Principles**

### **1. Single Responsibility**
- Each validation script should have one clear purpose
- Don't mix validation logic with error handling logic

### **2. Reusability**
- Scripts should be usable in different contexts
- Don't assume specific error handling requirements

### **3. Flexibility**
- Provide clear status information
- Let caller decide how to handle failures

### **4. Consistency**
- Use consistent status message formats
- Follow naming conventions

## 🎯 **Example: Improved Validation Pattern**

### **Validation Script (swap_constraint_validation.sql):**
```sql
-- Check constraints and provide status
IF v_disabled_constraints > 0 THEN
    IF v_auto_enable_flag THEN
        -- Try to enable constraints
        DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: ATTEMPTED - Auto-enabled constraints');
    ELSE
        DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: FAILED - Disabled constraints found, auto-enable disabled');
    END IF;
ELSE
    DBMS_OUTPUT.PUT_LINE('VALIDATION RESULT: PASSED - All constraints enabled');
END IF;
```

### **Template Usage:**
```sql
-- Handle validation with appropriate error handling
BEGIN
    @validation/swap_constraint_validation.sql {{ owner }} {{ table_name }} {{ v_auto_enable_constraints }}
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Constraint validation failed: ' || SQLERRM);
        -- Decide whether to continue or abort based on configuration
        IF NOT {{ migration_settings.continue_on_validation_failure | default(false) }} THEN
            RAISE_APPLICATION_ERROR(-20004, 'Constraint validation failed: ' || SQLERRM);
        END IF;
END;
```

## 🚀 **Benefits of This Approach**

1. **🔄 Reusability**: Validation scripts can be used in different contexts
2. **🧹 Separation of Concerns**: Validation logic separate from error handling
3. **🔧 Flexibility**: Caller can choose how to handle failures
4. **📝 Consistency**: Standardized validation patterns
5. **🛡️ Control**: Template has full control over error handling
6. **🧪 Testability**: Easier to test validation logic independently
