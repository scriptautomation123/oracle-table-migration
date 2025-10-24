#!/bin/bash

# Simple Trunk wrapper - Quick access to common Trunk operations
# This is a lightweight script for everyday use

echo "🔧 Quick Trunk Operations"
echo "========================="

case "${1:-all}" in
"fmt" | "format")
	echo "🎨 Running Trunk Format..."
	trunk fmt --all
	;;
"check")
	echo "🔍 Running Trunk Check (no fixes)..."
	trunk check --all --no-fix
	;;
"fix")
	echo "🔧 Running Trunk Check with Auto-fixes..."
	trunk check --all --fix
	;;
"all")
	echo "🚀 Running Format + Check + Fix..."
	trunk fmt --all
	echo ""
	trunk check --all --fix
	;;
"help" | "--help" | "-h")
	echo "Usage: $0 [COMMAND]"
	echo ""
	echo "Commands:"
	echo "  fmt, format    Quick formatting (fastest)"
	echo "  check          Check without fixes"
	echo "  fix            Check with auto-fixes"
	echo "  all            Format + Check + Fix (default)"
	echo "  help           Show this help"
	echo ""
	echo "Examples:"
	echo "  $0             # Run all operations"
	echo "  $0 fmt         # Quick format only"
	echo "  $0 check       # Check without fixing"
	;;
*)
	echo "❌ Unknown command: $1"
	echo "Use '$0 help' for usage information"
	exit 1
	;;
esac
