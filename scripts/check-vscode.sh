#!/bin/bash

# Quick VS Code Settings Checker
# Simple script to show all your current VS Code configurations

echo "🔍 VS Code Configuration Overview"
echo "=================================="

# Show workspace settings
echo "📁 Workspace Settings (.vscode/settings.json):"
if [ -f ".vscode/settings.json" ]; then
    cat .vscode/settings.json
else
    echo "  ❌ No workspace settings found"
fi

echo ""
echo "🔌 Workspace Extensions (.vscode/extensions.json):"
if [ -f ".vscode/extensions.json" ]; then
    cat .vscode/extensions.json
else
    echo "  ❌ No extensions config found"
fi

echo ""
echo "📦 Currently Installed Extensions:"
if command -v code >/dev/null 2>&1; then
    code --list-extensions | wc -l | xargs echo "Total:"
    echo "List:"
    code --list-extensions | sort
else
    echo "  ❌ VS Code command not found"
fi

echo ""
echo "🔧 User Settings Location: ~/.config/Code/User/settings.json"
if [ -f "$HOME/.config/Code/User/settings.json" ]; then
    echo "Extension settings in user config:"
    grep -n "extensions\." "$HOME/.config/Code/User/settings.json" 2>/dev/null || echo "  None found"
else
    echo "  ❌ No user settings found"
fi