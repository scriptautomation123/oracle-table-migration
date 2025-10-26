#!/bin/bash

# VS Code Extension Manager - Disable unwanted extensions for this workspace
# This script will disable all extensions except the ones you want to keep active

echo "🔌 Managing VS Code Extensions for this workspace..."
echo "=================================================="

# Extensions to keep enabled (the ones you want)
KEEP_ENABLED=(
    "trunk.io"
    "github.copilot" 
    "github.copilot-chat"
    "maciejdems.add-to-gitignore"
)

# Get all installed extensions (skip the header line)
ALL_EXTENSIONS=$(code --list-extensions 2>/dev/null | grep -v "Extensions installed")

if [ -z "$ALL_EXTENSIONS" ]; then
    echo "❌ Could not get extension list. Make sure VS Code is installed and 'code' command is available."
    exit 1
fi

echo "📋 Found $(echo "$ALL_EXTENSIONS" | wc -l) installed extensions"
echo ""

# Function to check if extension should be kept enabled
should_keep_enabled() {
    local ext="$1"
    for keep in "${KEEP_ENABLED[@]}"; do
        if [[ "$ext" == "$keep" ]]; then
            return 0  # Found in keep list
        fi
    done
    return 1  # Not in keep list
}

echo "✅ Extensions that will stay ENABLED:"
for ext in "${KEEP_ENABLED[@]}"; do
    echo "  - $ext"
done
echo ""

echo "⚠️  Extensions that will be DISABLED for this workspace:"
DISABLED_COUNT=0

# Process each installed extension
while IFS= read -r extension; do
    if ! should_keep_enabled "$extension"; then
        echo "  - $extension"
        ((DISABLED_COUNT++))
    fi
done <<< "$ALL_EXTENSIONS"

echo ""
echo "📊 Summary: $DISABLED_COUNT extensions will be disabled, ${#KEEP_ENABLED[@]} will remain enabled"
echo ""

# Ask for confirmation
read -p "Do you want to proceed with disabling these extensions? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Operation cancelled"
    exit 0
fi

echo "🔄 Disabling unwanted extensions..."

# Disable extensions
DISABLED_ACTUAL=0
while IFS= read -r extension; do
    if ! should_keep_enabled "$extension"; then
        echo "  Disabling: $extension"
        if code --disable-extension "$extension" >/dev/null 2>&1; then
            ((DISABLED_ACTUAL++))
        else
            echo "    ⚠️ Failed to disable $extension"
        fi
    fi
done <<< "$ALL_EXTENSIONS"

echo ""
echo "✅ Done! Disabled $DISABLED_ACTUAL extensions"
echo ""
echo "🔄 Please reload VS Code window to see the changes:"
echo "   1. Press Ctrl+Shift+P"
echo "   2. Type 'Developer: Reload Window'"
echo "   3. Press Enter"
echo ""
echo "To re-enable an extension later:"
echo "   code --enable-extension <extension-id>"