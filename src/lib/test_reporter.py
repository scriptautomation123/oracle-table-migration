#!/usr/bin/env python3
"""
Test Reporter Module
====================
Generates comprehensive test reports in JSON and Markdown formats.
"""

import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict


class TestReporter:
    """Generate test reports"""

    def __init__(self, verbose: bool = False):
        self.verbose = verbose

    def generate_report(
        self, results: Dict[str, Any], output_dir: Path
    ) -> Dict[Path, str]:
        """
        Generate JSON and Markdown reports

        Args:
            results: Dictionary containing test results
            output_dir: Directory to save reports

        Returns:
            Dictionary mapping file paths to report content
        """
        reports = {}

        json_path = output_dir / "test_report.json"
        json_content = json.dumps(results, indent=2, default=str)
        reports[json_path] = json_content

        md_path = output_dir / "test_report.md"
        md_content = self._create_markdown_report(results)
        reports[md_path] = md_content

        for path, content in reports.items():
            path.write_text(content)
            if self.verbose:
                print(f"Created report: {path}")

        return reports

    def _create_markdown_report(self, results: Dict[str, Any]) -> str:
        """Create Markdown formatted report"""
        lines = []

        lines.append("# Oracle Migration E2E Test Report\n")
        lines.append(f"**Generated:** {results.get('timestamp', datetime.now())}\n")
        lines.append(f"**Mode:** {results.get('mode', 'unknown')}\n")
        lines.append(
            f"**Status:** {'✅ SUCCESS' if results.get('status') == 'SUCCESS' else '❌ FAILED'}\n"
        )
        lines.append(
            f"**Duration:** {results.get('duration_seconds', 0):.2f} seconds\n"
        )

        if results.get("test_run_id"):
            lines.append(f"**Test Run ID:** {results['test_run_id']}\n")

        lines.append("\n---\n")

        metrics = results.get("metrics", {})
        if metrics:
            lines.append("## Metrics\n")
            for key, value in metrics.items():
                lines.append(f"- **{key.replace('_', ' ').title()}:** {value}")
            lines.append("")

        steps = results.get("steps", {})
        if steps:
            lines.append("## Workflow Steps\n")
            for step_name, step_data in steps.items():
                status = "✅" if step_data.get("success") else "❌"
                lines.append(f"\n### {step_name.replace('_', ' ').title()} {status}")
                if "duration" in step_data:
                    lines.append(f"- **Duration:** {step_data['duration']:.2f}s")
                if "message" in step_data:
                    lines.append(f"- **Message:** {step_data['message']}")
                if "details" in step_data and step_data["details"]:
                    lines.append("- **Details:**")
                    for k, v in step_data["details"].items():
                        lines.append(f"  - {k}: {v}")
            lines.append("")

        errors = results.get("errors", [])
        if errors:
            lines.append("## Errors\n")
            for error in errors:
                lines.append(f"- {error}")
            lines.append("")

        warnings = results.get("warnings", [])
        if warnings:
            lines.append("## Warnings\n")
            for warning in warnings:
                lines.append(f"- {warning}")
            lines.append("")

        return "\n".join(lines)

    def create_summary_json(
        self, test_run_id: str, results: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Create structured JSON summary

        Args:
            test_run_id: Unique test run identifier
            results: Test execution results

        Returns:
            Structured JSON summary
        """
        return {
            "test_run_id": test_run_id,
            "timestamp": datetime.now().isoformat(),
            "mode": results.get("mode", "unknown"),
            "status": "SUCCESS" if results.get("status") == "SUCCESS" else "FAILED",
            "duration_seconds": results.get("duration_seconds", 0),
            "steps": results.get("steps", {}),
            "metrics": results.get("metrics", {}),
            "errors": results.get("errors", []),
            "warnings": results.get("warnings", []),
        }

    def create_step_result(
        self,
        step_name: str,
        success: bool,
        duration: float,
        message: str = "",
        details: Dict[str, Any] = None,
    ) -> Dict[str, Any]:
        """
        Create a standardized step result

        Args:
            step_name: Name of the step
            success: Whether step succeeded
            duration: Step duration in seconds
            message: Optional message
            details: Optional additional details

        Returns:
            Step result dictionary
        """
        result = {"step": step_name, "success": success, "duration": duration}

        if message:
            result["message"] = message
        if details:
            result["details"] = details

        return result

    def create_metrics(
        self,
        tables_discovered: int = 0,
        tables_migrated: int = 0,
        sql_files_generated: int = 0,
        master_scripts_executed: int = 0,
    ) -> Dict[str, Any]:
        """
        Create metrics dictionary

        Args:
            tables_discovered: Number of tables discovered
            tables_migrated: Number of tables successfully migrated
            sql_files_generated: Number of SQL files generated
            master_scripts_executed: Number of master scripts executed

        Returns:
            Metrics dictionary
        """
        return {
            "tables_discovered": tables_discovered,
            "tables_migrated": tables_migrated,
            "sql_files_generated": sql_files_generated,
            "master_scripts_executed": master_scripts_executed,
        }
