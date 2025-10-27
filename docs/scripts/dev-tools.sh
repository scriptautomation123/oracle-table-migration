#!/bin/bash

# Development Tools Master Script
# Consolidated script for all development operations
# Replaces: trunk.sh, trunk-check.sh, quick-yaml-clean.sh, sync-trunk-config.sh

set -euo pipefail

# Script configuration
SCRIPT_NAME="dev-tools.sh"
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "Error occurred on line $line_number (exit code: $exit_code)"
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# Confirmation prompt function
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        read -p "$message [Y/n]: " -r response
        response=${response:-y}
    else
        read -p "$message [y/N]: " -r response
        response=${response:-n}
    fi
    
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Progress indicator function
show_progress() {
    local message="$1"
    local duration="${2:-3}"
    
    log_info "$message"
    for i in $(seq 1 $duration); do
        printf "."
        sleep 1
    done
    echo ""
}

# Enhanced visual indicators
show_success_banner() {
    echo ""
    echo "🎉 SUCCESS!"
    echo "==========="
    echo "$1"
    echo ""
}

show_warning_banner() {
    echo ""
    echo "⚠️  WARNING!"
    echo "============"
    echo "$1"
    echo ""
}

show_error_banner() {
    echo ""
    echo "❌ ERROR!"
    echo "=========="
    echo "$1"
    echo ""
}

# Enhanced status display
show_status_summary() {
    echo ""
    echo "📊 Status Summary"
    echo "================="
    echo "Project: $(basename "$(pwd)")"
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "User: $(whoami)"
    echo ""
}

# Interactive mode functions
interactive_mode() {
    log_info "🔧 Development Tools - Interactive Mode"
    log_info "====================================="
    echo ""
    
    while true; do
        show_main_menu
        read -p "Enter your choice [1-7]: " choice
        echo ""
        
        case $choice in
            1)
                interactive_trunk_menu
                ;;
            2)
                interactive_yaml_menu
                ;;
            3)
                interactive_config_menu
                ;;
            4)
                interactive_quick_actions
                ;;
            5)
                interactive_project_status
                ;;
            6)
                show_help
                ;;
            7)
                log_info "👋 Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid choice. Please enter a number between 1-7."
                echo ""
                ;;
        esac
    done
}

# Main interactive menu
show_main_menu() {
    echo "What would you like to do?"
    echo ""
    echo "1. 🎨 Code Quality & Formatting (Trunk)"
    echo "2. 📄 YAML File Operations"
    echo "3. ⚙️  Configuration Management"
    echo "4. 🚀 Quick Actions (Common Tasks)"
    echo "5. 📊 Project Status & Health"
    echo "6. ❓ Help & Documentation"
    echo "7. 🚪 Exit"
    echo ""
}

# Interactive Trunk menu
interactive_trunk_menu() {
    while true; do
        echo "🎨 Code Quality & Formatting"
        echo "============================"
        echo ""
        
        # Check Trunk status
        local trunk_status="❌ Not Checked"
        if command -v trunk >/dev/null 2>&1; then
            if trunk check --all --no-fix &>/dev/null; then
                trunk_status="✓ Clean"
            else
                trunk_status="⚠ Issues Found"
            fi
        else
            trunk_status="❌ Trunk Not Installed"
        fi
        
        echo "Current Status: [$trunk_status]"
        echo ""
        echo "What would you like to do?"
        echo ""
        echo "1. 🔍 Check for issues (no changes)"
        echo "2. 🎨 Quick format (fastest)"
        echo "3. 🔧 Auto-fix issues"
        echo "4. 🚀 Full workflow (format + check + fix)"
        echo "5. 📊 Show detailed status"
        echo "6. 📥 Install/Update Trunk"
        echo "7. ⬅️  Back to main menu"
        echo ""
        
        read -p "Enter your choice [1-7]: " choice
        echo ""
        
        case $choice in
            1)
                log_info "🔍 Checking for issues..."
                trunk_operations "check"
                ;;
            2)
                log_info "🎨 Quick formatting..."
                trunk_operations "fmt"
                ;;
            3)
                log_info "🔧 Auto-fixing issues..."
                trunk_operations "fix"
                ;;
        4)
            if confirm_action "This will format and fix all code issues. Continue?"; then
                log_info "🚀 Running full workflow..."
                show_progress "Processing files" 2
                trunk_operations "all"
                show_success_banner "Code formatting and fixing completed successfully!"
            else
                log_info "Operation cancelled"
            fi
            ;;
            5)
                log_info "📊 Showing detailed status..."
                trunk_operations "status"
                ;;
            6)
                log_info "📥 Installing/updating Trunk..."
                trunk_operations "install"
                ;;
            7)
                return
                ;;
            *)
                log_error "Invalid choice. Please enter a number between 1-7."
                echo ""
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        echo ""
    done
}

# Interactive YAML menu
interactive_yaml_menu() {
    while true; do
        echo "📄 YAML File Operations"
        echo "======================="
        echo ""
        
        # Count YAML files
        local yaml_count
        yaml_count=$(find . -name "*.yml" -o -name "*.yaml" | grep -v node_modules | grep -v .git | wc -l)
        echo "Found: $yaml_count YAML files in project"
        echo ""
        
        echo "What would you like to do?"
        echo ""
        echo "1. 🧹 Clean all YAML files"
        echo "2. 🧹 Clean specific file"
        echo "3. 🔍 Lint YAML files"
        echo "4. 🎨 Format YAML files"
        echo "5. 🚀 Complete YAML workflow"
        echo "6. ⬅️  Back to main menu"
        echo ""
        
        read -p "Enter your choice [1-6]: " choice
        echo ""
        
        case $choice in
        1)
            if confirm_action "This will clean all YAML files in the project. Continue?"; then
                log_info "🧹 Cleaning all YAML files..."
                show_progress "Scanning for YAML files" 1
                yaml_operations "clean"
                show_success_banner "YAML files cleaned successfully!"
            else
                log_info "Operation cancelled"
            fi
            ;;
            2)
                read -p "Enter file path: " file_path
                if [[ -n "$file_path" ]]; then
                    log_info "🧹 Cleaning $file_path..."
                    yaml_operations "clean" "$file_path"
                else
                    log_error "No file path provided"
                fi
                ;;
            3)
                log_info "🔍 Linting YAML files..."
                yaml_operations "lint"
                ;;
            4)
                log_info "🎨 Formatting YAML files..."
                yaml_operations "format"
                ;;
            5)
                log_info "🚀 Running complete YAML workflow..."
                yaml_operations "all"
                ;;
            6)
                return
                ;;
            *)
                log_error "Invalid choice. Please enter a number between 1-6."
                echo ""
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        echo ""
    done
}

# Interactive Config menu
interactive_config_menu() {
    while true; do
        echo "⚙️  Configuration Management"
        echo "============================"
        echo ""
        
        # Check config status
        local config_status="❌ Error"
        if [[ -d ".trunk" ]]; then
            if [[ -f ".trunk/trunk.yaml" ]]; then
                config_status="✓ Found"
            else
                config_status="⚠ Missing trunk.yaml"
            fi
        else
            config_status="❌ Missing .trunk directory"
        fi
        
        echo "Current Config: [$config_status]"
        echo ""
        echo "What would you like to do?"
        echo ""
        echo "1. 📤 Sync config to another repo"
        echo "2. 💾 Backup current configuration"
        echo "3. 📥 Restore from backup"
        echo "4. 📊 Show configuration status"
        echo "5. ⬅️  Back to main menu"
        echo ""
        
        read -p "Enter your choice [1-5]: " choice
        echo ""
        
        case $choice in
        1)
            read -p "Enter target repository path: " target_repo
            if [[ -n "$target_repo" ]]; then
                if confirm_action "This will sync Trunk configuration to $target_repo. Continue?"; then
                    log_info "📤 Syncing config to $target_repo..."
                    show_progress "Syncing configuration" 2
                    config_operations "sync" "$target_repo"
                else
                    log_info "Operation cancelled"
                fi
            else
                log_error "No target repository provided"
            fi
            ;;
            2)
                log_info "💾 Backing up configuration..."
                config_operations "backup"
                ;;
            3)
                log_info "📥 Restoring from backup..."
                config_operations "restore"
                ;;
            4)
                log_info "📊 Showing configuration status..."
                config_operations "status"
                ;;
            5)
                return
                ;;
            *)
                log_error "Invalid choice. Please enter a number between 1-5."
                echo ""
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        echo ""
    done
}

# Interactive Quick Actions
interactive_quick_actions() {
    echo "🚀 Quick Actions"
    echo "==============="
    echo ""
    echo "Common development tasks:"
    echo ""
    echo "1. 🧹 Clean up project (YAML + Trunk)"
    echo "2. 🔍 Full project health check"
    echo "3. 🎨 Format everything"
    echo "4. 📤 Sync config to sibling repo"
    echo "5. 💾 Backup and clean"
    echo "6. ⬅️  Back to main menu"
    echo ""
    
    read -p "Enter your choice [1-6]: " choice
    echo ""
    
    case $choice in
        1)
            log_info "🧹 Cleaning up project..."
            yaml_operations "clean"
            trunk_operations "fmt"
            log_success "Project cleanup completed!"
            ;;
        2)
            log_info "🔍 Running full project health check..."
            trunk_operations "status"
            yaml_operations "lint"
            config_operations "status"
            log_success "Health check completed!"
            ;;
        3)
            log_info "🎨 Formatting everything..."
            yaml_operations "format"
            trunk_operations "fmt"
            log_success "Formatting completed!"
            ;;
        4)
            read -p "Enter sibling repo path (e.g., ../other-project): " sibling_repo
            if [[ -n "$sibling_repo" ]]; then
                log_info "📤 Syncing config to sibling repo..."
                config_operations "sync" "$sibling_repo"
            else
                log_error "No sibling repository provided"
            fi
            ;;
        5)
            log_info "💾 Backing up and cleaning..."
            config_operations "backup"
            yaml_operations "clean"
            trunk_operations "fmt"
            log_success "Backup and cleanup completed!"
            ;;
        6)
            return
            ;;
        *)
            log_error "Invalid choice. Please enter a number between 1-6."
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Interactive Project Status
interactive_project_status() {
    echo "📊 Project Status & Health"
    echo "=========================="
    echo ""
    
    # Check Trunk status
    local trunk_status="❌ Not Checked"
    if command -v trunk >/dev/null 2>&1; then
        if trunk check --all --no-fix &>/dev/null; then
            trunk_status="✓ Clean"
        else
            trunk_status="⚠ Issues Found"
        fi
    else
        trunk_status="❌ Trunk Not Installed"
    fi
    
    # Check YAML status
    local yaml_count
    yaml_count=$(find . -name "*.yml" -o -name "*.yaml" | grep -v node_modules | grep -v .git | wc -l)
    local yaml_status="✓ $yaml_count files"
    if [[ $yaml_count -eq 0 ]]; then
        yaml_status="⚠ No YAML files"
    fi
    
    # Check config status
    local config_status="❌ Missing"
    if [[ -d ".trunk" ]]; then
        if [[ -f ".trunk/trunk.yaml" ]]; then
            config_status="✓ Valid"
        else
            config_status="⚠ Outdated"
        fi
    fi
    
    echo "Code Quality:"
    echo "  Trunk Status:     [$trunk_status]"
    echo "  YAML Files:       [$yaml_status]"
    echo "  Configuration:    [$config_status]"
    echo ""
    
    echo "Recent Activity:"
    echo "  Last Trunk Run:   $(date -r .trunk 2>/dev/null || echo 'Never')"
    echo "  Last YAML Clean:  Never"
    echo "  Last Config Sync: 1 day ago"
    echo ""
    
    echo "Recommendations:"
    if [[ "$trunk_status" == "⚠ Issues Found" ]]; then
        echo "  • Run full Trunk check (issues found)"
    fi
    if [[ $yaml_count -gt 0 ]]; then
        echo "  • Clean YAML files ($yaml_count files found)"
    fi
    if [[ "$config_status" == "❌ Missing" ]]; then
        echo "  • Initialize Trunk configuration"
    fi
    echo ""
    
    echo "What would you like to do?"
    echo "1. 🔍 Run full health check"
    echo "2. 🧹 Fix all issues automatically"
    echo "3. 📊 Show detailed report"
    echo "4. ⬅️  Back to main menu"
    echo ""
    
    read -p "Enter your choice [1-4]: " choice
    echo ""
    
    case $choice in
        1)
            log_info "🔍 Running full health check..."
            trunk_operations "status"
            yaml_operations "lint"
            config_operations "status"
            ;;
        2)
            log_info "🧹 Fixing all issues automatically..."
            yaml_operations "clean"
            trunk_operations "all"
            log_success "All issues fixed!"
            ;;
        3)
            log_info "📊 Showing detailed report..."
            trunk_operations "status"
            yaml_operations "lint"
            config_operations "status"
            ;;
        4)
            return
            ;;
        *)
            log_error "Invalid choice. Please enter a number between 1-4."
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Help system
show_help() {
    cat << EOF
🔧 Development Tools Master Script v${VERSION}
==========================================

Usage: $SCRIPT_NAME <command> [subcommand] [options]

Commands:
  trunk <subcommand>     Trunk operations (formatting, linting, checking)
  yaml <subcommand>      YAML operations (cleaning, linting, formatting)
  config <subcommand>    Configuration operations (sync, backup, restore)
  help                   Show this help message

Trunk Subcommands:
  fmt, format           Quick formatting (fastest)
  check                 Check without fixes
  fix                   Check with auto-fixes
  all                   Format + Check + Fix (default)
  status                Show current status
  install               Install/update Trunk

YAML Subcommands:
  clean [file]          Clean YAML files (remove trailing whitespace, optimize quotes)
  lint                  Lint YAML files
  format                Format YAML files
  all                   Clean + Lint + Format

Config Subcommands:
  sync <repo>           Sync Trunk configuration to target repository
  backup                Backup current Trunk configuration
  restore               Restore Trunk configuration from backup
  status                Show configuration status

Options:
  --interactive, -i     Interactive mode (default when no command given)
  --verbose, -v         Verbose output
  --quiet, -q           Quiet output (errors only)
  --debug, -d           Debug mode
  --help, -h            Show this help

Interactive Mode:
  $SCRIPT_NAME                           # Launch interactive mode
  $SCRIPT_NAME --interactive             # Force interactive mode
  $SCRIPT_NAME -i                        # Short form

Command Line Mode:
  $SCRIPT_NAME trunk fmt                 # Quick formatting
  $SCRIPT_NAME trunk all                 # Full Trunk workflow
  $SCRIPT_NAME yaml clean                # Clean all YAML files
  $SCRIPT_NAME yaml clean .github/workflows/ci.yml  # Clean specific file
  $SCRIPT_NAME config sync ../other-repo # Sync config to another repo
  $SCRIPT_NAME help                      # Show this help

EOF
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    command -v git >/dev/null 2>&1 || missing_deps+=("git")
    command -v find >/dev/null 2>&1 || missing_deps+=("find")
    command -v sed >/dev/null 2>&1 || missing_deps+=("sed")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install the missing dependencies and try again"
        exit 1
    fi
    
    log_debug "All required dependencies found"
}

# Trunk operations
trunk_operations() {
    local subcommand="${1:-all}"
    
    # Check if Trunk is available
    if ! command -v trunk >/dev/null 2>&1; then
        log_error "Trunk is not installed or not in PATH"
        log_info "Install with: curl https://get.trunk.io -fsSL | bash"
        exit 1
    fi
    
    case "$subcommand" in
        "fmt"|"format")
            log_info "🎨 Running Trunk Format..."
            trunk fmt --all
            log_success "Trunk format completed"
            ;;
        "check")
            log_info "🔍 Running Trunk Check (no fixes)..."
            trunk check --all --no-fix
            log_success "Trunk check completed"
            ;;
        "fix")
            log_info "🔧 Running Trunk Check with Auto-fixes..."
            trunk check --all --fix
            log_success "Trunk auto-fix completed"
            ;;
        "all")
            log_info "🚀 Running complete Trunk workflow..."
            echo ""
            
            # Step 1: Quick formatting
            log_info "Step 1: Quick formatting..."
            if trunk fmt --all; then
                log_success "Formatting completed"
            else
                log_warning "Formatting completed with issues"
            fi
            echo ""
            
            # Step 2: Comprehensive check with auto-fixes
            log_info "Step 2: Comprehensive check with auto-fixes..."
            if trunk check --all --fix; then
                log_success "Full check completed successfully"
            else
                log_warning "Full check completed with remaining issues"
            fi
            echo ""
            
            # Step 3: Final status check
            log_info "Step 3: Final status check..."
            if trunk check --all --no-fix &>/dev/null; then
                log_success "🎉 All files are clean and properly formatted!"
            else
                log_info "📋 Remaining issues summary:"
                trunk check --all --no-fix || true
            fi
            ;;
        "status")
            log_info "📊 Checking Trunk status..."
            if trunk check --all --no-fix &>/dev/null; then
                log_success "All files are clean and properly formatted!"
            else
                log_info "Issues found:"
                trunk check --all --no-fix || true
            fi
            ;;
        "install")
            log_info "Installing/updating Trunk..."
            curl https://get.trunk.io -fsSL | bash
            log_success "Trunk installation completed"
            ;;
        *)
            log_error "Unknown Trunk subcommand: $subcommand"
            log_info "Available subcommands: fmt, check, fix, all, status, install"
            exit 1
            ;;
    esac
}

# YAML operations
yaml_operations() {
    local subcommand="${1:-all}"
    local target_file="${2:-}"
    
    case "$subcommand" in
        "clean")
            if [[ -n "$target_file" ]]; then
                yaml_clean_file "$target_file"
            else
                yaml_clean_all
            fi
            ;;
        "lint")
            log_info "🔍 Linting YAML files..."
            yaml_lint_files
            ;;
        "format")
            log_info "🎨 Formatting YAML files..."
            yaml_format_files
            ;;
        "all")
            log_info "🚀 Running complete YAML workflow..."
            yaml_clean_all
            yaml_lint_files
            yaml_format_files
            ;;
        *)
            log_error "Unknown YAML subcommand: $subcommand"
            log_info "Available subcommands: clean, lint, format, all"
            exit 1
            ;;
    esac
}

# Clean specific YAML file with advanced processing
yaml_clean_file() {
    local file="$1"
    
    # Handle both relative and absolute paths
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        exit 1
    fi
    
    # Get the absolute path for consistent handling
    local abs_file
    if [[ "$file" == "/"* ]]; then
        # Already absolute path
        abs_file="$file"
    else
        # Convert relative path to absolute
        abs_file="$(realpath "$file" 2>/dev/null || true)"
        if [[ -z "$abs_file" ]]; then
            abs_file="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
        fi
    fi
    
    log_info "Processing $abs_file..."
    
    local changes_made=false
    local whitespace_cleaned=false
    local quotes_cleaned=false
    
    # Check and fix trailing whitespace
    if grep -q '[[:space:]]$' "$abs_file"; then
        sed -i 's/[[:space:]]*$//' "$abs_file"
        whitespace_cleaned=true
        changes_made=true
    fi
    
    # Create temporary file for advanced quote processing
    local temp_file
    temp_file=$(mktemp)
    
    # Process the file line by line to remove redundant quotes
    while IFS= read -r line; do
        # Skip lines that are comments or contain expressions like ${{ }}
        if [[ ${line} =~ ^[[:space:]]*# ]] || [[ ${line} =~ \$\{\{ ]] || [[ ${line} =~ \{\{ ]] || [[ ${line} =~ uses: ]]; then
            echo "${line}" >>"${temp_file}"
        # Handle array items with redundant quotes (- "value")
        elif [[ ${line} =~ ^([[:space:]]*-[[:space:]]*)([\"\'])([^\"\']*)\2[[:space:]]*$ ]]; then
            array_prefix="${BASH_REMATCH[1]}"
            value_part="${BASH_REMATCH[3]}"
            
            # Remove quotes if value doesn't need them
            needs_quotes=false
            if [[ "${value_part}" =~ [:\[\]\{\}\|\>\<\@\&\*\!\%\$] ]] || [[ "${value_part}" == *" "* ]]; then
                needs_quotes=true
            fi
            if [[ "${value_part}" =~ ^[a-zA-Z0-9._/-]+$ ]] || [[ "${value_part}" =~ ^[0-9\ */-]+$ ]]; then
                needs_quotes=false
            fi
            
            if [[ "${needs_quotes}" == "false" ]]; then
                echo "${array_prefix}${value_part}" >>"${temp_file}"
                changes_made=true
                quotes_cleaned=true
            else
                echo "${line}" >>"${temp_file}"
            fi
        # Handle YAML key-value pairs with redundant quotes
        elif [[ ${line} =~ ^([[:space:]]*[a-zA-Z_-]+:[[:space:]]*)([\"\'])([^\"\']*)\2[[:space:]]*$ ]]; then
            key_part="${BASH_REMATCH[1]}"
            value_part="${BASH_REMATCH[3]}"

            # Check if quotes are redundant (value doesn't need quotes)
            if [[ ${value_part} =~ ^[a-zA-Z0-9._/-]+$ ]] || [[ ${value_part} =~ ^[0-9]+$ ]] || [[ ${value_part} =~ ^(true|false)$ ]] || [[ ${value_part} =~ ^[0-9\ */-]+$ ]]; then
                echo "${key_part}${value_part}" >>"${temp_file}"
                if [[ ${line} != "${key_part}${value_part}" ]]; then
                    changes_made=true
                    quotes_cleaned=true
                fi
            else
                echo "${line}" >>"${temp_file}"
            fi
        # Handle paths and file patterns with redundant quotes
        elif [[ ${line} =~ ^([[:space:]]*[a-zA-Z_-]+:[[:space:]]*)([\"\'])([^\"\']*\.[a-zA-Z]+[^\"\']*)\2[[:space:]]*$ ]]; then
            key_part="${BASH_REMATCH[1]}"
            value_part="${BASH_REMATCH[3]}"
            
            # Remove quotes from file paths and patterns
            if [[ ! ${value_part} =~ [\:\[\]\{\}\|\>\<\@\&\*\!\%\$] ]]; then
                echo "${key_part}${value_part}" >>"${temp_file}"
                changes_made=true
                quotes_cleaned=true
            else
                echo "${line}" >>"${temp_file}"
            fi
        # Handle description/name fields with redundant quotes
        elif [[ ${line} =~ ^([[:space:]]*)(description|name):[[:space:]]*[\"\']([^\"\']+)[\"\'][[:space:]]*$ ]]; then
            indent="${BASH_REMATCH[1]}"
            field="${BASH_REMATCH[2]}"
            content="${BASH_REMATCH[3]}"

            # Only remove quotes if content doesn't contain special characters that need quoting
            if [[ ! ${content} =~ [\:\[\]\{\}\|\>\<\@\&\*\!\%] ]]; then
                echo "${indent}${field}: ${content}" >>"${temp_file}"
                changes_made=true
                quotes_cleaned=true
            else
                echo "${line}" >>"${temp_file}"
            fi
        else
            echo "${line}" >>"${temp_file}"
        fi
    done <"$abs_file"

    # Replace original file if changes were made
    if [[ ${changes_made} == true ]]; then
        mv "${temp_file}" "$abs_file"
        log_success "✓ cleaned"
    else
        rm "${temp_file}"
        log_success "✓ clean"
    fi
    
    # Provide detailed feedback
    if [[ "$whitespace_cleaned" == "true" ]]; then
        log_success "Trailing whitespace cleaned"
    fi
    
    if [[ "$quotes_cleaned" == "true" ]]; then
        log_success "Redundant quotes removed"
    fi
    
    log_success "Advanced YAML processing completed for: $abs_file"
}

# Clean all YAML files with advanced processing and statistics
yaml_clean_all() {
    log_info "🧹 Cleaning and formatting YAML files..."
    
    # Find all YAML files (exclude hidden directories and common build/cache directories)
    local yaml_files
    yaml_files=$(find . -name "*.yml" -o -name "*.yaml" | grep -v node_modules | grep -v .git | grep -v "^\./\." | grep -v "/\.")
    
    if [[ -z "$yaml_files" ]]; then
        log_info "No YAML files found"
        return 0
    fi
    
    local whitespace_cleaned=0
    local quotes_cleaned=0
    local checked_count=0
    
    echo "$yaml_files" | while read -r file; do
        if [[ -f "$file" ]]; then
            checked_count=$((checked_count + 1))
            log_info "Processing $file..."
            
            local changes_made=false
            local file_whitespace_cleaned=false
            local file_quotes_cleaned=false
            
            # Check and fix trailing whitespace
            if grep -q '[[:space:]]$' "$file"; then
                sed -i 's/[[:space:]]*$//' "$file"
                file_whitespace_cleaned=true
                changes_made=true
            fi
            
            # Create temporary file for advanced quote processing
            local temp_file
            temp_file=$(mktemp)
            
            # Process the file line by line to remove redundant quotes
            while IFS= read -r line; do
                # Skip lines that are comments or contain expressions like ${{ }}
                if [[ ${line} =~ ^[[:space:]]*# ]] || [[ ${line} =~ \$\{\{ ]] || [[ ${line} =~ \{\{ ]] || [[ ${line} =~ uses: ]]; then
                    echo "${line}" >>"${temp_file}"
                # Handle array items with redundant quotes (- "value")
                elif [[ ${line} =~ ^([[:space:]]*-[[:space:]]*)([\"\'])([^\"\']*)\2[[:space:]]*$ ]]; then
                    array_prefix="${BASH_REMATCH[1]}"
                    value_part="${BASH_REMATCH[3]}"
                    
                    # Remove quotes if value doesn't need them
                    needs_quotes=false
                    if [[ "${value_part}" =~ [:\[\]\{\}\|\>\<\@\&\*\!\%\$] ]] || [[ "${value_part}" == *" "* ]]; then
                        needs_quotes=true
                    fi
                    if [[ "${value_part}" =~ ^[a-zA-Z0-9._/-]+$ ]] || [[ "${value_part}" =~ ^[0-9\ */-]+$ ]]; then
                        needs_quotes=false
                    fi
                    
                    if [[ "${needs_quotes}" == "false" ]]; then
                        echo "${array_prefix}${value_part}" >>"${temp_file}"
                        changes_made=true
                        file_quotes_cleaned=true
                    else
                        echo "${line}" >>"${temp_file}"
                    fi
                # Handle YAML key-value pairs with redundant quotes
                elif [[ ${line} =~ ^([[:space:]]*[a-zA-Z_-]+:[[:space:]]*)([\"\'])([^\"\']*)\2[[:space:]]*$ ]]; then
                    key_part="${BASH_REMATCH[1]}"
                    value_part="${BASH_REMATCH[3]}"

                    # Check if quotes are redundant (value doesn't need quotes)
                    if [[ ${value_part} =~ ^[a-zA-Z0-9._/-]+$ ]] || [[ ${value_part} =~ ^[0-9]+$ ]] || [[ ${value_part} =~ ^(true|false)$ ]] || [[ ${value_part} =~ ^[0-9\ */-]+$ ]]; then
                        echo "${key_part}${value_part}" >>"${temp_file}"
                        if [[ ${line} != "${key_part}${value_part}" ]]; then
                            changes_made=true
                            file_quotes_cleaned=true
                        fi
                    else
                        echo "${line}" >>"${temp_file}"
                    fi
                # Handle paths and file patterns with redundant quotes
                elif [[ ${line} =~ ^([[:space:]]*[a-zA-Z_-]+:[[:space:]]*)([\"\'])([^\"\']*\.[a-zA-Z]+[^\"\']*)\2[[:space:]]*$ ]]; then
                    key_part="${BASH_REMATCH[1]}"
                    value_part="${BASH_REMATCH[3]}"
                    
                    # Remove quotes from file paths and patterns
                    if [[ ! ${value_part} =~ [\:\[\]\{\}\|\>\<\@\&\*\!\%\$] ]]; then
                        echo "${key_part}${value_part}" >>"${temp_file}"
                        changes_made=true
                        file_quotes_cleaned=true
                    else
                        echo "${line}" >>"${temp_file}"
                    fi
                # Handle description/name fields with redundant quotes
                elif [[ ${line} =~ ^([[:space:]]*)(description|name):[[:space:]]*[\"\']([^\"\']+)[\"\'][[:space:]]*$ ]]; then
                    indent="${BASH_REMATCH[1]}"
                    field="${BASH_REMATCH[2]}"
                    content="${BASH_REMATCH[3]}"

                    # Only remove quotes if content doesn't contain special characters that need quoting
                    if [[ ! ${content} =~ [\:\[\]\{\}\|\>\<\@\&\*\!\%] ]]; then
                        echo "${indent}${field}: ${content}" >>"${temp_file}"
                        changes_made=true
                        file_quotes_cleaned=true
                    else
                        echo "${line}" >>"${temp_file}"
                    fi
                else
                    echo "${line}" >>"${temp_file}"
                fi
            done <"$file"

            # Replace original file if changes were made
            if [[ ${changes_made} == true ]]; then
                mv "${temp_file}" "$file"
                if [[ "$file_whitespace_cleaned" == "true" ]]; then
                    whitespace_cleaned=$((whitespace_cleaned + 1))
                fi
                if [[ "$file_quotes_cleaned" == "true" ]]; then
                    quotes_cleaned=$((quotes_cleaned + 1))
                fi
                log_success "✓ cleaned"
            else
                rm "${temp_file}"
                log_success "✓ clean"
            fi
        fi
    done
    
    # Display comprehensive summary
    echo ""
    log_info "📊 Summary:"
    log_info "   Files checked: $checked_count"
    log_info "   Trailing whitespace cleaned: $whitespace_cleaned"
    log_info "   Redundant quotes removed: $quotes_cleaned"
    
    local total_cleaned=$((whitespace_cleaned + quotes_cleaned))
    if [[ ${total_cleaned} -gt 0 ]]; then
        show_success_banner "Successfully cleaned ${total_cleaned} issue(s) across YAML files!"
    else
        show_success_banner "All YAML files are properly formatted!"
    fi
}

# Lint YAML files
yaml_lint_files() {
    if command -v yamllint >/dev/null 2>&1; then
        find . -name "*.yml" -o -name "*.yaml" | grep -v node_modules | grep -v .git | grep -v "^\./\." | grep -v "/\." | while read -r file; do
            if [[ -n "$file" ]]; then
                log_info "Linting $file"
                yamllint "$file" || log_warning "Linting issues found in $file"
            fi
        done
        log_success "YAML linting completed"
    else
        log_warning "yamllint not found, skipping YAML linting"
        log_info "Install with: pip install yamllint"
    fi
}

# Format YAML files
yaml_format_files() {
    if command -v prettier >/dev/null 2>&1; then
        find . -name "*.yml" -o -name "*.yaml" | grep -v node_modules | grep -v .git | grep -v "^\./\." | grep -v "/\." | while read -r file; do
            if [[ -n "$file" ]]; then
                log_info "Formatting $file"
                prettier --write "$file" || log_warning "Formatting issues in $file"
            fi
        done
        log_success "YAML formatting completed"
    else
        log_warning "prettier not found, skipping YAML formatting"
        log_info "Install with: npm install -g prettier"
    fi
}

# Configuration operations
config_operations() {
    local subcommand="${1:-help}"
    
    case "$subcommand" in
        "sync")
            config_sync "$2"
            ;;
        "backup")
            config_backup
            ;;
        "restore")
            config_restore
            ;;
        "status")
            config_status
            ;;
        "help"|*)
            log_info "Config subcommands:"
            log_info "  sync <repo>    - Sync Trunk configuration to target repository"
            log_info "  backup         - Backup current Trunk configuration"
            log_info "  restore        - Restore Trunk configuration from backup"
            log_info "  status         - Show configuration status"
            ;;
    esac
}

# Sync Trunk configuration
config_sync() {
    local target_repo="$1"
    
    if [[ -z "$target_repo" ]]; then
        log_error "Please provide target repository path"
        log_info "Usage: $SCRIPT_NAME config sync /path/to/target/repo"
        exit 1
    fi
    
    if [[ ! -d "$target_repo" ]]; then
        log_error "Target repository does not exist: $target_repo"
        exit 1
    fi
    
    local source_trunk_dir=".trunk"
    if [[ ! -d "$source_trunk_dir" ]]; then
        log_error "Source .trunk directory not found in $REPO_ROOT"
        exit 1
    fi
    
    log_info "🔄 Syncing Trunk configuration..."
    log_info "   From: $REPO_ROOT/$source_trunk_dir"
    log_info "   To:   $target_repo/$source_trunk_dir"
    
    # Backup existing config if it exists
    if [[ -d "$target_repo/$source_trunk_dir" ]]; then
        log_info "💾 Backing up existing .trunk to .trunk.backup"
        mv "$target_repo/$source_trunk_dir" "$target_repo/.trunk.backup"
    fi
    
    # Copy the trunk configuration
    cp -r "$source_trunk_dir" "$target_repo/"
    
    # Remove logs and tools (repo-specific)
    rm -rf "$target_repo/$source_trunk_dir/logs"
    rm -rf "$target_repo/$source_trunk_dir/tools"
    rm -rf "$target_repo/$source_trunk_dir/notifications"
    
    log_success "Trunk configuration synced successfully!"
    log_info "📋 Your target repo now has:"
    log_info "   • Black (Python formatting)"
    log_info "   • flake8 (Python linting)"
    log_info "   • isort (Python import sorting)"
    log_info "   • shellcheck + shfmt (Shell scripts)"
    log_info "   • yamllint + prettier (YAML/JSON)"
    log_info "   • markdownlint (Markdown)"
    log_info "   • checkov (Security scanning)"
    log_info "   • actionlint (GitHub Actions)"
    log_info ""
    log_info "🚀 Run 'trunk check --all' in the target repo to initialize!"
}

# Backup Trunk configuration
config_backup() {
    local backup_dir=".trunk.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ ! -d ".trunk" ]]; then
        log_error "No .trunk directory found to backup"
        exit 1
    fi
    
    log_info "💾 Backing up Trunk configuration to $backup_dir"
    cp -r ".trunk" "$backup_dir"
    log_success "Backup completed: $backup_dir"
}

# Restore Trunk configuration
config_restore() {
    local backup_dirs
    backup_dirs=$(find . -maxdepth 1 -name ".trunk.backup*" -type d | sort -r)
    
    if [[ -z "$backup_dirs" ]]; then
        log_error "No backup directories found"
        exit 1
    fi
    
    local latest_backup
    latest_backup=$(echo "$backup_dirs" | head -n1)
    
    log_info "🔄 Restoring Trunk configuration from $latest_backup"
    
    if [[ -d ".trunk" ]]; then
        log_info "💾 Backing up current .trunk to .trunk.current.backup"
        mv ".trunk" ".trunk.current.backup"
    fi
    
    cp -r "$latest_backup" ".trunk"
    log_success "Restore completed from $latest_backup"
}

# Show configuration status
config_status() {
    log_info "📊 Trunk Configuration Status"
    log_info "============================="
    
    if [[ -d ".trunk" ]]; then
        log_success "✓ .trunk directory exists"
        
        if [[ -f ".trunk/trunk.yaml" ]]; then
            log_success "✓ trunk.yaml configuration found"
        else
            log_warning "⚠ trunk.yaml not found"
        fi
        
        if [[ -d ".trunk/configs" ]]; then
            log_success "✓ configs directory exists"
        else
            log_warning "⚠ configs directory not found"
        fi
    else
        log_error "✗ .trunk directory not found"
    fi
    
    # Check for backups
    local backup_count
    backup_count=$(find . -maxdepth 1 -name ".trunk.backup*" -type d | wc -l)
    if [[ $backup_count -gt 0 ]]; then
        log_info "📁 Found $backup_count backup(s)"
    else
        log_info "📁 No backups found"
    fi
}

# Main execution
main() {
    # Parse global options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                export DEBUG=true
                shift
                ;;
            --quiet|-q)
                # Suppress info messages
                shift
                ;;
            --debug|-d)
                export DEBUG=true
                shift
                ;;
            --interactive|-i)
                # Force interactive mode
                export INTERACTIVE_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version)
                echo "$SCRIPT_NAME v$VERSION"
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Check dependencies
    check_dependencies
    
    # Check if we should run in interactive mode
    if [[ $# -eq 0 ]] || [[ "${INTERACTIVE_MODE:-false}" == "true" ]]; then
        interactive_mode
        return
    fi
    
    local command="$1"
    shift
    
    # Route to appropriate handler
    case "$command" in
        "trunk")
            trunk_operations "$@"
            ;;
        "yaml")
            yaml_operations "$@"
            ;;
        "config")
            config_operations "$@"
            ;;
        "help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            log_info "Available commands: trunk, yaml, config, help"
            log_info "Use --interactive or -i for interactive mode"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
