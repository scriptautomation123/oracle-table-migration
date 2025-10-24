#!/bin/bash

# Oracle Database Test Setup Script
# Creates GitHub Actions workflow and directory structure for Oracle testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to create directory structure
create_directory_structure() {
    print_status "Creating directory structure..."
    
    mkdir -p sql/setup
    mkdir -p sql/tests  
    mkdir -p sql/cleanup
    mkdir -p .github/workflows
    
    print_status "Directory structure created successfully"
}

# Function to create basic SQL examples
create_sql_examples() {
    print_status "Creating example SQL files..."
    
    # Setup scripts
    cat > sql/setup/01_create_tables.sql << 'EOF'
-- Create sample tables for testing
CREATE TABLE users (
    id NUMBER PRIMARY KEY,
    username VARCHAR2(50) NOT NULL,
    email VARCHAR2(100) UNIQUE,
    created_at DATE DEFAULT SYSDATE
);

CREATE TABLE orders (
    id NUMBER PRIMARY KEY,
    user_id NUMBER REFERENCES users(id),
    total_amount NUMBER(10,2),
    order_date DATE DEFAULT SYSDATE
);

-- Create sequence for auto-increment
CREATE SEQUENCE users_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE orders_seq START WITH 1 INCREMENT BY 1;
EOF

    cat > sql/setup/02_insert_data.sql << 'EOF'
-- Insert sample data
INSERT INTO users (id, username, email) VALUES (users_seq.NEXTVAL, 'john_doe', 'john@example.com');
INSERT INTO users (id, username, email) VALUES (users_seq.NEXTVAL, 'jane_smith', 'jane@example.com');
INSERT INTO users (id, username, email) VALUES (users_seq.NEXTVAL, 'bob_wilson', 'bob@example.com');

INSERT INTO orders (id, user_id, total_amount) VALUES (orders_seq.NEXTVAL, 1, 99.99);
INSERT INTO orders (id, user_id, total_amount) VALUES (orders_seq.NEXTVAL, 2, 149.50);
INSERT INTO orders (id, user_id, total_amount) VALUES (orders_seq.NEXTVAL, 1, 75.25);

COMMIT;
EOF

    # Test scripts
    cat > sql/tests/01_test_queries.sql << 'EOF'
-- Test basic queries
SELECT 'Testing user count' as test_name, COUNT(*) as result FROM users;
SELECT 'Testing order count' as test_name, COUNT(*) as result FROM orders;

-- Test joins
SELECT 'Testing user-order join' as test_name, COUNT(*) as result 
FROM users u 
JOIN orders o ON u.id = o.user_id;

-- Test aggregations
SELECT 'Testing total sales' as test_name, SUM(total_amount) as result FROM orders;
EOF

    cat > sql/tests/02_test_procedures.sql << 'EOF'
-- Create and test a simple procedure
CREATE OR REPLACE PROCEDURE get_user_order_count(
    p_user_id IN NUMBER,
    p_count OUT NUMBER
) AS
BEGIN
    SELECT COUNT(*) INTO p_count FROM orders WHERE user_id = p_user_id;
END;
/

-- Test the procedure
DECLARE
    v_count NUMBER;
BEGIN
    get_user_order_count(1, v_count);
    DBMS_OUTPUT.PUT_LINE('User 1 has ' || v_count || ' orders');
END;
/
EOF

    # Cleanup scripts
    cat > sql/cleanup/01_cleanup_all.sql << 'EOF'
-- Clean up test data
DROP SEQUENCE orders_seq;
DROP SEQUENCE users_seq;
DROP TABLE orders;
DROP TABLE users;
EOF

    print_status "Example SQL files created successfully"
}

# Function to create basic workflow
create_basic_workflow() {
    print_status "Creating basic GitHub Actions workflow..."
    
    cat > .github/workflows/oracle-test.yml << 'EOF'
name: Oracle Database Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Test with Oracle Database
        uses: scriptautomation123/oracledb-action@main
        with:
          oracle-version: 21-slim
          setup-scripts: sql/setup/*.sql
          test-scripts: sql/tests/*.sql
          cleanup-scripts: sql/cleanup/*.sql
EOF

    print_status "Basic workflow created successfully"
}

# Function to create advanced workflow
create_advanced_workflow() {
    print_status "Creating advanced GitHub Actions workflow..."
    
    cat > .github/workflows/oracle-advanced-test.yml << 'EOF'
name: Advanced Oracle Database Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday at 2 AM

jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    strategy:
      matrix:
        oracle-version: [21-slim, 23-slim]

    steps:
      - uses: actions/checkout@v4

      - name: Test with Oracle Database
        uses: scriptautomation123/oracledb-action@main
        with:
          oracle-version: ${{ matrix.oracle-version }}
          setup-scripts: |
            database/schema/*.sql
            database/data/*.sql
          test-scripts: tests/**/*.sql
          cleanup-scripts: cleanup/drop_all.sql
          
          # SQL*Plus commands for advanced testing
          sqlplus-commands: |
            SELECT 'Database Status: ' || STATUS FROM V$INSTANCE;
            SELECT COUNT(*) as "Total Tables" FROM USER_TABLES;
            EXEC DBMS_STATS.GATHER_SCHEMA_STATS(USER);
          
          # Security and compliance
          run-checkov: true
          checkov-framework: dockerfile,secrets,yaml
          fail-on-checkov: true
          
          # Performance tuning
          wait-timeout: 600
          oracle-password: ${{ secrets.ORACLE_PASSWORD }}

  security-scan:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Security Scan
        uses: scriptautomation123/oracledb-action@main
        with:
          oracle-version: 21-slim
          test-scripts: sql/tests/*.sql
          run-checkov: true
          fail-on-checkov: true
          checkov-framework: all
EOF

    print_status "Advanced workflow created successfully"
}

# Function to create configuration examples
create_config_examples() {
    print_status "Creating configuration examples..."
    
    cat > oracle-test-configs.yml << 'EOF'
# Oracle Database Test Configuration Examples

# Basic Configuration
basic:
  oracle-version: 21-slim
  setup-scripts: sql/setup/*.sql
  test-scripts: sql/tests/*.sql
  cleanup-scripts: sql/cleanup/*.sql
  oracle-password: OraclePassword123
  wait-timeout: 300
  run-checkov: true
  fail-on-checkov: false

# Advanced Configuration
advanced:
  oracle-version: 23-slim
  setup-scripts: |
    database/schema/*.sql
    database/data/*.sql
  test-scripts: tests/**/*.sql
  cleanup-scripts: cleanup/drop_all.sql
  sqlplus-commands: |
    SELECT 'Database Status: ' || STATUS FROM V$INSTANCE;
    SELECT COUNT(*) as "Total Tables" FROM USER_TABLES;
    EXEC DBMS_STATS.GATHER_SCHEMA_STATS(USER);
  run-checkov: true
  checkov-framework: dockerfile,secrets,yaml
  fail-on-checkov: true
  wait-timeout: 600
  oracle-password: ${{ secrets.ORACLE_PASSWORD }}

# Security-Focused Configuration
security:
  oracle-version: 21-slim
  test-scripts: sql/tests/*.sql
  run-checkov: true
  checkov-framework: all
  fail-on-checkov: true
  oracle-password: ${{ secrets.ORACLE_PASSWORD }}

# Performance Testing Configuration
performance:
  oracle-version: 23-slim
  setup-scripts: sql/setup/*.sql
  test-scripts: sql/tests/*.sql
  sqlplus-commands: |
    EXEC DBMS_STATS.GATHER_SCHEMA_STATS(USER);
    SELECT 'Performance test completed' FROM DUAL;
  wait-timeout: 900
  oracle-password: OraclePassword123
EOF

    print_status "Configuration examples created successfully"
}

# Function to create README
create_readme() {
    print_status "Creating README documentation..."
    
    cat > ORACLE_TEST_README.md << 'EOF'
# Oracle Database Testing Setup

This directory contains the setup for Oracle Database testing using GitHub Actions.

## Quick Start

1. **Basic Setup** (30 seconds):
   ```bash
   # Run the setup script
   ./scripts/setup-oracle-test.sh
   
   # Commit and push
   git add .
   git commit -m "Add Oracle database testing"
   git push
   ```

2. **Directory Structure**:
   ```
   your-repo/
   ├── sql/
   │   ├── setup/          # Database setup scripts
   │   ├── tests/          # Test scripts
   │   └── cleanup/        # Cleanup scripts
   ├── .github/workflows/
   │   ├── oracle-test.yml           # Basic workflow
   │   └── oracle-advanced-test.yml  # Advanced workflow
   └── oracle-test-configs.yml       # Configuration examples
   ```

## Available Oracle Versions

- `21-slim` (recommended, default)
- `23-slim` (latest features)
- `19-slim` (LTS version)

## Configuration Options

### Basic Configuration
```yaml
- name: Oracle DB Test
  uses: scriptautomation123/oracledb-action@main
  with:
    oracle-version: 21-slim
    setup-scripts: sql/setup/*.sql
    test-scripts: sql/tests/*.sql
    cleanup-scripts: sql/cleanup/*.sql
    oracle-password: OraclePassword123
    wait-timeout: 300
    run-checkov: true
    fail-on-checkov: false
```

### Advanced Configuration
```yaml
- name: Advanced Oracle Testing
  uses: scriptautomation123/oracledb-action@main
  with:
    oracle-version: 23-slim
    setup-scripts: |
      database/schema/*.sql
      database/data/*.sql
    test-scripts: tests/**/*.sql
    cleanup-scripts: cleanup/drop_all.sql
    sqlplus-commands: |
      SELECT 'Database Status: ' || STATUS FROM V$INSTANCE;
      SELECT COUNT(*) as "Total Tables" FROM USER_TABLES;
      EXEC DBMS_STATS.GATHER_SCHEMA_STATS(USER);
    run-checkov: true
    checkov-framework: dockerfile,secrets,yaml
    fail-on-checkov: true
    wait-timeout: 600
    oracle-password: ${{ secrets.ORACLE_PASSWORD }}
```

## Security Features

- **Checkov Integration**: Automatic security scanning of SQL scripts
- **Multiple Frameworks**: Support for dockerfile, secrets, yaml scanning
- **Configurable Failures**: Choose whether to fail on security issues

## Performance Features

- **Connection Pooling**: Optimized database connections
- **Health Checks**: Automatic database readiness verification
- **Timeout Configuration**: Configurable wait times for database startup

## Examples

See the `oracle-test-configs.yml` file for complete configuration examples.

## Troubleshooting

1. **Database Connection Issues**: Check the `wait-timeout` setting
2. **Security Scan Failures**: Review `fail-on-checkov` setting
3. **Script Execution Errors**: Verify SQL syntax and file paths

## Support

For issues and questions, please refer to the [Oracle Database Action documentation](https://github.com/scriptautomation123/oracledb-action).
EOF

    print_status "README documentation created successfully"
}

# Main execution
main() {
    print_header "Oracle Database Test Setup Script"
    
    # Check if we're in a git repository
    if [ ! -d ".git" ]; then
        print_warning "Not in a git repository. Initializing git..."
        git init
    fi
    
    # Create directory structure
    create_directory_structure
    
    # Create SQL examples
    create_sql_examples
    
    # Create workflows
    create_basic_workflow
    create_advanced_workflow
    
    # Create configuration examples
    create_config_examples
    
    # Create documentation
    create_readme
    
    print_header "Setup Complete! 🎉"
    print_status "Created the following files:"
    echo "  📁 sql/setup/ - Database setup scripts"
    echo "  📁 sql/tests/ - Test scripts"  
    echo "  📁 sql/cleanup/ - Cleanup scripts"
    echo "  📁 .github/workflows/ - GitHub Actions workflows"
    echo "  📄 oracle-test-configs.yml - Configuration examples"
    echo "  📄 ORACLE_TEST_README.md - Documentation"
    
    print_status "Next steps:"
    echo "  1. Review and customize the SQL scripts in sql/ directory"
    echo "  2. Commit your changes: git add . && git commit -m 'Add Oracle testing'"
    echo "  3. Push to trigger the workflow: git push"
    echo "  4. Check the Actions tab in your GitHub repository"
    
    print_warning "Remember to:"
    echo "  - Update the Oracle password in your workflow files"
    echo "  - Customize the SQL scripts for your specific needs"
    echo "  - Review the security settings (Checkov configuration)"
}

# Run main function
main "$@"
