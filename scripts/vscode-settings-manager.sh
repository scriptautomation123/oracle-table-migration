#!/bin/bash

# VS Code Settings Management Script
# This script helps you view and manage all VS Code settings and extensions configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored headers
print_header() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===========================================${NC}"
}

print_subheader() {
    echo -e "${CYAN}--- $1 ---${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Get current directory
CURRENT_DIR=$(pwd)

print_header "VS Code Settings & Extensions Overview"
echo "Current directory: $CURRENT_DIR"
echo "Timestamp: $(date)"
echo ""

# 1. Check User Settings (Global)
print_subheader "1. User Settings (Global Profile)"
USER_SETTINGS_PATH="$HOME/.config/Code/User/settings.json"

if [ -f "$USER_SETTINGS_PATH" ]; then
    print_success "Found user settings: $USER_SETTINGS_PATH"
    echo "Extension-related settings in user config:"
    if grep -n "extensions\." "$USER_SETTINGS_PATH" 2>/dev/null; then
        echo ""
    else
        echo "  No extension-related settings found"
    fi
else
    print_warning "No user settings file found at $USER_SETTINGS_PATH"
fi
echo ""

# 2. Check Workspace Settings
print_subheader "2. Workspace Settings (Current Project)"
WORKSPACE_SETTINGS="$CURRENT_DIR/.vscode/settings.json"

if [ -f "$WORKSPACE_SETTINGS" ]; then
    print_success "Found workspace settings: $WORKSPACE_SETTINGS"
    echo "Contents:"
    cat "$WORKSPACE_SETTINGS" | jq . 2>/dev/null || cat "$WORKSPACE_SETTINGS"
else
    print_warning "No workspace settings found at $WORKSPACE_SETTINGS"
fi
echo ""

# 3. Check Workspace Extensions
print_subheader "3. Workspace Extensions Configuration"
WORKSPACE_EXTENSIONS="$CURRENT_DIR/.vscode/extensions.json"

if [ -f "$WORKSPACE_EXTENSIONS" ]; then
    print_success "Found extensions config: $WORKSPACE_EXTENSIONS"
    echo "Contents:"
    cat "$WORKSPACE_EXTENSIONS" | jq . 2>/dev/null || cat "$WORKSPACE_EXTENSIONS"
    
    # Count recommended vs unwanted
    if command -v jq >/dev/null 2>&1; then
        RECOMMENDED=$(jq '.recommendations | length' "$WORKSPACE_EXTENSIONS" 2>/dev/null || echo "0")
        UNWANTED=$(jq '.unwantedRecommendations | length' "$WORKSPACE_EXTENSIONS" 2>/dev/null || echo "0")
        echo ""
        echo "Summary: $RECOMMENDED recommended, $UNWANTED unwanted extensions"
    fi
else
    print_warning "No extensions config found at $WORKSPACE_EXTENSIONS"
fi
echo ""

# 4. List Currently Installed Extensions
print_subheader "4. Currently Installed Extensions"
if command -v code >/dev/null 2>&1; then
    INSTALLED_EXTENSIONS=$(code --list-extensions 2>/dev/null)
    if [ -n "$INSTALLED_EXTENSIONS" ]; then
        echo "$INSTALLED_EXTENSIONS" | wc -l | xargs echo "Total installed extensions:"
        echo ""
        echo "Extensions:"
        echo "$INSTALLED_EXTENSIONS" | sort
    else
        print_warning "No extensions installed or VS Code not accessible"
    fi
else
    print_error "VS Code command 'code' not found in PATH"
fi
echo ""

# 5. Check for conflicts
print_subheader "5. Potential Issues & Recommendations"

# Check if workspace extensions.json exists but has conflicting settings
if [ -f "$WORKSPACE_EXTENSIONS" ] && [ -f "$USER_SETTINGS_PATH" ]; then
    if grep -q "extensions.ignoreRecommendations.*true" "$USER_SETTINGS_PATH" 2>/dev/null; then
        print_warning "User settings has 'ignoreRecommendations: true' which may override workspace extension recommendations"
    fi
fi

# Check for deprecated settings
if [ -f "$WORKSPACE_SETTINGS" ]; then
    if grep -q "extensions.autoCheckUpdates\|extensions.autoUpdate" "$WORKSPACE_SETTINGS" 2>/dev/null; then
        print_error "Workspace settings contains global-only extension settings (autoCheckUpdates/autoUpdate)"
        echo "  These should be moved to user settings: $USER_SETTINGS_PATH"
    fi
fi

echo ""
print_subheader "6. Quick Actions"
echo "To modify settings, edit these files:"
echo "  • User (global): $USER_SETTINGS_PATH"
echo "  • Workspace: $WORKSPACE_SETTINGS"
echo "  • Extensions: $WORKSPACE_EXTENSIONS"
echo ""
echo "Useful commands:"
echo "  • code --list-extensions                    # List installed extensions"
echo "  • code --disable-extension <ext-id>        # Disable an extension"
echo "  • code --enable-extension <ext-id>         # Enable an extension"
echo "  • code --uninstall-extension <ext-id>      # Uninstall an extension"
echo ""

# 7. Create backup function
print_subheader "7. Backup Current Configuration"
BACKUP_DIR="$CURRENT_DIR/.vscode-backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

create_backup() {
    echo "Creating backup of current VS Code configuration..."
    mkdir -p "$BACKUP_DIR"
    
    # Backup workspace settings
    if [ -f "$WORKSPACE_SETTINGS" ]; then
        cp "$WORKSPACE_SETTINGS" "$BACKUP_DIR/settings_${TIMESTAMP}.json"
        print_success "Backed up workspace settings"
    fi
    
    # Backup extensions config
    if [ -f "$WORKSPACE_EXTENSIONS" ]; then
        cp "$WORKSPACE_EXTENSIONS" "$BACKUP_DIR/extensions_${TIMESTAMP}.json"
        print_success "Backed up extensions config"
    fi
    
    # Backup user settings (if accessible)
    if [ -f "$USER_SETTINGS_PATH" ]; then
        cp "$USER_SETTINGS_PATH" "$BACKUP_DIR/user_settings_${TIMESTAMP}.json"
        print_success "Backed up user settings"
    fi
    
    # Save current extension list
    if command -v code >/dev/null 2>&1; then
        code --list-extensions > "$BACKUP_DIR/installed_extensions_${TIMESTAMP}.txt"
        print_success "Saved installed extensions list"
    fi
    
    echo "Backups saved to: $BACKUP_DIR/"
}

echo "Run '$0 backup' to create a backup of current configuration"

# Handle command line arguments
case "${1:-}" in
    "backup")
        create_backup
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [backup|help]"
        echo "  backup  - Create backup of current VS Code configuration"
        echo "  help    - Show this help message"
        ;;
esac