#!/usr/bin/env python3
"""
Test Executor Module
====================
Executes individual workflow steps with proper error handling and logging.
"""

import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional


@dataclass
class ExecutionResult:
    """Result of executing a command"""

    success: bool
    return_code: int
    stdout: str
    stderr: str
    duration_seconds: float
    command: str


class StepExecutor:
    """Execute individual workflow steps"""

    def __init__(self, verbose: bool = False):
        self.verbose = verbose

    def execute_ddl_script(
        self, sql_file: Path, connection: str, output_file: Optional[Path] = None
    ) -> ExecutionResult:
        """
        Execute SQL file using sqlcl

        Args:
            sql_file: Path to SQL file
            connection: Oracle connection string
            output_file: Optional path to save output

        Returns:
            ExecutionResult with success status and output
        """
        cmd = f"sqlcl {connection} @{sql_file}"

        return self._execute_command(cmd, output_file)

    def execute_python_script(
        self, script: Path, args: List[str], output_file: Optional[Path] = None
    ) -> ExecutionResult:
        """
        Execute Python script with arguments

        Args:
            script: Path to Python script
            args: List of command-line arguments
            output_file: Optional path to save output

        Returns:
            ExecutionResult with success status and output
        """
        cmd = ["python3", str(script)] + args

        return self._execute_command(cmd, output_file)

    def execute_discovery(
        self,
        connection: str,
        schema: str,
        output_file: Path,
        output_dir: Optional[Path] = None,
    ) -> ExecutionResult:
        """
        Execute discovery step using generate.py

        Args:
            connection: Oracle connection string
            schema: Schema name to discover
            output_file: Path to save discovered config JSON
            output_dir: Optional output directory

        Returns:
            ExecutionResult with success status and output
        """
        cmd = [
            "python3",
            "src/generate.py",
            "--discover",
            "--schema",
            schema,
            "--connection",
            connection,
        ]

        if output_dir:
            cmd.extend(["--output-dir", str(output_dir)])
        else:
            cmd.extend(["--output-file", str(output_file)])

        return self._execute_command(cmd)

    def execute_generation(
        self, config_file: Path, output_dir: Path
    ) -> ExecutionResult:
        """
        Execute generation step using generate.py

        Args:
            config_file: Path to migration config JSON
            output_dir: Directory to save generated DDL

        Returns:
            ExecutionResult with success status and output
        """
        cmd = [
            "python3",
            "src/generate.py",
            "--config",
            str(config_file),
            "--output-dir",
            str(output_dir),
        ]

        return self._execute_command(cmd)

    def execute_generate_dataclasses(self) -> ExecutionResult:
        """
        Execute schema to dataclass generation

        Returns:
            ExecutionResult with success status and output
        """
        cmd = ["python3", "src/schema_to_dataclass.py"]

        return self._execute_command(cmd)

    def _execute_command(
        self, command: List[str] | str, output_file: Optional[Path] = None
    ) -> ExecutionResult:
        """
        Execute a command and capture output

        Args:
            command: Command to execute (list or string)
            output_file: Optional file to redirect output to

        Returns:
            ExecutionResult with execution details
        """
        start_time = time.time()

        if isinstance(command, str):
            command_str = command
            shell = True
        else:
            command_str = " ".join(command)
            shell = False

        if self.verbose:
            print(f"Executing: {command_str}")

        try:
            if output_file:
                stdout_fd = open(output_file, "w")
            else:
                stdout_fd = subprocess.PIPE

            result = subprocess.run(
                command,
                shell=shell,
                stdout=stdout_fd,
                stderr=subprocess.PIPE,
                text=True,
                check=False,
            )

            duration = time.time() - start_time

            if output_file:
                stdout_fd.close()
                stdout = f"Output saved to {output_file}"
                with open(output_file, "r") as f:
                    actual_output = f.read()
                    if len(actual_output) > 1000:
                        stdout = f"{stdout} ({len(actual_output)} characters)"
            else:
                stdout = result.stdout or ""

            return ExecutionResult(
                success=result.returncode == 0,
                return_code=result.returncode,
                stdout=stdout,
                stderr=result.stderr or "",
                duration_seconds=duration,
                command=command_str,
            )

        except Exception as e:
            duration = time.time() - start_time
            return ExecutionResult(
                success=False,
                return_code=-1,
                stdout="",
                stderr=str(e),
                duration_seconds=duration,
                command=command_str,
            )
