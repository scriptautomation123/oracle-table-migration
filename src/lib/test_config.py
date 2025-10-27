#!/usr/bin/env python3
"""
Test Configuration Module
=========================
Handles configuration for E2E test runner including connection strings,
paths, and test modes.
"""

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, List


@dataclass
class TestConfig:
    """Configuration for E2E test execution"""
    
    connection_string: str
    schema: str
    mode: str = "dev"  # dev, test, prod
    output_base: Path = Path("output")
    test_ddl: Path = Path("test/comprehensive_oracle_ddl.sql")
    cleanup_on_success: bool = False
    cleanup_on_failure: bool = False
    skip_schema_setup: bool = False
    tables: Optional[List[str]] = None
    verbose: bool = False
    thin_ldap: bool = False
    
    @classmethod
    def from_args(cls, args) -> "TestConfig":
        """Create configuration from CLI arguments"""
        mode = getattr(args, "mode", "dev")
        return cls(
            connection_string=getattr(args, "connection", None) or cls.get_connection_from_env(),
            schema=getattr(args, "schema", None) or cls.get_schema_from_env(),
            mode=mode,
            cleanup_on_success=mode == "test" and not getattr(args, "no_cleanup", False),
            cleanup_on_failure=getattr(args, "cleanup_on_failure", False),
            skip_schema_setup=getattr(args, "skip_schema_setup", False),
            tables=_parse_tables(getattr(args, "tables", None)),
            verbose=getattr(args, "verbose", False),
            thin_ldap=getattr(args, "thin_ldap", False),
        )
    
    @classmethod
    def from_env(cls) -> "TestConfig":
        """Create configuration from environment variables"""
        mode = os.getenv("TEST_MODE", "dev")
        return cls(
            connection_string=cls.get_connection_from_env(),
            schema=cls.get_schema_from_env(),
            mode=mode,
            cleanup_on_success=mode == "test",
        )
    
    @staticmethod
    def get_connection_from_env() -> str:
        """Get connection string from environment"""
        conn = os.getenv("ORACLE_CONN") or os.getenv("ORACLE_CONNECTION")
        if not conn:
            raise ValueError(
                "Connection string not provided. "
                "Use --connection or set ORACLE_CONN environment variable"
            )
        return conn
    
    @staticmethod
    def get_schema_from_env() -> str:
        """Get schema name from environment"""
        schema = os.getenv("ORACLE_SCHEMA") or os.getenv("SCHEMA")
        if not schema:
            raise ValueError(
                "Schema not provided. "
                "Use --schema or set ORACLE_SCHEMA environment variable"
            )
        return schema
    
    def validate(self):
        """Validate configuration"""
        errors = []
        
        if not self.connection_string:
            errors.append("Connection string is required")
        
        if not self.schema:
            errors.append("Schema name is required")
        
        if self.mode not in ("dev", "test", "prod"):
            errors.append(f"Invalid mode: {self.mode}. Must be dev, test, or prod")
        
        if not self.test_ddl.exists():
            errors.append(f"Test DDL file not found: {self.test_ddl}")
        
        if errors:
            raise ValueError("Configuration validation failed:\n" + "\n".join(f"  - {e}" for e in errors))


def _parse_tables(tables_arg: Optional[str]) -> Optional[List[str]]:
    """Parse comma-separated table list"""
    if not tables_arg:
        return None
    return [t.strip() for t in tables_arg.split(",") if t.strip()]
