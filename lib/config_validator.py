#!/usr/bin/env python3
"""
Configuration Validator Module
==============================
Validates migration configuration files against schema and best practices.
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Tuple

from jsonschema import ValidationError, validate

try:
    from .migration_models import MigrationConfig, TableConfig
except ImportError:
    try:
        from lib.migration_models import MigrationConfig, TableConfig
    except ImportError:
        print("ERROR: migration_models module not found!")
        print("Run: python3 src/schema_to_dataclass.py")
        MigrationConfig = None
        TableConfig = None


class ConfigValidator:
    """Validates migration configuration files"""

    def __init__(self, connection=None, schema_file="enhanced_migration_schema.json"):
        """
        Initialize validator

        Args:
            connection: Optional Oracle connection for database validation
            schema_file: Path to JSON schema file
        """
        self.connection = connection
        self.schema_file = Path(schema_file)
        self.schema = self._load_schema()
        self.errors = []
        self.warnings = []

    def _load_schema(self) -> Dict:
        """Load JSON schema from file"""
        if not self.schema_file.exists():
            # Try relative to this file
            schema_path = Path(__file__).parent / self.schema_file
            if not schema_path.exists():
                raise FileNotFoundError(f"Schema file not found: {self.schema_file}")
            self.schema_file = schema_path

        with open(self.schema_file) as f:
            return json.load(f)

    def validate_config(
        self, config: Dict, check_database: bool = False
    ) -> Tuple[bool, List[str], List[str]]:
        """
        Validate complete configuration

        Args:
            config: Configuration dictionary
            check_database: Whether to validate against database (requires connection)

        Returns:
            Tuple of (is_valid, errors, warnings)
        """
        self.errors = []
        self.warnings = []

        # Step 1: JSON schema validation
        print("Validating JSON schema...")
        self._validate_schema(config)

        # Step 2: Logical validation
        print("Validating logical consistency...")
        self._validate_logic(config)

        # Step 3: Database validation (if connection provided)
        if check_database and self.connection:
            print("Validating against database...")
            self._validate_database(config)
        elif check_database and not self.connection:
            self.warnings.append(
                "Database validation requested but no connection provided"
            )

        # Step 4: Best practice checks
        print("Checking best practices...")
        self._check_best_practices(config)

        is_valid = len(self.errors) == 0

        # Print summary
        print(f"\n{'='*70}")
        if is_valid:
            print("✓ Configuration is VALID")
        else:
            print("✗ Configuration has ERRORS")

        if self.errors:
            print(f"\nErrors ({len(self.errors)}):")
            for i, error in enumerate(self.errors, 1):
                print(f"  {i}. {error}")

        if self.warnings:
            print(f"\nWarnings ({len(self.warnings)}):")
            for i, warning in enumerate(self.warnings, 1):
                print(f"  {i}. ⚠  {warning}")

        print(f"{'='*70}\n")

        return is_valid, self.errors, self.warnings

    def _validate_schema(self, config: Dict):
        """Validate against JSON schema"""
        try:
            validate(instance=config, schema=self.schema)
        except ValidationError as e:
            self.errors.append(f"JSON Schema Validation: {e.message}")
            # Add path info for nested errors
            if e.path:
                path = " -> ".join(str(p) for p in e.path)
                self.errors.append(f"  at: {path}")

    def _validate_logic(self, config: Dict):
        """Validate logical consistency"""
        metadata = config.get("metadata", {})
        tables = config.get("tables", [])

        # Check metadata consistency
        total_found = metadata.get("total_tables_found", 0)
        selected = metadata.get("tables_selected_for_migration", 0)
        actual_count = len(tables)
        enabled_count = sum(1 for t in tables if t.get("enabled", False))

        if actual_count != total_found:
            self.warnings.append(
                f"Metadata says {total_found} tables found, but config has {actual_count} tables"
            )

        if enabled_count != selected:
            self.warnings.append(
                f"Metadata says {selected} tables selected, but {enabled_count} are enabled"
            )

        # Validate each table
        for idx, table in enumerate(tables):
            self._validate_table_logic(table, idx)

    def _validate_table_logic(self, table_dict: Dict, index: int):
        """Validate logic for a single table using typed models"""
        try:
            # Convert to typed model for better validation
            table = TableConfig(
                enabled=table_dict.get("enabled", False),
                owner=table_dict.get("owner", ""),
                table_name=table_dict.get("table_name", f"table[{index}]"),
                current_state=None,  # We'll access the dict directly for now
                common_settings=None,  # We'll access the dict directly for now
            )
        except Exception as e:
            self.errors.append(f"Table[{index}]: Failed to parse table structure: {e}")
            return

        table_name = table.table_name
        prefix = f"Table {table_name}"

        current_state = table_dict.get("current_state", {})
        common_settings = table_dict.get("common_settings", {})
        target_config = common_settings.get("target_configuration", {})
        available_cols = current_state.get("available_columns", {})
        migration_action = common_settings.get("migration_action")

        # Check partition column selection
        partition_col = target_config.get("partition_column")
        if partition_col:
            timestamp_cols = [
                c["name"] for c in available_cols.get("timestamp_columns", [])
            ]
            if partition_col not in timestamp_cols:
                self.errors.append(
                    f"{prefix}: partition_column '{partition_col}' not in available timestamp columns"
                )
        else:
            if target_config.get("partition_type") == "INTERVAL":
                self.errors.append(
                    f"{prefix}: partition_column required for INTERVAL partitioning"
                )

        # Check subpartition column selection
        subpart_col = target_config.get("subpartition_column")
        if subpart_col and target_config.get("subpartition_type") == "HASH":
            numeric_cols = [
                c["name"] for c in available_cols.get("numeric_columns", [])
            ]
            string_cols = [c["name"] for c in available_cols.get("string_columns", [])]
            all_hash_cols = numeric_cols + string_cols

            if subpart_col not in all_hash_cols:
                self.errors.append(
                    f"{prefix}: subpartition_column '{subpart_col}' not in available columns"
                )

        # Check interval type consistency
        interval_type = target_config.get("interval_type")
        interval_value = target_config.get("interval_value", 1)

        if interval_type and interval_value < 1:
            self.errors.append(f"{prefix}: interval_value must be >= 1")

        # Check hash subpartition count (recommend power of 2)
        subpart_count = target_config.get("subpartition_count", 0)
        if subpart_count > 0:
            if subpart_count > 1024:
                self.errors.append(
                    f"{prefix}: subpartition_count {subpart_count} exceeds maximum (1024)"
                )
            elif not self._is_power_of_2(subpart_count):
                self.warnings.append(
                    f"{prefix}: subpartition_count {subpart_count} is not a power of 2 (recommended: 2, 4, 8, 16, 32, ...)"
                )

        # Check migration action consistency
        is_partitioned = current_state.get("is_partitioned", False)
        has_subparts = current_state.get("has_subpartitions", False)

        if migration_action == "add_interval_hash_partitioning" and is_partitioned:
            self.warnings.append(
                f"{prefix}: action is 'add_interval_hash_partitioning' but table is already partitioned"
            )

        if migration_action == "add_hash_subpartitions" and has_subparts:
            self.warnings.append(
                f"{prefix}: action is 'add_hash_subpartitions' but table already has subpartitions"
            )

        # Check initial partition value format
        initial_value = target_config.get("initial_partition_value", "")
        if not self._validate_initial_partition_value(initial_value):
            self.errors.append(
                f"{prefix}: initial_partition_value must be Oracle TO_DATE format, got: {initial_value}"
            )

    def _validate_database(self, config: Dict):
        """Validate against actual database"""
        if not self.connection:
            return

        schema = config.get("metadata", {}).get("schema")
        if not schema:
            self.errors.append("No schema specified in metadata")
            return

        cursor = self.connection.cursor()

        for table_config in config.get("tables", []):
            if not table_config.get("enabled"):
                continue

            table_name = table_config.get("table_name")
            prefix = f"Table {schema}.{table_name}"

            # Check table exists
            try:
                cursor.execute(
                    """
                    SELECT COUNT(*) FROM all_tables
                    WHERE owner = :schema AND table_name = :table_name
                """,
                    schema=schema,
                    table_name=table_name,
                )

                exists = cursor.fetchone()[0] > 0
                if not exists:
                    self.errors.append(f"{prefix}: table does not exist")
                    continue
            except Exception as e:
                self.errors.append(f"{prefix}: error checking existence: {e}")
                continue

            # Check partition column exists
            target_config = table_config.get("target_configuration", {})
            partition_col = target_config.get("partition_column")

            if partition_col:
                try:
                    cursor.execute(
                        """
                        SELECT data_type FROM all_tab_columns
                        WHERE owner = :schema AND table_name = :table_name
                          AND column_name = :col_name
                    """,
                        schema=schema,
                        table_name=table_name,
                        col_name=partition_col,
                    )

                    result = cursor.fetchone()
                    if not result:
                        self.errors.append(
                            f"{prefix}: partition column '{partition_col}' does not exist"
                        )
                    else:
                        data_type = result[0]
                        if data_type not in [
                            "DATE",
                            "TIMESTAMP",
                            "TIMESTAMP(6)",
                            "TIMESTAMP(9)",
                        ]:
                            self.warnings.append(
                                f"{prefix}: partition column '{partition_col}' type '{data_type}' may not be suitable for interval partitioning"
                            )
                except Exception as e:
                    self.errors.append(
                        f"{prefix}: error checking partition column: {e}"
                    )

            # Check subpartition column exists
            subpart_col = target_config.get("subpartition_column")

            if subpart_col:
                try:
                    cursor.execute(
                        """
                        SELECT data_type, nullable FROM all_tab_columns
                        WHERE owner = :schema AND table_name = :table_name
                          AND column_name = :col_name
                    """,
                        schema=schema,
                        table_name=table_name,
                        col_name=subpart_col,
                    )

                    result = cursor.fetchone()
                    if not result:
                        self.errors.append(
                            f"{prefix}: subpartition column '{subpart_col}' does not exist"
                        )
                    else:
                        data_type, nullable = result
                        if nullable == "Y":
                            self.warnings.append(
                                f"{prefix}: subpartition column '{subpart_col}' allows NULL (may cause uneven distribution)"
                            )
                except Exception as e:
                    self.errors.append(
                        f"{prefix}: error checking subpartition column: {e}"
                    )

        cursor.close()

    def _check_best_practices(self, config: Dict):
        """Check for best practice violations"""
        for table_config in config.get("tables", []):
            if not table_config.get("enabled"):
                continue

            table_name = table_config.get("table_name")
            prefix = f"Table {table_name}"

            current_state = table_config.get("current_state", {})
            target_config = table_config.get("target_configuration", {})
            migration_settings = table_config.get("migration_settings", {})

            # Check table size vs parallel degree
            size_gb = current_state.get("size_gb", 0)
            parallel = target_config.get("parallel_degree", 1)

            if size_gb > 50 and parallel < 4:
                self.warnings.append(
                    f"{prefix}: Large table ({size_gb:.1f} GB) with low parallel degree ({parallel})"
                )

            if size_gb < 1 and parallel > 2:
                self.warnings.append(
                    f"{prefix}: Small table ({size_gb:.1f} GB) with high parallel degree ({parallel})"
                )

            # Check hash subpartition count vs table size
            subpart_count = target_config.get("subpartition_count", 0)

            if size_gb > 100 and subpart_count < 8:
                self.warnings.append(
                    f"{prefix}: Very large table ({size_gb:.1f} GB) may benefit from more subpartitions (current: {subpart_count}, consider: 16)"
                )

            if size_gb < 1 and subpart_count > 4:
                self.warnings.append(
                    f"{prefix}: Small table ({size_gb:.1f} GB) with many subpartitions ({subpart_count}) may cause overhead"
                )

            # Check LOB handling
            lob_count = current_state.get("lob_count", 0)
            if lob_count > 0:
                self.warnings.append(
                    f"{prefix}: Table has {lob_count} LOB column(s) - ensure LOB storage is properly configured"
                )

            # Check validation setting for large tables
            if size_gb > 50 and not migration_settings.get("validate_data", True):
                self.warnings.append(
                    f"{prefix}: Large table without data validation enabled"
                )

            # Check backup setting
            if not migration_settings.get("backup_old_table", True):
                self.warnings.append(
                    f"{prefix}: Old table backup disabled - no rollback possible"
                )

            # Check interval type vs row count
            row_count = current_state.get("row_count", 0)
            interval_type = target_config.get("interval_type")

            if row_count > 10000000 and interval_type == "MONTH":  # 10M+ rows
                self.warnings.append(
                    f"{prefix}: High row count ({row_count:,}) with MONTH interval - consider DAY or HOUR for better performance"
                )

    def _is_power_of_2(self, n: int) -> bool:
        """Check if number is a power of 2"""
        return n > 0 and (n & (n - 1)) == 0

    def _validate_initial_partition_value(self, value: str) -> bool:
        """Validate Oracle TO_DATE format"""
        if not value:
            return False

        # Pattern: TO_DATE('YYYY-MM-DD', 'YYYY-MM-DD')
        pattern = r"^TO_DATE\('[\d\-/ :]+',\s*'[A-Z\-/ :]+'\)$"
        return bool(re.match(pattern, value, re.IGNORECASE))

    @staticmethod
    def validate_file(
        config_file: str, connection=None, check_database: bool = False
    ) -> bool:
        """
        Validate a configuration file

        Args:
            config_file: Path to JSON config file
            connection: Optional database connection
            check_database: Whether to check against database

        Returns:
            True if valid, False otherwise
        """
        config_path = Path(config_file)
        if not config_path.exists():
            print(f"ERROR: Config file not found: {config_file}")
            return False

        try:
            with open(config_path) as f:
                config = json.load(f)
        except json.JSONDecodeError as e:
            print(f"ERROR: Invalid JSON in {config_file}")
            print(f"  {e}")
            return False

        validator = ConfigValidator(connection)
        is_valid, errors, warnings = validator.validate_config(config, check_database)

        return is_valid


# CLI usage
if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Validate migration configuration file"
    )
    parser.add_argument("config_file", help="Path to migration_config.json")
    parser.add_argument(
        "--check-database",
        "-d",
        action="store_true",
        help="Validate against database (requires connection string)",
    )
    parser.add_argument(
        "--connection",
        "-c",
        help="Oracle connection string (user/pass@host:port/service)",
    )

    args = parser.parse_args()

    connection = None
    if args.check_database and args.connection:
        try:
            import oracledb
        except ImportError:
            print(
                "ERROR: python-oracledb module required for database validation"
                "\nInstall with: pip install oracledb"
            )
            exit(1)

        try:
            connection = oracledb.connect(args.connection)
        except Exception as e:
            print(f"ERROR: Could not connect to database: {e}")
            exit(1)

    is_valid = ConfigValidator.validate_file(
        args.config_file, connection, args.check_database
    )

    if connection:
        connection.close()

    exit(0 if is_valid else 1)
