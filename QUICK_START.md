# Oracle Table Migration - Quick Start Guide

## 🚀 Universal Workflow Runner

### Basic Usage
```bash
# Run GitHub Actions workflow
./ci_cd_testing/universal-runner.sh github "Oracle Database Tests"

# Run local script
./ci_cd_testing/universal-runner.sh local ./scripts/dev-tools.sh trunk all

# Run Docker container
./ci_cd_testing/universal-runner.sh docker oracle:21-slim

# Watch existing process
./ci_cd_testing/universal-runner.sh watch 12345
```

### Advanced Options
```bash
# GitHub Actions with auto-commit and push
./ci_cd_testing/universal-runner.sh github "Test Oracle Action" --auto-commit --push

# With timeout and retry
./ci_cd_testing/universal-runner.sh github "Security Scan" --timeout 600 --retry 2

# Local script with arguments
./ci_cd_testing/universal-runner.sh local ./ci_cd_testing/init-oracle-ci.sh advanced --no-watch

# Docker with custom timeout
./ci_cd_testing/universal-runner.sh docker oracle:21-slim --timeout 1800

# List available workflows/processes
./ci_cd_testing/universal-runner.sh list

# Show recent run status
./ci_cd_testing/universal-runner.sh status
```

### Global Options
- `--auto-commit, -c` - Auto-commit changes before running
- `--push, -p` - Push changes to remote repository
- `--watch, -w` - Watch the process (default: true)
- `--no-watch, -n` - Don't watch, just trigger
- `--timeout, -t <sec>` - Set timeout for process (default: 300)
- `--retry, -r <count>` - Retry failed runs (default: 0)
- `--verbose, -v` - Verbose output
- `--debug, -d` - Debug mode

---

## 🔧 Development Tools

### Interactive Mode (Default)
```bash
# Launch interactive mode
./scripts/dev-tools.sh

# Force interactive mode
./scripts/dev-tools.sh --interactive
```

### Command Line Mode
```bash
# Trunk operations
./scripts/dev-tools.sh trunk fmt                 # Quick formatting
./scripts/dev-tools.sh trunk check               # Check without fixes
./scripts/dev-tools.sh trunk fix                 # Auto-fix issues
./scripts/dev-tools.sh trunk all                 # Full workflow
./scripts/dev-tools.sh trunk status              # Show status
./scripts/dev-tools.sh trunk install             # Install/update Trunk

# YAML operations
./scripts/dev-tools.sh yaml clean                # Clean all YAML files
./scripts/dev-tools.sh yaml clean .github/workflows/ci.yml  # Clean specific file
./scripts/dev-tools.sh yaml lint                 # Lint YAML files
./scripts/dev-tools.sh yaml format               # Format YAML files
./scripts/dev-tools.sh yaml all                  # Clean + Lint + Format

# Configuration management
./scripts/dev-tools.sh config sync ../other-repo # Sync config to another repo
./scripts/dev-tools.sh config backup             # Backup current configuration
./scripts/dev-tools.sh config restore            # Restore from backup
./scripts/dev-tools.sh config status             # Show configuration status
```

### Options
- `--interactive, -i` - Interactive mode (default when no command given)
- `--verbose, -v` - Verbose output
- `--quiet, -q` - Quiet output (errors only)
- `--debug, -d` - Debug mode

---

## 🏗️ Oracle CI/CD Initialization

### Basic Setup
```bash
# Basic Oracle testing setup
./ci_cd_testing/init-oracle-ci.sh

# Advanced setup with multiple Oracle versions
./ci_cd_testing/init-oracle-ci.sh advanced

# Security-focused setup
./ci_cd_testing/init-oracle-ci.sh security

# Performance testing setup
./ci_cd_testing/init-oracle-ci.sh performance

# Enterprise-grade setup
./ci_cd_testing/init-oracle-ci.sh enterprise
```

### Advanced Options
```bash
# Dry run (preview changes)
./ci_cd_testing/init-oracle-ci.sh --dry-run advanced

# Force overwrite existing files
./ci_cd_testing/init-oracle-ci.sh --force enterprise

# Verbose output
./ci_cd_testing/init-oracle-ci.sh --verbose security

# Debug mode
./ci_cd_testing/init-oracle-ci.sh --debug performance
```

### Templates Available
- **basic** - Simple Oracle testing setup
- **advanced** - Multi-version testing with comprehensive workflows
- **security** - Security-focused setup with compliance scanning
- **performance** - Performance testing with monitoring
- **enterprise** - Enterprise-grade setup with full compliance

---

## 🐍 Python Scripts

### Migration Script Generator

#### Discovery Mode
```bash
# Discover schema and generate config
python3 generate_scripts.py --discover --schema MYSCHEMA --connection "user/password@host:port/service"

# With include/exclude patterns
python3 generate_scripts.py --discover --schema MYSCHEMA --connection "user/password@host:port/service" --include "TBL_*" --exclude "*_TEMP"

# With environment
python3 generate_scripts.py --discover --schema MYSCHEMA --connection "user/password@host:port/service" --environment PROD
```

#### Generation Mode
```bash
# Generate scripts from config
python3 generate_scripts.py --config migration_config.json

# With database validation
python3 generate_scripts.py --config migration_config.json --check-database --connection "user/password@host:port/service"

# Validate only
python3 generate_scripts.py --config migration_config.json --validate-only
```

#### Options
- `--discover, -d` - Discovery mode: Scan schema and generate config
- `--config, -c` - Generation mode: Use JSON config file
- `--schema, -s` - Schema name
- `--connection` - Oracle connection string
- `--template-dir` - Template directory (default: templates)
- `--output-dir` - Output directory (default: output)
- `--environment` - Environment name
- `--validate-only` - Only validate configuration
- `--check-database` - Validate config against database
- `--include` - Table name patterns to include
- `--exclude` - Table name patterns to exclude

### POC Generation System

#### Schema-Only POC
```bash
# Generate POC from schema configuration
python3 generate_poc.py --schema-config schema_config.json --schema-connection "user/password@host:port/service" --output-dir poc_output
```

#### POC with Data Sampling
```bash
# Generate POC with data sampling
python3 generate_poc.py --schema-config schema_config.json --data-config data_config.json --schema-connection "user/password@host:port/service" --data-connection "user/password@host:port/service" --output-dir poc_output
```

#### Execute POC Test
```bash
# Execute POC test cycle
python3 generate_poc.py --poc-config poc_output/poc-config.json --target-connection "user/password@host:port/service" --output-dir poc_output
```

#### Options
- `--schema-config` - Generate POC from schema configuration
- `--data-config` - Data sampling configuration
- `--poc-config` - Execute POC test from configuration
- `--schema-connection` - Schema source database connection
- `--data-connection` - Data source database connection
- `--target-connection` - Target database connection
- `--output-dir` - Output directory for POC files
- `--template-dir` - Template directory

---

## 🔄 Common Workflows

### Complete Development Cycle
```bash
# 1. Clean up project
./scripts/dev-tools.sh yaml clean
./scripts/dev-tools.sh trunk fmt

# 2. Run tests
./ci_cd_testing/universal-runner.sh local ./scripts/dev-tools.sh trunk all

# 3. Initialize Oracle CI/CD
./ci_cd_testing/init-oracle-ci.sh advanced

# 4. Run GitHub workflow
./ci_cd_testing/universal-runner.sh github "Oracle Database Tests" --auto-commit --push
```

### Migration Development
```bash
# 1. Discover schema
python3 generate_scripts.py --discover --schema MYSCHEMA --connection "user/password@host:port/service"

# 2. Edit configuration
# Edit migration_config.json

# 3. Validate configuration
python3 generate_scripts.py --config migration_config.json --validate-only

# 4. Generate scripts
python3 generate_scripts.py --config migration_config.json

# 5. Test with POC
python3 generate_poc.py --schema-config schema_config.json --schema-connection "user/password@host:port/service"
```

### CI/CD Pipeline
```bash
# 1. Auto-commit and push changes
./ci_cd_testing/universal-runner.sh github "Oracle Database Tests" --auto-commit --push

# 2. Run security scan
./ci_cd_testing/universal-runner.sh github "Security Scan" --timeout 600

# 3. Run performance tests
./ci_cd_testing/universal-runner.sh github "Performance Test" --retry 2
```

---

## 📋 Quick Reference

### Universal Runner Commands
- `github <workflow>` - Run GitHub Actions workflow
- `local <script>` - Run local script
- `docker <container>` - Run Docker container
- `compose <service>` - Run Docker Compose service
- `watch <process>` - Watch existing process by PID
- `list` - List available workflows/processes
- `status` - Show status of recent runs

### Dev Tools Commands
- `trunk <subcommand>` - Trunk operations (fmt, check, fix, all, status, install)
- `yaml <subcommand>` - YAML operations (clean, lint, format, all)
- `config <subcommand>` - Configuration operations (sync, backup, restore, status)

### Oracle CI Templates
- `basic` - Simple Oracle testing setup
- `advanced` - Multi-version testing
- `security` - Security-focused setup
- `performance` - Performance testing
- `enterprise` - Enterprise-grade setup

### Python Script Modes
- `--discover` - Discovery mode
- `--config` - Generation mode
- `--validate-only` - Validation mode
- `--schema-config` - POC from schema
- `--data-config` - POC with data sampling
- `--poc-config` - Execute POC test

---

## 🆘 Troubleshooting

### Common Issues
1. **Permission denied**: Make scripts executable with `chmod +x scripts/*.sh`
2. **Missing dependencies**: Install with `pip install jinja2 oracledb`
3. **Database connection**: Check connection strings and credentials
4. **Template errors**: Verify template directory and file permissions

### Debug Mode
```bash
# Enable debug mode for any script
DEBUG=true ./ci_cd_testing/universal-runner.sh local ./scripts/dev-tools.sh trunk all
./ci_cd_testing/init-oracle-ci.sh --debug advanced
python3 generate_scripts.py --discover --schema MYSCHEMA --connection "user/password@host:port/service" --debug
```

### Help and Documentation
```bash
# Get help for any script
./ci_cd_testing/universal-runner.sh --help
./scripts/dev-tools.sh --help
./ci_cd_testing/init-oracle-ci.sh --help
python3 generate_scripts.py --help
python3 generate_poc.py --help
```
