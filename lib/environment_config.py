#!/usr/bin/env python3
"""
Environment Configuration Manager
=================================
Manages environment-specific configuration for Oracle table migrations.
Handles tablespace selection, subpartition counts, and environment detection.
"""

import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

# Import dataclasses from generated models (single source of truth)
from lib.migration_models import (
    EnvironmentConfig,
    ParallelDefaults,
    SubpartitionDefaults,
    TablespaceConfig,
)


class EnvironmentConfigManager:
    """Manages environment-specific configuration"""

    def __init__(self, config_file: str = "config.json"):
        """
        Initialize environment configuration manager

        Args:
            config_file: Path to consolidated configuration file
        """
        self.config_file = Path(config_file)
        self._configs: Dict[str, EnvironmentConfig] = {}
        self._current_environment: Optional[str] = None

    def detect_environment(self) -> str:
        """
        Detect the current environment from various sources

        Returns:
            Environment name (default: 'global')
        """
        # 1. Check command line argument (if available)
        # This would be set by the CLI when --environment is used

        # 2. Check environment variable
        env_var = os.getenv("MIGRATION_ENV")
        if env_var:
            return env_var

        # 3. Check for environment file
        env_file = os.getenv("MIGRATION_ENV_FILE")
        if env_file and Path(env_file).exists():
            return Path(env_file).stem

        # 4. Default to global
        return "global"

    def load_environment_config(self, environment: str) -> EnvironmentConfig:
        """
        Load configuration for a specific environment

        Args:
            environment: Environment name

        Returns:
            EnvironmentConfig object
        """
        if environment in self._configs:
            return self._configs[environment]

        # Load consolidated config file
        if not self.config_file.exists():
            # Fallback to default config
            return self._create_default_config(environment)

        with open(self.config_file, "r") as f:
            config_data = json.load(f)

        # Get environment config from consolidated file
        env_config = config_data.get("environments", {}).get(environment, {})
        if not env_config:
            # Try additional_configs if not found in environments
            env_config = config_data.get("additional_configs", {}).get(environment, {})

        if not env_config:
            # Fallback to global config
            env_config = config_data.get("environments", {}).get("global", {})

        # Convert to EnvironmentConfig object
        config_obj = self._parse_config(env_config)
        self._configs[environment] = config_obj

        return config_obj

    def _create_default_config(self, environment: str) -> EnvironmentConfig:
        """Create default configuration for environment"""
        default_config = {
            "environment": environment,
            "description": f"Default configuration for {environment} environment",
            "tablespaces": {
                "data": {
                    "primary": "USERS",
                    "lob": ["GD_LOB_01", "GD_LOB_02", "GD_LOB_03", "GD_LOB_04"],
                }
            },
            "subpartition_defaults": {
                "min_count": 2,
                "max_count": 16,
                "size_based_recommendations": {
                    "small": {"max_gb": 1, "count": 2},
                    "medium": {"max_gb": 10, "count": 4},
                    "large": {"max_gb": 50, "count": 8},
                    "xlarge": {"max_gb": 100, "count": 12},
                    "xxlarge": {"max_gb": 999999, "count": 16},
                },
            },
            "parallel_defaults": {
                "min_degree": 1,
                "max_degree": 8,
                "default_degree": 4,
            },
        }

        config_obj = self._parse_config(default_config)
        self._configs[environment] = config_obj
        return config_obj

    def _parse_config(self, config: Dict[str, Any]) -> EnvironmentConfig:
        """Parse configuration dictionary into EnvironmentConfig object"""
        tablespaces = TablespaceConfig(
            primary=config["tablespaces"]["data"]["primary"],
            lob=config["tablespaces"]["data"]["lob"],
        )

        subpartition_defaults = SubpartitionDefaults(
            min_count=config["subpartition_defaults"]["min_count"],
            max_count=config["subpartition_defaults"]["max_count"],
            size_based_recommendations=config["subpartition_defaults"][
                "size_based_recommendations"
            ],
        )

        parallel_defaults = ParallelDefaults(
            min_degree=config["parallel_defaults"]["min_degree"],
            max_degree=config["parallel_defaults"]["max_degree"],
            default_degree=config["parallel_defaults"]["default_degree"],
        )

        return EnvironmentConfig(
            environment=config["environment"],
            description=config["description"],
            tablespaces=tablespaces,
            subpartition_defaults=subpartition_defaults,
            parallel_defaults=parallel_defaults,
        )

    def calculate_subpartition_count(
        self, table_size_gb: float, environment: str
    ) -> int:
        """
        Calculate optimal subpartition count based on table size and environment

        Args:
            table_size_gb: Table size in GB
            environment: Environment name

        Returns:
            Recommended subpartition count
        """
        config = self.load_environment_config(environment)
        recommendations = config.subpartition_defaults.size_based_recommendations

        # Find the appropriate size category
        for _, size_config in recommendations.items():
            if table_size_gb <= size_config["max_gb"]:
                count = size_config["count"]
                # Ensure count is within environment limits
                count = max(count, config.subpartition_defaults.min_count)
                count = min(count, config.subpartition_defaults.max_count)
                return count

        # Fallback to maximum
        return config.subpartition_defaults.max_count

    def get_tablespaces(
        self, environment: str, table_config: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Get tablespaces for a table based on environment and table config

        Args:
            environment: Environment name
            table_config: Optional table-specific configuration

        Returns:
            Dictionary with 'data' and 'lob' tablespace information
        """
        config = self.load_environment_config(environment)

        # Use table-specific tablespace if provided, otherwise use environment default
        data_tablespace = None
        lob_tablespaces = None

        if table_config:
            data_tablespace = table_config.get("tablespace")
            lob_tablespaces = table_config.get("lob_tablespaces")

        # Fall back to environment defaults
        if not data_tablespace:
            data_tablespace = config.tablespaces.primary
        if not lob_tablespaces:
            lob_tablespaces = config.tablespaces.lob

        return {"data": data_tablespace, "lob": lob_tablespaces}

    def get_parallel_degree(self, environment: str, table_size_gb: float) -> int:
        """
        Get recommended parallel degree for an environment and table size

        Args:
            environment: Environment name
            table_size_gb: Table size in GB

        Returns:
            Recommended parallel degree
        """
        config = self.load_environment_config(environment)

        # Simple size-based calculation
        if table_size_gb > 100:
            degree = min(16, config.parallel_defaults.max_degree)
        elif table_size_gb > 50:
            degree = min(8, config.parallel_defaults.max_degree)
        elif table_size_gb > 10:
            degree = min(4, config.parallel_defaults.max_degree)
        else:
            degree = config.parallel_defaults.default_degree

        # Ensure within environment limits
        degree = max(degree, config.parallel_defaults.min_degree)
        degree = min(degree, config.parallel_defaults.max_degree)

        return degree

    def create_environment_config(
        self,
        environment: str,
        primary_tablespace: str,
        lob_tablespaces: List[str],
        **kwargs,
    ) -> None:
        """
        Create a new environment configuration in consolidated config file

        Args:
            environment: Environment name
            primary_tablespace: Primary data tablespace
            lob_tablespaces: List of LOB tablespaces
            **kwargs: Additional configuration options
        """
        config = {
            "environment": environment,
            "description": kwargs.get(
                "description", f"Configuration for {environment} environment"
            ),
            "tablespaces": {
                "data": {"primary": primary_tablespace, "lob": lob_tablespaces}
            },
            "subpartition_defaults": {
                "min_count": kwargs.get("min_subpartitions", 2),
                "max_count": kwargs.get("max_subpartitions", 16),
                "size_based_recommendations": kwargs.get(
                    "size_recommendations",
                    {
                        "small": {"max_gb": 1, "count": 2},
                        "medium": {"max_gb": 10, "count": 4},
                        "large": {"max_gb": 50, "count": 8},
                        "xlarge": {"max_gb": 100, "count": 12},
                        "xxlarge": {"max_gb": 999999, "count": 16},
                    },
                ),
            },
            "parallel_defaults": {
                "min_degree": kwargs.get("min_parallel", 1),
                "max_degree": kwargs.get("max_parallel", 8),
                "default_degree": kwargs.get("default_parallel", 4),
            },
        }

        # Load existing config or create new one
        if self.config_file.exists():
            with open(self.config_file, "r") as f:
                existing_config = json.load(f)
        else:
            existing_config = {"environments": {}, "additional_configs": {}}

        # Add new environment to additional_configs
        if "additional_configs" not in existing_config:
            existing_config["additional_configs"] = {}
        existing_config["additional_configs"][environment] = config

        # Write back to file
        with open(self.config_file, "w") as f:
            json.dump(existing_config, f, indent=2)

        print(f"Created environment configuration: {environment} in {self.config_file}")


# Example usage and testing
if __name__ == "__main__":
    # Create environment config manager
    env_manager = EnvironmentConfigManager()

    # Create example environment configurations
    env_manager.create_environment_config(
        environment="production",
        primary_tablespace="PROD_DATA_01",
        lob_tablespaces=["PROD_LOB_01", "PROD_LOB_02", "PROD_LOB_03", "PROD_LOB_04"],
        min_subpartitions=4,
        max_subpartitions=32,
        min_parallel=2,
        max_parallel=16,
        default_parallel=8,
    )

    env_manager.create_environment_config(
        environment="development",
        primary_tablespace="DEV_DATA",
        lob_tablespaces=["DEV_LOB_01", "DEV_LOB_02"],
        min_subpartitions=2,
        max_subpartitions=8,
        min_parallel=1,
        max_parallel=4,
        default_parallel=2,
    )

    # Test configuration loading
    prod_config = env_manager.load_environment_config("production")
    print(f"Production config: {prod_config.tablespaces.primary}")

    # Test subpartition calculation
    subpart_count = env_manager.calculate_subpartition_count(75.5, "production")
    print(f"Recommended subpartitions for 75.5GB table: {subpart_count}")

    # Test tablespace selection
    tablespaces = env_manager.get_tablespaces("production")
    print(f"Production tablespaces: {tablespaces}")
