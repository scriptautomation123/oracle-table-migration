#!/usr/bin/env python3
"""
Oracle Table Migration Generator - Unified Entry Point
=====================================================
Consolidated migration script generator combining all previous implementations.

This is the single entry point for generating Oracle table re-partitioning migrations.
"""

import argparse
import json
import sys
import os
from contextlib import contextmanager
from dataclasses import dataclass, asdict
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

# Oracle database import
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
from lib.discovery_queries import TableDiscovery
from lib.migration_models import *
from lib.template_filters import get_template_filters
from lib.config_validator import ConfigValidator


class MigrationError(Exception):
    """Base exception for migration-related errors"""
    pass


class ConfigError(MigrationError):
    """Configuration validation errors"""
    pass


class TemplateError(MigrationError):
    """Template rendering errors"""
    pass


class DatabaseConnectionError(MigrationError):
    """Database connection related errors"""
    pass


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
            
            # Handle SYSDBA connections
            if "as sysdba" in self.connection_string.lower():
                # Parse connection string for SYSDBA
                conn_str = self.connection_string.replace(" as sysdba", "").replace(" as SYSDBA", "")
                self._connection = oracledb.connect(conn_str, mode=oracledb.AUTH_MODE_SYSDBA)
            else:
                self._connection = oracledb.connect(self.connection_string)
                
            print("✓ Connected successfully")
            yield self._connection
        except Exception as e:
            raise DatabaseConnectionError(f"Connection failed: {e}") from e
        finally:
            if self._connection:
                self._connection.close()
                print("✓ Database connection closed")


@dataclass
class GenerationConfig:
    """Configuration for migration generation"""
    config_file: str
    output_dir: str
    template_dir: str = "templates"
    validate_only: bool = False
    verbose: bool = False
    force: bool = False


class MigrationGenerator:
    """Main migration generator class"""
    
    def __init__(self, config: GenerationConfig):
        self.config = config
        self.validator = ConfigValidator()
        self.setup_jinja()
    
    def setup_jinja(self):
        """Initialize Jinja2 environment with custom filters"""
        self.jinja_env = Environment(
            loader=FileSystemLoader(self.config.template_dir),
            autoescape=select_autoescape(['html', 'xml']),
            trim_blocks=True,
            lstrip_blocks=True
        )
        
        # Add custom filters
        filters = get_template_filters()
        self.jinja_env.filters.update(filters)
    
    def load_config(self) -> Dict[str, Any]:
        """Load and validate migration configuration"""
        try:
            with open(self.config.config_file, 'r') as f:
                config_data = json.load(f)
            
            if not self.config.validate_only:
                # Full validation during generation
                is_valid, errors, warnings = self.validator.validate_config(config_data)
                if not is_valid:
                    raise ConfigError(f"Configuration validation failed: {errors}")
            
            return config_data
            
        except FileNotFoundError:
            raise ConfigError(f"Configuration file not found: {self.config.config_file}")
        except json.JSONDecodeError as e:
            raise ConfigError(f"Invalid JSON in configuration file: {e}")
    
    def generate_migration_scripts(self, config_data: Dict[str, Any]) -> bool:
        """Generate all migration scripts from configuration"""
        try:
            # Create output directory
            output_path = Path(self.config.output_dir)
            output_path.mkdir(parents=True, exist_ok=True)
            
            # Process each table individually
            tables = config_data.get('tables', [])
            if not tables:
                raise ConfigError("No tables found in configuration")
            
            for table_config in tables:
                if not table_config.get('enabled', True):
                    continue
                    
                table_name = table_config.get('table_name')
                owner = table_config.get('owner')
                
                if self.config.verbose:
                    print(f"Processing table: {owner}.{table_name}")
                
                # Create table-specific output directory
                table_output_path = output_path / f"{owner}_{table_name}"
                table_output_path.mkdir(parents=True, exist_ok=True)
                
                # Create context for this table by flattening the table config
                table_context = {
                    **config_data,  # Include metadata and environment_config
                    **table_config,  # Include table-specific data
                    **table_config.get('current_state', {}),  # Flatten current_state
                    **table_config.get('common_settings', {}),  # Flatten common_settings
                    'generation_date': config_data.get('metadata', {}).get('generated_date', ''),
                    'owner': owner,
                    'table_name': table_name
                }
                
                # Generate each template for this table
                templates = [
                    'master1.sql.j2',
                    '10_create_table.sql.j2',
                    '20_data_load.sql.j2', 
                    '30_create_indexes.sql.j2',
                    '40_delta_load.sql.j2',
                    '50_swap_tables.sql.j2',
                    '60_restore_grants.sql.j2',
                    '70_drop_old_table.sql.j2',
                    'dynamic_grants.sql.j2'
                ]
                
                for template_name in templates:
                    if self.config.verbose:
                        print(f"  Generating {template_name} for {table_name}...")
                    
                    try:
                        template = self.jinja_env.get_template(template_name)
                        content = template.render(**table_context)
                        
                        # Write output file
                        output_file = table_output_path / template_name.replace('.j2', '')
                        with open(output_file, 'w') as f:
                            f.write(content)
                            
                    except Exception as e:
                        raise TemplateError(f"Error rendering {template_name} for table {table_name}: {e}")
                
                # Generate table-specific README
                self.generate_table_readme(table_output_path, table_context)
            
            # Generate main README
            self.generate_main_readme(output_path, config_data)
            
            return True
            
        except Exception as e:
            if self.config.verbose:
                import traceback
                traceback.print_exc()
            raise MigrationError(f"Generation failed: {e}")
    
    def generate_table_readme(self, output_path: Path, table_context: Dict[str, Any]):
        """Generate README file for a specific table migration"""
        table_name = table_context.get('table_name', 'Unknown Table')
        owner = table_context.get('owner', 'Unknown Owner')
        
        readme_content = f"""# Migration Scripts for {owner}.{table_name}

Generated on: {datetime.now().isoformat()}

## Files Generated:
- `master1.sql` - **MAIN SCRIPT** - Complete migration (run this only)
- `10_create_table.sql` - Create new partitioned table
- `20_data_load.sql` - Migrate data (if enabled)
- `30_create_indexes.sql` - Recreate indexes
- `40_delta_load.sql` - Delta load script (if enabled)
- `50_swap_tables.sql` - Atomic table swap
- `60_restore_grants.sql` - Restore grants
- `70_drop_old_table.sql` - Drop old table (manual step)
- `dynamic_grants.sql` - Backup grants script

## Usage:
1. Review the generated scripts
2. Connect to Oracle database as appropriate user
3. Execute: `@master1.sql`
4. Validate results
5. Optionally run: `@70_drop_old_table.sql` (after verification)

## Migration Details:
- **Source Table**: {owner}.{table_name}
- **Target Table**: {owner}.{table_context.get('new_table_name', table_name + '_NEW')}
- **Migration Action**: {table_context.get('migration_action', 'Unknown')}
- **Current Size**: {table_context.get('size_gb', 0)} GB
- **Row Count**: {table_context.get('row_count', 0):,} rows
- **Current Partitioning**: {table_context.get('partition_type', 'NONE')}
- **Target Partitioning**: {table_context.get('target_configuration', {}).get('partition_type', 'Unknown')}

## Important Notes:
- **CRITICAL**: master1.sql should run completely without manual intervention
- All steps are included in master1.sql for zero-downtime migration
- Review scripts before execution in production
- Keep backups before running migration
"""
        
        with open(output_path / 'README.md', 'w') as f:
            f.write(readme_content)

    def generate_main_readme(self, output_path: Path, config_data: Dict[str, Any]):
        """Generate main README file for all migrations"""
        tables = config_data.get('tables', [])
        enabled_tables = [t for t in tables if t.get('enabled', True)]
        
        readme_content = f"""# Oracle Table Migration Scripts

Generated on: {datetime.now().isoformat()}
Environment: {config_data.get('environment_config', {}).get('name', 'Unknown')}
Source Schema: {config_data.get('metadata', {}).get('source_schema', 'Unknown')}

## Tables Processed: {len(enabled_tables)}

"""
        
        for table in enabled_tables:
            owner = table.get('owner', 'Unknown')
            table_name = table.get('table_name', 'Unknown')
            migration_action = table.get('common_settings', {}).get('migration_action', 'Unknown')
            readme_content += f"""### {owner}.{table_name}
- **Directory**: `{owner}_{table_name}/`
- **Migration Type**: {migration_action}
- **Main Script**: `{owner}_{table_name}/master1.sql`

"""
        
        readme_content += """## Usage Instructions:

1. **Navigate to each table directory**
2. **Review the table-specific README.md**
3. **Execute the master1.sql script for each table**

Example:
```bash
cd APP_DATA_OWNER_ORDERS/
sqlplus user/pass@db @master1.sql

cd APP_DATA_OWNER_CUSTOMERS/  
sqlplus user/pass@db @master1.sql
```

## Directory Structure:
```
├── README.md (this file)
├── SCHEMA_TABLE1/
│   ├── README.md
│   ├── master1.sql ⭐ (MAIN SCRIPT)
│   ├── 10_create_table.sql
│   ├── 20_data_load.sql
│   └── ... (other scripts)
└── SCHEMA_TABLE2/
    ├── README.md  
    ├── master1.sql ⭐ (MAIN SCRIPT)
    └── ... (other scripts)
```

**CRITICAL**: Each master1.sql should run completely without manual intervention.
"""
        
        with open(output_path / 'README.md', 'w') as f:
            f.write(readme_content)


def add_discovery_validation_hash(config, output_file: str):
    """Add validation hash to mark config as discovery-generated"""
    import hashlib
    
    # Create unique hash based on discovery metadata
    generated_date = config.metadata.generated_date
    source_schema = config.metadata.source_schema  
    source_db = config.metadata.source_database_service
    
    hash_content = f"DISCOVERY_{generated_date}_{source_schema}_{source_db}"
    validation_hash = hashlib.md5(hash_content.encode()).hexdigest()
    
    # Add to metadata (modify the dataclass instance)
    config.metadata.discovery_validation_hash = validation_hash
    print(f"✓ Added discovery validation hash: {validation_hash[:8]}...")


def validate_config_is_generated(config_file: str, verbose: bool = False) -> bool:
    """
    Validate that the config.json was generated by discovery process
    
    Checks for discovery_validation_hash field that's only added during discovery
    """
    try:
        if not Path(config_file).exists():
            if verbose:
                print(f"❌ Config file not found: {config_file}")
            return False
            
        with open(config_file, 'r') as f:
            config_data = json.load(f)
        
        metadata = config_data.get('metadata', {})
        
        # Check for discovery validation hash - only added during discovery
        discovery_hash = metadata.get('discovery_validation_hash')
        if not discovery_hash:
            if verbose:
                print("❌ Config missing discovery_validation_hash - not generated by discovery")
            return False
            
        # Check if hash matches expected pattern (timestamp + schema + connection)
        generated_date = metadata.get('generated_date', '')
        source_schema = metadata.get('source_schema', '')
        source_db = metadata.get('source_database_service', '')
        
        # Reconstruct expected hash
        import hashlib
        expected_content = f"DISCOVERY_{generated_date}_{source_schema}_{source_db}"
        expected_hash = hashlib.md5(expected_content.encode()).hexdigest()
        
        if discovery_hash != expected_hash:
            if verbose:
                print("❌ Config discovery_validation_hash invalid - config may be manually created")
            return False
            
        if verbose:
            print("✅ Config validated as discovery-generated")
        return True
        
    except (json.JSONDecodeError, FileNotFoundError, KeyError) as e:
        if verbose:
            print(f"❌ Config validation error: {e}")
        return False


def run_discovery_mode(args) -> int:
    """Run discovery mode to generate config from database schema"""
    print("\n" + "=" * 70)
    print("DISCOVERY MODE")
    print("=" * 70 + "\n")
    
    database_service = DatabaseService(args.connection)
    
    try:
        with database_service.connection() as connection:
            discovery = TableDiscovery(connection, args.environment, args.connection)
            config = discovery.discover_schema(
                args.schema, args.include, args.exclude
            )
            discovery.save_config(config, args.output_file)
            
            # Print next steps like generate_scripts.py does
            print("\n" + "=" * 70)
            print("NEXT STEPS:")
            print("=" * 70)
            print(f"1. Review and edit: {args.output_file}")
            print("2. Customize settings:")
            print("   - Enable/disable tables (set 'enabled': true/false)")
            print("   - Choose partition column")
            print("   - Choose interval type (HOUR/DAY/WEEK/MONTH)")
            print("   - Choose hash subpartition column")
            print("   - Adjust hash subpartition count")
            print(f"3. Validate: python3 src/generate.py --config {args.output_file} --validate-only")
            print(f"4. Generate: python3 src/generate.py --config {args.output_file}")
            print("=" * 70 + "\n")
            
            return 0
    except Exception as e:
        print(f"\n✗ Discovery failed: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1


def run_generation_mode(args) -> int:
    """Run generation/validation mode with existing config"""
    # TODO: Add discovery validation back after discovery is working
    # if not args.ignore_discovery_requirement:
    #     if not validate_config_is_generated(args.config, args.verbose):
    #         print("❌ Config validation failed - not generated by discovery")
    #         return 1
    
    # Create configuration
    config = GenerationConfig(
        config_file=args.config,
        output_dir=args.output_dir,
        template_dir=args.template_dir,
        validate_only=args.validate_only,
        verbose=args.verbose,
        force=args.force
    )
    
    generator = MigrationGenerator(config)
    config_data = generator.load_config()
    
    # Validation with optional database check
    if args.validate_only:
        print("\n" + "=" * 70)
        print("VALIDATION MODE")
        print("=" * 70 + "\n")
        
        # Database validation if connection provided
        if args.check_database and args.connection:
            database_service = DatabaseService(args.connection)
            try:
                with database_service.connection() as conn:
                    # Enhanced validation with database connection
                    from lib.config_validator import ConfigValidator
                    validator = ConfigValidator(conn)
                    is_valid, errors, warnings = validator.validate_config(config_data, True)
                    if is_valid:
                        print(f"✅ Configuration {args.config} is valid (database validated)")
                        return 0
                    else:
                        print(f"❌ Configuration validation failed")
                        return 1
            except DatabaseConnectionError:
                print("WARNING: Could not connect to database, skipping database validation")
                print(f"✅ Configuration {args.config} is valid (schema only)")
                return 0
        else:
            print(f"✅ Configuration {args.config} is valid")
            return 0
    
    # Generation mode
    print("\n" + "=" * 70)
    print("GENERATION MODE")
    print("=" * 70 + "\n")
    
    if generator.generate_migration_scripts(config_data):
        print(f"✅ Migration scripts generated successfully in {args.output_dir}")
        return 0
    else:
        print("❌ Script generation failed")
        return 1


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Oracle table re-partitioning migration generator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Discovery mode - generate config from database
  %(prog)s --discover --schema APP_DATA_OWNER --connection "user/pass@host:1521/service" --output-file discovered_config.json
  
  # Generation mode - generate scripts from config  
  %(prog)s --config examples/configs/migration_config.json
  %(prog)s --config config.json --output-dir /path/to/output --verbose
  
  # Validation mode
  %(prog)s --config config.json --validate-only
        """
    )
    
    # Mode selection - either discovery or config-based generation
    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument(
        '--discover', '-d',
        action='store_true',
        help='Discovery mode: Scan schema and generate config'
    )
    mode_group.add_argument(
        '--config', '-c',
        help='Generation mode: Path to migration configuration JSON file'
    )
    
    # Discovery mode options
    parser.add_argument(
        '--schema', '-s',
        help='Oracle schema name to discover (required for --discover)'
    )
    parser.add_argument(
        '--connection',
        help='Oracle connection string (required for --discover and --check-database)'
    )
    parser.add_argument(
        '--include',
        nargs='+',
        help='Table name patterns to include (e.g., EMP* DEPT*)'
    )
    parser.add_argument(
        '--exclude', 
        nargs='+',
        help='Table name patterns to exclude (e.g., TEMP* OLD*)'
    )
    parser.add_argument(
        '--output-file',
        default='migration_config.json',
        help='Output file for discovered configuration (default: migration_config.json)'
    )
    
    # Generation mode options
    parser.add_argument(
        '--output-dir', '-o',
        default='output',
        help='Output directory for generated scripts (default: output)'
    )
    
    parser.add_argument(
        '--template-dir', '-t',
        default='templates',
        help='Template directory (default: templates)'
    )
    
    # Validation options
    parser.add_argument(
        '--validate-only',
        action='store_true',
        help='Only validate configuration, do not generate scripts'
    )
    parser.add_argument(
        '--check-database',
        action='store_true',
        help='Validate configuration against database (requires --connection)'
    )
    
    # Common options
    parser.add_argument(
        '--environment', '-e',
        default='development',
        help='Environment name (development, test, production)'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose output'
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='Force overwrite existing output directory'
    )
    parser.add_argument(
        '--ignore-discovery-requirement',
        action='store_true',
        help='DANGEROUS: Allow using pre-existing config.json not generated by discovery (NOT RECOMMENDED)'
    )
    
    args = parser.parse_args()
    
    # Validate arguments based on mode
    if args.discover:
        if not args.schema:
            parser.error("--discover requires --schema")
        if not args.connection:
            parser.error("--discover requires --connection")
    elif args.check_database and not args.connection:
        parser.error("--check-database requires --connection")
    
    try:
        # Discovery mode
        if args.discover:
            return run_discovery_mode(args)
        
        # Generation/Validation mode
        else:
            return run_generation_mode(args)
            
    except (ConfigError, TemplateError, MigrationError, DatabaseConnectionError) as e:
        print(f"❌ {e}")
        return 1
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())