#!/usr/bin/env python3
"""
Test Validator Module
=====================
Validates results at each step of the workflow.
"""

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List


@dataclass
class ValidationResult:
    """Result of a validation check"""

    passed: bool
    message: str
    details: Dict[str, Any] = None


class TestValidator:
    """Validate workflow results"""

    def __init__(self, verbose: bool = False):
        self.verbose = verbose

    def validate_discovery_config(self, config_file: Path) -> ValidationResult:
        """
        Validate generated configuration file

        Args:
            config_file: Path to config JSON file

        Returns:
            ValidationResult indicating success and details
        """
        try:
            if not config_file.exists():
                return ValidationResult(
                    passed=False,
                    message=f"Config file not found: {config_file}",
                    details={"file": str(config_file)},
                )

            with open(config_file, "r") as f:
                config = json.load(f)

            required_fields = ["metadata", "environment_config", "tables"]
            missing_fields = [f for f in required_fields if f not in config]

            if missing_fields:
                return ValidationResult(
                    passed=False,
                    message=f"Config missing required fields: {missing_fields}",
                    details={"missing": missing_fields, "found": list(config.keys())},
                )

            tables = config.get("tables", [])
            if not tables:
                return ValidationResult(
                    passed=False,
                    message="No tables found in configuration",
                    details={"table_count": 0},
                )

            return ValidationResult(
                passed=True,
                message=f"Config validation passed: {len(tables)} tables",
                details={
                    "table_count": len(tables),
                    "tables": [t.get("name") for t in tables[:5]],
                },
            )

        except json.JSONDecodeError as e:
            return ValidationResult(
                passed=False,
                message=f"Invalid JSON in config file: {e}",
                details={"error": str(e)},
            )
        except Exception as e:
            return ValidationResult(
                passed=False,
                message=f"Error validating config: {e}",
                details={"error": str(e)},
            )

    def validate_generated_sql(
        self, output_dir: Path, expected_tables: int
    ) -> ValidationResult:
        """
        Validate generated SQL files exist and are non-empty

        Args:
            output_dir: Directory containing generated SQL files
            expected_tables: Expected number of tables

        Returns:
            ValidationResult with details about generated files
        """
        if not output_dir.exists():
            return ValidationResult(
                passed=False,
                message=f"Output directory not found: {output_dir}",
                details={"directory": str(output_dir)},
            )

        master_scripts = list(output_dir.glob("**/master1.sql"))
        non_master_sql = list(output_dir.glob("**/*.sql"))
        non_master_sql = [f for f in non_master_sql if "master" not in f.name]

        if len(master_scripts) < expected_tables:
            return ValidationResult(
                passed=False,
                message=f"Expected {expected_tables} master1.sql files, found {len(master_scripts)}",
                details={
                    "expected": expected_tables,
                    "found": len(master_scripts),
                    "files": [str(f) for f in master_scripts[:5]],
                },
            )

        empty_files = []
        for sql_file in master_scripts:
            if sql_file.stat().st_size == 0:
                empty_files.append(str(sql_file))

        if empty_files:
            return ValidationResult(
                passed=False,
                message=f"Found {len(empty_files)} empty SQL files",
                details={"empty_files": empty_files},
            )

        return ValidationResult(
            passed=True,
            message=f"SQL validation passed: {len(master_scripts)} master scripts, {len(non_master_sql)} support files",
            details={
                "master_scripts": len(master_scripts),
                "support_files": len(non_master_sql),
                "total_files": len(master_scripts) + len(non_master_sql),
            },
        )

    def validate_sql_structure(self, sql_file: Path) -> ValidationResult:
        """
        Validate basic SQL syntax and structure

        Args:
            sql_file: Path to SQL file to validate

        Returns:
            ValidationResult with validation details
        """
        try:
            content = sql_file.read_text()

            checks = {
                "not_empty": len(content.strip()) > 0,
                "has_semicolons": ";" in content,
                "has_create_or_alter": "CREATE" in content.upper()
                or "ALTER" in content.upper(),
                "balanced_quotes": content.count('"') % 2 == 0,
                "balanced_parentheses": content.count("(") == content.count(")"),
            }

            failed_checks = [k for k, v in checks.items() if not v]

            if failed_checks:
                return ValidationResult(
                    passed=False,
                    message=f"SQL validation failed checks: {failed_checks}",
                    details={"failed_checks": failed_checks, "checks": checks},
                )

            return ValidationResult(
                passed=True, message="SQL structure validation passed", details=checks
            )

        except Exception as e:
            return ValidationResult(
                passed=False,
                message=f"Error reading SQL file: {e}",
                details={"error": str(e)},
            )

    def validate_file_sizes(
        self, output_dir: Path, min_size_bytes: int = 100
    ) -> ValidationResult:
        """
        Validate that generated files meet minimum size requirements

        Args:
            output_dir: Directory to check
            min_size_bytes: Minimum file size in bytes

        Returns:
            ValidationResult with file size details
        """
        sql_files = list(output_dir.glob("**/*.sql"))
        small_files = [f for f in sql_files if f.stat().st_size < min_size_bytes]

        if small_files:
            return ValidationResult(
                passed=False,
                message=f"Found {len(small_files)} files smaller than {min_size_bytes} bytes",
                details={
                    "small_files": [
                        (str(f), f.stat().st_size) for f in small_files[:10]
                    ]
                },
            )

        avg_size = (
            sum(f.stat().st_size for f in sql_files) / len(sql_files)
            if sql_files
            else 0
        )

        return ValidationResult(
            passed=True,
            message=f"File size validation passed: {len(sql_files)} files, avg {avg_size:.0f} bytes",
            details={
                "total_files": len(sql_files),
                "average_size": avg_size,
                "min_size_check": min_size_bytes,
            },
        )

    def validate_directory_structure(self, output_dir: Path) -> ValidationResult:
        """
        Validate that output directory has expected structure

        Args:
            output_dir: Directory to validate

        Returns:
            ValidationResult with structure details
        """
        subdirs = [d for d in output_dir.iterdir() if d.is_dir()]
        sql_files = list(output_dir.glob("**/*.sql"))
        json_files = list(output_dir.glob("**/*.json"))

        if not subdirs and not sql_files:
            return ValidationResult(
                passed=False,
                message="Output directory is empty",
                details={"directory": str(output_dir)},
            )

        return ValidationResult(
            passed=True,
            message=f"Directory structure valid: {len(subdirs)} subdirs, {len(sql_files)} SQL files, {len(json_files)} JSON files",
            details={
                "subdirectories": len(subdirs),
                "sql_files": len(sql_files),
                "json_files": len(json_files),
                "subdir_names": [d.name for d in subdirs[:10]],
            },
        )

    def validate_table_names(
        self, config_file: Path, sql_dirs: List[Path]
    ) -> ValidationResult:
        """
        Validate that tables in config have corresponding SQL directories

        Args:
            config_file: Path to config JSON
            sql_dirs: List of SQL directory paths

        Returns:
            ValidationResult with matching details
        """
        try:
            with open(config_file, "r") as f:
                config = json.load(f)

            config_tables = {t.get("name") for t in config.get("tables", [])}
            sql_table_dirs = {d.name for d in sql_dirs if d.is_dir()}

            missing = config_tables - sql_table_dirs
            extra = sql_table_dirs - config_tables

            issues = []
            if missing:
                issues.append(f"Config tables without SQL dirs: {missing}")
            if extra:
                issues.append(f"SQL dirs not in config: {extra}")

            if issues:
                return ValidationResult(
                    passed=False,
                    message="Table/SQL directory mismatch",
                    details={
                        "missing_dirs": list(missing),
                        "extra_dirs": list(extra),
                        "config_tables": list(config_tables),
                        "sql_dirs": list(sql_table_dirs),
                    },
                )

            return ValidationResult(
                passed=True,
                message=f"All {len(config_tables)} tables have corresponding SQL directories",
                details={"table_count": len(config_tables)},
            )

        except Exception as e:
            return ValidationResult(
                passed=False,
                message=f"Error validating table names: {e}",
                details={"error": str(e)},
            )
