# Templates Instructions

## When Working on Templates (`/templates/` directory):

### Master Template (Critical):
- **templates/master1.sql.j2**: Must contain complete end-to-end migration (steps 00-80)
- This template is the cornerstone of the "master1.sql only" principle
- Any missing functionality must be added to this template, not handled manually

### Template Development Workflow:
1. **Identify missing functionality** in master1.sql.j2
2. **Add Jinja2 logic** using dataclass variables from migration_models.py
3. **Apply custom filters** from lib/template_filters.py
4. **Test with TDD loop**: `./scripts/tdd-migration-loop.sh --generate-only --verbose`
5. **Validate completeness**: `./scripts/final-migration-test.sh`

### Template Structure Guidelines:
- Use typed dataclass variables: `{{ table.current_state.partition_type }}`
- Apply filters for formatting: `{{ table.table_name | sql_identifier }}`
- Include comprehensive error handling and rollback logic
- Add validation queries between major steps
- Support all Oracle partitioning types and constraints

### Jinja2 Best Practices:
- Use meaningful variable names
- Add comments explaining complex logic
- Implement conditional blocks for different scenarios
- Include SQL comments in generated output for debugging
- Test with all partition types and constraint combinations

### Validation Templates:
- Located in `templates/validation/`
- Used for pre/post operation checks
- Must validate data integrity and constraint status
- Include performance validation (partition pruning)

### Template Variables Available:
- **table**: Complete TableConfig dataclass
- **metadata**: Migration metadata
- **environment**: Environment-specific settings
- All nested dataclass properties accessible via dot notation