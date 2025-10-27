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
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Protocol, Any, Generator
from abc import ABC, abstractmethod

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
    try:
        oracledb.init_oracle_client()
        print("Oracle thick mode enabled")
    except Exception as e:
        print(f"WARNING: Could not initialize Oracle Client: {e}")
except ImportError:
    try:
        import cx_Oracle as oracledb
    except ImportError:
        print("WARNING: Oracle driver not found. Install with: pip install oracledb")
        oracledb = None

# Local imports
from lib.config_validator import ConfigValidator
from lib.discovery_queries import TableDiscovery
from lib.template_filters import register_custom_filters
from lib.migration_models import MigrationConfig as TypedMigrationConfig, TableConfig


# Constants
class Constants:
    DEFAULT_TEMPLATE_DIR = "templates"
    DEFAULT_OUTPUT_DIR = "output"
    DEFAULT_CONFIG_FILE = "config.json"
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


class RunDirs:
    """Utility to manage structured run directories under output/"""

    def __init__(self, base_output: Path) -> None:
        self.base_output = base_output
        self.base_output.mkdir(parents=True, exist_ok=True)

    def _timestamp(self) -> str:
        return datetime.now().strftime("%Y%m%d_%H%M%S")

    def new_generation_run(self) -> Path:
        run_dir = self.base_output / f"run_{self._timestamp()}_generation_test"
        (run_dir / "config").mkdir(parents=True, exist_ok=True)
        (run_dir / "generated_ddl").mkdir(parents=True, exist_ok=True)
        (run_dir / "logs").mkdir(parents=True, exist_ok=True)
        (run_dir / "test_data").mkdir(parents=True, exist_ok=True)
        # Track current simple run
        (self.base_output.parent / ".current_run").write_text(f"RUN_DIR={run_dir.as_posix()}\n", encoding="utf-8")
        return run_dir

    def new_full_workflow_run(self) -> Path:
        run_dir = self.base_output / f"run_{self._timestamp()}_full_workflow_test"
        # Standardized staged folders
        (run_dir / "01_discovery").mkdir(parents=True, exist_ok=True)
        (run_dir / "02_generated_ddl").mkdir(parents=True, exist_ok=True)
        (run_dir / "03_test_execution").mkdir(parents=True, exist_ok=True)
        (run_dir / "logs").mkdir(parents=True, exist_ok=True)
        # Track current full workflow run
        (self.base_output.parent / ".current_full_run").write_text(f"FULL_RUN_DIR={run_dir.as_posix()}\n", encoding="utf-8")
        return run_dir

    def load_current_full(self) -> Optional[Path]:
        marker = self.base_output.parent / ".current_full_run"
        if not marker.exists():
            return None
        try:
            line = marker.read_text(encoding="utf-8").strip()
            if line.startswith("FULL_RUN_DIR="):
                path = Path(line.split("=", 1)[1])
                return path if path.exists() else None
        except Exception:
            return None
        return None

    def load_current_simple(self) -> Optional[Path]:
        marker = self.base_output.parent / ".current_run"
        if not marker.exists():
            return None
        try:
            line = marker.read_text(encoding="utf-8").strip()
            if line.startswith("RUN_DIR="):
                path = Path(line.split("=", 1)[1])
                return path if path.exists() else None
        except Exception:
            return None
        return None


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
    def load_config(self, config_file: str) -> TypedMigrationConfig: ...
    def validate_config(self, config: TypedMigrationConfig, check_database: bool = False) -> bool: ...


class TemplateServiceProtocol(Protocol):
    def render_template(self, template_name: str, context: Dict[str, Any], output_path: Path) -> bool: ...


# Service Implementations
class DatabaseService:
    """Handles database connections and operations"""
    
    def __init__(self, connection_string: str):
        self.connection_string = connection_string
        self._connection: Optional[Any] = None
    
    @contextmanager
    def connection(self) -> Generator[Any, None, None]:
        """Context manager for database connections"""
        if not oracledb:
            raise DatabaseConnectionError("Oracle driver not available")
        
        if not self.connection_string:
            raise DatabaseConnectionError("No connection string provided")
        
        try:
            print("Connecting to database...")
            # Check if connecting as SYS user - requires SYSDBA mode
            if self.connection_string.lower().startswith('sys/'):
                self._connection = oracledb.connect(
                    self.connection_string, 
                    mode=oracledb.AUTH_MODE_SYSDBA
                )
            else:
                self._connection = oracledb.connect(self.connection_string)
            print("✓ Connected successfully")
            yield self._connection
        except Exception as e:
            raise DatabaseConnectionError(f"Connection failed: {e}") from e
        finally:
            if self._connection:
                try:
                    self._connection.close()
                    print("✓ Database connection closed")
                except Exception:
                    # Ignore close errors during cleanup as they're not critical
                    pass


class ConfigService:
    """Handles configuration loading and validation"""
    
    def __init__(self, database_service: Optional[DatabaseService] = None):
        self.database_service = database_service
    
    def load_config(self, config_file: str) -> TypedMigrationConfig:
        """Load configuration from JSON file and deserialize to typed MigrationConfig"""
        config_path = Path(config_file)
        if not config_path.exists():
            raise ConfigurationError(f"Configuration file not found: {config_file}")
        
        try:
            print(f"Loading configuration: {config_file}")
            config = TypedMigrationConfig.from_json_file(config_file)
            
            print("✓ Configuration loaded")
            self._print_config_summary(config)
            return config
            
        except json.JSONDecodeError as e:
            raise ConfigurationError(f"Invalid JSON in {config_file}: {e}") from e
        except Exception as e:
            raise ConfigurationError(f"Failed to load configuration: {e}") from e
    
    def validate_config(self, config: TypedMigrationConfig, check_database: bool = False) -> bool:
        """Validate typed configuration"""
        print("\n" + "=" * 70)
        print("VALIDATION MODE")
        print("=" * 70 + "\n")
        
        connection = None
        # Convert typed config to dict for validator (validator expects dict)
        config_dict = config.to_dict()
        
        if check_database and self.database_service:
            try:
                with self.database_service.connection() as conn:
                    connection = conn
                    validator = ConfigValidator(connection)
                    is_valid, errors, warnings = validator.validate_config(config_dict, True)
                    return is_valid
            except DatabaseConnectionError:
                print("WARNING: Could not connect to database, skipping database validation")
                validator = ConfigValidator()
                is_valid, errors, warnings = validator.validate_config(config_dict, False)
                return is_valid
        
        validator = ConfigValidator()
        is_valid, errors, warnings = validator.validate_config(config_dict, False)
        return is_valid
    
    def _print_config_summary(self, config: TypedMigrationConfig) -> None:
        """Print configuration summary from typed config"""
        print(f"  Schema: {config.metadata.source_schema}")
        print(f"  Total tables: {config.metadata.total_tables_found}")
        print(f"  Enabled tables: {config.metadata.tables_selected_for_migration}")


class TemplateService:
    """Handles Jinja2 template rendering"""
    
    def __init__(self, template_dir: str):
        self.template_dir = Path(template_dir)
        self.jinja_env = Environment(
            loader=FileSystemLoader(str(self.template_dir), encoding='utf-8'),
            autoescape=select_autoescape(),
            trim_blocks=False,
            lstrip_blocks=False,
            keep_trailing_newline=True,
        )
        register_custom_filters(self.jinja_env)
    
    def render_template(self, template_name: str, context: Dict[str, Any], output_path: Path) -> bool:
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
    
    def __init__(self, config: MigrationConfig, schema: str, 
                 include_patterns: Optional[List[str]] = None,
                 exclude_patterns: Optional[List[str]] = None,
                 output_file: str = Constants.DEFAULT_CONFIG_FILE):
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
        
        database_service = DatabaseService(self.config.connection_string)
        # Prepare structured run directories under output/
        run_mgr = RunDirs(Path(self.config.output_dir))
        run_dir = run_mgr.load_current_full() or run_mgr.new_full_workflow_run()
        discovery_dir = run_dir / "01_discovery"
        
        try:
            with database_service.connection() as connection:
                discovery = TableDiscovery(connection, self.config.environment, self.config.connection_string)
                config = discovery.discover_schema(
                    self.schema, self.include_patterns, self.exclude_patterns
                )
                # Always save into 01_discovery with specified filename or default config.json
                output_name = Path(self.output_file).name if self.output_file else Constants.DEFAULT_CONFIG_FILE
                output_path = discovery_dir / output_name
                discovery.save_config(config, str(output_path))
                
                # Prominently display the config file location
                print(f"\n" + "=" * 80)
                print("✅ DISCOVERY COMPLETE!")
                print("=" * 80)
                print(f"📁 Run folder: {run_dir}")
                print(f"📄 CONFIG FILE: {output_path}")
                print("=" * 80)
                
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
        print(f"3. Validate: python3 generate_scripts.py --config {self.output_file} --validate-only")
        print(f"4. Generate: python3 generate_scripts.py --config {self.output_file}")
        print("=" * 70 + "\n")


class ValidationCommand(MigrationCommand):
    """Validation mode command"""
    
    def __init__(self, config: MigrationConfig, check_database: bool = False):
        self.config = config
        self.check_database = check_database
    
    def execute(self) -> bool:
        """Execute validation mode"""
        database_service = DatabaseService(self.config.connection_string) if self.config.connection_string else None
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
        
        database_service = DatabaseService(self.config.connection_string) if self.config.connection_string else None
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
    
        def _generate_scripts(self, config_data: TypedMigrationConfig, template_service: TemplateService) -> bool:
            """Generate migration scripts from typed configuration"""
        # Determine structured run directories
        base_output = Path(self.config.output_dir)
        run_mgr = RunDirs(base_output)
        full_run = run_mgr.load_current_full()
        if full_run:
            run_dir = full_run
            # Within full workflow, write generated DDL into staged folder
            output_dir = run_dir / "02_generated_ddl"
            output_dir.mkdir(parents=True, exist_ok=True)
            (run_dir / "logs").mkdir(parents=True, exist_ok=True)
        else:
            # Standalone generation run structure
            run_dir = run_mgr.load_current_simple() or run_mgr.new_generation_run()
            output_dir = run_dir / "generated_ddl"
            output_dir.mkdir(parents=True, exist_ok=True)
        print(f"Run folder: {run_dir}")
        print(f"Output directory: {output_dir}")

        # Persist effective config into the run's config/ folder for auditability
        try:
            config_dir = (run_dir / "config") if (run_dir / "config").exists() else (run_dir / "01_discovery")
            config_dir.mkdir(parents=True, exist_ok=True)
            cfg_name = "migration_config.json"
            cfg_path = config_dir / cfg_name
                config_data.save_to_file(str(cfg_path))
            print(f"Config snapshot: {cfg_path}")
        except Exception as e:
            print(f"WARNING: Could not save config snapshot: {e}")
        
            # Process each table using typed objects
            enabled_tables = [t for t in config_data.tables if t.enabled]
        
        print(f"\nProcessing {len(enabled_tables)} enabled table(s)...\n")
        
        success_count = 0
        for idx, table_config in enumerate(enabled_tables, 1):
                table_name = table_config.table_name
            print(f"[{idx}/{len(enabled_tables)}] Processing: {table_name}")
            
            try:
                if self._generate_table_scripts(table_config, template_service, output_dir):
                    success_count += 1
                    self.stats.tables_processed += 1
                else:
                    self.stats.errors += 1
            except Exception as e:
                print(f"  ✗ Error: {e}")
                self.stats.errors += 1
        
        self._print_generation_summary(success_count, len(enabled_tables), output_dir)
        return success_count == len(enabled_tables)
    
        def _generate_table_scripts(self, table_config: TableConfig, 
                               template_service: TemplateService, 
                               output_dir: Path) -> bool:
            """Generate scripts for a single table from typed config"""
            owner = table_config.owner
            table_name = table_config.table_name
        
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
                
                if template_service.render_template(template_name, context, output_path):
                    generated += 1
                    self.stats.scripts_generated += 1
            except Exception as e:
                print(f"  ✗ Failed to generate {template_name}: {e}")
                return False
        
        # Generate README
    self._generate_table_readme(table_config, table_dir)
        
        print(f"  ✓ Generated {generated} scripts")
        return True
    
    def _prepare_template_context(self, table: TableConfig) -> Dict[str, Any]:
        """Prepare template context from typed TableConfig"""
        owner = table.owner
        table_name = table.table_name
        target_config = table.common_settings.target_configuration
        current_state = table.current_state
        available_cols = current_state.available_columns
        
        # Extract column information from typed lists
        timestamp_cols = [c.name for c in available_cols.timestamp_columns]
        numeric_cols = [c.name for c in available_cols.numeric_columns]
        string_cols = [c.name for c in available_cols.string_columns]
        all_columns = [*timestamp_cols, *numeric_cols, *string_cols]
        
        # Normalize enums to string values for template compatibility
        def _val(x):
            return getattr(x, "value", x)
        
        target_cfg_dict = {
            "partition_type": _val(target_config.partition_type),
            "partition_column": target_config.partition_column,
            "interval_type": _val(target_config.interval_type),
            "interval_value": target_config.interval_value,
            "initial_partition_value": target_config.initial_partition_value,
            "subpartition_type": _val(target_config.subpartition_type),
            "subpartition_column": target_config.subpartition_column,
            "subpartition_count": target_config.subpartition_count,
            "tablespace": target_config.tablespace,
            "lob_tablespaces": target_config.lob_tablespaces,
            "parallel_degree": target_config.parallel_degree,
        }
        migration_action_value = _val(table.common_settings.migration_action)
        
        return {
            "table": table,  # give templates full typed access
            "owner": owner,
            "table_name": table_name,
            "new_table_name": table.common_settings.new_table_name,
            "old_table_name": table.common_settings.old_table_name,
            "target_configuration": target_cfg_dict,
            "current_state": current_state,
            "migration_action": migration_action_value,
            "migration_settings": table.common_settings.migration_settings,
            "environment_config": None,  # environment is at root; include if needed
            "columns": current_state.columns,
            "column_list": ", ".join(all_columns) if all_columns else "*",
            "primary_key_columns": target_cfg_dict.get("partition_column") or (all_columns[0] if all_columns else "ID"),
            "lob_storage": current_state.lob_storage,
            "storage_parameters": current_state.storage_parameters,
            "indexes": current_state.indexes,
            "grants": current_state.grants,
            "generation_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "cutoff_timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "available_columns": available_cols,
        }
    
    def _generate_table_readme(self, table_config: TableConfig, table_dir: Path) -> None:
        """Generate README for table migration scripts (typed)"""
        # Simplified README generation - could be extracted to a separate service
        owner = table_config.owner
        table_name = table_config.table_name
        
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
    
    def _print_generation_summary(self, success_count: int, total_count: int, output_dir: Path) -> None:
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
    mode_group.add_argument("--discover", "-d", action="store_true",
                           help="Discovery mode: Scan schema and generate config")
    mode_group.add_argument("--config", "-c", type=str,
                           help="Generation mode: Use JSON config file")
    
    # Common options
    parser.add_argument("--schema", "-s", type=str, help="Schema name")
    parser.add_argument("--connection", type=str, help="Oracle connection string: user/password@host:port/service")
    parser.add_argument("--template-dir", default=Constants.DEFAULT_TEMPLATE_DIR,
                       help="Template directory")
    parser.add_argument("--output-dir", default=Constants.DEFAULT_OUTPUT_DIR,
                       help="Output directory")
    parser.add_argument("--output-file", default=Constants.DEFAULT_CONFIG_FILE,
                       help="[OPTIONAL] Config filename only (no paths allowed). Defaults to 'config.json'")
    parser.add_argument("--environment", type=str, help="Environment name")
    parser.add_argument("--validate-only", action="store_true",
                       help="Only validate configuration")
    parser.add_argument("--check-database", action="store_true",
                       help="Validate config against database")
    
    # Additional discovery options
    parser.add_argument("--include", type=str, nargs="+",
                       help="Table name patterns to include")
    parser.add_argument("--exclude", type=str, nargs="+",
                       help="Table name patterns to exclude")
    
    args = parser.parse_args()
    
    # Validate arguments
    if args.discover and not args.schema:
        parser.error("--discover requires --schema")
    if args.discover and not args.connection:
        parser.error("--discover requires --connection")
    if args.check_database and not args.connection:
        parser.error("--check-database requires --connection")
    
    # Validate output-file is just a filename, not a path
    if args.output_file and ('/' in args.output_file or '\\' in args.output_file):
        parser.error("--output-file must be just a filename (no paths). Use 'config.json' not 'path/config.json'")
    
    # Create and run command
    command = create_command(args)
    generator = MigrationScriptGenerator(MigrationConfig())
    success = generator.run(command)
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
