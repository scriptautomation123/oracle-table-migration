#!/usr/bin/env python3
"""
SQL Executor Module
===================
Executes SQL/PL/SQL scripts with proper SQL client detection and error handling.
Consolidates SQL execution logic from shell scripts into Python.
"""

import subprocess
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, List, Tuple
from enum import Enum


class SQLClient(str, Enum):
    """Supported SQL clients"""
    SQLCL = "sqlcl"
    SQLPLUS = "sqlplus"


@dataclass
class SQLExecutionResult:
    """Result of SQL execution"""
    success: bool
    return_code: int
    stdout: str
    stderr: str
    client_used: str
    execution_time_seconds: float


class SQLExecutor:
    """Execute SQL scripts with auto-detection of SQL client"""
    
    def __init__(self, explicit_client: Optional[str] = None, thin_ldap: bool = False, verbose: bool = False):
        """
        Initialize SQL executor
        
        Args:
            explicit_client: Force specific client ('sqlcl' or 'sqlplus')
            thin_ldap: Enable thin client LDAP mode support
            verbose: Enable verbose output
        """
        self.explicit_client = explicit_client
        self.thin_ldap = thin_ldap
        self.verbose = verbose
        self._client = None
    
    def find_sql_client(self) -> SQLClient:
        """
        Auto-detect available SQL client
        
        Returns:
            SQLClient enum value
            
        Raises:
            RuntimeError: If no SQL client found
        """
        if self.explicit_client:
            if self.explicit_client == "sqlcl" and self._check_command_exists("sqlcl"):
                return SQLClient.SQLCL
            elif self.explicit_client == "sqlplus" and self._check_command_exists("sqlplus"):
                return SQLClient.SQLPLUS
            else:
                raise RuntimeError(
                    f"Specified SQL client '{self.explicit_client}' not found. "
                    "Please install sqlcl or sqlplus."
                )
        
        if self._client:
            return self._client
        
        if self._check_command_exists("sqlcl"):
            self._client = SQLClient.SQLCL
            return SQLClient.SQLCL
        
        if self._check_command_exists("sqlplus"):
            self._client = SQLClient.SQLPLUS
            return SQLClient.SQLPLUS
        
        raise RuntimeError(
            "No SQL client found. Please install sqlcl or sqlplus"
        )
    
    def execute_sql_script(
        self,
        sql_file: Path,
        connection: str,
        output_file: Optional[Path] = None
    ) -> SQLExecutionResult:
        """
        Execute SQL script file
        
        Args:
            sql_file: Path to SQL file to execute
            connection: Oracle connection string
            output_file: Optional path to save output
            
        Returns:
            SQLExecutionResult with execution details
        """
        client = self.find_sql_client()
        formatted_connection = self._parse_ldap_connection(connection)
        
        if client == SQLClient.SQLCL:
            cmd = f"echo '@{sql_file}' | sqlcl {formatted_connection}"
        else:
            cmd = f"echo '@{sql_file}' | sqlplus -S {formatted_connection}"
        
        return self._execute_command(cmd, output_file, client.value)
    
    def execute_plsql_util(
        self,
        plsql_script: Path,
        category: str,
        operation: str,
        args: List[str],
        connection: str,
        output_file: Optional[Path] = None
    ) -> SQLExecutionResult:
        """
        Execute plsql-util.sql with category and operation
        
        Args:
            plsql_script: Path to plsql-util.sql
            category: Category (READONLY, WRITE, WORKFLOW, CLEANUP)
            operation: Operation name
            args: Additional arguments to pass to plsql-util.sql
            connection: Oracle connection string
            output_file: Optional path to save output
            
        Returns:
            SQLExecutionResult with execution details
        """
        client = self.find_sql_client()
        formatted_connection = self._parse_ldap_connection(connection)
        
        args_str = " ".join(str(arg) for arg in args)
        if client == SQLClient.SQLCL:
            cmd = f"echo '@{plsql_script} {category} {operation} {args_str}' | sqlcl {formatted_connection}"
        else:
            cmd = f"echo '@{plsql_script} {category} {operation} {args_str}' | sqlplus -S {formatted_connection}"
        
        return self._execute_command(cmd, output_file, client.value)
    
    def parse_sql_result(self, output_file: Path) -> Tuple[bool, str]:
        """
        Parse SQL output file for RESULT status
        
        Args:
            output_file: Path to SQL output file
            
        Returns:
            Tuple of (success: bool, status_message: str)
        """
        if not output_file.exists():
            return False, "No output file found"
        
        content = output_file.read_text()
        
        if "RESULT: PASSED" in content or "VALIDATION RESULT: PASSED" in content:
            return True, "PASSED"
        elif "RESULT: FAILED" in content or "VALIDATION RESULT: FAILED" in content:
            return False, "FAILED"
        elif "RESULT: ERROR" in content or "ERROR:" in content:
            return False, "ERROR"
        else:
            return False, "UNKNOWN"
    
    def _parse_ldap_connection(self, connection: str) -> str:
        """
        Parse and format LDAP connection string for SQL clients
        
        Args:
            connection: Oracle connection string (may contain LDAP://)
            
        Returns:
            Formatted connection string for SQL client
        """
        if not self.thin_ldap or 'ldap://' not in connection.lower():
            return connection
        
        if self.verbose:
            print(f"Parsing LDAP connection: {connection}")
        
        return connection
    
    def _check_command_exists(self, command: str) -> bool:
        """Check if command exists in PATH"""
        return shutil.which(command) is not None
    
    def _execute_command(
        self,
        command: str,
        output_file: Optional[Path],
        client: str
    ) -> SQLExecutionResult:
        """
        Execute shell command and capture output
        
        Args:
            command: Shell command to execute
            output_file: Optional file to redirect output to
            client: SQL client used (for logging)
            
        Returns:
            SQLExecutionResult with execution details
        """
        import time
        start_time = time.time()
        
        if self.verbose:
            print(f"Executing: {command}")
            if output_file:
                print(f"Output: {output_file}")
        
        try:
            with open(output_file, 'w') if output_file else subprocess.PIPE as f:
                result = subprocess.run(
                    command,
                    shell=True,
                    stdout=f,
                    stderr=subprocess.PIPE,
                    text=True,
                    check=False
                )
            
            duration = time.time() - start_time
            
            if output_file:
                stdout = f"Output saved to {output_file}"
            else:
                stdout = result.stdout or ""
            
            return SQLExecutionResult(
                success=result.returncode == 0,
                return_code=result.returncode,
                stdout=stdout,
                stderr=result.stderr or "",
                client_used=client,
                execution_time_seconds=duration
            )
            
        except Exception as e:
            duration = time.time() - start_time
            return SQLExecutionResult(
                success=False,
                return_code=-1,
                stdout="",
                stderr=str(e),
                client_used=client,
                execution_time_seconds=duration
            )
