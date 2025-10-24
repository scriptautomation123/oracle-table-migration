# Writable Views Framework - Usage Guide

## Overview
This framework provides a generic way to make Oracle views writable using INSTEAD OF triggers. It automatically generates the necessary triggers to enable INSERT, UPDATE, and DELETE operations on views.

## Installation
```sql
@make_views_writable.sql
```

## Usage Examples

### 1. Make a Single View Writable
```sql
BEGIN
    create_writable_view('MY_VIEW', 'MY_TABLE');
END;
/
```

### 2. Make a View Writable with Specific Owners
```sql
BEGIN
    create_writable_view('HR_VIEW', 'HR_TABLE', 'HR_SCHEMA', 'HR_SCHEMA');
END;
/
```

### 3. Make All Views in a Schema Writable
```sql
BEGIN
    make_all_views_writable('HR_SCHEMA');
END;
/
```

### 4. Make Views with Specific Prefix Writable
```sql
BEGIN
    make_all_views_writable('HR_SCHEMA', 'V_');
END;
/
```

## Status and Management

### Check Writable Views Status
```sql
BEGIN
    check_writable_views_status('HR_SCHEMA');
END;
/
```

### Drop All Writable Triggers
```sql
BEGIN
    drop_writable_triggers('HR_SCHEMA');
END;
/
```

## How It Works

1. **INSTEAD OF Triggers**: The framework creates INSTEAD OF triggers on views
2. **Automatic Column Mapping**: Maps view columns to base table columns
3. **CRUD Operations**: Supports INSERT, UPDATE, DELETE operations
4. **Error Handling**: Includes proper error handling and validation

## Requirements

- Oracle Database 11g or higher
- CREATE TRIGGER privilege
- Access to base tables
- Proper view definitions

## Limitations

- Views with complex joins may need manual adjustment
- Views with computed columns may not work correctly
- Views with multiple base tables need custom triggers
- Views with subqueries may require manual intervention

## Troubleshooting

### Common Issues

1. **Column Mismatch**: Ensure view columns match base table columns
2. **Permission Issues**: Verify you have necessary privileges
3. **Complex Views**: Manual trigger creation may be required

### Debug Mode
```sql
-- Enable debug output
SET SERVEROUTPUT ON SIZE 1000000
```

## Best Practices

1. **Test First**: Always test on non-production environments
2. **Backup**: Create backups before making views writable
3. **Documentation**: Document which views are made writable
4. **Monitoring**: Monitor performance impact of triggers
5. **Cleanup**: Remove triggers when no longer needed

## Advanced Usage

### Custom Trigger Creation
For complex views, you may need to create custom triggers:

```sql
CREATE OR REPLACE TRIGGER trg_my_view_writable
INSTEAD OF INSERT OR UPDATE OR DELETE ON my_view
FOR EACH ROW
BEGIN
    -- Custom logic here
    IF INSERTING THEN
        -- Custom insert logic
    ELSIF UPDATING THEN
        -- Custom update logic
    ELSIF DELETING THEN
        -- Custom delete logic
    END IF;
END;
/
```

## Support

For issues or questions:
1. Check Oracle documentation on INSTEAD OF triggers
2. Verify view and table structures
3. Test with simple views first
4. Consider manual trigger creation for complex cases
