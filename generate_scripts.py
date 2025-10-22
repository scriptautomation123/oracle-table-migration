#!/usr/bin/env python3
"""
Migration Script Generator - JSON-Driven with Jinja2
====================================================
Generates Oracle table migration scripts from JSON configuration.

Features:
- Discovery mode: Scan schema and generate migration_config.json
- Generation mode: Read JSON config and generate migration scripts
- Validation mode: Validate configuration without generating
- Supports all partition scenarios (non-partitioned, interval, interval-hash)
- Jinja2 templates with powerful conditional logic
- HOUR/DAY/WEEK/MONTH interval support

Usage:
    # Discovery mode - scan schema
    python3 generate_scripts.py --discover --schema MYSCHEMA --connection "user/pass@host:port/service"

    # Generation mode - create scripts from config
    python3 generate_scripts.py --config migration_config.json

        # Validation options
    parser.add_argument('--validate-only', action='store_true',
                       help='Only validate configuration (do not generate scripts)')
    parser.add_argument('--validate-pre', action='store_true',
                       help='Run pre-migration validation checks')
    parser.add_argument('--validate-post', action='store_true',
                       help='Run post-migration validation checks')
    parser.add_argument('--compare-data', action='store_true',
                       help='Compare data between old and new tables')
    parser.add_argument('--validation-report', type=str, metavar='FILE',
                       help='Generate comprehensive validation report (default: validation_report.md)')

    # Other options

    # Validation with database check
    python3 generate_scripts.py --config migration_config.json --validate-only --check-database --connection "..."

Requirements:
    pip install oracledb jinja2 jsonschema
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

# Jinja2 for templating
try:
    from jinja2 import Environment, FileSystemLoader, select_autoescape
except ImportError:
    print("ERROR: jinja2 module not found!")
    print("Install with: pip install jinja2")
    sys.exit(1)

# Oracle connection
try:
    import oracledb

    # Enable thick mode for TNS/OID support
    try:
        oracledb.init_oracle_client()
        print("Oracle thick mode enabled (Instant Client)")
    except Exception as e:
        print(f"WARNING: Could not initialize Oracle Client (thick mode): {e}")
        print("Falling back to thin mode - TNS names and OID may not work")
except ImportError:
    try:
        import cx_Oracle as oracledb
    except ImportError:
        print("WARNING: Neither oracledb nor cx_Oracle found")
        print("Discovery mode will not work without Oracle driver")
        print("Install with: pip install oracledb")
        oracledb = None

from lib.config_validator import ConfigValidator

# Import our modules
from lib.discovery_queries import TableDiscovery
from lib.migration_validator import MigrationValidator
from lib.template_filters import register_custom_filters


class MigrationScriptGenerator:
    """
    Main generator class that orchestrates:
    - Discovery (scan database, generate JSON)
    - Validation (validate JSON config)
    - Generation (create migration scripts from JSON + Jinja2 templates)
    """

    def __init__(
        self,
        connection_string: Optional[str] = None,
        config_file: Optional[str] = None,
        template_dir: str = "templates",
        output_dir: str = "output",
    ):
        """
        Initialize generator

        Args:
            connection_string: Oracle connection (user/pass@host:port/service)
            config_file: Path to migration_config.json
            template_dir: Directory containing Jinja2 templates
            output_dir: Output directory for generated scripts
        """
        self.connection_string = connection_string
        self.config_file = config_file
        self.template_dir = Path(template_dir)
        self.output_dir = Path(output_dir)
        self.connection = None
        self.config = None

        # Setup Jinja2 environment
        self.jinja_env = Environment(
            loader=FileSystemLoader(str(self.template_dir), encoding='utf-8'),
            autoescape=select_autoescape(),
            trim_blocks=True,
            lstrip_blocks=True,
            keep_trailing_newline=True,
        )

        # Register custom filters
        register_custom_filters(self.jinja_env)

        # Statistics
        self.stats = {
            "tables_discovered": 0,
            "tables_enabled": 0,
            "tables_processed": 0,
            "scripts_generated": 0,
            "errors": 0,
        }

    def connect_database(self) -> bool:
        """
        Establish database connection

        Returns:
            True if successful, False otherwise
        """
        if not oracledb:
            print("ERROR: Oracle driver not available")
            return False

        if not self.connection_string:
            print("ERROR: No connection string provided")
            return False

        try:
            print("Connecting to database...")
            self.connection = oracledb.connect(self.connection_string)
            print("✓ Connected successfully")
            return True
        except Exception as e:
            print(f"✗ Connection failed: {e}")
            return False

    def disconnect_database(self):
        """Close database connection"""
        if self.connection:
            try:
                self.connection.close()
                print("✓ Database connection closed")
            except Exception:  # nosec B110 - Silently ignore close errors in cleanup
                # Connection may already be closed or invalid, which is acceptable during cleanup
                pass

    def discover_schema(
        self,
        schema_name: str,
        include_patterns: Optional[List[str]] = None,
        exclude_patterns: Optional[List[str]] = None,
        output_file: str = "migration_config.json",
    ) -> bool:
        """
        Discovery mode: Scan schema and generate migration configuration

        Args:
            schema_name: Schema to discover
            include_patterns: Table name patterns to include
            exclude_patterns: Table name patterns to exclude
            output_file: Output JSON file

        Returns:
            True if successful
        """
        print("\n" + "=" * 70)
        print("DISCOVERY MODE")
        print("=" * 70 + "\n")

        # Connect to database
        if not self.connect_database():
            return False

        try:
            # Run discovery
            discovery = TableDiscovery(self.connection)
            config = discovery.discover_schema(
                schema_name, include_patterns, exclude_patterns
            )

            # Save configuration
            discovery.save_config(config, output_file)

            # Update stats
            self.stats["tables_discovered"] = config["metadata"]["total_tables_found"]
            self.stats["tables_enabled"] = config["metadata"][
                "tables_selected_for_migration"
            ]

            # Print instructions
            print("\n" + "=" * 70)
            print("NEXT STEPS:")
            print("=" * 70)
            print(f"1. Review and edit: {output_file}")
            print("2. Customize settings:")
            print("   - Enable/disable tables (set 'enabled': true/false)")
            print("   - Choose partition column")
            print("   - Choose interval type (HOUR/DAY/WEEK/MONTH)")
            print("   - Choose hash subpartition column")
            print("   - Adjust hash subpartition count")
            print(
                f"3. Validate: python3 generate_scripts.py --config {output_file} --validate-only"
            )
            print(f"4. Generate: python3 generate_scripts.py --config {output_file}")
            print("=" * 70 + "\n")

            return True

        except Exception as e:
            print(f"\n✗ Discovery failed: {e}")
            import traceback

            traceback.print_exc()
            return False
        finally:
            self.disconnect_database()

    def load_config(self) -> bool:
        """
        Load configuration from JSON file

        Returns:
            True if successful
        """
        if not self.config_file:
            print("ERROR: No configuration file specified")
            return False

        config_path = Path(self.config_file)
        if not config_path.exists():
            print(f"ERROR: Configuration file not found: {self.config_file}")
            return False

        try:
            print(f"Loading configuration: {self.config_file}")
            with open(config_path, encoding="utf-8") as f:
                self.config = json.load(f)

            # Update stats
            metadata = self.config.get("metadata", {})
            self.stats["tables_discovered"] = metadata.get("total_tables_found", 0)
            self.stats["tables_enabled"] = metadata.get(
                "tables_selected_for_migration", 0
            )

            print("✓ Configuration loaded")
            print(f"  Schema: {metadata.get('schema', 'N/A')}")
            print(f"  Total tables: {self.stats['tables_discovered']}")
            print(f"  Enabled tables: {self.stats['tables_enabled']}")

            return True

        except json.JSONDecodeError as e:
            print(f"ERROR: Invalid JSON in {self.config_file}")
            print(f"  {e}")
            return False
        except Exception as e:
            print(f"ERROR: Failed to load configuration: {e}")
            return False

    def validate_config(self, check_database: bool = False) -> bool:
        """
        Validate configuration

        Args:
            check_database: Whether to validate against database

        Returns:
            True if valid
        """
        print("\n" + "=" * 70)
        print("VALIDATION MODE")
        print("=" * 70 + "\n")

        if not self.config:
            print("ERROR: No configuration loaded")
            return False

        # Connect if database validation requested
        connection = None
        if check_database:
            if not self.connect_database():
                print("WARNING: Could not connect to database")
                print("         Skipping database validation")
            else:
                connection = self.connection

        try:
            validator = ConfigValidator(connection)
            is_valid, errors, warnings = validator.validate_config(
                self.config, check_database and connection is not None
            )

            return is_valid

        except Exception as e:
            print(f"\n✗ Validation failed: {e}")
            import traceback

            traceback.print_exc()
            return False
        finally:
            if check_database and connection:
                self.disconnect_database()

    def validate_pre_migration(self) -> bool:
        """
        Run pre-migration validation checks

        Returns:
            True if all checks pass
        """
        if not self.config:
            print("ERROR: No configuration loaded")
            return False

        if not self.connect_database():
            return False

        try:
            validator = MigrationValidator(self.connection_string, self.config)
            validator.connect()

            tables = self.config.get("tables", [])
            enabled_tables = [t for t in tables if t.get("enabled", False)]

            print(
                f"\nRunning pre-migration checks on {len(enabled_tables)} table(s)...\n"
            )

            all_passed = True
            for table_config in enabled_tables:
                results = validator.validate_pre_migration(table_config)

                # Check if any critical failures
                failures = [r for r in results if r.status == "FAIL"]
                if failures:
                    all_passed = False

            validator.disconnect()
            return all_passed

        except Exception as e:
            print(f"\n✗ Pre-migration validation failed: {e}")
            import traceback

            traceback.print_exc()
            return False
        finally:
            self.disconnect_database()

    def validate_post_migration(self) -> bool:
        """
        Run post-migration validation checks

        Returns:
            True if all checks pass
        """
        if not self.config:
            print("ERROR: No configuration loaded")
            return False

        if not self.connect_database():
            return False

        try:
            validator = MigrationValidator(self.connection_string, self.config)
            validator.connect()

            tables = self.config.get("tables", [])
            enabled_tables = [t for t in tables if t.get("enabled", False)]

            print(
                f"\nRunning post-migration checks on {len(enabled_tables)} table(s)...\n"
            )

            all_passed = True
            for table_config in enabled_tables:
                results = validator.validate_post_migration(table_config)

                failures = [r for r in results if r.status == "FAIL"]
                if failures:
                    all_passed = False

            validator.disconnect()
            return all_passed

        except Exception as e:
            print(f"\n✗ Post-migration validation failed: {e}")
            import traceback

            traceback.print_exc()
            return False
        finally:
            self.disconnect_database()

    def compare_data(self) -> bool:
        """
        Run data comparison between old and new tables

        Returns:
            True if data matches
        """
        if not self.config:
            print("ERROR: No configuration loaded")
            return False

        if not self.connect_database():
            return False

        try:
            validator = MigrationValidator(self.connection_string, self.config)
            validator.connect()

            tables = self.config.get("tables", [])
            enabled_tables = [t for t in tables if t.get("enabled", False)]

            print(f"\nComparing data for {len(enabled_tables)} table(s)...\n")

            all_passed = True
            for table_config in enabled_tables:
                results = validator.compare_data(table_config)

                failures = [r for r in results if r.status == "FAIL"]
                if failures:
                    all_passed = False

            validator.disconnect()
            return all_passed

        except Exception as e:
            print(f"\n✗ Data comparison failed: {e}")
            import traceback

            traceback.print_exc()
            return False
        finally:
            self.disconnect_database()

    def generate_validation_report(
        self, output_file: str = "validation_report.md"
    ) -> bool:
        """
        Generate comprehensive validation report

        Args:
            output_file: Output file path

        Returns:
            True if successful
        """
        if not self.config:
            print("ERROR: No configuration loaded")
            return False

        if not self.connect_database():
            return False

        try:
            validator = MigrationValidator(self.connection_string, self.config)
            validator.connect()

            tables = self.config.get("tables", [])
            enabled_tables = [t for t in tables if t.get("enabled", False)]

            print(
                f"\nGenerating validation report for {len(enabled_tables)} table(s)...\n"
            )

            # Run all validations
            for table_config in enabled_tables:
                print(
                    f"Validating: {table_config.get('owner')}.{table_config.get('table_name')}"
                )
                validator.validate_pre_migration(table_config)
                validator.validate_post_migration(table_config)
                validator.compare_data(table_config)

            # Generate report
            validator.generate_report(output_file)

            validator.disconnect()
            return True

        except Exception as e:
            print(f"\n✗ Report generation failed: {e}")
            import traceback

            traceback.print_exc()
            return False
        finally:
            self.disconnect_database()

    def generate_scripts(self) -> bool:
        """
        Generation mode: Create migration scripts from configuration

        Returns:
            True if successful
        """
        print("\n" + "=" * 70)
        print("GENERATION MODE")
        print("=" * 70 + "\n")

        if not self.config:
            print("ERROR: No configuration loaded")
            return False

        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        print(f"Output directory: {self.output_dir}")

        # Process each table
        tables = self.config.get("tables", [])
        enabled_tables = [t for t in tables if t.get("enabled", False)]

        print(f"\nProcessing {len(enabled_tables)} enabled table(s)...\n")

        success_count = 0
        for idx, table_config in enumerate(enabled_tables, 1):
            table_name = table_config.get("table_name", f"table_{idx}")
            print(f"[{idx}/{len(enabled_tables)}] Processing: {table_name}")

            try:
                if self.generate_table_scripts(table_config):
                    success_count += 1
                    self.stats["tables_processed"] += 1
                else:
                    self.stats["errors"] += 1
            except Exception as e:
                print(f"  ✗ Error: {e}")
                self.stats["errors"] += 1
                import traceback

                traceback.print_exc()

        # Print summary
        print("\n" + "=" * 70)
        print("GENERATION COMPLETE")
        print("=" * 70)
        print(f"Tables processed: {success_count}/{len(enabled_tables)}")
        print(f"Scripts generated: {self.stats['scripts_generated']}")
        print(f"Errors: {self.stats['errors']}")
        print(f"Output directory: {self.output_dir}")
        print("=" * 70 + "\n")

        return success_count == len(enabled_tables)

    def generate_table_scripts(self, table_config: Dict) -> bool:
        """
        Generate all migration scripts for a single table

        Args:
            table_config: Table configuration from JSON

        Returns:
            True if successful
        """
        owner = table_config.get("owner")
        table_name = table_config.get("table_name")

        # Create table-specific directory
        table_dir = self.output_dir / f"{owner}_{table_name}"
        table_dir.mkdir(parents=True, exist_ok=True)

        print(f"  Directory: {table_dir}")

        # Prepare template context
        context = self._prepare_template_context(table_config)

        # Generate each script
        templates = [
            "10_create_table.sql.j2",
            "20_data_load.sql.j2",
            "30_create_indexes.sql.j2",
            "40_delta_load.sql.j2",
            "50_swap_tables.sql.j2",
            "60_restore_grants.sql.j2",
            "70_drop_old_table.sql.j2",
            "master1.sql.j2",
            "master2.sql.j2",
        ]

        generated = 0
        for template_name in templates:
            try:
                output_name = template_name.replace(".j2", "")
                output_path = table_dir / output_name

                if self._render_template(template_name, context, output_path):
                    generated += 1
                    self.stats["scripts_generated"] += 1

            except Exception as e:
                print(f"  ✗ Failed to generate {template_name}: {e}")
                return False

        # Generate README
        self._generate_table_readme(table_config, table_dir)

        print(f"  ✓ Generated {generated} scripts")
        return True

    def _prepare_template_context(self, table_config: Dict) -> Dict:
        """
        Prepare context dictionary for Jinja2 templates

        Args:
            table_config: Table configuration

        Returns:
            Context dictionary with all variables needed by templates
        """
        owner = table_config.get("owner")
        table_name = table_config.get("table_name")
        target_config = table_config.get("target_configuration", {})
        current_state = table_config.get("current_state", {})

        # Extract column information
        available_cols = table_config.get("available_columns", {})
        all_columns = []

        # We would normally query the database here, but for now use available columns
        timestamp_cols = [
            c["name"] for c in available_cols.get("timestamp_columns", [])
        ]
        numeric_cols = [c["name"] for c in available_cols.get("numeric_columns", [])]
        string_cols = [c["name"] for c in available_cols.get("string_columns", [])]
        all_columns = timestamp_cols + numeric_cols + string_cols

        context = {
            # Basic info
            "owner": owner,
            "table_name": table_name,
            "new_table_name": f"{table_name}_NEW",
            "old_table_name": f"{table_name}_OLD",
            # Configuration
            "target_configuration": target_config,
            "current_state": current_state,
            "migration_action": table_config.get("migration_action"),
            "migration_settings": table_config.get("migration_settings", {}),
            # Columns
            "column_list": ", ".join(all_columns) if all_columns else "*",
            "column_definitions": "-- Column definitions to be extracted from source table",
            "primary_key_columns": target_config.get(
                "partition_column", all_columns[0] if all_columns else "ID"
            ),
            # LOBs
            "lob_columns": [],  # Would be populated from database
            # Indexes
            "index_definitions": f"-- {current_state.get('index_count', 0)} index definitions to be generated",
            # Grants
            "grant_statements": "-- Grant statements to be generated",
            # Timestamps
            "generation_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "cutoff_timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            # Additional context
            "update_set_clause": "-- UPDATE SET clause",
            "include_delta_load": False,
            "drop_old_table": False,
            # Available columns for reference
            "available_columns": available_cols,
        }

        return context

    def _render_template(
        self, template_name: str, context: Dict, output_path: Path
    ) -> bool:
        """
        Render a Jinja2 template and save to file

        Args:
            template_name: Template filename
            context: Template context
            output_path: Output file path

        Returns:
            True if successful
        """
        try:
            template = self.jinja_env.get_template(template_name)
            rendered = template.render(**context)

            with open(output_path, "w", encoding="utf-8") as f:
                f.write(rendered)

            return True

        except Exception as e:
            print(f"    ERROR rendering {template_name}: {e}")
            return False

    def _generate_table_readme(self, table_config: Dict, table_dir: Path):
        """Generate README for table migration scripts"""
        owner = table_config.get("owner")
        table_name = table_config.get("table_name")
        target_config = table_config.get("target_configuration", {})
        current_state = table_config.get("current_state", {})
        migration_settings = table_config.get("migration_settings", {})

        readme_content = f"""# Migration Scripts: {owner}.{table_name}

## Overview

**Source Table**: `{owner}.{table_name}`
**Target Configuration**: {target_config.get('partition_type', 'N/A')}
**Migration Action**: {table_config.get('migration_action', 'N/A')}

## Current State

- **Partitioned**: {current_state.get('is_partitioned', False)}
- **Size**: {current_state.get('size_gb', 0):.2f} GB
- **Row Count**: {current_state.get('row_count', 0):,}
- **LOB Columns**: {current_state.get('lob_count', 0)}
- **Indexes**: {current_state.get('index_count', 0)}

## Target Configuration

- **Partition Column**: `{target_config.get('partition_column', 'N/A')}`
- **Interval Type**: {target_config.get('interval_type', 'N/A')}
- **Hash Subpartitions**: {target_config.get('subpartition_count', 0)} on `{target_config.get('subpartition_column', 'N/A')}`
- **Parallel Degree**: {target_config.get('parallel_degree', 1)}

## Estimated Time

**Total Migration Time**: ~{migration_settings.get('estimated_hours', 0):.1f} hours

## Execution Steps

### Phase 1: Structure and Initial Load

```bash
sqlplus {owner}/password @master1.sql
```

This executes:
1. `10_create_table.sql` - Create new partitioned table
2. `20_data_load.sql` - Initial data load (~{current_state.get('size_gb', 0) / 8:.1f} hours)
3. `30_create_indexes.sql` - Rebuild indexes (~{current_state.get('index_count', 0) * 0.75:.1f} hours)
4. `40_delta_load.sql` - Load incremental changes

### Phase 2: Cutover and Cleanup

**After validating Phase 1:**

```bash
sqlplus {owner}/password @master2.sql
```

This executes:
5. `50_swap_tables.sql` - Rename tables (downtime starts here)
6. `60_restore_grants.sql` - Restore privileges
7. `70_drop_old_table.sql` - Drop old table (optional)

## Individual Scripts

Run scripts individually for more control:

```bash
# Create structure
sqlplus {owner}/password @10_create_table.sql

# Load data
sqlplus {owner}/password @20_data_load.sql

# Create indexes
sqlplus {owner}/password @30_create_indexes.sql

# Delta load (if needed)
sqlplus {owner}/password @40_delta_load.sql

# Cutover (downtime)
sqlplus {owner}/password @50_swap_tables.sql

# Restore grants
sqlplus {owner}/password @60_restore_grants.sql

# Drop old table (optional)
sqlplus {owner}/password @70_drop_old_table.sql
```

## Validation

Before cutover, run validation:

```bash
cd ../../03_validation
sqlplus {owner}/password @pre_migration_checks.sql
sqlplus {owner}/password @data_comparison.sql
```

After cutover:

```bash
sqlplus {owner}/password @post_migration_validation.sql
```

## Rollback

If issues occur, see `../rollback/emergency_rollback.sql`

## Notes

- **Priority**: {migration_settings.get('priority', 'N/A')}
- **Backup Old Table**: {migration_settings.get('backup_old_table', True)}
- **Drop After Days**: {migration_settings.get('drop_old_after_days', 7)}

Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""

        readme_path = table_dir / "README.md"
        with open(readme_path, "w", encoding="utf-8") as f:
            f.write(readme_content)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Generate Oracle table migration scripts (JSON-driven with Jinja2)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # Mode selection
    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument(
        "--discover",
        "-d",
        action="store_true",
        help="Discovery mode: Scan schema and generate migration_config.json",
    )
    mode_group.add_argument(
        "--config",
        "-c",
        type=str,
        help="Generation mode: Use JSON config file to generate scripts",
    )

    # Discovery mode options
    parser.add_argument(
        "--schema", "-s", type=str, help="Schema name (required for discovery mode)"
    )
    parser.add_argument(
        "--include",
        type=str,
        nargs="+",
        help="Table name patterns to include (e.g., IE_%%)",
    )
    parser.add_argument(
        "--exclude",
        type=str,
        nargs="+",
        help="Table name patterns to exclude (e.g., TEMP_%%)",
    )

    # Common options
    parser.add_argument(
        "--connection",
        type=str,
        help="Oracle connection string (user/pass@host:port/service)",
    )
    parser.add_argument(
        "--template-dir",
        type=str,
        default="templates",
        help="Template directory (default: templates)",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="output",
        help="Output directory (default: output)",
    )
    parser.add_argument(
        "--output-file",
        type=str,
        default="migration_config.json",
        help="Output JSON file for discovery (default: migration_config.json)",
    )

    # Validation options
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Only validate configuration (do not generate scripts)",
    )
    parser.add_argument(
        "--validate-pre",
        action="store_true",
        help="Run pre-migration validation checks",
    )
    parser.add_argument(
        "--validate-post",
        action="store_true",
        help="Run post-migration validation checks",
    )
    parser.add_argument(
        "--compare-data",
        action="store_true",
        help="Compare data between old and new tables",
    )
    parser.add_argument(
        "--validation-report",
        type=str,
        metavar="FILE",
        help="Generate comprehensive validation report (default: validation_report.md)",
    )
    parser.add_argument(
        "--check-database",
        action="store_true",
        help="Validate config against database (requires --connection)",
    )

    args = parser.parse_args()

    # Validate arguments
    if args.discover and not args.schema:
        parser.error("--discover requires --schema")

    if args.discover and not args.connection:
        parser.error("--discover requires --connection")

    if args.check_database and not args.connection:
        parser.error("--check-database requires --connection")

    # Validation modes require --connection
    if (
        args.validate_pre
        or args.validate_post
        or args.compare_data
        or args.validation_report
    ) and not args.connection:
        parser.error("Validation modes require --connection")

    # Create generator
    generator = MigrationScriptGenerator(
        connection_string=args.connection,
        config_file=args.config,
        template_dir=args.template_dir,
        output_dir=args.output_dir,
    )

    # Execute appropriate mode
    success = False

    if args.discover:
        # Discovery mode
        success = generator.discover_schema(
            args.schema, args.include, args.exclude, args.output_file
        )
    elif args.validate_pre:
        # Pre-migration validation mode
        if not generator.load_config():
            sys.exit(1)
        success = generator.validate_pre_migration()
        if success:
            print("\n✓ All pre-migration checks passed")
        else:
            print("\n✗ Some pre-migration checks failed")
    elif args.validate_post:
        # Post-migration validation mode
        if not generator.load_config():
            sys.exit(1)
        success = generator.validate_post_migration()
        if success:
            print("\n✓ All post-migration checks passed")
        else:
            print("\n✗ Some post-migration checks failed")
    elif args.compare_data:
        # Data comparison mode
        if not generator.load_config():
            sys.exit(1)
        success = generator.compare_data()
        if success:
            print("\n✓ Data comparison passed")
        else:
            print("\n✗ Data comparison failed")
    elif args.validation_report:
        # Generate validation report
        if not generator.load_config():
            sys.exit(1)
        output_file = (
            args.validation_report
            if args.validation_report != "FILE"
            else "validation_report.md"
        )
        success = generator.generate_validation_report(output_file)
        if success:
            print(f"\n✓ Validation report generated: {output_file}")
        else:
            print("\n✗ Report generation failed")
    else:
        # Load configuration
        if not generator.load_config():
            sys.exit(1)

        # Validate
        if not generator.validate_config(args.check_database):
            print("\n✗ Configuration validation failed")
            sys.exit(1)

        if args.validate_only:
            print("\n✓ Configuration is valid")
            success = True
        else:
            # Generate scripts
            success = generator.generate_scripts()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
