#!/bin/bash

# Quick Demo of TDD Migration Loop
# ================================
# This script demonstrates the complete TDD workflow

set -e

echo "🚀 Oracle Table Migration TDD Loop Demo"
echo "========================================"

# Check if we have the necessary files
if [ ! -f "./scripts/tdd-migration-loop.sh" ]; then
    echo "❌ TDD loop script not found!"
    exit 1
fi

echo "📁 Available TDD Loop Options:"
echo ""
./scripts/tdd-migration-loop.sh --help | head -20

echo ""
echo "🔍 Testing environment validation..."
./scripts/tdd-migration-loop.sh --validate-only

echo ""
echo "📊 Quick configuration check..."
./scripts/check-vscode.sh | head -20

echo ""
echo "✨ TDD Loop Demo Complete!"
echo ""
echo "Next steps to run full TDD loop:"
echo "1. Set up Oracle connection in sqlcl:"
echo "   sqlcl /nolog"
echo "   conn your_connection_string"
echo "   save connection my_oracle_db"
echo ""
echo "2. Run the full TDD loop:"
echo "   ./scripts/tdd-migration-loop.sh --connection my_oracle_db --verbose"
echo ""
echo "3. For development iterations:"
echo "   ./scripts/tdd-migration-loop.sh --generate-only --verbose"
echo ""
echo "4. For testing with specific tables:"
echo "   ./scripts/tdd-migration-loop.sh --subset 'SALES_*' --iterations 3"