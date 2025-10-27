#!/usr/bin/env python3
"""
Validation Runner Module
========================
Provides high-level validation functions that invoke plsql-util.sql
for database validation operations.
"""

from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from .sql_executor import SQLExecutionResult, SQLExecutor


@dataclass
class ValidationResult:
    """Result of a validation operation"""

    success: bool
    message: str
    status: str
    execution_result: Optional[SQLExecutionResult] = None


class ValidationRunner:
    """Execute validation operations via plsql-util.sql"""

    def __init__(
        self, plsql_util_path: Path, sql_executor: Optional[SQLExecutor] = None
    ):
        """
        Initialize validation runner

        Args:
            plsql_util_path: Path to plsql-util.sql script
            sql_executor: Optional SQLExecutor instance (creates new one if not provided)
        """
        self.plsql_util_path = Path(plsql_util_path)
        self.sql_executor = sql_executor or SQLExecutor(verbose=True)

    def validate_table_existence(
        self,
        owner: str,
        table: str,
        connection: str,
        output_file: Optional[Path] = None,
    ) -> ValidationResult:
        """
        Validate that a table exists

        Args:
            owner: Schema owner
            table: Table name
            connection: Oracle connection string
            output_file: Optional path to save output

        Returns:
            ValidationResult indicating success and details
        """
        args = [owner, table]
        result = self.sql_executor.execute_plsql_util(
            plsql_script=self.plsql_util_path,
            category="READONLY",
            operation="check_existence",
            args=args,
            connection=connection,
            output_file=output_file,
        )

        success, status = (
            self.sql_executor.parse_sql_result(output_file)
            if output_file
            else (False, "UNKNOWN")
        )

        return ValidationResult(
            success=success,
            message=(
                f"Table {owner}.{table} exists"
                if success
                else f"Table {owner}.{table} does not exist"
            ),
            status=status,
            execution_result=result,
        )

    def validate_row_count(
        self,
        owner: str,
        table: str,
        expected: Optional[int],
        connection: str,
        output_file: Optional[Path] = None,
    ) -> ValidationResult:
        """
        Validate table row count

        Args:
            owner: Schema owner
            table: Table name
            expected: Expected row count (None for info only)
            connection: Oracle connection string
            output_file: Optional path to save output

        Returns:
            ValidationResult with row count validation details
        """
        args = [owner, table]
        if expected is not None:
            args.append(str(expected))

        result = self.sql_executor.execute_plsql_util(
            plsql_script=self.plsql_util_path,
            category="READONLY",
            operation="count_rows",
            args=args,
            connection=connection,
            output_file=output_file,
        )

        success, status = (
            self.sql_executor.parse_sql_result(output_file)
            if output_file
            else (False, "UNKNOWN")
        )

        message = f"Row count validation for {owner}.{table}"
        if expected is not None:
            message += f" (expected: {expected})"

        return ValidationResult(
            success=success, message=message, status=status, execution_result=result
        )

    def validate_constraints(
        self,
        owner: str,
        table: str,
        connection: str,
        output_file: Optional[Path] = None,
    ) -> ValidationResult:
        """
        Validate table constraints

        Args:
            owner: Schema owner
            table: Table name
            connection: Oracle connection string
            output_file: Optional path to save output

        Returns:
            ValidationResult with constraint validation details
        """
        args = [owner, table]
        result = self.sql_executor.execute_plsql_util(
            plsql_script=self.plsql_util_path,
            category="READONLY",
            operation="check_constraints",
            args=args,
            connection=connection,
            output_file=output_file,
        )

        success, status = (
            self.sql_executor.parse_sql_result(output_file)
            if output_file
            else (False, "UNKNOWN")
        )

        return ValidationResult(
            success=success,
            message=f"Constraint validation for {owner}.{table}",
            status=status,
            execution_result=result,
        )

    def validate_pre_swap(
        self,
        owner: str,
        table: str,
        new_table: str,
        old_table: str,
        connection: str,
        output_file: Optional[Path] = None,
    ) -> ValidationResult:
        """
        Validate pre-swap conditions

        Args:
            owner: Schema owner
            table: Original table name
            new_table: New table name
            old_table: Old table name
            connection: Oracle connection string
            output_file: Optional path to save output

        Returns:
            ValidationResult with pre-swap validation details
        """
        args = [owner, table, new_table, old_table]
        result = self.sql_executor.execute_plsql_util(
            plsql_script=self.plsql_util_path,
            category="WORKFLOW",
            operation="pre_swap",
            args=args,
            connection=connection,
            output_file=output_file,
        )

        success, status = (
            self.sql_executor.parse_sql_result(output_file)
            if output_file
            else (False, "UNKNOWN")
        )

        return ValidationResult(
            success=success,
            message=f"Pre-swap validation for {owner}.{table}",
            status=status,
            execution_result=result,
        )

    def validate_post_swap(
        self,
        owner: str,
        table: str,
        old_table: str,
        connection: str,
        output_file: Optional[Path] = None,
    ) -> ValidationResult:
        """
        Validate post-swap conditions

        Args:
            owner: Schema owner
            table: Current table name (after swap)
            old_table: Old table name
            connection: Oracle connection string
            output_file: Optional path to save output

        Returns:
            ValidationResult with post-swap validation details
        """
        args = [owner, table, old_table]
        result = self.sql_executor.execute_plsql_util(
            plsql_script=self.plsql_util_path,
            category="WORKFLOW",
            operation="post_swap",
            args=args,
            connection=connection,
            output_file=output_file,
        )

        success, status = (
            self.sql_executor.parse_sql_result(output_file)
            if output_file
            else (False, "UNKNOWN")
        )

        return ValidationResult(
            success=success,
            message=f"Post-swap validation for {owner}.{table}",
            status=status,
            execution_result=result,
        )
