#!/bin/bash

# Script to capture test results and save to files
# This runs after the Oracle tests complete

echo "📋 Capturing test results..."

# Create results directory
mkdir -p test-results

# Run the test script and capture output
echo "Running test script and capturing output..."
sqlplus -s system/OraclePassword123@localhost:1521/XE << 'EOF' > test-results/01_basic_queries_results.txt 2>&1
SET PAGESIZE 0
SET LINESIZE 1000
SET FEEDBACK OFF
SET HEADING OFF
SET ECHO OFF

@ci_cd_testing/sql/tests/01_basic_queries.sql

EXIT;
EOF

echo "📄 Test results saved to:"
find test-results -name "*.txt" -exec echo "  📄 {}" \; -exec cat {} \;

echo "✅ Test results captured successfully"
