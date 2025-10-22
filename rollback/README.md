# Emergency Rollback

Fast emergency rollback procedure for reverting table migration when critical issues occur.

## Overview

**emergency_rollback.sql** - Reverts migration by swapping tables back to original state in under 2 minutes.

## When to Use

Use emergency rollback when:
- Production outage due to migration
- Critical data corruption detected
- Application completely non-functional  
- Immediate restoration required

## Usage

```bash
sqlplus user/pass@db @emergency_rollback.sql
```

**Interactive Prompts**:
- Table owner (optional, defaults to current user)
- Table name
- Confirmation: Type `EMERGENCY` to proceed

## What It Does

```bash
Step 1: Assess Current State
  └─> Checks which tables exist (current, _OLD, _NEW)

Step 2: Determine Rollback Strategy
  └─> Verifies _OLD table exists (cannot rollback without it)

Step 3: Create Safety Backup
  └─> Renames current table to table_name_EMERG_timestamp

Step 4: Restore OLD Table
  └─> Renames table_name_OLD to table_name

Step 5: Verify Rollback
  └─> Tests table access and checks index status

Step 6: Report Status
  └─> Shows elapsed time and next steps
```

## Execution Time

- Small tables (<1GB): **5-30 seconds**
- Medium tables (1-50GB): **30-120 seconds**
- Large tables (>50GB): **2-5 minutes**

## Data Loss Warning

⚠️ **Data inserted/updated after cutover timestamp will be lost**

Example:
```bash
Cutover: 2025-10-22 14:00:00
Inserts: 50 new orders at 14:10:00
Rollback: 2025-10-22 14:15:00

Result: Those 50 orders are LOST
```

**Mitigation**: Execute rollback as quickly as possible after detecting issues.

## Output Example

```bash
================================================================
⚠⚠⚠  EMERGENCY ROLLBACK PROCEDURE  ⚠⚠⚠
================================================================

⚠ EMERGENCY ROLLBACK INITIATED

[STEP 1] 14:23:45.123 - ASSESSING CURRENT STATE
        Current table exists: YES
        OLD table exists: YES

[STEP 2] 14:23:45.234 - DETERMINING ROLLBACK STRATEGY
        Strategy: Swap current table with OLD table

[STEP 3] 14:23:45.456 - CREATING SAFETY BACKUP
        ✓ Safety backup created: ORDERS_EMERG_20251022142345

[STEP 4] 14:23:46.789 - RESTORING ORIGINAL TABLE
        ✓ Original table restored to active name

[STEP 5] 14:23:47.012 - VERIFYING ROLLBACK
        ✓ Table is accessible
        Indexes: 8 total, 0 invalid

================================================================
✓ EMERGENCY ROLLBACK COMPLETE
================================================================

Time Elapsed: 1.89 seconds

Current State:
  ✓ ORDERS = Original table (RESTORED)
  ⚠ ORDERS_EMERG_20251022142345 = Migration table (backup)

IMMEDIATE ACTIONS REQUIRED:
  1. ✓ Verify application connectivity
  2. ✓ Run smoke tests
  3. ✓ Check for data consistency
  4. ⚠ Review why rollback was necessary
```

## Post-Rollback Actions

### Immediate (Within 1 Hour)

```bash
# 1. Verify application functionality
sqlplus user/pass@db
SELECT COUNT(*) FROM schema.table_name WHERE ROWNUM <= 1000;

# 2. Run smoke tests
# Test critical business processes

# 3. Identify root cause
# Review alert logs, migration logs, error messages
```

### Within 24 Hours

```bash
# 1. Assess data loss
# Compare row counts before/after
# Review application transaction logs

# 2. Data recovery (if needed)
# Recover from application logs
# Manual data entry for critical records

# 3. Conduct post-mortem
# Document what went wrong
# Update procedures to prevent recurrence
```

### After 7 Days Validation

```sql
-- Cleanup emergency backup
DROP TABLE schema.table_name_EMERG_timestamp CASCADE CONSTRAINTS PURGE;
```

## Troubleshooting

### "Cannot rollback - no backup table found"

**Cause**: _OLD table was already dropped

**Options**:
1. Check for emergency backup: `table_name_EMERG_*`
2. Restore from database backup
3. If new table has correct data, rename it:
```sql
ALTER TABLE schema.table_name_NEW RENAME TO table_name;
```

### "Some indexes are invalid after rollback"

**Solution**:
```sql
-- Rebuild invalid indexes
SELECT 'ALTER INDEX ' || owner || '.' || index_name || ' REBUILD PARALLEL 4;'
FROM all_indexes
WHERE table_owner = 'SCHEMA'
  AND table_name = 'TABLE_NAME'
  AND status != 'VALID';
```

### Rollback fails mid-process

**Manual Recovery**:
```sql
-- Check what tables exist
SELECT table_name 
FROM all_tables 
WHERE owner = 'SCHEMA' 
  AND table_name LIKE 'TABLE_NAME%';

-- If needed, restore from recyclebin
FLASHBACK TABLE schema.table_name_OLD TO BEFORE DROP;

-- Manually rename as needed
ALTER TABLE schema.current_name RENAME TO correct_name;
```

## Best Practices

**Before Migration**:
- ✅ Test rollback in non-production
- ✅ Document rollback plan
- ✅ Verify backup exists and is restorable
- ✅ Establish communication plan

**During Migration**:
- ✅ Monitor continuously during cutover
- ✅ Have rollback script ready
- ✅ Keep team on standby for 1 hour

**After Rollback**:
- ✅ Verify application immediately
- ✅ Document reason for rollback
- ✅ Assess data loss
- ✅ Conduct post-mortem within 24 hours

## Files

```bash
04_rollback/
├── README.md (this file)
└── emergency_rollback.sql     (340 lines) - Emergency rollback script
```

## Related Documentation

- **00_discovery/** - Table discovery
- **01_templates/** - Migration templates
- **02_generator/** - Script generator
- **03_validation/** - Validation scripts
- **05_tables/** - Generated migrations

---

**Last Updated**: 2025-10-22
**Version**: 1.0
**CRITICAL**: Test rollback procedures before production use
