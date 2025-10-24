#!/bin/bash

# Trunk Config Sync Script
# Copy your perfected Trunk configuration to other repositories

SOURCE_TRUNK_DIR=".trunk"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "${SCRIPT_DIR}")"

sync_trunk_config() {
	local target_repo="$1"

	if [[ -z ${target_repo} ]]; then
		echo "❌ Error: Please provide target repository path"
		echo "Usage: $0 /path/to/target/repo"
		exit 1
	fi

	if [[ ! -d ${target_repo} ]]; then
		echo "❌ Error: Target repository does not exist: ${target_repo}"
		exit 1
	fi

	if [[ ! -d "${SOURCE_DIR}/${SOURCE_TRUNK_DIR}" ]]; then
		echo "❌ Error: Source .trunk directory not found in ${SOURCE_DIR}"
		exit 1
	fi

	echo "🔄 Syncing Trunk configuration..."
	echo "   From: ${SOURCE_DIR}/${SOURCE_TRUNK_DIR}"
	echo "   To:   ${target_repo}/${SOURCE_TRUNK_DIR}"

	# Backup existing config if it exists
	if [[ -d "${target_repo}/${SOURCE_TRUNK_DIR}" ]]; then
		echo "💾 Backing up existing .trunk to .trunk.backup"
		mv "${target_repo}/${SOURCE_TRUNK_DIR}" "${target_repo}/.trunk.backup"
	fi

	# Copy the trunk configuration
	cp -r "${SOURCE_DIR}/${SOURCE_TRUNK_DIR}" "${target_repo}/"

	# Remove logs and tools (repo-specific)
	rm -rf "${target_repo}/${SOURCE_TRUNK_DIR}/logs"
	rm -rf "${target_repo}/${SOURCE_TRUNK_DIR}/tools"
	rm -rf "${target_repo}/${SOURCE_TRUNK_DIR}/notifications"

	echo "✅ Trunk configuration synced successfully!"
	echo ""
	echo "📋 Your target repo now has:"
	echo "   • Black (Python formatting)"
	echo "   • flake8 (Python linting)"
	echo "   • isort (Python import sorting)"
	echo "   • shellcheck + shfmt (Shell scripts)"
	echo "   • yamllint + prettier (YAML/JSON)"
	echo "   • markdownlint (Markdown)"
	echo "   • checkov (Security scanning)"
	echo "   • actionlint (GitHub Actions)"
	echo ""
	echo "🚀 Run 'trunk check --all' in the target repo to initialize!"
}

# Show help if no arguments
if [[ $# -eq 0 ]]; then
	echo "🔧 Trunk Configuration Sync Tool"
	echo "================================="
	echo ""
	echo "This script copies your perfected Trunk configuration to other repositories."
	echo ""
	echo "Usage:"
	echo "  $0 /path/to/target/repository"
	echo ""
	echo "Example:"
	echo "  $0 ../my-other-project"
	echo "  $0 /home/user/projects/another-repo"
	echo ""
	echo "What gets synced:"
	echo "  ✓ trunk.yaml (linter configuration)"
	echo "  ✓ configs/ (tool-specific settings)"
	echo "  ✓ .gitignore"
	echo "  ✗ logs/ (repo-specific, excluded)"
	echo "  ✗ tools/ (downloaded binaries, excluded)"
	exit 0
fi

# Run the sync
sync_trunk_config "$1"
