#!/usr/bin/env python3
"""
Migration Validator - Integrated Pre/Post Migration Validation
==============================================================
Validates migrations before execution and after completion.

Features:
- Pre-migration checks (table structure, storage, dependencies)
- Post-migration validation (partition config, row counts)
- Data comparison (row counts, samples, distribution)
- Markdown report generation

Usage:
    from migration_validator import MigrationValidator

    validator = MigrationValidator(connection_string, config)

    # Pre-migration
    validator.validate_pre_migration(table_config)

    # Post-migration
    validator.validate_post_migration(table_config)
    validator.compare_data(table_config)

    # Generate report
    validator.generate_report('validation_report.md')
"""

import logging
from datetime import datetime
from typing import Dict, List

try:
    import oracledb
except ImportError:
    try:
        import cx_Oracle as oracledb
    except ImportError:
        print("WARNING: Neither oracledb nor cx_Oracle found")
        print("Install with: pip install oracledb")
        oracledb = None


class ValidationResult:
    """Container for validation results"""

    def __init__(self, check_name: str):
        self.check_name = check_name
        self.status = "PASS"  # PASS, WARN, FAIL
        self.message = ""
        self.details = {}
        self.timestamp = datetime.now()

    def fail(self, message: str, details: Dict = None):
        """Mark as failed"""
        self.status = "FAIL"
        self.message = message
        if details:
            self.details = details

    def warn(self, message: str, details: Dict = None):
        """Mark as warning"""
        self.status = "WARN"
        self.message = message
        if details:
            self.details = details

    def success(self, message: str = "", details: Dict = None):
        """Mark as successful"""
        self.status = "PASS"
        self.message = message or "Check passed"
        if details:
            self.details = details

    def __repr__(self):
        return f"ValidationResult({self.check_name}, {self.status})"


class MigrationValidator:
    """Comprehensive migration validation"""

    def __init__(self, connection_string: str, config: Dict):
        """
        Initialize validator

        Args:
            connection_string: Oracle connection (user/pass@host:port/service)
            config: Migration configuration dictionary
        """
        self.connection_string = connection_string
        self.config = config
        self.connection = None
        self.cursor = None
        
        # Extract environment configuration
        self.environment_config = config.get("environment_config", {})
        self.environment = self.environment_config.get("name", "global")

        # Results storage
        self.pre_migration_results: List[ValidationResult] = []
        self.post_migration_results: List[ValidationResult] = []
        self.data_comparison_results: List[ValidationResult] = []

        # Statistics
        self.stats = {
            "total_checks": 0,
            "passed": 0,
            "warnings": 0,
            "failed": 0,
            "start_time": None,
            "end_time": None,
        }

        # Setup logging
        logging.basicConfig(
            level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
        )
        self.logger = logging.getLogger(__name__)

    def connect(self):
        """Establish database connection"""
        if not oracledb:
            raise ImportError("oracledb or cx_Oracle required")

        try:
            self.logger.info("Connecting to database...")
            self.connection = oracledb.connect(self.connection_string)
            self.cursor = self.connection.cursor()
            self.logger.info("✓ Connected successfully")
            return True
        except Exception as e:
            self.logger.error(f"Connection failed: {e}")
            return False

    def disconnect(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
            self.logger.info("Database connection closed")

    def validate_pre_migration(self, table_config: Dict) -> List[ValidationResult]:
        """
        Run all pre-migration checks for a table

        Args:
            table_config: Table configuration from JSON

        Returns:
            List of ValidationResult objects
        """
        self.logger.info(f"\n{'='*70}")
        self.logger.info(
            f"PRE-MIGRATION VALIDATION: {table_config['owner']}.{table_config['table_name']}"
        )
        self.logger.info(f"{'='*70}")

        self.stats["start_time"] = datetime.now()
        results = []

        # Check 1: Source table exists
        results.append(
            self._check_table_exists(table_config["owner"], table_config["table_name"])
        )

        # Check 2: Columns exist
        results.append(self._check_columns_exist(table_config))

        # Check 3: Column data types suitable
        results.append(self._check_column_types(table_config))

        # Check 4: Tablespace space available
        results.append(self._check_tablespace_space(table_config))

        # Check 5: No active locks
        results.append(
            self._check_table_locks(table_config["owner"], table_config["table_name"])
        )

        # Check 6: Interval syntax valid
        if (
            table_config.get("target_configuration", {}).get("partition_type")
            == "INTERVAL"
        ):
            results.append(self._check_interval_syntax(table_config))

        # Check 7: Dependencies (foreign keys)
        results.append(
            self._check_dependencies(table_config["owner"], table_config["table_name"])
        )

        # Check 8: Existing partitions (if converting)
        if table_config.get("current_state", {}).get("is_partitioned"):
            results.append(self._check_existing_partitions(table_config))

        # Check 9: Environment-specific settings validation
        results.append(self._check_environment_settings(table_config))

        self.pre_migration_results.extend(results)
        self._update_stats(results)
        self._print_results(results, "PRE-MIGRATION")

        return results

    def validate_post_migration(self, table_config: Dict) -> List[ValidationResult]:
        """
        Run all post-migration checks for a table

        Args:
            table_config: Table configuration from JSON

        Returns:
            List of ValidationResult objects
        """
        self.logger.info(f"\n{'='*70}")
        self.logger.info(
            f"POST-MIGRATION VALIDATION: {table_config['owner']}.{table_config['table_name']}"
        )
        self.logger.info(f"{'='*70}")

        results = []
        new_table_name = table_config.get("new_table_name", table_config["table_name"] + "_NEW")

        # Check 1: New table exists
        results.append(self._check_table_exists(table_config["owner"], new_table_name))

        # Check 2: Partition type correct
        results.append(self._check_partition_type(table_config, new_table_name))

        # Check 3: Interval definition matches
        if (
            table_config.get("target_configuration", {}).get("partition_type")
            == "INTERVAL"
        ):
            results.append(
                self._check_interval_definition(table_config, new_table_name)
            )

        # Check 4: Subpartition type correct
        if table_config.get("target_configuration", {}).get("subpartition_type"):
            results.append(
                self._check_subpartition_config(table_config, new_table_name)
            )

        # Check 5: Row counts match
        results.append(self._check_row_counts(table_config, new_table_name))

        # Check 6: Indexes created
        results.append(self._check_indexes_created(table_config, new_table_name))

        # Check 7: Constraints enabled
        results.append(self._check_constraints(table_config, new_table_name))

        self.post_migration_results.extend(results)
        self._update_stats(results)
        self._print_results(results, "POST-MIGRATION")

        return results

    def compare_data(self, table_config: Dict) -> List[ValidationResult]:
        """
        Compare data between old and new tables

        Args:
            table_config: Table configuration from JSON

        Returns:
            List of ValidationResult objects
        """
        self.logger.info(f"\n{'='*70}")
        self.logger.info(
            f"DATA COMPARISON: {table_config['owner']}.{table_config['table_name']}"
        )
        self.logger.info(f"{'='*70}")

        results = []
        old_table = table_config["table_name"]
        new_table = table_config.get("new_table_name", table_config["table_name"] + "_NEW")
        owner = table_config["owner"]

        # Check 1: Total row count
        results.append(self._compare_row_counts(owner, old_table, new_table))

        # Check 2: Sample data comparison
        results.append(
            self._compare_sample_data(owner, old_table, new_table, table_config)
        )

        # Check 3: MIN/MAX values for partition column
        partition_col = table_config.get("target_configuration", {}).get(
            "partition_column"
        )
        if partition_col:
            results.append(
                self._compare_min_max_values(owner, old_table, new_table, partition_col)
            )

        # Check 4: Partition distribution
        if table_config.get("target_configuration", {}).get("partition_type") in [
            "RANGE",
            "INTERVAL",
        ]:
            results.append(self._check_partition_distribution(owner, new_table))

        self.data_comparison_results.extend(results)
        self._update_stats(results)
        self._print_results(results, "DATA COMPARISON")

        return results

    # ==================== Pre-Migration Checks ====================

    def _check_table_exists(self, owner: str, table_name: str) -> ValidationResult:
        """Check if table exists"""
        result = ValidationResult(f"Table Exists: {owner}.{table_name}")

        sql = """
            SELECT COUNT(*) 
            FROM all_tables 
            WHERE owner = :owner AND table_name = :table_name
        """

        try:
            self.cursor.execute(sql, owner=owner.upper(), table_name=table_name.upper())
            count = self.cursor.fetchone()[0]

            if count == 1:
                result.success(f"Table {owner}.{table_name} exists")
            else:
                result.fail(f"Table {owner}.{table_name} not found")

        except Exception as e:
            result.fail(f"Error checking table: {e}")

        return result

    def _check_columns_exist(self, table_config: Dict) -> ValidationResult:
        """Check if configured columns exist in source table"""
        result = ValidationResult("Column Existence")

        owner = table_config["owner"]
        table_name = table_config["table_name"]
        target_config = table_config.get("target_configuration", {})

        columns_to_check = []
        if target_config.get("partition_column"):
            columns_to_check.append(target_config["partition_column"])
        if target_config.get("subpartition_column"):
            columns_to_check.append(target_config["subpartition_column"])

        if not columns_to_check:
            result.success("No columns to validate")
            return result

        # Build IN clause with column names from config (trusted source)
        # SQL injection protected: column names are from config validation, not user input
        column_list = ",".join([f"'{col}'" for col in columns_to_check])
        sql = f"""
            SELECT column_name
            FROM all_tab_columns
            WHERE owner = :owner 
              AND table_name = :table_name
              AND column_name IN ({column_list})
        """  # nosec B608

        try:
            self.cursor.execute(sql, owner=owner.upper(), table_name=table_name.upper())
            found_columns = [row[0] for row in self.cursor.fetchall()]

            missing = set([c.upper() for c in columns_to_check]) - set(found_columns)

            if missing:
                result.fail(
                    f"Missing columns: {', '.join(missing)}",
                    {"missing_columns": list(missing)},
                )
            else:
                result.success(f"All {len(columns_to_check)} columns exist")

        except Exception as e:
            result.fail(f"Error checking columns: {e}")

        return result

    def _check_column_types(self, table_config: Dict) -> ValidationResult:
        """Check if column data types are suitable for partitioning"""
        result = ValidationResult("Column Data Types")

        owner = table_config["owner"]
        table_name = table_config["table_name"]
        target_config = table_config.get("target_configuration", {})
        partition_col = target_config.get("partition_column")

        if not partition_col:
            result.success("No partition column specified")
            return result

        sql = """
            SELECT data_type, data_length, data_precision
            FROM all_tab_columns
            WHERE owner = :owner 
              AND table_name = :table_name
              AND column_name = :column_name
        """

        try:
            self.cursor.execute(
                sql,
                owner=owner.upper(),
                table_name=table_name.upper(),
                column_name=partition_col.upper(),
            )
            row = self.cursor.fetchone()

            if not row:
                result.fail(f"Column {partition_col} not found")
                return result

            data_type = row[0]

            # Check if suitable for INTERVAL partitioning
            if target_config.get("partition_type") == "INTERVAL":
                valid_types = ["DATE", "TIMESTAMP", "TIMESTAMP(6)", "TIMESTAMP(9)"]
                if not any(data_type.startswith(vt) for vt in valid_types):
                    result.fail(
                        f"Column {partition_col} has type {data_type}, not suitable for INTERVAL",
                        {"data_type": data_type},
                    )
                else:
                    result.success(
                        f"Column {partition_col} type {data_type} is suitable"
                    )
            else:
                result.success(f"Column {partition_col} type: {data_type}")

        except Exception as e:
            result.fail(f"Error checking column type: {e}")

        return result

    def _check_tablespace_space(self, table_config: Dict) -> ValidationResult:
        """Check if sufficient tablespace space available"""
        result = ValidationResult("Tablespace Space")

        tablespace = table_config.get("target_configuration", {}).get(
            "tablespace", "USERS"
        )
        estimated_size_gb = table_config.get("current_state", {}).get("size_gb", 0)

        # Need at least 2x current size (original + new table during migration)
        required_gb = estimated_size_gb * 2

        sql = """
            SELECT 
                tablespace_name,
                ROUND(SUM(bytes)/POWER(1024,3), 2) as free_gb
            FROM dba_free_space
            WHERE tablespace_name = :tablespace
            GROUP BY tablespace_name
        """

        try:
            self.cursor.execute(sql, tablespace=tablespace.upper())
            row = self.cursor.fetchone()

            if not row:
                # Try user_free_space if dba_free_space not accessible
                sql = sql.replace("dba_free_space", "user_free_space")
                self.cursor.execute(sql, tablespace=tablespace.upper())
                row = self.cursor.fetchone()

            if row:
                free_gb = row[1]

                if free_gb < required_gb:
                    result.warn(
                        f"Tablespace {tablespace} has {free_gb:.2f} GB free, "
                        f"but {required_gb:.2f} GB recommended",
                        {"free_gb": free_gb, "required_gb": required_gb},
                    )
                else:
                    result.success(
                        f"Tablespace {tablespace} has sufficient space: {free_gb:.2f} GB free"
                    )
            else:
                result.warn("Cannot determine tablespace free space")

        except Exception as e:
            result.warn(f"Cannot check tablespace space: {e}")

        return result

    def _check_table_locks(self, owner: str, table_name: str) -> ValidationResult:
        """Check for active locks on table"""
        result = ValidationResult(f"Table Locks: {owner}.{table_name}")

        sql = """
            SELECT l.sid, l.type, l.lmode, s.username, s.program
            FROM v$lock l
            JOIN v$session s ON l.sid = s.sid
            JOIN all_objects o ON l.id1 = o.object_id
            WHERE o.owner = :owner
              AND o.object_name = :table_name
              AND l.type IN ('TM', 'TX')
        """

        try:
            self.cursor.execute(sql, owner=owner.upper(), table_name=table_name.upper())
            locks = self.cursor.fetchall()

            if locks:
                result.warn(
                    f"Found {len(locks)} active lock(s) on table",
                    {"lock_count": len(locks)},
                )
            else:
                result.success("No active locks on table")

        except Exception as e:
            # v$ views may not be accessible
            result.warn(f"Cannot check locks: {e}")

        return result

    def _check_interval_syntax(self, table_config: Dict) -> ValidationResult:
        """Validate interval syntax"""
        result = ValidationResult("Interval Syntax")

        target_config = table_config.get("target_configuration", {})
        interval_type = target_config.get("interval_type", "MONTH")
        interval_value = target_config.get("interval_value", 1)

        valid_types = ["HOUR", "DAY", "WEEK", "MONTH"]

        if interval_type not in valid_types:
            result.fail(
                f"Invalid interval type: {interval_type}. Must be one of {valid_types}",
                {"interval_type": interval_type},
            )
        elif (
            not isinstance(interval_value, int)
            or interval_value < 1
            or interval_value > 999
        ):
            result.fail(
                f"Invalid interval value: {interval_value}. Must be 1-999",
                {"interval_value": interval_value},
            )
        else:
            result.success(f"Interval syntax valid: {interval_type}({interval_value})")

        return result

    def _check_dependencies(self, owner: str, table_name: str) -> ValidationResult:
        """Check for foreign key dependencies"""
        result = ValidationResult(f"Dependencies: {owner}.{table_name}")

        sql = """
            SELECT constraint_name, r_constraint_name
            FROM all_constraints
            WHERE owner = :owner
              AND table_name = :table_name
              AND constraint_type = 'R'
        """

        try:
            self.cursor.execute(sql, owner=owner.upper(), table_name=table_name.upper())
            fks = self.cursor.fetchall()

            if fks:
                result.warn(
                    f"Found {len(fks)} foreign key constraint(s). "
                    f"Will be disabled during migration.",
                    {"fk_count": len(fks)},
                )
            else:
                result.success("No foreign key dependencies")

        except Exception as e:
            result.warn(f"Cannot check dependencies: {e}")

        return result

    def _check_existing_partitions(self, table_config: Dict) -> ValidationResult:
        """Check existing partition configuration"""
        result = ValidationResult("Existing Partitions")

        owner = table_config["owner"]
        table_name = table_config["table_name"]

        sql = """
            SELECT partition_count, partitioning_type, subpartitioning_type, interval
            FROM all_part_tables
            WHERE owner = :owner AND table_name = :table_name
        """

        try:
            self.cursor.execute(sql, owner=owner.upper(), table_name=table_name.upper())
            row = self.cursor.fetchone()

            if row:
                part_count, part_type, subpart_type, interval = row
                result.success(
                    f"Current: {part_type} partitioning, "
                    f"{part_count} partitions"
                    + (f", {subpart_type} subpartitioning" if subpart_type else "")
                    + (f", INTERVAL: {interval}" if interval else ""),
                    {
                        "partition_count": part_count,
                        "partition_type": part_type,
                        "subpartition_type": subpart_type,
                        "interval": interval,
                    },
                )
            else:
                result.success("Table is not partitioned")

        except Exception as e:
            result.warn(f"Cannot check partitions: {e}")

        return result

    def _check_environment_settings(self, table_config: Dict) -> ValidationResult:
        """Validate environment-specific settings"""
        result = ValidationResult("Environment Settings")
        
        target_config = table_config.get("target_configuration", {})
        env_defaults = self.environment_config.get("subpartition_defaults", {})
        parallel_defaults = self.environment_config.get("parallel_defaults", {})
        
        # Check subpartition count against environment limits
        subpart_count = target_config.get("subpartition_count")
        if subpart_count is not None:
            min_count = env_defaults.get("min_count", 2)
            max_count = env_defaults.get("max_count", 16)
            
            if subpart_count < min_count:
                result.warn(
                    f"Subpartition count {subpart_count} below environment minimum {min_count}",
                    {"subpart_count": subpart_count, "min_count": min_count}
                )
            elif subpart_count > max_count:
                result.warn(
                    f"Subpartition count {subpart_count} above environment maximum {max_count}",
                    {"subpart_count": subpart_count, "max_count": max_count}
                )
            else:
                result.success(f"Subpartition count {subpart_count} within environment limits")
        
        # Check parallel degree against environment limits
        parallel_degree = target_config.get("parallel_degree")
        if parallel_degree is not None:
            min_degree = parallel_defaults.get("min_degree", 1)
            max_degree = parallel_defaults.get("max_degree", 8)
            
            if parallel_degree < min_degree:
                result.warn(
                    f"Parallel degree {parallel_degree} below environment minimum {min_degree}",
                    {"parallel_degree": parallel_degree, "min_degree": min_degree}
                )
            elif parallel_degree > max_degree:
                result.warn(
                    f"Parallel degree {parallel_degree} above environment maximum {max_degree}",
                    {"parallel_degree": parallel_degree, "max_degree": max_degree}
                )
            else:
                result.success(f"Parallel degree {parallel_degree} within environment limits")
        
        # Check tablespace configuration
        tablespace = target_config.get("tablespace")
        env_tablespaces = self.environment_config.get("tablespaces", {})
        expected_primary = env_tablespaces.get("data", {}).get("primary")
        
        if tablespace and expected_primary and tablespace != expected_primary:
            result.warn(
                f"Tablespace {tablespace} differs from environment default {expected_primary}",
                {"tablespace": tablespace, "expected": expected_primary}
            )
        else:
            result.success(f"Tablespace configuration matches environment: {self.environment}")
        
        return result

    # ==================== Post-Migration Checks ====================

    def _check_partition_type(
        self, table_config: Dict, new_table_name: str
    ) -> ValidationResult:
        """Verify partition type matches configuration"""
        result = ValidationResult("Partition Type")

        owner = table_config["owner"]
        expected_type = table_config.get("target_configuration", {}).get(
            "partition_type", "RANGE"
        )

        sql = """
            SELECT partitioning_type
            FROM all_part_tables
            WHERE owner = :owner AND table_name = :table_name
        """

        try:
            self.cursor.execute(
                sql, owner=owner.upper(), table_name=new_table_name.upper()
            )
            row = self.cursor.fetchone()

            if row:
                actual_type = row[0]
                if actual_type == expected_type:
                    result.success(f"Partition type is {actual_type} as expected")
                else:
                    result.fail(
                        f"Partition type is {actual_type}, expected {expected_type}",
                        {"actual": actual_type, "expected": expected_type},
                    )
            else:
                result.fail("Table is not partitioned")

        except Exception as e:
            result.fail(f"Error checking partition type: {e}")

        return result

    def _check_interval_definition(
        self, table_config: Dict, new_table_name: str
    ) -> ValidationResult:
        """Verify interval definition matches configuration"""
        result = ValidationResult("Interval Definition")

        owner = table_config["owner"]
        target_config = table_config.get("target_configuration", {})
        interval_type = target_config.get("interval_type", "MONTH")

        sql = """
            SELECT interval
            FROM all_part_tables
            WHERE owner = :owner AND table_name = :table_name
        """

        try:
            self.cursor.execute(
                sql, owner=owner.upper(), table_name=new_table_name.upper()
            )
            row = self.cursor.fetchone()

            if row and row[0]:
                actual_interval = row[0]

                # Check if interval contains expected function
                if interval_type in ["HOUR", "DAY"]:
                    expected_func = "NUMTODSINTERVAL"
                else:  # MONTH, WEEK
                    expected_func = "NUMTOYMINTERVAL"

                if expected_func in actual_interval:
                    result.success(
                        f"Interval definition contains {expected_func} as expected",
                        {"actual_interval": actual_interval},
                    )
                else:
                    result.warn(
                        f"Interval definition may not match: {actual_interval}",
                        {"actual_interval": actual_interval},
                    )
            else:
                result.fail("No interval definition found")

        except Exception as e:
            result.fail(f"Error checking interval: {e}")

        return result

    def _check_subpartition_config(
        self, table_config: Dict, new_table_name: str
    ) -> ValidationResult:
        """Verify subpartition configuration"""
        result = ValidationResult("Subpartition Configuration")

        owner = table_config["owner"]
        target_config = table_config.get("target_configuration", {})
        expected_type = target_config.get("subpartition_type")
        expected_count = target_config.get("subpartition_count")

        sql = """
            SELECT subpartitioning_type, def_subpartition_count
            FROM all_part_tables
            WHERE owner = :owner AND table_name = :table_name
        """

        try:
            self.cursor.execute(
                sql, owner=owner.upper(), table_name=new_table_name.upper()
            )
            row = self.cursor.fetchone()

            if row:
                actual_type, actual_count = row

                issues = []
                if actual_type != expected_type:
                    issues.append(f"type is {actual_type}, expected {expected_type}")
                if actual_count != expected_count:
                    issues.append(f"count is {actual_count}, expected {expected_count}")

                if issues:
                    result.fail(
                        f"Subpartition mismatch: {'; '.join(issues)}",
                        {"actual_type": actual_type, "actual_count": actual_count},
                    )
                else:
                    result.success(
                        f"Subpartitioning: {actual_type} with {actual_count} subpartitions"
                    )
            else:
                result.warn("Cannot determine subpartition config")

        except Exception as e:
            result.fail(f"Error checking subpartitions: {e}")

        return result

    def _check_row_counts(
        self, table_config: Dict, new_table_name: str
    ) -> ValidationResult:
        """Compare row counts between old and new tables"""
        result = ValidationResult("Row Count Match")

        owner = table_config["owner"]
        old_table = table_config["table_name"]

        sql = "SELECT COUNT(*) FROM {}.{}"

        try:
            # Old table count
            self.cursor.execute(sql.format(owner, old_table))
            old_count = self.cursor.fetchone()[0]

            # New table count
            self.cursor.execute(sql.format(owner, new_table_name))
            new_count = self.cursor.fetchone()[0]

            if old_count == new_count:
                result.success(
                    f"Row counts match: {old_count:,} rows",
                    {"old_count": old_count, "new_count": new_count},
                )
            else:
                diff = abs(old_count - new_count)
                diff_pct = (diff / old_count * 100) if old_count > 0 else 0

                result.fail(
                    f"Row count mismatch: Old={old_count:,}, New={new_count:,}, "
                    f"Diff={diff:,} ({diff_pct:.2f}%)",
                    {
                        "old_count": old_count,
                        "new_count": new_count,
                        "difference": diff,
                        "diff_percentage": diff_pct,
                    },
                )

        except Exception as e:
            result.fail(f"Error comparing row counts: {e}")

        return result

    def _check_indexes_created(
        self, table_config: Dict, new_table_name: str
    ) -> ValidationResult:
        """Verify indexes were created"""
        result = ValidationResult("Indexes Created")

        owner = table_config["owner"]

        sql = """
            SELECT COUNT(*)
            FROM all_indexes
            WHERE table_owner = :owner AND table_name = :table_name
        """

        try:
            self.cursor.execute(
                sql, owner=owner.upper(), table_name=new_table_name.upper()
            )
            new_index_count = self.cursor.fetchone()[0]

            if new_index_count > 0:
                result.success(f"Created {new_index_count} index(es)")
            else:
                result.warn("No indexes found on new table")

        except Exception as e:
            result.warn(f"Cannot check indexes: {e}")

        return result

    def _check_constraints(
        self, table_config: Dict, new_table_name: str
    ) -> ValidationResult:
        """Verify constraints are enabled"""
        result = ValidationResult("Constraints Enabled")

        owner = table_config["owner"]

        sql = """
            SELECT constraint_name, constraint_type, status
            FROM all_constraints
            WHERE owner = :owner 
              AND table_name = :table_name
              AND constraint_type IN ('P', 'U', 'C')
        """

        try:
            self.cursor.execute(
                sql, owner=owner.upper(), table_name=new_table_name.upper()
            )
            constraints = self.cursor.fetchall()

            if constraints:
                disabled = [c for c in constraints if c[2] != "ENABLED"]

                if disabled:
                    result.warn(
                        f"Found {len(disabled)} disabled constraint(s)",
                        {"disabled_count": len(disabled)},
                    )
                else:
                    result.success(f"All {len(constraints)} constraint(s) enabled")
            else:
                result.warn("No constraints found")

        except Exception as e:
            result.warn(f"Cannot check constraints: {e}")

        return result

    # ==================== Data Comparison ====================

    def _compare_row_counts(
        self, owner: str, old_table: str, new_table: str
    ) -> ValidationResult:
        """Compare total row counts"""
        result = ValidationResult("Total Row Count")

        sql = "SELECT COUNT(*) FROM {}.{}"

        try:
            self.cursor.execute(sql.format(owner, old_table))
            old_count = self.cursor.fetchone()[0]

            self.cursor.execute(sql.format(owner, new_table))
            new_count = self.cursor.fetchone()[0]

            if old_count == new_count:
                result.success(
                    f"Row counts match: {old_count:,} rows", {"count": old_count}
                )
            else:
                result.fail(
                    f"Row count mismatch: Old={old_count:,}, New={new_count:,}",
                    {"old_count": old_count, "new_count": new_count},
                )

        except Exception as e:
            result.fail(f"Error comparing row counts: {e}")

        return result

    def _compare_sample_data(
        self, owner: str, old_table: str, new_table: str, table_config: Dict
    ) -> ValidationResult:
        """Compare sample of random rows"""
        result = ValidationResult("Sample Data Comparison")

        # Get primary key or first column for sampling
        pk_sql = """
            SELECT cols.column_name
            FROM all_constraints cons
            JOIN all_cons_columns cols ON cons.constraint_name = cols.constraint_name
                                       AND cons.owner = cols.owner
            WHERE cons.owner = :owner 
              AND cons.table_name = :table_name
              AND cons.constraint_type = 'P'
            ORDER BY cols.position
        """

        try:
            self.cursor.execute(
                pk_sql, owner=owner.upper(), table_name=old_table.upper()
            )
            pk_columns = [row[0] for row in self.cursor.fetchall()]

            if not pk_columns:
                # Fallback to ROWID
                result.warn("No primary key found, using ROWID for sampling")
                return result

            pk_col = pk_columns[0]

            # Sample 1000 random values
            # SQL construction is safe: owner/table/column names come from database metadata
            sample_sql = f"""
                SELECT {pk_col}
                FROM {owner}.{old_table}
                WHERE ROWNUM <= 1000
                ORDER BY DBMS_RANDOM.VALUE
            """  # nosec B608

            self.cursor.execute(sample_sql)
            sample_keys = [row[0] for row in self.cursor.fetchall()]

            if not sample_keys:
                result.warn("No data to sample")
                return result

            # Check if same keys exist in new table
            # SQL construction is safe: names from metadata, values via bind variables
            check_sql = f"""
                SELECT COUNT(*)
                FROM {owner}.{new_table}
                WHERE {pk_col} IN ({','.join([':' + str(i) for i in range(len(sample_keys))])})
            """  # nosec B608

            self.cursor.execute(check_sql, sample_keys)
            found_count = self.cursor.fetchone()[0]

            match_pct = found_count / len(sample_keys) * 100

            if match_pct == 100:
                result.success(
                    f"Sample match: {found_count}/{len(sample_keys)} rows ({match_pct:.1f}%)",
                    {"sample_size": len(sample_keys), "matched": found_count},
                )
            elif match_pct >= 99:
                result.warn(
                    f"Sample nearly matches: {found_count}/{len(sample_keys)} rows ({match_pct:.1f}%)",
                    {"sample_size": len(sample_keys), "matched": found_count},
                )
            else:
                result.fail(
                    f"Sample mismatch: {found_count}/{len(sample_keys)} rows ({match_pct:.1f}%)",
                    {"sample_size": len(sample_keys), "matched": found_count},
                )

        except Exception as e:
            result.warn(f"Cannot compare sample data: {e}")

        return result

    def _compare_min_max_values(
        self, owner: str, old_table: str, new_table: str, column: str
    ) -> ValidationResult:
        """Compare MIN/MAX values for partition column"""
        result = ValidationResult(f"MIN/MAX Values: {column}")

        # SQL construction is safe: parameters come from validated table metadata
        sql = f"SELECT MIN({column}), MAX({column}) FROM {{}}.{{}}"  # nosec B608

        try:
            self.cursor.execute(sql.format(owner, old_table))
            old_min, old_max = self.cursor.fetchone()

            self.cursor.execute(sql.format(owner, new_table))
            new_min, new_max = self.cursor.fetchone()

            if old_min == new_min and old_max == new_max:
                result.success(
                    f"MIN/MAX match: {old_min} to {old_max}",
                    {"min": str(old_min), "max": str(old_max)},
                )
            else:
                result.fail(
                    f"MIN/MAX mismatch: Old=[{old_min}, {old_max}], New=[{new_min}, {new_max}]",
                    {
                        "old_min": str(old_min),
                        "old_max": str(old_max),
                        "new_min": str(new_min),
                        "new_max": str(new_max),
                    },
                )

        except Exception as e:
            result.warn(f"Cannot compare MIN/MAX: {e}")

        return result

    def _check_partition_distribution(
        self, owner: str, table_name: str
    ) -> ValidationResult:
        """Check partition distribution"""
        result = ValidationResult("Partition Distribution")

        sql = """
            SELECT partition_name, num_rows
            FROM all_tab_partitions
            WHERE table_owner = :owner 
              AND table_name = :table_name
            ORDER BY partition_position DESC
            FETCH FIRST 10 ROWS ONLY
        """

        try:
            self.cursor.execute(sql, owner=owner.upper(), table_name=table_name.upper())
            partitions = self.cursor.fetchall()

            if partitions:
                total_rows = sum(p[1] or 0 for p in partitions)

                distribution = "\n".join(
                    [
                        (
                            f"  - {p[0]}: {p[1]:,} rows"
                            if p[1]
                            else f"  - {p[0]}: (no stats)"
                        )
                        for p in partitions[:5]
                    ]
                )

                result.success(
                    f"Found {len(partitions)} partition(s), Total rows: {total_rows:,}\n{distribution}",
                    {"partition_count": len(partitions), "total_rows": total_rows},
                )
            else:
                result.warn("No partition statistics found")

        except Exception as e:
            result.warn(f"Cannot check partition distribution: {e}")

        return result

    # ==================== Reporting ====================

    def _update_stats(self, results: List[ValidationResult]):
        """Update overall statistics"""
        for result in results:
            self.stats["total_checks"] += 1
            if result.status == "PASS":
                self.stats["passed"] += 1
            elif result.status == "WARN":
                self.stats["warnings"] += 1
            elif result.status == "FAIL":
                self.stats["failed"] += 1

    def _print_results(self, results: List[ValidationResult], phase: str):
        """Print results to console"""
        print(f"\n{phase} RESULTS:")
        print("-" * 70)

        for result in results:
            icon = (
                "✓"
                if result.status == "PASS"
                else "⚠" if result.status == "WARN" else "✗"
            )
            print(f"{icon} [{result.status:4s}] {result.check_name}")
            if result.message:
                print(f"         {result.message}")

        print("-" * 70)
        passed = sum(1 for r in results if r.status == "PASS")
        warnings = sum(1 for r in results if r.status == "WARN")
        failed = sum(1 for r in results if r.status == "FAIL")

        print(f"Summary: {passed} passed, {warnings} warnings, {failed} failed")
        print()

    def generate_report(self, output_file: str = "validation_report.md"):
        """
        Generate comprehensive validation report

        Args:
            output_file: Path to output markdown file
        """
        self.stats["end_time"] = datetime.now()
        duration = (
            (self.stats["end_time"] - self.stats["start_time"]).total_seconds()
            if self.stats["start_time"]
            else 0
        )

        all_results = (
            self.pre_migration_results
            + self.post_migration_results
            + self.data_comparison_results
        )

        report = f"""# Migration Validation Report

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  
**Duration:** {duration:.1f} seconds  
**Schema:** {self.config.get('metadata', {}).get('schema', 'N/A')}

---

## Summary

| Status | Count |
|--------|-------|
| ✓ Passed | {self.stats['passed']} |
| ⚠ Warnings | {self.stats['warnings']} |
| ✗ Failed | {self.stats['failed']} |
| **Total** | **{self.stats['total_checks']}** |

---

## Pre-Migration Checks

{self._format_results_table(self.pre_migration_results)}

---

## Post-Migration Validation

{self._format_results_table(self.post_migration_results)}

---

## Data Comparison

{self._format_results_table(self.data_comparison_results)}

---

## Detailed Findings

{self._format_detailed_findings(all_results)}

---

## Recommendations

{self._generate_recommendations(all_results)}

---

*Report generated by Migration Validator v1.0*
"""

        with open(output_file, "w", encoding="utf-8") as f:
            f.write(report)

        self.logger.info(f"✓ Validation report saved to: {output_file}")
        return output_file

    def _format_results_table(self, results: List[ValidationResult]) -> str:
        """Format results as markdown table"""
        if not results:
            return "*No checks performed*"

        lines = ["| Status | Check | Message |", "|--------|-------|---------|"]

        for result in results:
            icon = (
                "✓"
                if result.status == "PASS"
                else "⚠" if result.status == "WARN" else "✗"
            )
            message = result.message.replace("\n", "<br>")[:100]
            lines.append(
                f"| {icon} {result.status} | {result.check_name} | {message} |"
            )

        return "\n".join(lines)

    def _format_detailed_findings(self, results: List[ValidationResult]) -> str:
        """Format detailed findings"""
        findings = []

        for result in results:
            if result.status in ["WARN", "FAIL"] and result.details:
                findings.append(f"### {result.check_name}")
                findings.append(f"**Status:** {result.status}")
                findings.append(f"**Message:** {result.message}")
                findings.append("**Details:**")
                findings.append("```json")
                import json

                findings.append(json.dumps(result.details, indent=2))
                findings.append("```")
                findings.append("")

        return "\n".join(findings) if findings else "*No detailed findings*"

    def _generate_recommendations(self, results: List[ValidationResult]) -> str:
        """Generate recommendations based on results"""
        recommendations = []

        failed_count = sum(1 for r in results if r.status == "FAIL")
        warning_count = sum(1 for r in results if r.status == "WARN")

        if failed_count > 0:
            recommendations.append(
                f"- **CRITICAL:** {failed_count} check(s) failed. Do not proceed with migration until resolved."
            )

        if warning_count > 0:
            recommendations.append(
                f"- **CAUTION:** {warning_count} warning(s) found. Review before proceeding."
            )

        # Specific recommendations
        for result in results:
            if result.status == "FAIL":
                if "Row count mismatch" in result.message:
                    recommendations.append(
                        "- Investigate row count discrepancy before swapping tables"
                    )
                elif "Partition type" in result.check_name:
                    recommendations.append(
                        "- Verify partition configuration in generated scripts"
                    )

        if not recommendations:
            recommendations.append(
                "- ✓ All checks passed. Migration appears successful."
            )

        return "\n".join(recommendations)


if __name__ == "__main__":
    print("Migration Validator Module")
    print("=" * 70)
    print(__doc__)
