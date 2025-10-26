#!/usr/bin/env python3
"""
Migration Models Module
======================
Python dataclasses representing the migration configuration schema.
Similar to POJOs in Java, these provide type safety and structure.
"""

from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any, Union
from enum import Enum
import json
from datetime import datetime


class PartitionType(Enum):
    NONE = "NONE"
    RANGE = "RANGE"
    LIST = "LIST"
    HASH = "HASH"
    REFERENCE = "REFERENCE"
    SYSTEM = "SYSTEM"
    INTERVAL = "INTERVAL"


class IntervalType(Enum):
    HOUR = "HOUR"
    DAY = "DAY"
    WEEK = "WEEK"
    MONTH = "MONTH"


class SubpartitionType(Enum):
    HASH = "HASH"
    NONE = "NONE"


class MigrationAction(Enum):
    CONVERT_INTERVAL_TO_INTERVAL_HASH = "convert_interval_to_interval_hash"
    ADD_INTERVAL_HASH_PARTITIONING = "add_interval_hash_partitioning"
    ADD_INTERVAL_PARTITIONING = "add_interval_partitioning"
    ADD_HASH_SUBPARTITIONS = "add_hash_subpartitions"
    CONVERT_TO_INTERVAL_HASH = "convert_to_interval_hash"


class Priority(Enum):
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"


@dataclass
class ColumnInfo:
    """Information about a database column"""
    name: str
    type: str
    nullable: str  # "Y" or "N"
    length: Optional[int] = None
    precision: Optional[int] = None
    scale: Optional[int] = None
    default: Optional[str] = None
    char_length: Optional[int] = None
    is_identity: bool = False
    identity_generation: Optional[str] = None
    identity_sequence: Optional[str] = None
    identity_start_with: Optional[int] = None
    identity_increment_by: Optional[int] = None
    identity_max_value: Optional[int] = None
    identity_min_value: Optional[int] = None
    identity_cache_size: Optional[int] = None
    identity_cycle_flag: Optional[str] = None
    identity_order_flag: Optional[str] = None


@dataclass
class LobStorageInfo:
    """LOB storage configuration details"""
    column_name: str
    segment_name: str
    tablespace_name: str
    original_tablespace: str
    securefile: str
    compression: str
    deduplication: str
    in_row: str
    chunk: int
    cache: str


@dataclass
class StorageParameters:
    """Table storage parameters"""
    compression: str = "DISABLED"
    compress_for: str = ""
    pct_free: int = 10
    ini_trans: int = 1
    max_trans: int = 255
    initial_extent: Optional[int] = None
    next_extent: Optional[int] = None
    buffer_pool: str = "DEFAULT"


@dataclass
class IndexInfo:
    """Index definition with columns and storage details"""
    index_name: str
    index_type: str
    uniqueness: str
    tablespace_name: str
    compression: str
    pct_free: int
    ini_trans: int
    max_trans: int
    degree: str
    partitioned: str
    columns: str
    is_reverse: bool = False
    locality: Optional[str] = None


@dataclass  
class GrantInfo:
    """Table grant/privilege information"""
    grantee: str
    privilege: str
    grantable: str
    grantor: str
    grant_type: str = "OBJECT"  # OBJECT, ROLE, SYSTEM


@dataclass
class AvailableColumns:
    """Available columns for partitioning"""
    timestamp_columns: List[ColumnInfo] = field(default_factory=list)
    numeric_columns: List[ColumnInfo] = field(default_factory=list)
    string_columns: List[ColumnInfo] = field(default_factory=list)


@dataclass
class CurrentState:
    """Complete current table state with all metadata details"""
    is_partitioned: bool
    partition_type: str
    size_gb: float
    row_count: int
    lob_count: int
    index_count: int
    columns: List[ColumnInfo]
    lob_storage: List[LobStorageInfo]
    storage_parameters: StorageParameters
    indexes: List[IndexInfo]
    available_columns: AvailableColumns
    grants: List[GrantInfo] = field(default_factory=list)  # Captured grants information
    # Optional fields for partitioned tables
    is_interval: Optional[bool] = None
    interval_definition: Optional[str] = None
    current_partition_count: Optional[int] = None
    current_partition_key: Optional[str] = None
    has_subpartitions: Optional[bool] = None
    subpartition_type: Optional[str] = None
    subpartition_count: Optional[int] = None


@dataclass
class TargetConfiguration:
    """Target partitioning configuration"""
    partition_type: PartitionType
    partition_column: str
    interval_type: IntervalType
    interval_value: int
    initial_partition_value: str
    subpartition_type: SubpartitionType
    subpartition_column: Optional[str]
    subpartition_count: int
    tablespace: str
    lob_tablespaces: List[str]
    parallel_degree: int


@dataclass
class MigrationSettings:
    """Migration execution settings"""
    validate_data: bool = True
    backup_old_table: bool = True
    drop_old_after_days: int = 7
    # New fields for conditional workflow
    migrate_data: bool = True  # Whether to perform data migration (step 20)
    enable_delta_load: bool = False  # Whether to perform delta loads (step 40)
    delta_load_interval: str = "last_day"  # Options: "last_day", "last_hour", "last_week"
    constraint_validation: bool = True  # Whether to validate constraints during swap
    auto_enable_constraints: bool = True  # Whether to auto-enable constraints after data load


@dataclass
class CommonSettings:
    """Common configurable settings for migration"""
    new_table_name: str
    old_table_name: str
    migration_action: MigrationAction
    target_configuration: TargetConfiguration
    migration_settings: MigrationSettings


@dataclass
class TablespaceConfig:
    """Tablespace configuration"""
    primary: str
    lob: List[str]


@dataclass
class DataTablespaces:
    """Data tablespaces configuration"""
    data: TablespaceConfig


@dataclass
class SizeRecommendation:
    """Size-based subpartition recommendation"""
    max_gb: int
    count: int


@dataclass
class SubpartitionDefaults:
    """Subpartition default settings"""
    min_count: int
    max_count: int
    size_based_recommendations: Dict[str, SizeRecommendation]


@dataclass
class ParallelDefaults:
    """Parallel processing defaults"""
    min_degree: int
    max_degree: int
    default_degree: int


@dataclass
class EnvironmentConfig:
    """Environment-specific configuration"""
    name: str
    tablespaces: DataTablespaces
    subpartition_defaults: SubpartitionDefaults
    parallel_defaults: ParallelDefaults


@dataclass
class ConnectionDetails:
    """Source database connection details"""
    type: str
    host: str
    port: str
    service: str
    user: str


@dataclass
class Metadata:
    """Metadata about the migration configuration"""
    generated_date: str
    environment: str
    source_schema: str
    source_database_service: str
    source_connection_details: ConnectionDetails
    discovery_criteria: str
    total_tables_found: int
    tables_selected_for_migration: int
    schema: str  # Legacy field for backward compatibility
    discovery_validation_hash: Optional[str] = None  # Added to validate discovery-generated configs


@dataclass
class TableConfig:
    """Configuration for a single table migration"""
    enabled: bool
    owner: str
    table_name: str
    current_state: CurrentState
    common_settings: CommonSettings


@dataclass
class MigrationConfig:
    """Complete migration configuration"""
    metadata: Metadata
    environment_config: EnvironmentConfig
    tables: List[TableConfig]

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        return {
            "metadata": {
                "generated_date": self.metadata.generated_date,
                "environment": self.metadata.environment,
                "source_schema": self.metadata.source_schema,
                "source_database_service": self.metadata.source_database_service,
                "source_connection_details": {
                    "type": self.metadata.source_connection_details.type,
                    "host": self.metadata.source_connection_details.host,
                    "port": self.metadata.source_connection_details.port,
                    "service": self.metadata.source_connection_details.service,
                    "user": self.metadata.source_connection_details.user,
                },
                "discovery_criteria": self.metadata.discovery_criteria,
                "total_tables_found": self.metadata.total_tables_found,
                "tables_selected_for_migration": self.metadata.tables_selected_for_migration,
                "schema": self.metadata.schema,
            },
            "environment_config": {
                "name": self.environment_config.name,
                "tablespaces": {
                    "data": {
                        "primary": self.environment_config.tablespaces.data.primary,
                        "lob": self.environment_config.tablespaces.data.lob,
                    }
                },
                "subpartition_defaults": {
                    "min_count": self.environment_config.subpartition_defaults.min_count,
                    "max_count": self.environment_config.subpartition_defaults.max_count,
                    "size_based_recommendations": {
                        k: {
                            "max_gb": v.max_gb,
                            "count": v.count,
                        }
                        for k, v in self.environment_config.subpartition_defaults.size_based_recommendations.items()
                    },
                },
                "parallel_defaults": {
                    "min_degree": self.environment_config.parallel_defaults.min_degree,
                    "max_degree": self.environment_config.parallel_defaults.max_degree,
                    "default_degree": self.environment_config.parallel_defaults.default_degree,
                },
            },
            "tables": [self._table_to_dict(table) for table in self.tables],
        }

    def _table_to_dict(self, table: TableConfig) -> Dict[str, Any]:
        """Convert table config to dictionary"""
        return {
            "enabled": table.enabled,
            "owner": table.owner,
            "table_name": table.table_name,
            "current_state": {
                "is_partitioned": table.current_state.is_partitioned,
                "partition_type": table.current_state.partition_type,
                "size_gb": table.current_state.size_gb,
                "row_count": table.current_state.row_count,
                "lob_count": table.current_state.lob_count,
                "index_count": table.current_state.index_count,
                "columns": [self._column_to_dict(col) for col in table.current_state.columns],
                "lob_storage": [self._lob_to_dict(lob) for lob in table.current_state.lob_storage],
                "storage_parameters": {
                    "compression": table.current_state.storage_parameters.compression,
                    "compress_for": table.current_state.storage_parameters.compress_for,
                    "pct_free": table.current_state.storage_parameters.pct_free,
                    "ini_trans": table.current_state.storage_parameters.ini_trans,
                    "max_trans": table.current_state.storage_parameters.max_trans,
                    "initial_extent": table.current_state.storage_parameters.initial_extent,
                    "next_extent": table.current_state.storage_parameters.next_extent,
                    "buffer_pool": table.current_state.storage_parameters.buffer_pool,
                },
                "indexes": [self._index_to_dict(idx) for idx in table.current_state.indexes],
                "available_columns": {
                    "timestamp_columns": [self._column_info_to_dict(col) for col in table.current_state.available_columns.timestamp_columns],
                    "numeric_columns": [self._column_info_to_dict(col) for col in table.current_state.available_columns.numeric_columns],
                    "string_columns": [self._column_info_to_dict(col) for col in table.current_state.available_columns.string_columns],
                },
                # Optional fields
                **{k: v for k, v in {
                    "is_interval": table.current_state.is_interval,
                    "interval_definition": table.current_state.interval_definition,
                    "current_partition_count": table.current_state.current_partition_count,
                    "current_partition_key": table.current_state.current_partition_key,
                    "has_subpartitions": table.current_state.has_subpartitions,
                    "subpartition_type": table.current_state.subpartition_type,
                    "subpartition_count": table.current_state.subpartition_count,
                }.items() if v is not None}
            },
            "common_settings": {
                "new_table_name": table.common_settings.new_table_name,
                "old_table_name": table.common_settings.old_table_name,
                "migration_action": table.common_settings.migration_action.value,
                "target_configuration": {
                    "partition_type": table.common_settings.target_configuration.partition_type.value,
                    "partition_column": table.common_settings.target_configuration.partition_column,
                    "interval_type": table.common_settings.target_configuration.interval_type.value,
                    "interval_value": table.common_settings.target_configuration.interval_value,
                    "initial_partition_value": table.common_settings.target_configuration.initial_partition_value,
                    "subpartition_type": table.common_settings.target_configuration.subpartition_type.value,
                    "subpartition_column": table.common_settings.target_configuration.subpartition_column,
                    "subpartition_count": table.common_settings.target_configuration.subpartition_count,
                    "tablespace": table.common_settings.target_configuration.tablespace,
                    "lob_tablespaces": table.common_settings.target_configuration.lob_tablespaces,
                    "parallel_degree": table.common_settings.target_configuration.parallel_degree,
                },
                "migration_settings": {
                    "validate_data": table.common_settings.migration_settings.validate_data,
                    "backup_old_table": table.common_settings.migration_settings.backup_old_table,
                    "drop_old_after_days": table.common_settings.migration_settings.drop_old_after_days,
                },
            },
        }

    def _column_to_dict(self, col: ColumnInfo) -> Dict[str, Any]:
        """Convert column info to dictionary"""
        result = {
            "name": col.name,
            "type": col.type,
            "length": col.length,
            "precision": col.precision,
            "scale": col.scale,
            "nullable": col.nullable,
            "default": col.default,
            "char_length": col.char_length,
            "is_identity": col.is_identity,
        }
        
        # Add identity fields if column is identity
        if col.is_identity:
            result.update({
                "identity_generation": col.identity_generation,
                "identity_sequence": col.identity_sequence,
                "identity_start_with": col.identity_start_with,
                "identity_increment_by": col.identity_increment_by,
                "identity_max_value": col.identity_max_value,
                "identity_min_value": col.identity_min_value,
                "identity_cache_size": col.identity_cache_size,
                "identity_cycle_flag": col.identity_cycle_flag,
                "identity_order_flag": col.identity_order_flag,
            })
        
        return result

    def _column_info_to_dict(self, col: ColumnInfo) -> Dict[str, Any]:
        """Convert column info for available_columns to dictionary"""
        return {
            "name": col.name,
            "type": col.type,
            "nullable": col.nullable,
        }

    def _lob_to_dict(self, lob: LobStorageInfo) -> Dict[str, Any]:
        """Convert LOB storage info to dictionary"""
        return {
            "column_name": lob.column_name,
            "segment_name": lob.segment_name,
            "tablespace_name": lob.tablespace_name,
            "original_tablespace": lob.original_tablespace,
            "securefile": lob.securefile,
            "compression": lob.compression,
            "deduplication": lob.deduplication,
            "in_row": lob.in_row,
            "chunk": lob.chunk,
            "cache": lob.cache,
        }

    def _index_to_dict(self, idx: IndexInfo) -> Dict[str, Any]:
        """Convert index info to dictionary"""
        result = {
            "index_name": idx.index_name,
            "index_type": idx.index_type,
            "uniqueness": idx.uniqueness,
            "tablespace_name": idx.tablespace_name,
            "compression": idx.compression,
            "pct_free": idx.pct_free,
            "ini_trans": idx.ini_trans,
            "max_trans": idx.max_trans,
            "degree": idx.degree,
            "partitioned": idx.partitioned,
            "columns": idx.columns,
            "is_reverse": idx.is_reverse,
        }
        
        if idx.locality:
            result["locality"] = idx.locality
            
        return result

    def to_json(self, indent: int = 2) -> str:
        """Convert to JSON string"""
        return json.dumps(self.to_dict(), indent=indent, default=str)

    def save_to_file(self, filename: str) -> None:
        """Save to JSON file"""
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(self.to_json())

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'MigrationConfig':
        """Create MigrationConfig from dictionary (deserialization)"""
        # Parse metadata
        metadata_dict = data["metadata"]
        metadata = Metadata(
            generated_date=metadata_dict["generated_date"],
            environment=metadata_dict["environment"],
            source_schema=metadata_dict["source_schema"],
            source_database_service=metadata_dict["source_database_service"],
            source_connection_details=ConnectionDetails(**metadata_dict["source_connection_details"]),
            discovery_criteria=metadata_dict["discovery_criteria"],
            total_tables_found=metadata_dict["total_tables_found"],
            tables_selected_for_migration=metadata_dict["tables_selected_for_migration"],
            schema=metadata_dict["schema"],
        )

        # Parse environment config
        env_dict = data["environment_config"]
        env_config = EnvironmentConfig(
            name=env_dict["name"],
            tablespaces=DataTablespaces(
                data=TablespaceConfig(
                    primary=env_dict["tablespaces"]["data"]["primary"],
                    lob=env_dict["tablespaces"]["data"]["lob"],
                )
            ),
            subpartition_defaults=SubpartitionDefaults(
                min_count=env_dict["subpartition_defaults"]["min_count"],
                max_count=env_dict["subpartition_defaults"]["max_count"],
                size_based_recommendations={
                    k: SizeRecommendation(**v)
                    for k, v in env_dict["subpartition_defaults"]["size_based_recommendations"].items()
                },
            ),
            parallel_defaults=ParallelDefaults(**env_dict["parallel_defaults"]),
        )

        # Parse tables
        tables = [cls._table_from_dict(table_dict) for table_dict in data["tables"]]

        return cls(metadata=metadata, environment_config=env_config, tables=tables)

    @classmethod
    def _table_from_dict(cls, data: Dict[str, Any]) -> TableConfig:
        """Create TableConfig from dictionary"""
        current_state_dict = data["current_state"]
        common_settings_dict = data["common_settings"]

        # Parse current state
        current_state = CurrentState(
            is_partitioned=current_state_dict["is_partitioned"],
            partition_type=current_state_dict["partition_type"],
            size_gb=current_state_dict["size_gb"],
            row_count=current_state_dict["row_count"],
            lob_count=current_state_dict["lob_count"],
            index_count=current_state_dict["index_count"],
            columns=[ColumnInfo(**col_dict) for col_dict in current_state_dict["columns"]],
            lob_storage=[LobStorageInfo(**lob_dict) for lob_dict in current_state_dict["lob_storage"]],
            storage_parameters=StorageParameters(**current_state_dict["storage_parameters"]),
            indexes=[IndexInfo(**idx_dict) for idx_dict in current_state_dict["indexes"]],
            available_columns=AvailableColumns(
                timestamp_columns=[ColumnInfo(**col) for col in current_state_dict["available_columns"]["timestamp_columns"]],
                numeric_columns=[ColumnInfo(**col) for col in current_state_dict["available_columns"]["numeric_columns"]],
                string_columns=[ColumnInfo(**col) for col in current_state_dict["available_columns"]["string_columns"]],
            ),
            # Optional fields
            is_interval=current_state_dict.get("is_interval"),
            interval_definition=current_state_dict.get("interval_definition"),
            current_partition_count=current_state_dict.get("current_partition_count"),
            current_partition_key=current_state_dict.get("current_partition_key"),
            has_subpartitions=current_state_dict.get("has_subpartitions"),
            subpartition_type=current_state_dict.get("subpartition_type"),
            subpartition_count=current_state_dict.get("subpartition_count"),
        )

        # Parse target configuration
        target_dict = common_settings_dict["target_configuration"]
        target_config = TargetConfiguration(
            partition_type=PartitionType(target_dict["partition_type"]),
            partition_column=target_dict["partition_column"],
            interval_type=IntervalType(target_dict["interval_type"]),
            interval_value=target_dict["interval_value"],
            initial_partition_value=target_dict["initial_partition_value"],
            subpartition_type=SubpartitionType(target_dict["subpartition_type"]),
            subpartition_column=target_dict.get("subpartition_column"),
            subpartition_count=target_dict["subpartition_count"],
            tablespace=target_dict["tablespace"],
            lob_tablespaces=target_dict["lob_tablespaces"],
            parallel_degree=target_dict["parallel_degree"],
        )

        # Parse common settings
        common_settings = CommonSettings(
            new_table_name=common_settings_dict["new_table_name"],
            old_table_name=common_settings_dict["old_table_name"],
            migration_action=MigrationAction(common_settings_dict["migration_action"]),
            target_configuration=target_config,
            migration_settings=MigrationSettings(**common_settings_dict["migration_settings"]),
        )

        return TableConfig(
            enabled=data["enabled"],
            owner=data["owner"],
            table_name=data["table_name"],
            current_state=current_state,
            common_settings=common_settings,
        )

    @classmethod
    def from_json_file(cls, filename: str) -> 'MigrationConfig':
        """Load MigrationConfig from JSON file"""
        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return cls.from_dict(data)