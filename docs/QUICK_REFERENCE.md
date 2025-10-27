# Validation Wrapper - Quick Reference

## Quick Start

```bash
# Set connection
export ORACLE_CONN="system/oracle123@localhost:1521/FREEPDB1"

# Run validation
./validate.sh <operation> [owner] [table] [args...]
```

## Common Operations

```bash
# Check if table exists
./validate.sh check_existence OWNER TABLE

# Count rows
./validate.sh count_rows OWNER TABLE

# Count with comparison
./validate.sh count_rows OWNER TABLE 1000000

# Enable constraints
./validate.sh check_constraints OWNER TABLE enable

# Disable constraints
./validate.sh check_constraints OWNER TABLE disable

# Check structure
./validate.sh check_structure OWNER TABLE

# Show partition distribution
./validate.sh check_partitions OWNER TABLE
```

## Workflow Operations

```bash
# Pre-swap validation
./validate.sh pre_swap OWNER TABLE NEW_TABLE OLD_TABLE

# Post-swap validation  
./validate.sh post_swap OWNER TABLE OLD_TABLE

# Post-create validation
./validate.sh post_create OWNER TABLE 4

# Post-data-load validation
./validate.sh post_load OWNER TARGET SOURCE COUNT PARALLEL
```

## Options

- `-c, --connection` - Connection string
- `-o, --output-dir` - Custom output directory
- `-v, --verbose` - Verbose output
- `-h, --help` - Show help

## Examples

```bash
# Using environment variable
export ORACLE_CONN="user/pass@host:port/service"
./validate.sh check_existence SCHEMA TABLE

# With inline connection
./validate.sh check_existence -c "user/pass@host:port/service" SCHEMA TABLE

# Verbose mode
./validate.sh count_rows -v SCHEMA TABLE 1000000

# Custom output
./validate.sh check_structure -o /tmp/validation SCHEMA TABLE
```

## Exit Codes

- `0` = PASSED
- `1` = FAILED
- `2` = UNKNOWN
- `3` = Usage error

See `README.md` for full documentation.
