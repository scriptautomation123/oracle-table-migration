#!/usr/bin/env python3
"""
POC Generation System - Refactored Version
==========================================
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
from typing import Any, Dict, Generator, List, Optional, Protocol

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

from lib.poc_data_sampling import POCDataSampling
from lib.poc_ddl_generator import POCDDLGenerator
from lib.poc_migration_tester import POCMigrationTester

# Local imports
from lib.poc_schema_discovery import POCSchemaDiscovery


# Constants
class Constants:
    DEFAULT_TEMPLATE_DIR = "templates"
    DEFAULT_OUTPUT_DIR = "poc_output"
    DEFAULT_SAMPLE_PERCENTAGE = 10
    DEFAULT_SAMPLE_STRATEGY = "random"

    EXECUTION_SCRIPTS = [
        "01_cleanup_target.sql",
        "02_create_schema.sql",
        "03_load_sample_data.sql",
        "04_create_constraints.sql",
        "05_create_indexes.sql",
        "06_run_migration.sql",
        "07_validate_results.sql",
        "08_cleanup.sql",
    ]


# Custom Exceptions
class POCError(Exception):
    """Base exception for POC operations"""

    pass


class DatabaseConnectionError(POCError):
    """Database connection related errors"""

    pass


class ConfigurationError(POCError):
    """Configuration related errors"""

    pass


class POCGenerationError(POCError):
    """POC generation related errors"""

    pass


# Data Classes
@dataclass
class POCConfig:
    """Configuration for POC operations"""

    schema_connection: Optional[str] = None
    data_connection: Optional[str] = None
    target_connection: Optional[str] = None
    template_dir: str = Constants.DEFAULT_TEMPLATE_DIR
    output_dir: str = Constants.DEFAULT_OUTPUT_DIR


@dataclass
class POCStats:
    """Statistics for POC operations"""

    tables_discovered: int = 0
    tables_sampled: int = 0
    ddl_scripts_generated: int = 0
    data_scripts_generated: int = 0
    migration_scripts_generated: int = 0
    errors: int = 0


# Protocols for Dependency Injection
class DatabaseServiceProtocol(Protocol):
    def get_schema_connection(self) -> Any: ...
    def get_data_connection(self) -> Any: ...
    def get_target_connection(self) -> Any: ...


class SchemaDiscoveryProtocol(Protocol):
    def discover_schema(
        self, schema_name: str, include_patterns: List[str], exclude_patterns: List[str]
    ) -> Dict[str, Any]: ...


class DataSamplingProtocol(Protocol):
    def sample_data(
        self,
        schema_info: Dict[str, Any],
        sample_percentage: int,
        sample_strategy: str,
        preserve_referential_integrity: bool,
    ) -> Dict[str, Any]: ...


# Service Implementations
class DatabaseConnectionService:
    """Handles database connections and operations"""

    def __init__(self, config: POCConfig):
        self.config = config
        self._schema_conn: Optional[Any] = None
        self._data_conn: Optional[Any] = None
        self._target_conn: Optional[Any] = None

    @contextmanager
    def schema_connection(self) -> Generator[Any, None, None]:
        """Context manager for schema database connection"""
        if not self.config.schema_connection:
            raise DatabaseConnectionError("No schema connection string provided")

        try:
            print("Connecting to schema source database...")
            self._schema_conn = oracledb.connect(self.config.schema_connection)
            print("✓ Schema source connected")
            yield self._schema_conn
        except Exception as e:
            raise DatabaseConnectionError(
                f"Schema source connection failed: {e}"
            ) from e
        finally:
            if self._schema_conn:
                try:
                    self._schema_conn.close()
                    print("✓ Schema connection closed")
                except Exception:
                    # Suppress close errors as they're not critical
                    pass

    @contextmanager
    def data_connection(self) -> Generator[Any, None, None]:
        """Context manager for data database connection"""
        if not self.config.data_connection:
            raise DatabaseConnectionError("No data connection string provided")

        try:
            print("Connecting to data source database...")
            self._data_conn = oracledb.connect(self.config.data_connection)
            print("✓ Data source connected")
            yield self._data_conn
        except Exception as e:
            raise DatabaseConnectionError(f"Data source connection failed: {e}") from e
        finally:
            if self._data_conn:
                try:
                    self._data_conn.close()
                    print("✓ Data connection closed")
                except Exception:
                    # Suppress close errors as they're not critical
                    pass

    @contextmanager
    def target_connection(self) -> Generator[Any, None, None]:
        """Context manager for target database connection"""
        if not self.config.target_connection:
            raise DatabaseConnectionError("No target connection string provided")

        try:
            print("Connecting to target database...")
            self._target_conn = oracledb.connect(self.config.target_connection)
            print("✓ Target connected")
            yield self._target_conn
        except Exception as e:
            raise DatabaseConnectionError(f"Target connection failed: {e}") from e
        finally:
            if self._target_conn:
                try:
                    self._target_conn.close()
                    print("✓ Target connection closed")
                except Exception:
                    # Suppress close errors as they're not critical
                    pass


class ConfigurationService:
    """Handles configuration loading and validation"""

    def load_schema_config(self, config_file: str) -> Dict[str, Any]:
        """Load schema configuration from JSON file"""
        return self._load_config(config_file, "schema configuration")

    def load_data_config(self, config_file: str) -> Dict[str, Any]:
        """Load data configuration from JSON file"""
        return self._load_config(config_file, "data configuration")

    def load_poc_config(self, config_file: str) -> Dict[str, Any]:
        """Load POC configuration from JSON file"""
        return self._load_config(config_file, "POC configuration")

    def _load_config(self, config_file: str, config_type: str) -> Dict[str, Any]:
        """Generic configuration loader"""
        try:
            with open(config_file, "r") as f:
                config = json.load(f)
            print(f"✓ Loaded {config_type}: {config_file}")
            return config
        except Exception as e:
            raise ConfigurationError(f"Failed to load {config_type}: {e}") from e


class SchemaDiscoveryService:
    """Handles schema discovery operations"""

    def __init__(self, database_service: DatabaseConnectionService):
        self.database_service = database_service

    def discover_schema(
        self, schema_name: str, include_patterns: List[str], exclude_patterns: List[str]
    ) -> Dict[str, Any]:
        """Discover schema information"""
        with self.database_service.schema_connection() as connection:
            discovery = POCSchemaDiscovery(connection)
            return discovery.discover_schema(
                schema_name, include_patterns, exclude_patterns
            )


class DataSamplingService:
    """Handles data sampling operations"""

    def __init__(self, database_service: DatabaseConnectionService):
        self.database_service = database_service

    def sample_data(
        self,
        schema_info: Dict[str, Any],
        sample_percentage: int,
        sample_strategy: str,
        preserve_referential_integrity: bool,
    ) -> Dict[str, Any]:
        """Sample data from source database"""
        with self.database_service.data_connection() as connection:
            sampling = POCDataSampling(connection)
            return sampling.sample_data(
                schema_info,
                sample_percentage,
                sample_strategy,
                preserve_referential_integrity,
            )


class DDLGenerationService:
    """Handles DDL script generation"""

    def __init__(self, template_dir: str, output_dir: Path):
        self.template_dir = Path(template_dir)
        self.output_dir = output_dir
        self.jinja_env = Environment(
            loader=FileSystemLoader(str(self.template_dir), encoding="utf-8"),
            autoescape=select_autoescape(),
            trim_blocks=False,
            lstrip_blocks=False,
            keep_trailing_newline=True,
        )

    def generate_ddl_scripts(
        self, schema_info: Dict[str, Any], target_schema: str, cleanup_existing: bool
    ) -> List[str]:
        """Generate DDL scripts"""
        generator = POCDDLGenerator(self.jinja_env, self.output_dir)
        return generator.generate_ddl_scripts(
            schema_info, target_schema, cleanup_existing
        )

    def generate_data_scripts(self, sample_data: Dict[str, Any]) -> List[str]:
        """Generate data loading scripts"""
        generator = POCDDLGenerator(self.jinja_env, self.output_dir)
        return generator.generate_data_scripts(sample_data)


class POCExecutionService:
    """Handles POC test execution"""

    def __init__(self, database_service: DatabaseConnectionService, output_dir: Path):
        self.database_service = database_service
        self.output_dir = output_dir

    def execute_poc_test(self, poc_config: Dict[str, Any]) -> bool:
        """Execute POC test cycle"""
        with self.database_service.target_connection() as connection:
            tester = POCMigrationTester(connection, self.output_dir)
            return tester.execute_poc_test(poc_config)


# Command Pattern for POC Operations
class POCCommand(ABC):
    """Abstract base class for POC commands"""

    @abstractmethod
    def execute(self) -> bool:
        """Execute the command"""
        pass


class SchemaOnlyPOCCommand(POCCommand):
    """Generate POC from schema configuration only"""

    def __init__(self, config: POCConfig, schema_config_file: str):
        self.config = config
        self.schema_config_file = schema_config_file
        self.stats = POCStats()

    def execute(self) -> bool:
        """Execute schema-only POC generation"""
        print("\n" + "=" * 70)
        print("POC GENERATION FROM SCHEMA CONFIG")
        print("=" * 70 + "\n")

        try:
            # Initialize services
            database_service = DatabaseConnectionService(self.config)
            config_service = ConfigurationService()
            schema_service = SchemaDiscoveryService(database_service)
            ddl_service = DDLGenerationService(
                self.config.template_dir, self.config.output_dir
            )

            # Load configuration
            schema_config = config_service.load_schema_config(self.schema_config_file)

            # Create output directory
            self.config.output_dir.mkdir(parents=True, exist_ok=True)
            print(f"Output directory: {self.config.output_dir}")

            # Execute steps
            schema_info = self._discover_schema(schema_service, schema_config)
            self._generate_ddl(ddl_service, schema_info, schema_config)
            poc_config = self._generate_poc_config(schema_info, schema_config)
            self._save_poc_config(poc_config)

            self._print_completion_summary()
            return True

        except Exception as e:
            print(f"\n✗ POC generation failed: {e}")
            return False

    def _discover_schema(
        self, schema_service: SchemaDiscoveryService, schema_config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Discover schema information"""
        print("\nStep 1: Discovering schema...")
        schema_info = schema_service.discover_schema(
            schema_config.get("source_schema"),
            schema_config.get("include_patterns", []),
            schema_config.get("exclude_patterns", []),
        )
        self.stats.tables_discovered = len(schema_info.get("tables", []))
        return schema_info

    def _generate_ddl(
        self,
        ddl_service: DDLGenerationService,
        schema_info: Dict[str, Any],
        schema_config: Dict[str, Any],
    ) -> None:
        """Generate DDL scripts"""
        print("\nStep 2: Generating DDL...")
        ddl_scripts = ddl_service.generate_ddl_scripts(
            schema_info,
            schema_config.get("target_schema"),
            schema_config.get("cleanup_existing", True),
        )
        self.stats.ddl_scripts_generated = len(ddl_scripts)

    def _generate_poc_config(
        self, schema_info: Dict[str, Any], schema_config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Generate POC configuration"""
        print("\nStep 3: Generating POC configuration...")
        return {
            "metadata": {
                "generated_date": datetime.now().isoformat(),
                "poc_type": "schema_only",
                "source_schema": schema_config.get("source_schema"),
                "target_schema": schema_config.get("target_schema"),
                "tables_count": len(schema_info.get("tables", [])),
            },
            "schema_info": schema_info,
            "sample_data": None,
            "execution_scripts": Constants.EXECUTION_SCRIPTS,
        }

    def _save_poc_config(self, poc_config: Dict[str, Any]) -> None:
        """Save POC configuration to file"""
        poc_config_file = self.config.output_dir / "poc-config.json"
        with open(poc_config_file, "w") as f:
            json.dump(poc_config, f, indent=2)
        print(f"✓ Generated POC configuration: {poc_config_file}")

    def _print_completion_summary(self) -> None:
        """Print completion summary"""
        print("\n" + "=" * 70)
        print("POC GENERATION COMPLETE")
        print("=" * 70)
        print(f"Tables discovered: {self.stats.tables_discovered}")
        print(f"DDL scripts generated: {self.stats.ddl_scripts_generated}")
        print(f"Output directory: {self.config.output_dir}")
        print("=" * 70 + "\n")


class DataSamplingPOCCommand(POCCommand):
    """Generate POC with data sampling"""

    def __init__(
        self, config: POCConfig, schema_config_file: str, data_config_file: str
    ):
        self.config = config
        self.schema_config_file = schema_config_file
        self.data_config_file = data_config_file
        self.stats = POCStats()

    def execute(self) -> bool:
        """Execute POC generation with data sampling"""
        print("\n" + "=" * 70)
        print("POC GENERATION WITH DATA SAMPLING")
        print("=" * 70 + "\n")

        try:
            # Initialize services
            database_service = DatabaseConnectionService(self.config)
            config_service = ConfigurationService()
            schema_service = SchemaDiscoveryService(database_service)
            data_service = DataSamplingService(database_service)
            ddl_service = DDLGenerationService(
                self.config.template_dir, self.config.output_dir
            )

            # Load configurations
            schema_config = config_service.load_schema_config(self.schema_config_file)
            data_config = config_service.load_data_config(self.data_config_file)

            # Create output directory
            self.config.output_dir.mkdir(parents=True, exist_ok=True)

            # Execute steps
            schema_info = self._discover_schema(schema_service, schema_config)
            sample_data = self._sample_data(data_service, schema_info, data_config)
            self._generate_ddl(ddl_service, schema_info, schema_config)
            self._generate_data_scripts(ddl_service, sample_data)
            poc_config = self._generate_poc_config(
                schema_info, schema_config, sample_data
            )
            self._save_poc_config(poc_config)

            self._print_completion_summary()
            return True

        except Exception as e:
            print(f"\n✗ POC generation failed: {e}")
            return False

    def _discover_schema(
        self, schema_service: SchemaDiscoveryService, schema_config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Discover schema information"""
        print("\nStep 1: Discovering schema...")
        schema_info = schema_service.discover_schema(
            schema_config.get("source_schema"),
            schema_config.get("include_patterns", []),
            schema_config.get("exclude_patterns", []),
        )
        self.stats.tables_discovered = len(schema_info.get("tables", []))
        return schema_info

    def _sample_data(
        self,
        data_service: DataSamplingService,
        schema_info: Dict[str, Any],
        data_config: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Sample data from source database"""
        print("\nStep 2: Sampling data...")
        sample_data = data_service.sample_data(
            schema_info,
            data_config.get("sample_percentage", Constants.DEFAULT_SAMPLE_PERCENTAGE),
            data_config.get("sample_strategy", Constants.DEFAULT_SAMPLE_STRATEGY),
            data_config.get("preserve_referential_integrity", True),
        )
        self.stats.tables_sampled = len(sample_data.get("tables", []))
        return sample_data

    def _generate_ddl(
        self,
        ddl_service: DDLGenerationService,
        schema_info: Dict[str, Any],
        schema_config: Dict[str, Any],
    ) -> None:
        """Generate DDL scripts"""
        print("\nStep 3: Generating DDL...")
        ddl_scripts = ddl_service.generate_ddl_scripts(
            schema_info,
            schema_config.get("target_schema"),
            schema_config.get("cleanup_existing", True),
        )
        self.stats.ddl_scripts_generated = len(ddl_scripts)

    def _generate_data_scripts(
        self, ddl_service: DDLGenerationService, sample_data: Dict[str, Any]
    ) -> None:
        """Generate data loading scripts"""
        print("\nStep 4: Generating data loading scripts...")
        data_scripts = ddl_service.generate_data_scripts(sample_data)
        self.stats.data_scripts_generated = len(data_scripts)

    def _generate_poc_config(
        self,
        schema_info: Dict[str, Any],
        schema_config: Dict[str, Any],
        sample_data: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Generate POC configuration"""
        print("\nStep 5: Generating POC configuration...")
        return {
            "metadata": {
                "generated_date": datetime.now().isoformat(),
                "poc_type": "with_data",
                "source_schema": schema_config.get("source_schema"),
                "target_schema": schema_config.get("target_schema"),
                "tables_count": len(schema_info.get("tables", [])),
            },
            "schema_info": schema_info,
            "sample_data": sample_data,
            "execution_scripts": Constants.EXECUTION_SCRIPTS,
        }

    def _save_poc_config(self, poc_config: Dict[str, Any]) -> None:
        """Save POC configuration to file"""
        poc_config_file = self.config.output_dir / "poc-config.json"
        with open(poc_config_file, "w") as f:
            json.dump(poc_config, f, indent=2)
        print(f"✓ Generated POC configuration: {poc_config_file}")

    def _print_completion_summary(self) -> None:
        """Print completion summary"""
        print("\n" + "=" * 70)
        print("POC GENERATION WITH DATA COMPLETE")
        print("=" * 70)
        print(f"Tables discovered: {self.stats.tables_discovered}")
        print(f"Tables sampled: {self.stats.tables_sampled}")
        print(f"DDL scripts generated: {self.stats.ddl_scripts_generated}")
        print(f"Data scripts generated: {self.stats.data_scripts_generated}")
        print(f"Output directory: {self.config.output_dir}")
        print("=" * 70 + "\n")


class POCExecutionCommand(POCCommand):
    """Execute POC test cycle"""

    def __init__(self, config: POCConfig, poc_config_file: str):
        self.config = config
        self.poc_config_file = poc_config_file

    def execute(self) -> bool:
        """Execute POC test cycle"""
        print("\n" + "=" * 70)
        print("POC TEST EXECUTION")
        print("=" * 70 + "\n")

        try:
            # Initialize services
            database_service = DatabaseConnectionService(self.config)
            config_service = ConfigurationService()
            execution_service = POCExecutionService(
                database_service, self.config.output_dir
            )

            # Load POC configuration
            poc_config = config_service.load_poc_config(self.poc_config_file)

            # Execute POC test
            success = execution_service.execute_poc_test(poc_config)

            if success:
                print("\n✓ POC test execution completed successfully")
            else:
                print("\n✗ POC test execution failed")

            return success

        except Exception as e:
            print(f"\n✗ POC test execution failed: {e}")
            return False


# Main Application
class POCGenerator:
    """Main application class - simplified and focused"""

    def __init__(self, config: POCConfig):
        self.config = config

    def run(self, command: POCCommand) -> bool:
        """Run a POC command"""
        try:
            return command.execute()
        except Exception as e:
            print(f"Unexpected error: {e}")
            return False


def create_command(args: argparse.Namespace) -> POCCommand:
    """Factory function to create appropriate command"""
    config = POCConfig(
        schema_connection=args.schema_connection,
        data_connection=args.data_connection,
        target_connection=args.target_connection,
        template_dir=args.template_dir,
        output_dir=Path(args.output_dir),
    )

    if args.schema_config:
        if args.data_config:
            return DataSamplingPOCCommand(config, args.schema_config, args.data_config)
        else:
            return SchemaOnlyPOCCommand(config, args.schema_config)
    elif args.poc_config:
        return POCExecutionCommand(config, args.poc_config)
    else:
        raise ValueError("No valid command specified")


def main() -> None:
    """Main entry point - simplified"""
    parser = argparse.ArgumentParser(
        description="Generate POC environments for testing Oracle table migration scripts",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    # Mode selection
    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument(
        "--schema-config", type=str, help="Generate POC from schema configuration"
    )
    mode_group.add_argument(
        "--poc-config", type=str, help="Execute POC test from configuration"
    )

    # Data sampling
    parser.add_argument("--data-config", type=str, help="Data sampling configuration")

    # Database connections
    parser.add_argument(
        "--schema-connection", type=str, help="Schema source database connection"
    )
    parser.add_argument(
        "--data-connection", type=str, help="Data source database connection"
    )
    parser.add_argument(
        "--target-connection", type=str, help="Target database connection"
    )

    # Output options
    parser.add_argument(
        "--output-dir",
        default=Constants.DEFAULT_OUTPUT_DIR,
        help="Output directory for POC files",
    )
    parser.add_argument(
        "--template-dir",
        default=Constants.DEFAULT_TEMPLATE_DIR,
        help="Template directory",
    )

    # Execution options
    parser.add_argument("--execute", action="store_true", help="Execute POC test cycle")

    args = parser.parse_args()

    # Validate arguments
    if args.schema_config and not args.schema_connection:
        parser.error("--schema-config requires --schema-connection")
    if args.data_config and not args.data_connection:
        parser.error("--data-config requires --data-connection")
    if args.poc_config and not args.target_connection:
        parser.error("--poc-config requires --target-connection")

    # Create and run command
    command = create_command(args)
    generator = POCGenerator(POCConfig())
    success = generator.run(command)

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
