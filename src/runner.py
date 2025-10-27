#!/usr/bin/env python3
"""
Unified Runner - Oracle Table Migration
========================================
Single tool for development testing, validation, and production deployment.
Replaces test_runner.py, unified_runner.sh, and unified_wrapper.sh.

Usage:
    python3 src/runner.py <command> [options]

Commands:
    test        - Full E2E test workflow
    validate    - Database validation operations
    migrate     - Migration execution
    discover    - Schema discovery
    generate    - DDL generation
"""

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from src.lib import (
    TestOrchestrator, TestConfig,
    ValidationRunner, SQLExecutor,
)


def cmd_test(args):
    """Execute full E2E test workflow"""
    config = TestConfig.from_args(args)
    orchestrator = TestOrchestrator(config)
    orchestrator.run()
    return 0 if orchestrator.results['status'] == 'SUCCESS' else 1


def cmd_validate(args):
    """Execute validation operations"""
    import tempfile
    
    if not args.connection:
        print("ERROR: Connection string required (--connection)")
        return 1
    
    plsql_util = Path("templates/plsql-util/plsql-util.sql")
    if not plsql_util.exists():
        print(f"ERROR: plsql-util.sql not found at {plsql_util}")
        return 1
    
    thin_ldap = getattr(args, 'thin_ldap', False)
    sql_executor = SQLExecutor(explicit_client=args.sql_client, thin_ldap=thin_ldap, verbose=args.verbose)
    validation_runner = ValidationRunner(
        plsql_util_path=plsql_util,
        sql_executor=sql_executor
    )
    
    operation = args.operation
    operation_args = args.args
    
    if len(operation_args) < 2:
        print(f"ERROR: Operation '{operation}' requires at least 2 arguments")
        print(f"Usage: validate {operation} <owner> <table> [additional_args...]")
        return 1
    
    owner = operation_args[0]
    table = operation_args[1]
    additional = operation_args[2:] if len(operation_args) > 2 else []
    
    with tempfile.TemporaryDirectory() as tmpdir:
        output_file = Path(tmpdir) / "validation_output.log"
        
        if operation == "check_existence":
            result = validation_runner.validate_table_existence(
                owner, table, args.connection, output_file
            )
        elif operation == "count_rows":
            expected = int(additional[0]) if additional else None
            result = validation_runner.validate_row_count(
                owner, table, expected, args.connection, output_file
            )
        elif operation == "check_constraints":
            result = validation_runner.validate_constraints(
                owner, table, args.connection, output_file
            )
        else:
            print(f"ERROR: Unknown operation: {operation}")
            return 1
        
        if result.success:
            print(f"✓ {result.message}")
            return 0
        else:
            print(f"✗ {result.message}")
            return 1


def cmd_migrate(args):
    """Execute migration operations"""
    print("Migration mode not yet implemented")
    print(f"Mode: {args.mode}")
    print(f"Owner: {args.owner}")
    print(f"Table: {args.table}")
    return 0


def cmd_discover(args):
    """Execute schema discovery"""
    if not args.connection:
        print("ERROR: Connection string required (--connection)")
        return 1
    
    if not args.schema:
        print("ERROR: Schema name required (--schema)")
        return 1
    
    from src.generate import run_discovery
    
    run_discovery(
        schema=args.schema,
        connection=args.connection,
        output_dir=Path(args.output_dir) if args.output_dir else None
    )
    return 0


def cmd_generate(args):
    """Generate DDL from configuration"""
    if not args.config:
        print("ERROR: Config file required (--config)")
        return 1
    
    from src.generate import run_generation
    
    config_file = Path(args.config)
    if not config_file.exists():
        print(f"ERROR: Config file not found: {config_file}")
        return 1
    
    output_dir = Path(args.output_dir) if args.output_dir else None
    run_generation(config_file, output_dir)
    return 0


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Unified Oracle Migration Runner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Full E2E test
  python3 src/runner.py test --connection "$ORACLE_CONN" --schema APP_DATA_OWNER

  # Validate table exists
  python3 src/runner.py validate check_existence APP_OWNER MY_TABLE --connection "$ORACLE_CONN"

  # Discover schema
  python3 src/runner.py discover --schema APP_DATA_OWNER --connection "$ORACLE_CONN"

  # Generate DDL
  python3 src/runner.py generate --config path/to/config.json
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')
    
    # test subcommand
    parser_test = subparsers.add_parser('test', help='Full E2E test workflow')
    parser_test.add_argument('--connection', required=True, help='Oracle connection string')
    parser_test.add_argument('--schema', required=True, help='Schema name to test')
    parser_test.add_argument('--mode', choices=['dev', 'test', 'prod'], default='dev', help='Test mode')
    parser_test.add_argument('--skip-schema-setup', action='store_true', help='Skip schema setup phase')
    parser_test.add_argument('--sql-client', choices=['sqlcl', 'sqlplus'], help='Force specific SQL client')
    parser_test.add_argument('--thin-ldap', action='store_true', help='Enable thin client LDAP mode')
    parser_test.add_argument('--verbose', action='store_true', help='Enable verbose output')
    
    # validate subcommand
    parser_validate = subparsers.add_parser('validate', help='Database validation operations')
    parser_validate.add_argument('operation', choices=['check_existence', 'count_rows', 'check_constraints'],
                                  help='Validation operation')
    parser_validate.add_argument('args', nargs='*', help='Arguments for the operation')
    parser_validate.add_argument('--connection', required=True, help='Oracle connection string')
    parser_validate.add_argument('--sql-client', choices=['sqlcl', 'sqlplus'], help='Force specific SQL client')
    parser_validate.add_argument('--thin-ldap', action='store_true', help='Enable thin client LDAP mode')
    parser_validate.add_argument('--verbose', action='store_true', help='Enable verbose output')
    
    # migrate subcommand
    parser_migrate = subparsers.add_parser('migrate', help='Migration execution')
    parser_migrate.add_argument('mode', choices=['generate', 'execute', 'auto'], help='Migration mode')
    parser_migrate.add_argument('owner', help='Schema owner')
    parser_migrate.add_argument('table', help='Table name')
    parser_migrate.add_argument('--connection', required=True, help='Oracle connection string')
    parser_migrate.add_argument('--sql-client', choices=['sqlcl', 'sqlplus'], help='Force specific SQL client')
    parser_migrate.add_argument('--thin-ldap', action='store_true', help='Enable thin client LDAP mode')
    
    # discover subcommand
    parser_discover = subparsers.add_parser('discover', help='Schema discovery')
    parser_discover.add_argument('--schema', required=True, help='Schema name to discover')
    parser_discover.add_argument('--connection', required=True, help='Oracle connection string')
    parser_discover.add_argument('--output-dir', help='Output directory for discovery results')
    
    # generate subcommand
    parser_generate = subparsers.add_parser('generate', help='DDL generation')
    parser_generate.add_argument('--config', required=True, help='Path to migration config JSON')
    parser_generate.add_argument('--output-dir', help='Output directory for generated DDL')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    try:
        command_map = {
            'test': cmd_test,
            'validate': cmd_validate,
            'migrate': cmd_migrate,
            'discover': cmd_discover,
            'generate': cmd_generate,
        }
        
        return command_map[args.command](args)
        
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        return 130
    except Exception as e:
        print(f"\n❌ Fatal error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
