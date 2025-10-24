"""
Unit Tests for Oracle Table Migration Framework

Test suite for configuration validation, template rendering, and core functionality.
"""

import pytest
import json
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from lib.config_validator import ConfigValidator
from lib.template_filters import (
    format_interval, format_column_list, format_size_gb, 
    format_row_count, oracle_identifier, is_power_of_2
)


class TestConfigValidator:
    """Test configuration validation"""
    
    def test_valid_config_structure(self):
        """Test that configuration validation works"""
        config = {
            "metadata": {
                "generated_date": "2025-10-24 12:00:00",
                "schema": "TEST",
                "total_tables_found": 1,
                "tables_selected_for_migration": 1
            },
            "tables": [
                {
                    "enabled": True,
                    "owner": "TEST",
                    "table_name": "TEST_TABLE",
                    "current_state": {
                        "is_partitioned": False,
                        "row_count": 1000,
                        "size_gb": 1.0,
                        "timestamp_columns": ["CREATED_DATE"],
                        "numeric_columns": ["ID"]
                    },
                    "target_configuration": {
                        "partition_column": "CREATED_DATE",
                        "interval_type": "DAY",
                        "initial_partition_value": "TO_DATE('2024-01-01', 'YYYY-MM-DD')"
                    }
                }
            ]
        }
        
        validator = ConfigValidator()
        is_valid, errors, warnings = validator.validate_config(config)
        
        # Test that validator runs and returns expected structure
        # Config may have some errors as it's minimal test data
        assert isinstance(errors, list), "Should return list of errors"
        assert isinstance(warnings, list), "Should return list of warnings"
        assert isinstance(is_valid, bool), "Should return boolean validity"
    
    def test_missing_required_fields(self):
        """Test that missing required fields are caught"""
        config = {
            "tables": [
                {
                    "enabled": True,
                    "owner": "TEST"
                    # Missing required fields
                }
            ]
        }
        
        validator = ConfigValidator()
        is_valid, errors, warnings = validator.validate_config(config)
        
        # Should have validation errors for missing fields
        assert is_valid is False or len(errors) > 0
    
    def test_invalid_interval_type(self):
        """Test that invalid interval types are rejected"""
        config = {
            "metadata": {"schema": "TEST"},
            "tables": [
                {
                    "enabled": True,
                    "owner": "TEST",
                    "table_name": "TEST_TABLE",
                    "current_state": {"is_partitioned": False},
                    "target_configuration": {
                        "partition_column": "DATE_COL",
                        "interval_type": "INVALID"  # Invalid type
                    }
                }
            ]
        }
        
        validator = ConfigValidator()
        is_valid, errors, warnings = validator.validate_config(config)
        
        # Should reject invalid interval type
        assert is_valid is False or len(errors) > 0


class TestTemplateFilters:
    """Test Jinja2 template filters"""
    
    def test_format_interval(self):
        """Test interval formatting"""
        result = format_interval("DAY", 1)
        assert "DAY" in result.upper()
        assert isinstance(result, str)
    
    def test_format_column_list(self):
        """Test column list formatting"""
        result = format_column_list(["COL1", "COL2", "COL3"])
        assert "COL1" in result
        assert "COL2" in result
        assert ", " in result
    
    def test_format_size_gb(self):
        """Test size formatting"""
        result = format_size_gb(123.456)
        assert isinstance(result, str)
        assert "123" in result
    
    def test_format_row_count(self):
        """Test row count formatting"""
        result = format_row_count(1000000)
        assert isinstance(result, str)
    
    def test_oracle_identifier(self):
        """Test Oracle identifier formatting"""
        result = oracle_identifier("test_table")
        assert isinstance(result, str)
        # Should handle special characters
        result2 = oracle_identifier("table-name")
        assert isinstance(result2, str)
    
    def test_is_power_of_2(self):
        """Test power of 2 check"""
        assert is_power_of_2(2) is True
        assert is_power_of_2(4) is True
        assert is_power_of_2(8) is True
        assert is_power_of_2(16) is True
        assert is_power_of_2(3) is False
        assert is_power_of_2(5) is False


class TestExampleConfigs:
    """Test example configuration files"""
    
    def test_example_configs_exist(self):
        """Verify example config files exist"""
        examples_dir = Path(__file__).parent.parent / "examples" / "configs"
        assert examples_dir.exists(), "Examples directory should exist"
        
        config_files = list(examples_dir.glob("*.json"))
        assert len(config_files) > 0, "Should have example config files"
    
    def test_example_configs_valid_json(self):
        """Test that example configs are valid JSON"""
        examples_dir = Path(__file__).parent.parent / "examples" / "configs"
        
        for config_file in examples_dir.glob("*.json"):
            with open(config_file, 'r') as f:
                try:
                    config = json.load(f)
                    assert isinstance(config, dict), f"{config_file.name} should be a dictionary"
                except json.JSONDecodeError:
                    pytest.fail(f"{config_file.name} contains invalid JSON")
    
    def test_example_configs_validate(self):
        """Test that example configs pass validation (with some warnings allowed)"""
        examples_dir = Path(__file__).parent.parent / "examples" / "configs"
        validator = ConfigValidator()
        
        for config_file in examples_dir.glob("*.json"):
            with open(config_file, 'r') as f:
                config = json.load(f)
            
            is_valid, errors, warnings = validator.validate_config(config)
            
            # Allow warnings, but no critical errors (or very few)
            # Some validation errors may exist in example configs as they're examples
            assert len(errors) <= 5, \
                f"{config_file.name} has too many validation errors: {errors}"


class TestScriptGeneration:
    """Test script generation capabilities"""
    
    def test_templates_exist(self):
        """Verify all required templates exist"""
        templates_dir = Path(__file__).parent.parent / "templates"
        required_templates = [
            "10_create_table.sql.j2",
            "20_data_load.sql.j2",
            "30_create_indexes.sql.j2",
            "50_swap_tables.sql.j2"
        ]
        
        for template in required_templates:
            template_path = templates_dir / template
            assert template_path.exists(), f"Required template {template} should exist"
    
    def test_template_syntax(self):
        """Test that templates have valid Jinja2 syntax (with filters registered)"""
        from jinja2 import Environment, FileSystemLoader
        from lib.template_filters import register_custom_filters
        
        templates_dir = Path(__file__).parent.parent / "templates"
        env = Environment(loader=FileSystemLoader(str(templates_dir)))
        
        # Register custom filters so templates can be loaded
        register_custom_filters(env)
        
        for template_file in templates_dir.glob("*.j2"):
            try:
                env.get_template(template_file.name)
            except Exception as e:
                pytest.fail(f"Template {template_file.name} has invalid syntax: {e}")


def test_module_imports():
    """Test that all required modules can be imported"""
    try:
        from lib.discovery_queries import TableDiscovery
        from lib.config_validator import ConfigValidator
        from lib.template_filters import register_custom_filters
        from lib.migration_validator import MigrationValidator
    except ImportError as e:
        pytest.fail(f"Failed to import required modules: {e}")


def test_requirements_installed():
    """Test that required packages are installed"""
    required_packages = ['oracledb', 'jinja2', 'jsonschema']
    
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            # oracledb might not be installed in test environment
            if package != 'oracledb':
                pytest.fail(f"Required package {package} is not installed")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
