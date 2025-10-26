#!/usr/bin/env python3
"""
Oracle Schema Discovery Script
==============================
Command-line interface for discovering Oracle schemas and generating migration configs.

Usage:
    python src/discover.py --schema SCHEMA_NAME --connection CONNECTION_NAME --output config.json
"""

import argparse
import json
import sys
import os
from pathlib import Path

# Add project root to path for imports
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Third-party imports
try:
    import oracledb
except ImportError:
    print("ERROR: oracledb module not found! Install with: pip install oracledb")
    sys.exit(1)

# Local imports
from lib.discovery_queries import TableDiscovery


def connect_to_oracle(connection_name: str):
    """Connect to Oracle using SQLcl saved connection or connection string"""
    # This is a placeholder - in real implementation, you'd:
    # 1. Read SQLcl connection details from saved connections
    # 2. Or parse a connection string
    # 3. Create oracledb connection
    
    # For now, return None to demonstrate the workflow
    print(f"⚠️  Connection functionality not implemented yet")
    print(f"   Requested connection: {connection_name}")
    print(f"   This would connect to Oracle and return a connection object")
    return None


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Discover Oracle schema and generate migration configuration",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --schema APP_DATA_OWNER --connection my_db --output discovered_config.json
  %(prog)s --schema HR --connection hr_db --include "EMP*,DEPT*" --output hr_migration.json
        """
    )
    
    parser.add_argument(
        '--schema', '-s',
        required=True,
        help='Oracle schema name to discover'
    )
    
    parser.add_argument(
        '--connection', '-c',
        required=True,
        help='Oracle connection name (SQLcl saved connection) or connection string'
    )
    
    parser.add_argument(
        '--output', '-o',
        required=True,
        help='Output file path for generated migration config'
    )
    
    parser.add_argument(
        '--include',
        help='Comma-separated list of table patterns to include (e.g., "EMP*,DEPT*")'
    )
    
    parser.add_argument(
        '--exclude',
        help='Comma-separated list of table patterns to exclude (e.g., "TEMP*,OLD*")'
    )
    
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
    
    args = parser.parse_args()
    
    try:
        # Parse include/exclude patterns
        include_patterns = None
        if args.include:
            include_patterns = [p.strip() for p in args.include.split(',')]
            
        exclude_patterns = None
        if args.exclude:
            exclude_patterns = [p.strip() for p in args.exclude.split(',')]
        
        # Connect to Oracle
        print(f"🔄 Connecting to Oracle...")
        connection = connect_to_oracle(args.connection)
        
        if connection is None:
            print("❌ Cannot proceed without database connection")
            print("   To implement real connection:")
            print("   1. Add SQLcl connection parsing")
            print("   2. Add oracledb connection creation")
            print("   3. Handle authentication")
            return 1
        
        # Run discovery
        print(f"🔄 Discovering schema: {args.schema}")
        discovery = TableDiscovery(connection, environment=args.environment, connection_string=args.connection)
        
        migration_config = discovery.discover_schema(
            schema_name=args.schema,
            include_patterns=include_patterns,
            exclude_patterns=exclude_patterns
        )
        
        # Save to file
        print(f"💾 Saving configuration to: {args.output}")
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Convert dataclass to dict for JSON serialization
        config_dict = migration_config.to_dict()
        
        with open(output_path, 'w') as f:
            json.dump(config_dict, f, indent=2, default=str)
        
        print(f"✅ Discovery complete!")
        print(f"   Schema: {args.schema}")
        print(f"   Tables found: {migration_config.metadata.total_tables_found}")
        print(f"   Selected for migration: {migration_config.metadata.tables_selected_for_migration}")
        print(f"   Config saved to: {args.output}")
        
        return 0
        
    except Exception as e:
        print(f"❌ Discovery failed: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())