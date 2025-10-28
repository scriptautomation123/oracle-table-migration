# Scripts Instructions

## When Working on Scripts (`/scripts/` directory):

### TDD Development Scripts:
- **tdd-migration-loop.sh**: Complete 7-phase TDD automation
- **final-migration-test.sh**: Ultimate validation ensuring master1.sql completeness
- **demo-*.sh**: Demonstration scripts showing capabilities

### Development Workflow for Scripts:
1. **Before modifying any script**: Run `./scripts/tdd-migration-loop.sh --validate-only`
2. **Test script changes**: Execute modified script with `--dry-run` first
3. **Validate integration**: Run full TDD loop after script modifications
4. **Update help text**: Ensure `--help` option reflects all changes

### Script Enhancement Guidelines:
- All scripts must support `--help` and `--verbose` options
- Include comprehensive error handling with actionable messages
- Use structured output (JSON) for CI/CD integration
- Support background execution for long-running operations
- Always validate prerequisites before execution

### VS Code Management Scripts:
- **check-vscode.sh**: Quick configuration overview
- **vscode-settings-manager.sh**: Comprehensive settings management
- **disable-unwanted-extensions.sh**: Extension management

### Key Script Patterns:
- Use `set -e` for fail-fast behavior
- Implement proper signal handling for cleanup
- Provide progress indicators for long operations
- Log all operations with timestamps
- Support configuration via environment variables