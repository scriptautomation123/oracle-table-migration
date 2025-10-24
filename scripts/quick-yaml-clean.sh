#!/bin/bash
# Quick YAML cleaner - one-liner version
# Usage: ./scripts/quick-yaml-clean.sh [file_path]
# Examples:
#   ./scripts/quick-yaml-clean.sh                                    # Clean all YAML files
#   ./scripts/quick-yaml-clean.sh .github/workflows/ci.yml          # Clean specific file (relative path)
#   ./scripts/quick-yaml-clean.sh /full/path/to/file.yml            # Clean specific file (absolute path)

if [[ $# -eq 1 ]]; then
	# Clean specific file
	file="$1"

	# Handle both relative and absolute paths
	if [[ ! -f ${file} ]]; then
		echo "❌ Error: File not found: ${file}"
		exit 1
	fi

	# Get the absolute path for consistent handling
	if [[ ${file} == "/"* ]]; then
		# Already absolute path
		abs_file="${file}"
	else
		# Convert relative path to absolute
		abs_file="$(realpath "${file}" 2>/dev/null || true)"
		if [[ -z ${abs_file} ]]; then
			abs_file="$(cd "$(dirname "${file}")" && pwd)/$(basename "${file}")"
		fi
	fi

	echo "Cleaning ${abs_file}..."

	# Remove trailing whitespace and comprehensive redundant quotes
	sed -i \
		-e 's/[[:space:]]*$//' \
		-e 's/^\([[:space:]]*[a-zA-Z_-]*:[[:space:]]*\)"\([a-zA-Z0-9._/-]*\)"$/\1\2/' \
		-e 's/^\([[:space:]]*-[[:space:]]*\)"\([^"]*\)"$/\1\2/' \
		-e 's/^\([[:space:]]*[a-zA-Z_-]*:[[:space:]]*\)"\([^"]*\)"$/\1\2/' \
		-e 's/^\([[:space:]]*\)\([a-zA-Z_-]*\):[[:space:]]*"\([0-9 */-]*\)"$/\1\2: \3/' \
		"${abs_file}"

	# Check results using the absolute path
	if grep -q '[[:space:]]$' "${abs_file}"; then
		echo "⚠️  Still has trailing whitespace"
	else
		echo "✅ Trailing whitespace cleaned"
	fi

	echo "✅ Quote cleanup completed for: ${abs_file}"
else
	# Clean all YAML files
	echo "Quick cleaning all YAML files..."
	yaml_files=$(find . -name "*.yml" -o -name "*.yaml")
	yaml_files=$(echo "${yaml_files}" | grep -v node_modules)
	yaml_files=$(echo "${yaml_files}" | grep -v .git)

	echo "${yaml_files}" | while read -r file; do
		if [[ -n ${file} ]]; then
			echo "Processing ${file}"
			# Comprehensive quote removal patterns
			sed -i \
				-e 's/[[:space:]]*$//' \
				-e 's/^\([[:space:]]*[a-zA-Z_-]*:[[:space:]]*\)"\([a-zA-Z0-9._/-]*\)"$/\1\2/' \
				-e 's/^\([[:space:]]*-[[:space:]]*\)"\([^"]*\)"$/\1\2/' \
				-e 's/^\([[:space:]]*[a-zA-Z_-]*:[[:space:]]*\)"\([^"]*\)"$/\1\2/' \
				-e 's/^\([[:space:]]*\)\([a-zA-Z_-]*\):[[:space:]]*"\([0-9 */-]*\)"$/\1\2: \3/' \
				"${file}" || true
		fi
	done
	echo "✅ Quick clean completed!"
fi
