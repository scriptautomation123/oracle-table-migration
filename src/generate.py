#!/usr/bin/env python3
"""
Migration Script Generator - Refactored Version
==============================================
Clean, maintainable Python code following best practices.

Key improvements:
- Single Responsibility Principle
- Dependency Injection
- Context Managers
- Type Hints
- Custom Exceptions
- Strategy Pattern
"""

import argparse
import json
import sys
from abc import ABC, abstractmethod
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Generator, List, Optional, Protocol, Tuple

# Add project root to path for imports
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Third-party imports
try:
    from jinja2 import Environment, FileSystemLoader, select_autoescape
except ImportError:
    print("ERROR: jinja2 module not found! Install with: pip install jinja2")
    sys.exit(1)

try:
    import oracledb

    # Initialize Oracle thick mode (optional, enables more features)
    try:
        oracledb.init_oracle_client()
        print("Oracle thick mode enabled")
    except Exception as e:
        # Thin mode is fine - fallback to thin mode
        print(f"Oracle thin mode: {e}")
except ImportError:
    print("ERROR: python-oracledb not found. Install with: pip install oracledb")
    sys.exit(1)

# Local imports
# sys.path modification above requires imports here - this is intentional
from lib.config_validator import ConfigValidator  # noqa: E402
from lib.discovery_queries import TableDiscovery  # noqa: E402
from lib.template_filters import register_custom_filters  # noqa: E402


# Constants
class Constants:
    DEFAULT_TEMPLATE_DIR = "templates"
    DEFAULT_OUTPUT_DIR = "output"
    DEFAULT_CONFIG_FILE = "migration_config.json"
    DEFAULT_VALIDATION_REPORT = "validation_report.md"

    TEMPLATES = [
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


# Custom Exceptions
class MigrationError(Exception):
    """Base exception for migration operations"""

    pass


class DatabaseConnectionError(MigrationError):
    """Database connection related errors"""

    pass


class ConfigurationError(MigrationError):
    """Configuration related errors"""

    pass


class TemplateError(MigrationError):
    """Template rendering errors"""

    pass


# Data Classes
@dataclass
class MigrationConfig:
    """Configuration for migration operations"""

    connection_string: Optional[str] = None
    config_file: Optional[str] = None
    template_dir: str = Constants.DEFAULT_TEMPLATE_DIR
    output_dir: str = Constants.DEFAULT_OUTPUT_DIR
    environment: Optional[str] = None
    thin_ldap: bool = False


@dataclass
class MigrationStats:
    """Statistics for migration operations"""

    tables_discovered: int = 0
    tables_enabled: int = 0
    tables_processed: int = 0
    scripts_generated: int = 0
    errors: int = 0


# Protocols for Dependency Injection
class DatabaseServiceProtocol(Protocol):
    def connect(self) -> None: ...
    def disconnect(self) -> None: ...
    def is_connected(self) -> bool: ...


class ConfigServiceProtocol(Protocol):
    def load_config(self, config_file: str) -> Dict[str, Any]: ...
    def validate_config(
        self, config: Dict[str, Any], check_database: bool = False
    ) -> bool: ...


class TemplateServiceProtocol(Protocol):
    def render_template(
        self, template_name: str, context: Dict[str, Any], output_path: Path
    ) -> bool: ...


# Service Implementations
class DatabaseService:
    """Handles database connections and operations"""

    def __init__(self, connection_string: str, thin_ldap: bool = False):
        self.connection_string = connection_string
        self.thin_ldap = thin_ldap
        self._connection: Optional[Any] = None

    def _parse_ldap_servers(self, dsn: str) -> Tuple[str, str, str]:
        """Parse LDAP DSN to extract servers, port, and DN"""
        if not dsn.startswith("ldap://"):
            return None, None, None

        dsn = dsn.replace("ldap://", "", 1)

        if "/" in dsn:
            server_part, dn_part = dsn.split("/", 1)
        else:
            server_part = dsn
            dn_part = ""

        if ":" in server_part:
            servers, port = server_part.rsplit(":", 1)
        else:
            servers = server_part
            port = "389"

        return servers, port, dn_part

    def _build_ldap_dsn(self, servers: str, port: str, dn: str) -> str:
        """Build LDAP DSN from components"""
        return f"ldap://{servers}:{port}/{dn}"

    @contextmanager
    def connection(self) -> Generator[Any, None, None]:
        """Context manager for database connections"""
        if not oracledb:
            raise DatabaseConnectionError("Oracle driver not available")

        if not self.connection_string:
            raise DatabaseConnectionError("No connection string provided")

        try:
            print("Connecting to database...")

            if "@" in self.connection_string:
                user_pass, dsn_part = self.connection_string.rsplit("@", 1)
                is_sys = user_pass.lower().startswith("sys/")
            else:
                user_pass = None
                dsn_part = self.connection_string
                is_sys = False

            if self.thin_ldap and dsn_part.startswith("ldap://"):
                servers, port, dn = self._parse_ldap_servers(dsn_part)

                if servers:
                    server_list = [s.strip() for s in servers.split(",")]

                    if len(server_list) > 1:
                        print(f"Trying with {len(server_list)} LDAP servers...")
                        dsn_multi = self._build_ldap_dsn(servers, port, dn)
                        try:
                            if is_sys:
                                self._connection = oracledb.connect(
                                    dsn=dsn_multi, mode=oracledb.AUTH_MODE_SYSDBA
                                )
                            else:
                                self._connection = oracledb.connect(
                                    dsn=dsn_multi,
                                    user=(
                                        user_pass.split("/")[0]
                                        if "/" in user_pass
                                        else None
                                    ),
                                    password=(
                                        user_pass.split("/")[1]
                                        if "/" in user_pass
                                        else None
                                    ),
                                )
                            print("✓ Connected successfully with multiple LDAP servers")
                            yield self._connection
                            return
                        except Exception as e:
                            print(
                                f"Multiple servers failed: {e}, trying single server..."
                            )
                            dsn_single = self._build_ldap_dsn(server_list[0], port, dn)
                            if is_sys:
                                self._connection = oracledb.connect(
                                    dsn=dsn_single, mode=oracledb.AUTH_MODE_SYSDBA
                                )
                            else:
                                self._connection = oracledb.connect(
                                    dsn=dsn_single,
                                    user=(
                                        user_pass.split("/")[0]
                                        if "/" in user_pass
                                        else None
                                    ),
                                    password=(
                                        user_pass.split("/")[1]
                                        if "/" in user_pass
                                        else None
                                    ),
                                )
                            print("✓ Connected successfully with single LDAP server")
                            yield self._connection
                            return

            if is_sys:
                self._connection = oracledb.connect(
                    dsn=dsn_part if dsn_part else self.connection_string,
                    mode=oracledb.AUTH_MODE_SYSDBA,
                )
            else:
                if user_pass and "/" in user_pass:
                    user, password = user_pass.split("/", 1)
                    self._connection = oracledb.connect(
                        user=user,
                        password=password,
                        dsn=dsn_part if dsn_part else self.connection_string,
                    )
                else:
                    self._connection = oracledb.connect(
                        dsn=dsn_part if dsn_part else self.connection_string
                    )

            print("✓ Connected successfully")
            yield self._connection
        except Exception as e:
            raise DatabaseConnectionError(f"Connection failed: {e}") from e
        finally:
            if self._connection:
                try:
                    self._connection.close()
                    print("✓ Database connection closed")
                except Exception as close_error:
                    # Log but don't fail on close errors during cleanup
                    print(f"Note: Error closing connection: {close_error}")


class ConfigService:
    """Handles configuration loading and validation"""

    def __init__(self, database_service: Optional[DatabaseService] = None):
        self.database_service = database_service

    def load_config(self, config_file: str) -> Dict[str, Any]:
        """Load configuration from JSON file"""
        config_path = Path(config_file)
        if not config_path.exists():
            raise ConfigurationError(f"Configuration file not found: {config_file}")

        try:
            print(f"Loading configuration: {config_file}")
            with open(config_path, encoding="utf-8") as f:
                config = json.load(f)

            print("✓ Configuration loaded")
            self._print_config_summary(config)
            return config

        except json.JSONDecodeError as e:
            raise ConfigurationError(f"Invalid JSON in {config_file}: {e}") from e
        except Exception as e:
            raise ConfigurationError(f"Failed to load configuration: {e}") from e

    def validate_config(
        self, config: Dict[str, Any], check_database: bool = False
    ) -> bool:
        """Validate configuration"""
        print("\n" + "=" * 70)
        print("VALIDATION MODE")
        print("=" * 70 + "\n")

        connection = None
        if check_database and self.database_service:
            try:
                with self.database_service.connection() as conn:
                    connection = conn
                    validator = ConfigValidator(connection)
                    is_valid, errors, warnings = validator.validate_config(config, True)
                    return is_valid
            except DatabaseConnectionError:
                print(
                    "WARNING: Could not connect to database, skipping database validation"
                )
                validator = ConfigValidator()
                is_valid, errors, warnings = validator.validate_config(config, False)
                return is_valid

        validator = ConfigValidator()
        is_valid, errors, warnings = validator.validate_config(config, False)
        return is_valid

    def _print_config_summary(self, config: Dict[str, Any]) -> None:
        """Print configuration summary"""
        metadata = config.get("metadata", {})
        print(f"  Schema: {metadata.get('schema', 'N/A')}")
        print(f"  Total tables: {metadata.get('total_tables_found', 0)}")
        print(f"  Enabled tables: {metadata.get('tables_selected_for_migration', 0)}")


class TemplateService:
    """Handles Jinja2 template rendering"""

    def __init__(self, template_dir: str):
        self.template_dir = Path(template_dir)
        self.jinja_env = Environment(
            loader=FileSystemLoader(str(self.template_dir), encoding="utf-8"),
            autoescape=select_autoescape(),
            trim_blocks=False,
            lstrip_blocks=False,
            keep_trailing_newline=True,
        )
        register_custom_filters(self.jinja_env)

    def render_template(
        self, template_name: str, context: Dict[str, Any], output_path: Path
    ) -> bool:
        """Render a Jinja2 template and save to file"""
        try:
            template = self.jinja_env.get_template(template_name)
            rendered = template.render(**context)

            with open(output_path, "w", encoding="utf-8") as f:
                f.write(rendered)

            return True
        except Exception as e:
            print(f"    ERROR rendering {template_name}: {e}")
            return False


# Command Pattern for Operations
class MigrationCommand(ABC):
    """Abstract base class for migration commands"""

    @abstractmethod
    def execute(self) -> bool:
        """Execute the command"""
        pass


class DiscoveryCommand(MigrationCommand):
    """Discovery mode command"""

    def __init__(
        self,
        config: MigrationConfig,
        schema: str,
        include_patterns: Optional[List[str]] = None,
        exclude_patterns: Optional[List[str]] = None,
        output_file: str = Constants.DEFAULT_CONFIG_FILE,
    ):
        self.config = config
        self.schema = schema
        self.include_patterns = include_patterns
        self.exclude_patterns = exclude_patterns
        self.output_file = output_file

    def execute(self) -> bool:
        """Execute discovery mode"""
        print("\n" + "=" * 70)
        print("DISCOVERY MODE")
        print("=" * 70 + "\n")

        database_service = DatabaseService(
            self.config.connection_string, self.config.thin_ldap
        )

        try:
            with database_service.connection() as connection:
                discovery = TableDiscovery(
                    connection,
                    self.config.environment,
                    self.config.connection_string
                )
                config = discovery.discover_schema(
                    self.schema, self.include_patterns, self.exclude_patterns
                )
                discovery.save_config(config, self.output_file)
                self._print_next_steps()
                return True
        except Exception as e:
            print(f"\n✗ Discovery failed: {e}")
            return False

    def _print_next_steps(self) -> None:
        """Print next steps instructions"""
        print("\n" + "=" * 70)
        print("NEXT STEPS:")
        print("=" * 70)
        print(f"1. Review and edit: {self.output_file}")
        print("2. Customize settings:")
        print("   - Enable/disable tables (set 'enabled': true/false)")
        print("   - Choose partition column")
        print("   - Choose interval type (HOUR/DAY/WEEK/MONTH)")
        print("   - Choose hash subpartition column")
        print("   - Adjust hash subpartition count")
        print(
            f"3. Validate: python3 generate_scripts.py --config {self.output_file} --validate-only"
        )
        print(f"4. Generate: python3 generate_scripts.py --config {self.output_file}")
        print("=" * 70 + "\n")


class ValidationCommand(MigrationCommand):
    """Validation mode command"""

    def __init__(self, config: MigrationConfig, check_database: bool = False):
        self.config = config
        self.check_database = check_database

    def execute(self) -> bool:
        """Execute validation mode"""
        database_service = (
            DatabaseService(self.config.connection_string, self.config.thin_ldap)
            if self.config.connection_string
            else None
        )
        config_service = ConfigService(database_service)

        try:
            config_data = config_service.load_config(self.config.config_file)
            return config_service.validate_config(config_data, self.check_database)
        except Exception as e:
            print(f"\n✗ Validation failed: {e}")
            return False


class GenerationCommand(MigrationCommand):
    """Script generation mode command"""

    def __init__(self, config: MigrationConfig, check_database: bool = False):
        self.config = config
        self.check_database = check_database
        self.stats = MigrationStats()

    def execute(self) -> bool:
        """Execute script generation mode"""
        print("\n" + "=" * 70)
        print("GENERATION MODE")
        print("=" * 70 + "\n")

        database_service = (
            DatabaseService(self.config.connection_string, self.config.thin_ldap)
            if self.config.connection_string
            else None
        )
        config_service = ConfigService(database_service)
        template_service = TemplateService(self.config.template_dir)

        try:
            config_data = config_service.load_config(self.config.config_file)

            # Validate configuration first
            if not config_service.validate_config(config_data, self.check_database):
                print("\n✗ Configuration validation failed")
                return False

            return self._generate_scripts(config_data, template_service)
        except Exception as e:
            print(f"\n✗ Generation failed: {e}")
            return False

    def _generate_scripts(
        self, config_data: Dict[str, Any], template_service: TemplateService
    ) -> bool:
        """Generate migration scripts"""
        # Create output directory
        output_dir = Path(self.config.output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        print(f"Output directory: {output_dir}")

        # Process each table
        tables = config_data.get("tables", [])
        enabled_tables = [t for t in tables if t.get("enabled", False)]

        print(f"\nProcessing {len(enabled_tables)} enabled table(s)...\n")

        success_count = 0
        for idx, table_config in enumerate(enabled_tables, 1):
            table_name = table_config.get("table_name", f"table_{idx}")
            print(f"[{idx}/{len(enabled_tables)}] Processing: {table_name}")

            try:
                if self._generate_table_scripts(
                    table_config, template_service, output_dir
                ):
                    success_count += 1
                    self.stats.tables_processed += 1
                else:
                    self.stats.errors += 1
            except Exception as e:
                print(f"  ✗ Error: {e}")
                self.stats.errors += 1

        self._print_generation_summary(success_count, len(enabled_tables), output_dir)
        return success_count == len(enabled_tables)

    def _generate_table_scripts(
        self,
        table_config: Dict[str, Any],
        template_service: TemplateService,
        output_dir: Path,
    ) -> bool:
        """Generate scripts for a single table"""
        owner = table_config.get("owner")
        table_name = table_config.get("table_name")

        # Create table-specific directory
        table_dir = output_dir / f"{owner}_{table_name}"
        table_dir.mkdir(parents=True, exist_ok=True)
        print(f"  Directory: {table_dir}")

        # Prepare template context
        context = self._prepare_template_context(table_config)

        # Generate each script
        generated = 0
        for template_name in Constants.TEMPLATES:
            try:
                output_name = template_name.replace(".j2", "")
                output_path = table_dir / output_name

                if template_service.render_template(
                    template_name, context, output_path
                ):
                    generated += 1
                    self.stats.scripts_generated += 1
            except Exception as e:
                print(f"  ✗ Failed to generate {template_name}: {e}")
                return False

        # Generate README
        self._generate_table_readme(table_config, table_dir)

        print(f"  ✓ Generated {generated} scripts")
        return True

    def _prepare_template_context(self, table_config: Dict[str, Any]) -> Dict[str, Any]:
        """Prepare template context"""
        owner = table_config.get("owner")
        table_name = table_config.get("table_name")
        target_config = table_config.get("target_configuration", {})
        current_state = table_config.get("current_state", {})
        available_cols = table_config.get("available_columns", {})

        # Extract column information
        timestamp_cols = [
            c["name"] for c in available_cols.get("timestamp_columns", [])
        ]
        numeric_cols = [c["name"] for c in available_cols.get("numeric_columns", [])]
        string_cols = [c["name"] for c in available_cols.get("string_columns", [])]
        all_columns = timestamp_cols + numeric_cols + string_cols

        return {
            "owner": owner,
            "table_name": table_name,
            "new_table_name": table_config.get("new_table_name", f"{table_name}_NEW"),
            "old_table_name": table_config.get("old_table_name", f"{table_name}_OLD"),
            "target_configuration": target_config,
            "current_state": current_state,
            "migration_action": table_config.get("migration_action"),
            "migration_settings": table_config.get("migration_settings", {}),
            "environment_config": table_config.get("environment_config", {}),
            "columns": table_config.get("columns", []),
            "column_list": ", ".join(all_columns) if all_columns else "*",
            "primary_key_columns": target_config.get(
                "partition_column", all_columns[0] if all_columns else "ID"
            ),
            "lob_storage": table_config.get("lob_storage", []),
            "storage_parameters": table_config.get("storage_parameters", {}),
            "indexes": table_config.get("indexes", []),
            "generation_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "cutoff_timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "available_columns": available_cols,
        }

    def _generate_table_readme(
        self, table_config: Dict[str, Any], table_dir: Path
    ) -> None:
        """Generate README for table migration scripts"""
        # Simplified README generation - could be extracted to a separate service
        owner = table_config.get("owner")
        table_name = table_config.get("table_name")

        readme_content = f"""# Migration Scripts: {owner}.{table_name}

Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Execution Steps

### Phase 1: Structure and Initial Load
```bash
sqlplus {owner}/password @master1.sql
```

### Phase 2: Cutover and Cleanup
```bash
sqlplus {owner}/password @master2.sql
```
"""

        readme_path = table_dir / "README.md"
        with open(readme_path, "w", encoding="utf-8") as f:
            f.write(readme_content)

    def _print_generation_summary(
        self, success_count: int, total_count: int, output_dir: Path
    ) -> None:
        """Print generation summary"""
        print("\n" + "=" * 70)
        print("GENERATION COMPLETE")
        print("=" * 70)
        print(f"Tables processed: {success_count}/{total_count}")
        print(f"Scripts generated: {self.stats.scripts_generated}")
        print(f"Errors: {self.stats.errors}")
        print(f"Output directory: {output_dir}")
        print("=" * 70 + "\n")


# Main Application
class MigrationScriptGenerator:
    """Main application class - simplified and focused"""

    def __init__(self, config: MigrationConfig):
        self.config = config

    def run(self, command: MigrationCommand) -> bool:
        """Run a migration command"""
        try:
            return command.execute()
        except Exception as e:
            print(f"Unexpected error: {e}")
            return False


def create_command(args: argparse.Namespace) -> MigrationCommand:
    """Factory function to create appropriate command"""
    config = MigrationConfig(
        connection_string=args.connection,
        config_file=args.config,
        template_dir=args.template_dir,
        output_dir=args.output_dir,
        environment=args.environment,
        thin_ldap=args.thin_ldap,
    )

    if args.discover:
        return DiscoveryCommand(
            config, args.schema, args.include, args.exclude, args.output_file
        )
    elif args.validate_only:
        return ValidationCommand(config, args.check_database)
    else:
        return GenerationCommand(config, args.check_database)


def main() -> None:
    """Main entry point - simplified"""
    parser = argparse.ArgumentParser(
        description="Generate Oracle table migration scripts",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    # Mode selection
    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument(
        "--discover",
        "-d",
        action="store_true",
        help="Discovery mode: Scan schema and generate config",
    )
    mode_group.add_argument(
        "--config", "-c", type=str, help="Generation mode: Use JSON config file"
    )

    # Common options
    parser.add_argument("--schema", "-s", type=str, help="Schema name")
    parser.add_argument("--connection", type=str, help="Oracle connection string")
    parser.add_argument(
        "--template-dir",
        default=Constants.DEFAULT_TEMPLATE_DIR,
        help="Template directory",
    )
    parser.add_argument(
        "--output-dir", default=Constants.DEFAULT_OUTPUT_DIR, help="Output directory"
    )
    parser.add_argument(
        "--output-file",
        default=Constants.DEFAULT_CONFIG_FILE,
        help="Output JSON file for discovery",
    )
    parser.add_argument("--environment", type=str, help="Environment name")
    parser.add_argument(
        "--validate-only", action="store_true", help="Only validate configuration"
    )
    parser.add_argument(
        "--check-database", action="store_true", help="Validate config against database"
    )
    parser.add_argument(
        "--thin-ldap",
        action="store_true",
        help="Use thin client LDAP mode with fallback (try multiple servers, then single)",
    )

    # Additional discovery options
    parser.add_argument(
        "--include", type=str, nargs="+", help="Table name patterns to include"
    )
    parser.add_argument(
        "--exclude", type=str, nargs="+", help="Table name patterns to exclude"
    )

    args = parser.parse_args()

    # Validate arguments
    if args.discover and not args.schema:
        parser.error("--discover requires --schema")
    if args.discover and not args.connection:
        parser.error("--discover requires --connection")
    if args.check_database and not args.connection:
        parser.error("--check-database requires --connection")

    # Create and run command
    command = create_command(args)
    generator = MigrationScriptGenerator(MigrationConfig())
    success = generator.run(command)

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
