#!/bin/bash
# YAML Formatter and Cleaner
# Automatically removes trailing whitespace and redundant quotes from YAML files

set -e

echo "🧹 Cleaning and formatting YAML files..."

# Find all YAML files
yaml_files=$(find . -name "*.yml" -o -name "*.yaml")
yaml_files=$(echo "${yaml_files}" | grep -v node_modules)
yaml_files=$(echo "${yaml_files}" | grep -v .git)

whitespace_cleaned=0
quotes_cleaned=0
checked_count=0

for file in ${yaml_files}; do
	if [[ -f ${file} ]]; then
		checked_count=$((checked_count + 1))
		echo -n "Processing ${file}... "

		changes_made=false

		# Check and fix trailing whitespace
		if grep -q '[[:space:]]$' "${file}"; then
			sed -i 's/[[:space:]]*$//' "${file}"
			whitespace_cleaned=$((whitespace_cleaned + 1))
			changes_made=true
		fi

		# Remove redundant quotes from YAML values
		# This handles common patterns like:
		# description: "Some text" -> description: Some text
		# default: "value" -> default: value
		# name: "text" -> name: text

		# Create temporary file for processing
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
				if [[ "${value_part}" =~ [:\[\]{}|><@&*!%$] ]] || [[ "${value_part}" == *" "* ]]; then
					needs_quotes=true
				fi
				if [[ "${value_part}" =~ ^[a-zA-Z0-9._/-]+$ ]] || [[ "${value_part}" =~ ^[0-9\ */-]+$ ]]; then
					needs_quotes=false
				fi
				
				if [[ "${needs_quotes}" == "false" ]]; then
					echo "${array_prefix}${value_part}" >>"${temp_file}"
					changes_made=true
				else
					echo "${line}" >>"${temp_file}"
				fi
			# Handle YAML key-value pairs with redundant quotes
			elif [[ ${line} =~ ^([[:space:]]*[a-zA-Z_-]+:[[:space:]]*)([\"\'])([^\"\']*)\2[[:space:]]*$ ]]; then
				key_part="${BASH_REMATCH[1]}"
				value_part="${BASH_REMATCH[3]}"

				# Check if quotes are redundant (value doesn't need quotes)
				if [[ ${value_part} =~ ^[a-zA-Z0-9._/-]+$ ]] || [[ ${value_part} =~ ^[0-9]+$ ]] || [[ ${value_part} =~ ^(true|false)$ ]] || [[ ${value_part} =~ ^[0-9 */-]+$ ]]; then
					echo "${key_part}${value_part}" >>"${temp_file}"
					if [[ ${line} != "${key_part}${value_part}" ]]; then
						changes_made=true
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
				else
					echo "${line}" >>"${temp_file}"
				fi
			else
				echo "${line}" >>"${temp_file}"
			fi
		done <"${file}"

		# Replace original file if changes were made
		if [[ ${changes_made} == true ]]; then
			mv "${temp_file}" "${file}"
			if grep -q 'description:\|name:\|default:' "${file}" && ! grep -q '".*"' "${file}"; then
				quotes_cleaned=$((quotes_cleaned + 1))
			fi
			echo "✓ cleaned"
		else
			rm "${temp_file}"
			echo "✓ clean"
		fi
	fi
done

echo ""
echo "📊 Summary:"
echo "   Files checked: ${checked_count}"
echo "   Trailing whitespace cleaned: ${whitespace_cleaned}"
echo "   Redundant quotes removed: ${quotes_cleaned}"

total_cleaned=$((whitespace_cleaned + quotes_cleaned))
if [[ ${total_cleaned} -gt 0 ]]; then
	echo "🎉 Successfully cleaned ${total_cleaned} issue(s) across YAML files!"
else
	echo "✅ All YAML files are properly formatted!"
fi
