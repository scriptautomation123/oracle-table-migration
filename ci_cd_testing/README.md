# CI/CD Testing Tools

This directory contains tools for Oracle Database CI/CD testing and workflow automation.

## 🚀 Universal Workflow Runner

**File**: `universal-runner.sh`

A comprehensive tool for running and monitoring any type of workflow or process. Supports GitHub Actions, local scripts, Docker containers, and more.

### Features

- **Multiple Process Types**: GitHub Actions, local scripts, Docker containers, Docker Compose services
- **Process Monitoring**: Watch existing processes by PID
- **Auto-commit & Push**: Automatically commit and push changes before running
- **Timeout Control**: Configurable timeouts for processes
- **Retry Logic**: Retry failed runs
- **Status Reporting**: Show status of recent runs
- **List Discovery**: List available workflows/processes

### Usage

```bash
# Basic workflow execution
./universal-runner.sh github "Oracle Database Tests"

# With auto-commit and push
./universal-runner.sh github "Test Oracle Action" --auto-commit --push

# With timeout and retry
./universal-runner.sh github "Security Scan" --timeout 600 --retry 2

# Local scripts
./universal-runner.sh local ../scripts/dev-tools.sh trunk all

# Docker operations
./universal-runner.sh docker oracle:21-slim --timeout 1800

# Process monitoring
./universal-runner.sh watch 12345 --timeout 300

# List available workflows/processes
./universal-runner.sh list

# Show recent run status
./universal-runner.sh status
```

### Commands

- `github <workflow>` - Run and watch GitHub Actions workflow
- `local <script>` - Run and watch local script
- `docker <container>` - Run and watch Docker container
- `compose <service>` - Run and watch Docker Compose service
- `watch <process>` - Watch existing process by PID
- `list` - List available workflows/processes
- `status` - Show status of recent runs

### Options

- `--auto-commit, -c` - Auto-commit changes before running
- `--push, -p` - Push changes to remote repository
- `--watch, -w` - Watch the process (default: true)
- `--no-watch, -n` - Don't watch, just trigger
- `--timeout, -t <sec>` - Set timeout for process (default: 300)
- `--retry, -r <count>` - Retry failed runs (default: 0)
- `--verbose, -v` - Verbose output
- `--debug, -d` - Debug mode

---

## 🏗️ Oracle CI/CD Initialization

**File**: `init-oracle-ci.sh`

Sets up Oracle Database testing infrastructure with GitHub Actions. Implements best practices for Oracle database CI/CD.

### Features

- **Template System**: Multiple setup templates (basic, advanced, security, performance, enterprise)
- **Dry-run Mode**: Preview changes without making them
- **Modular Functions**: Clean, maintainable code structure
- **Comprehensive Documentation**: Auto-generated documentation
- **Configuration Management**: YAML-based configuration
- **Error Handling**: Robust error handling and validation

### Usage

```bash
# Basic Oracle testing setup
./init-oracle-ci.sh

# Advanced setup with multiple Oracle versions
./init-oracle-ci.sh advanced

# Security-focused setup
./init-oracle-ci.sh security

# Performance testing setup
./init-oracle-ci.sh performance

# Enterprise-grade setup
./init-oracle-ci.sh enterprise
```

### Advanced Options

```bash
# Dry run (preview changes)
./init-oracle-ci.sh --dry-run advanced

# Force overwrite existing files
./init-oracle-ci.sh --force enterprise

# Verbose output
./init-oracle-ci.sh --verbose security

# Debug mode
./init-oracle-ci.sh --debug performance
```

### Templates Available

- **basic** - Simple Oracle testing setup
- **advanced** - Multi-version testing with comprehensive workflows
- **security** - Security-focused setup with compliance scanning
- **performance** - Performance testing with monitoring
- **enterprise** - Enterprise-grade setup with full compliance

### Options

- `--verbose, -v` - Verbose output
- `--debug, -d` - Debug mode
- `--dry-run, -n` - Show what would be created without making changes
- `--force, -f` - Overwrite existing files
- `--help, -h` - Show help
- `--version` - Show version

---

## 🔄 Common Workflows

### Complete Development Cycle

```bash
# 1. Initialize Oracle CI/CD
./init-oracle-ci.sh advanced

# 2. Run development tools
./universal-runner.sh local ../scripts/dev-tools.sh trunk all

# 3. Run GitHub workflow
./universal-runner.sh github "Oracle Database Tests" --auto-commit --push
```

### Migration Development

```bash
# 1. Initialize Oracle CI/CD
./init-oracle-ci.sh security

# 2. Run tests with timeout
./universal-runner.sh github "Security Scan" --timeout 600

# 3. Run performance tests
./universal-runner.sh github "Performance Test" --retry 2
```

### CI/CD Pipeline

```bash
# 1. Auto-commit and push changes
./universal-runner.sh github "Oracle Database Tests" --auto-commit --push

# 2. Run security scan
./universal-runner.sh github "Security Scan" --timeout 600

# 3. Run performance tests
./universal-runner.sh github "Performance Test" --retry 2
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

### Oracle CI Templates
- `basic` - Simple Oracle testing setup
- `advanced` - Multi-version testing
- `security` - Security-focused setup
- `performance` - Performance testing
- `enterprise` - Enterprise-grade setup

### Global Options (Universal Runner)
- `--auto-commit, -c` - Auto-commit changes before running
- `--push, -p` - Push changes to remote repository
- `--watch, -w` - Watch the process (default: true)
- `--no-watch, -n` - Don't watch, just trigger
- `--timeout, -t <sec>` - Set timeout for process (default: 300)
- `--retry, -r <count>` - Retry failed runs (default: 0)
- `--verbose, -v` - Verbose output
- `--debug, -d` - Debug mode

---

## 🆘 Troubleshooting

### Common Issues
1. **Permission denied**: Make scripts executable with `chmod +x *.sh`
2. **Missing dependencies**: Install required tools (gh, docker, etc.)
3. **Database connection**: Check connection strings and credentials
4. **Template errors**: Verify template directory and file permissions

### Debug Mode
```bash
# Enable debug mode for any script
DEBUG=true ./universal-runner.sh local ../scripts/dev-tools.sh trunk all
./init-oracle-ci.sh --debug advanced
```

### Help and Documentation
```bash
# Get help for any script
./universal-runner.sh --help
./init-oracle-ci.sh --help
```

---

## 📄 SQL Scripts

**Directory**: `sql/`

Contains Oracle Database testing SQL scripts organized by purpose.

### Setup Scripts (`sql/setup/`)

- **`01_schema_setup.sql`** - Creates basic database schema for testing
- **`02_test_data.sql`** - Inserts test data for Oracle database testing

### Test Scripts (`sql/tests/`)

- **`01_basic_queries.sql`** - Basic query tests for Oracle database
- **`02_advanced_queries.sql`** - Advanced query tests (generated by advanced/enterprise templates)

### Cleanup Scripts (`sql/cleanup/`)

- **`01_cleanup_all.sql`** - Cleanup script for Oracle database testing

### Usage

These SQL scripts are automatically referenced by the Oracle CI/CD workflows:

```yaml
# GitHub Actions workflow example
- name: Test with Oracle Database
  uses: scriptautomation123/oracledb-action@main
  with:
    setup-scripts: sql/setup/*.sql
    test-scripts: sql/tests/*.sql
    cleanup-scripts: sql/cleanup/*.sql
```

### Customization

You can customize these SQL scripts for your specific testing needs:

1. **Edit existing scripts** in the respective directories
2. **Add new scripts** following the naming convention (e.g., `03_custom_test.sql`)
3. **Modify the init-oracle-ci.sh script** to generate additional scripts for your templates

---

## 📁 Directory Structure

```
ci_cd_testing/
├── README.md                    # This documentation
├── universal-runner.sh          # Universal workflow runner
├── init-oracle-ci.sh           # Oracle CI/CD initialization
└── sql/                        # SQL scripts for Oracle testing
    ├── setup/                  # Database setup scripts
    │   ├── 01_schema_setup.sql
    │   └── 02_test_data.sql
    ├── tests/                  # Test scripts
    │   └── 01_basic_queries.sql
    └── cleanup/                # Cleanup scripts
        └── 01_cleanup_all.sql
```

---

**Last Updated**: 2025-01-27  
**Version**: 2.0.0  
**CRITICAL**: Test all procedures before production use
