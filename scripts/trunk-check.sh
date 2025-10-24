#!/bin/bash

# Trunk Check Script - Comprehensive code quality and formatting
# This script runs Trunk checks and fixes across the entire codebase

echo "🔍 Trunk Code Quality & Formatting Script"
echo "=========================================="

# Function to display help
show_help() {
	echo "Usage: $0 [OPTIONS]"
	echo ""
	echo "Options:"
	echo "  --check-only    Run checks without applying fixes"
	echo "  --fmt-only      Run only formatting (fastest)"
	echo "  --fix-only      Run only auto-fixes without full check"
	echo "  --all           Run full check + auto-fix + format (default)"
	echo "  --help          Show this help message"
	echo ""
	echo "Examples:"
	echo "  $0                    # Full check, fix, and format"
	echo "  $0 --fmt-only         # Quick formatting only"
	echo "  $0 --check-only       # Check without fixes"
}

# Parse command line arguments
CHECK_ONLY=false
FMT_ONLY=false
FIX_ONLY=false
RUN_ALL=true

while [[ $# -gt 0 ]]; do
	case $1 in
	--check-only)
		CHECK_ONLY=true
		RUN_ALL=false
		shift
		;;
	--fmt-only)
		FMT_ONLY=true
		RUN_ALL=false
		shift
		;;
	--fix-only)
		FIX_ONLY=true
		RUN_ALL=false
		shift
		;;
	--all)
		RUN_ALL=true
		shift
		;;
	--help)
		show_help
		exit 0
		;;
	*)
		echo "Unknown option: $1"
		show_help
		exit 1
		;;
	esac
done

# Change to repository root
repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z ${repo_root} ]]; then
	echo "❌ Error: Not in a git repository"
	exit 1
fi
cd "${repo_root}" || exit 1 || exit

# Check if trunk is available
if ! command -v trunk >/dev/null 2>&1; then
	echo "❌ Error: Trunk is not installed or not in PATH"
	echo "   Install with: curl https://get.trunk.io -fsSL | bash"
	exit 1
fi

current_dir=$(pwd)
echo "📁 Working directory: ${current_dir}"
echo ""

# Function to run trunk fmt
run_trunk_fmt() {
	echo "🎨 Running Trunk Format (fastest formatting)..."
	if trunk fmt --all; then
		echo "✅ Trunk format completed successfully"
	else
		echo "⚠️  Trunk format completed with issues"
		return 1
	fi
	echo ""
}

# Function to run trunk check without fixes
run_trunk_check() {
	echo "🔍 Running Trunk Check (analysis only)..."
	if trunk check --all --no-fix; then
		echo "✅ Trunk check completed - no issues found"
	else
		echo "⚠️  Trunk check found issues (not auto-fixed)"
		return 1
	fi
	echo ""
}

# Function to run trunk check with auto-fixes
run_trunk_fix() {
	echo "🔧 Running Trunk Check with Auto-fixes..."
	if trunk check --all --fix; then
		echo "✅ Trunk auto-fix completed successfully"
	else
		echo "⚠️  Trunk auto-fix completed with remaining issues"
		return 1
	fi
	echo ""
}

# Function to run full trunk check and fix
run_full_check() {
	echo "🔍 Running Full Trunk Check + Auto-fix..."
	if trunk check --all --fix; then
		echo "✅ Full trunk check completed successfully"
	else
		echo "⚠️  Full trunk check completed with remaining issues"
		return 1
	fi
	echo ""
}

# Function to show final summary
show_summary() {
	echo "📊 Final Status Check..."
	echo "========================"

	# Run a final check to show current status
	if trunk check --all --no-fix &>/dev/null; then
		echo "🎉 All files are clean and properly formatted!"
	else
		echo "📋 Remaining issues summary:"
		trunk check --all --no-fix || true
	fi
}

# Main execution logic
OVERALL_SUCCESS=true

if [[ ${FMT_ONLY} == true ]]; then
	if ! run_trunk_fmt; then
		OVERALL_SUCCESS=false
	fi
elif [[ ${CHECK_ONLY} == true ]]; then
	if ! run_trunk_check; then
		OVERALL_SUCCESS=false
	fi
elif [[ ${FIX_ONLY} == true ]]; then
	if ! run_trunk_fix; then
		OVERALL_SUCCESS=false
	fi
elif [[ ${RUN_ALL} == true ]]; then
	# Run in optimal order: format first (fastest), then full check with fixes
	echo "🚀 Running complete Trunk workflow..."
	echo ""

	# Step 1: Quick formatting
	if ! run_trunk_fmt; then
		OVERALL_SUCCESS=false
	fi

	# Step 2: Comprehensive check with auto-fixes
	if ! run_full_check; then
		OVERALL_SUCCESS=false
	fi
fi

# Show final summary
show_summary

# Exit with appropriate code
if [[ ${OVERALL_SUCCESS} == true ]]; then
	echo ""
	echo "🎉 Trunk script completed successfully!"
	exit 0
else
	echo ""
	echo "⚠️  Trunk script completed with issues. Check the output above."
	exit 1
fi
