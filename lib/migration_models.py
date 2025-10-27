#!/usr/bin/env python3
"""
Generated Migration Models
=========================
Auto-generated from enhanced_migration_schema.json
DO NOT EDIT MANUALLY - Run: python3 src/schema_to_dataclass.py

Generated: 2025-10-27 09:20:20
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import List, Optional, Dict, Any

class PartitionTypeEnum(Enum):
    """PartitionTypeEnum enumeration"""
    NONE = "NONE"
    RANGE = "RANGE"
    LIST = "LIST"
    HASH = "HASH"
    REFERENCE = "REFERENCE"
    SYSTEM = "SYSTEM"
    INTERVAL = "INTERVAL"

class IntervalTypeEnum(Enum):
    """IntervalTypeEnum enumeration"""
    HOUR = "HOUR"
    DAY = "DAY"
    WEEK = "WEEK"
    MONTH = "MONTH"
    YEAR = "YEAR"

class SubpartitionTypeEnum(Enum):
    """SubpartitionTypeEnum enumeration"""
    HASH = "HASH"
    LIST = "LIST"
    RANGE = "RANGE"
    NONE = "NONE"

class MigrationActionEnum(Enum):
    """MigrationActionEnum enumeration"""
    CONVERT_INTERVAL_TO_INTERVAL_HASH = "convert_interval_to_interval_hash"
    ADD_INTERVAL_HASH_PARTITIONING = "add_interval_hash_partitioning"
    ADD_INTERVAL_PARTITIONING = "add_interval_partitioning"
    ADD_HASH_SUBPARTITIONS = "add_hash_subpartitions"
    CONVERT_TO_INTERVAL_HASH = "convert_to_interval_hash"
    ADD_RANGE_PARTITIONING = "add_range_partitioning"
    ADD_LIST_PARTITIONING = "add_list_partitioning"
    ADD_HASH_PARTITIONING = "add_hash_partitioning"
    CONVERT_RANGE_TO_INTERVAL = "convert_range_to_interval"
    ADD_COMPOSITE_PARTITIONING = "add_composite_partitioning"

class YesNoEnum(Enum):
    """YesNoEnum enumeration"""
    Y = "Y"
    N = "N"
    YES = "YES"
    NO = "NO"

class TypeEnum(Enum):
    """TypeEnum enumeration"""
    SERVICE_NAME = "Service Name"
    SID = "SID"
    EASY_CONNECT = "Easy Connect"

class IdentityGenerationEnum(Enum):
    """IdentityGenerationEnum enumeration"""
    ALWAYS = "ALWAYS"
    BY_DEFAULT = "BY DEFAULT"

class IdentityCycleFlagEnum(Enum):
    """IdentityCycleFlagEnum enumeration"""
    Y = "Y"
    N = "N"

class CompressionEnum(Enum):
    """CompressionEnum enumeration"""
    DISABLED = "DISABLED"
    ENABLED = "ENABLED"
    BASIC = "BASIC"
    OLTP = "OLTP"
    QUERY_HIGH = "QUERY HIGH"
    QUERY_LOW = "QUERY LOW"
    ARCHIVE_LOW = "ARCHIVE LOW"
    ARCHIVE_HIGH = "ARCHIVE HIGH"

class BufferPoolEnum(Enum):
    """BufferPoolEnum enumeration"""
    DEFAULT = "DEFAULT"
    KEEP = "KEEP"
    RECYCLE = "RECYCLE"

class IndexTypeEnum(Enum):
    """IndexTypeEnum enumeration"""
    NORMAL = "NORMAL"
    BITMAP = "BITMAP"
    FUNCTION_BASED_NORMAL = "FUNCTION-BASED NORMAL"
    FUNCTION_BASED_BITMAP = "FUNCTION-BASED BITMAP"

class UniquenessEnum(Enum):
    """UniquenessEnum enumeration"""
    UNIQUE = "UNIQUE"
    NONUNIQUE = "NONUNIQUE"

class LocalityEnum(Enum):
    """LocalityEnum enumeration"""
    LOCAL = "LOCAL"
    GLOBAL = "GLOBAL"

@dataclass
class IndexInfo:
    """Oracle index definition with storage details"""
    index_name: str  # Index name
    index_type: str  # Oracle index type
    columns: str  # Comma-separated list of index columns
    uniqueness: str = None  # Index uniqueness
    tablespace_name: str = None  # Index tablespace
    compression: str = None  # Index compression
    pct_free: int = None  # Index PCTFREE
    ini_trans: int = None  # Index INITRANS
    max_trans: int = None  # Index MAXTRANS
    degree: str = None  # Parallel degree for index operations
    partitioned: YesNoEnum = None
    is_reverse: bool = None  # Whether index is reverse key
    locality: Optional[str] = None  # Partitioned index locality

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "IndexInfo":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            index_name=data["index_name"],
            index_type=data["index_type"],
            uniqueness=data.get("uniqueness"),
            tablespace_name=data.get("tablespace_name"),
            compression=data.get("compression"),
            pct_free=data.get("pct_free"),
            ini_trans=data.get("ini_trans"),
            max_trans=data.get("max_trans"),
            degree=data.get("degree"),
            partitioned=YesNoEnum(data["partitioned"]) if "partitioned" in data and data["partitioned"] is not None else None,
            columns=data["columns"],
            is_reverse=data.get("is_reverse", False),
            locality=data.get("locality"),
        )


@dataclass
class ColumnInfo:
    """Complete column metadata for Oracle DDL generation"""
    name: str  # Column name
    type: str  # Oracle data type (VARCHAR2, NUMBER, etc.)
    nullable: YesNoEnum
    length: Optional[int] = None  # Data length for VARCHAR2, etc.
    precision: Optional[int] = None  # Numeric precision
    scale: Optional[int] = None  # Numeric scale
    default: Optional[str] = None  # Default value expression
    char_length: Optional[int] = None  # Character length for CHAR/VARCHAR2
    is_identity: bool = None  # Whether column is an identity column
    identity_generation: Optional[str] = None  # Identity generation type
    identity_sequence: Optional[str] = None  # Associated sequence name for identity
    identity_start_with: Optional[int] = None  # Identity START WITH value
    identity_increment_by: Optional[int] = None  # Identity INCREMENT BY value
    identity_max_value: Optional[int] = None  # Identity MAXVALUE
    identity_min_value: Optional[int] = None  # Identity MINVALUE
    identity_cache_size: Optional[int] = None  # Identity CACHE size
    identity_cycle_flag: Optional[str] = None  # Identity CYCLE flag
    identity_order_flag: Optional[str] = None  # Identity ORDER flag

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        # Remove identity-specific fields if this is not an identity column
        if hasattr(self, 'is_identity') and not self.is_identity:
            identity_fields = [
                'identity_generation', 'identity_sequence', 'identity_start_with',
                'identity_increment_by', 'identity_max_value', 'identity_min_value',
                'identity_cache_size', 'identity_cycle_flag', 'identity_order_flag'
            ]
            for field in identity_fields:
                result.pop(field, None)
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ColumnInfo":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            name=data["name"],
            type=data["type"],
            length=data.get("length"),
            precision=data.get("precision"),
            scale=data.get("scale"),
            nullable=YesNoEnum(data["nullable"]) if "nullable" in data else None,
            default=data.get("default"),
            char_length=data.get("char_length"),
            is_identity=data.get("is_identity", False),
            identity_generation=data.get("identity_generation"),
            identity_sequence=data.get("identity_sequence"),
            identity_start_with=data.get("identity_start_with"),
            identity_increment_by=data.get("identity_increment_by"),
            identity_max_value=data.get("identity_max_value"),
            identity_min_value=data.get("identity_min_value"),
            identity_cache_size=data.get("identity_cache_size"),
            identity_cycle_flag=data.get("identity_cycle_flag"),
            identity_order_flag=data.get("identity_order_flag"),
        )


@dataclass
class AvailableColumns:
    """Columns available for different partitioning strategies"""
    timestamp_columns: List[ColumnInfo] = field(default_factory=list)  # Timestamp/date columns suitable for interval partitioning
    numeric_columns: List[ColumnInfo] = field(default_factory=list)  # Numeric columns suitable for hash/range partitioning
    string_columns: List[ColumnInfo] = field(default_factory=list)  # String columns suitable for hash/list partitioning

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "AvailableColumns":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            timestamp_columns=[ColumnInfo.from_dict(x) for x in data.get("timestamp_columns", [])],
            numeric_columns=[ColumnInfo.from_dict(x) for x in data.get("numeric_columns", [])],
            string_columns=[ColumnInfo.from_dict(x) for x in data.get("string_columns", [])],
        )


@dataclass
class StorageParameters:
    """Oracle table storage parameters"""
    compression: str = None  # Table compression setting
    compress_for: str = None  # Compression type details
    pct_free: int = None  # PCTFREE storage parameter
    ini_trans: int = None  # INITRANS storage parameter
    max_trans: int = None  # MAXTRANS storage parameter
    initial_extent: Optional[int] = None  # Initial extent size in bytes
    next_extent: Optional[int] = None  # Next extent size in bytes
    buffer_pool: str = None  # Buffer pool assignment

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "StorageParameters":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            compression=data.get("compression", "DISABLED"),
            compress_for=data.get("compress_for"),
            pct_free=data.get("pct_free", 10),
            ini_trans=data.get("ini_trans", 1),
            max_trans=data.get("max_trans", 255),
            initial_extent=data.get("initial_extent"),
            next_extent=data.get("next_extent"),
            buffer_pool=data.get("buffer_pool", "DEFAULT"),
        )


@dataclass
class LobStorageInfo:
    """LOB storage configuration for Oracle DDL"""
    column_name: str  # LOB column name
    tablespace_name: str  # LOB tablespace
    segment_name: str = None  # LOB segment name
    original_tablespace: str = None  # Original LOB tablespace
    securefile: YesNoEnum = None
    compression: YesNoEnum = None
    deduplication: YesNoEnum = None
    in_row: YesNoEnum = None
    chunk: int = None  # LOB chunk size
    cache: YesNoEnum = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "LobStorageInfo":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            column_name=data["column_name"],
            segment_name=data.get("segment_name"),
            tablespace_name=data["tablespace_name"],
            original_tablespace=data.get("original_tablespace"),
            securefile=YesNoEnum(data["securefile"]) if "securefile" in data and data["securefile"] is not None else None,
            compression=YesNoEnum(data["compression"]) if "compression" in data and data["compression"] is not None else None,
            deduplication=YesNoEnum(data["deduplication"]) if "deduplication" in data and data["deduplication"] is not None else None,
            in_row=YesNoEnum(data["in_row"]) if "in_row" in data and data["in_row"] is not None else None,
            chunk=data.get("chunk"),
            cache=YesNoEnum(data["cache"]) if "cache" in data and data["cache"] is not None else None,
        )


@dataclass
class CurrentState:
    """Complete current table state with all Oracle metadata"""
    is_partitioned: bool  # Whether table is currently partitioned
    partition_type: PartitionTypeEnum
    size_gb: float  # Table size in GB
    row_count: int  # Approximate row count
    lob_count: int  # Number of LOB columns
    index_count: int  # Number of indexes
    columns: List[ColumnInfo]  # Complete column metadata for DDL generation
    lob_storage: List[LobStorageInfo]  # LOB storage configuration details
    storage_parameters: StorageParameters
    indexes: List[IndexInfo]  # Index definitions with columns and storage
    available_columns: AvailableColumns
    is_interval: bool = None  # Whether table uses interval partitioning
    interval_definition: str = None  # Current interval definition if applicable
    current_partition_count: int = None  # Current number of partitions
    current_partition_key: str = None  # Current partition key column(s)
    has_subpartitions: bool = None  # Whether table has subpartitions
    subpartition_type: str = None  # Current subpartition type if applicable
    subpartition_count: int = None  # Current number of subpartitions per partition
    grants: List[Dict[str, Any]] = field(default_factory=list)  # Table grants and privileges for DDL generation

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "CurrentState":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            is_partitioned=data.get("is_partitioned", False),
            partition_type=PartitionTypeEnum(data["partition_type"]) if "partition_type" in data else None,
            size_gb=data["size_gb"],
            row_count=data["row_count"],
            lob_count=data["lob_count"],
            index_count=data["index_count"],
            columns=[ColumnInfo.from_dict(x) for x in data.get("columns", [])],
            lob_storage=[LobStorageInfo.from_dict(x) for x in data.get("lob_storage", [])],
            storage_parameters=StorageParameters.from_dict(data["storage_parameters"]) if "storage_parameters" in data else None,
            indexes=[IndexInfo.from_dict(x) for x in data.get("indexes", [])],
            available_columns=AvailableColumns.from_dict(data["available_columns"]) if "available_columns" in data else None,
            is_interval=data.get("is_interval", False),
            interval_definition=data.get("interval_definition"),
            current_partition_count=data.get("current_partition_count"),
            current_partition_key=data.get("current_partition_key"),
            has_subpartitions=data.get("has_subpartitions", False),
            subpartition_type=data.get("subpartition_type"),
            subpartition_count=data.get("subpartition_count"),
            grants=data.get("grants", []),
        )


@dataclass
class MigrationSettings:
    """Migration execution and validation settings"""
    validate_data: bool = None  # Whether to validate data after migration
    backup_old_table: bool = None  # Whether to keep old table as backup
    drop_old_after_days: int = None  # Days to wait before dropping old table (0 = immediate)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "MigrationSettings":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            validate_data=data.get("validate_data", True),
            backup_old_table=data.get("backup_old_table", True),
            drop_old_after_days=data.get("drop_old_after_days", 7),
        )


@dataclass
class PartitionStorageSettings:
    """Storage parameters for interval-hash partitioned tables"""
    data_tablespace: str = None  # Primary data tablespace for partitions
    subpartition_tablespaces: List[str] = field(default_factory=list)  # Array of tablespaces to distribute hash subpartitions across
    pct_free: int = None  # PCTFREE for partitions
    compression: str = None  # Partition-level compression
    segment_attributes: Dict[str, Any] = field(default_factory=dict)  # Additional segment attributes for partitions

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "PartitionStorageSettings":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            data_tablespace=data.get("data_tablespace", "USERS"),
            subpartition_tablespaces=data.get("subpartition_tablespaces", []),
            pct_free=data.get("pct_free", 10),
            compression=data.get("compression", "DISABLED"),
            segment_attributes=data.get("segment_attributes"),
        )


@dataclass
class TargetConfiguration:
    """Target partitioning configuration for Oracle tables"""
    partition_type: PartitionTypeEnum
    partition_column: Optional[str] = None  # Column to partition on
    interval_type: IntervalTypeEnum = None
    interval_value: int = None  # Interval value (e.g., 1 for 1 month)
    initial_partition_value: str = None  # Initial partition boundary (Oracle TO_DATE format)
    subpartition_type: SubpartitionTypeEnum = None
    subpartition_column: Optional[str] = None  # Column to subpartition on
    subpartition_count: int = None  # Number of hash subpartitions (power of 2 recommended)
    tablespace: str = None  # Primary tablespace name
    lob_tablespaces: List[str] = field(default_factory=list)  # LOB tablespace names
    parallel_degree: int = None  # Parallel degree for migration operations
    partition_storage: PartitionStorageSettings = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "TargetConfiguration":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            partition_type=PartitionTypeEnum(data["partition_type"]) if "partition_type" in data else None,
            partition_column=data.get("partition_column"),
            interval_type=IntervalTypeEnum(data["interval_type"]) if "interval_type" in data and data["interval_type"] is not None else None,
            interval_value=data.get("interval_value", 1),
            initial_partition_value=data.get("initial_partition_value"),
            subpartition_type=SubpartitionTypeEnum(data["subpartition_type"]) if "subpartition_type" in data and data["subpartition_type"] is not None else None,
            subpartition_column=data.get("subpartition_column"),
            subpartition_count=data.get("subpartition_count"),
            tablespace=data.get("tablespace"),
            lob_tablespaces=data.get("lob_tablespaces", []),
            parallel_degree=data.get("parallel_degree"),
            partition_storage=PartitionStorageSettings.from_dict(data["partition_storage"]) if "partition_storage" in data and data["partition_storage"] is not None else None,
        )


@dataclass
class CommonSettings:
    """Common configurable settings for table migration"""
    new_table_name: str  # Name for the new partitioned table
    old_table_name: str  # Name for the old table backup
    migration_action: MigrationActionEnum
    target_configuration: TargetConfiguration
    migration_settings: MigrationSettings

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "CommonSettings":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            new_table_name=data["new_table_name"],
            old_table_name=data["old_table_name"],
            migration_action=MigrationActionEnum(data["migration_action"]) if "migration_action" in data else None,
            target_configuration=TargetConfiguration.from_dict(data["target_configuration"]) if "target_configuration" in data else None,
            migration_settings=MigrationSettings.from_dict(data["migration_settings"]) if "migration_settings" in data else None,
        )


@dataclass
class TableConfig:
    """Complete table configuration for migration"""
    enabled: bool  # Whether this table should be migrated
    owner: str  # Table owner (schema)
    table_name: str  # Table name
    current_state: CurrentState
    common_settings: CommonSettings

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "TableConfig":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            enabled=data.get("enabled", False),
            owner=data["owner"],
            table_name=data["table_name"],
            current_state=CurrentState.from_dict(data["current_state"]) if "current_state" in data else None,
            common_settings=CommonSettings.from_dict(data["common_settings"]) if "common_settings" in data else None,
        )


@dataclass
class ConnectionDetails:
    """Database connection details for metadata tracking"""
    type: str = None  # Oracle connection type
    host: str = None  # Database host
    port: str = None  # Database port
    service: str = None  # Oracle service name or SID
    user: str = None  # Database user

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ConnectionDetails":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            type=data.get("type"),
            host=data.get("host"),
            port=data.get("port"),
            service=data.get("service"),
            user=data.get("user"),
        )


@dataclass
class Metadata:
    """Metadata about the migration configuration"""
    generated_date: str  # Date and time when configuration was generated
    source_schema: str  # Oracle schema name being analyzed
    environment: str = None  # Environment name (dev, test, prod)
    source_database_service: str = None  # Oracle database service name
    source_connection_details: ConnectionDetails = None
    discovery_criteria: str = None  # Criteria used for table discovery
    total_tables_found: int = None  # Total number of tables discovered
    tables_selected_for_migration: int = None  # Number of tables enabled for migration
    schema: str = None  # Alias for source_schema for backward compatibility

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Metadata":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            generated_date=data["generated_date"],
            environment=data.get("environment", "global"),
            source_schema=data["source_schema"],
            source_database_service=data.get("source_database_service"),
            source_connection_details=ConnectionDetails.from_dict(data["source_connection_details"]) if "source_connection_details" in data and data["source_connection_details"] is not None else None,
            discovery_criteria=data.get("discovery_criteria"),
            total_tables_found=data.get("total_tables_found"),
            tables_selected_for_migration=data.get("tables_selected_for_migration"),
            schema=data.get("schema"),
        )


@dataclass
class TablespaceConfig:
    """Tablespace names for data and LOB storage"""
    primary: str = None  # Primary tablespace for table data
    lob: List[str] = field(default_factory=list)  # Array of LOB tablespaces

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "TablespaceConfig":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            primary=data.get("primary"),
            lob=data.get("lob", []),
        )


@dataclass
class DataTablespaces:
    """Tablespace configuration for data and LOB storage"""
    data: TablespaceConfig = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "DataTablespaces":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            data=TablespaceConfig.from_dict(data["data"]) if "data" in data and data["data"] is not None else None,
        )


@dataclass
class ParallelDefaults:
    """Default parallel execution settings"""
    min_degree: int = None  # Minimum parallel degree
    max_degree: int = None  # Maximum parallel degree
    default_degree: int = None  # Default parallel degree

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ParallelDefaults":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            min_degree=data.get("min_degree"),
            max_degree=data.get("max_degree"),
            default_degree=data.get("default_degree"),
        )


@dataclass
class SubpartitionDefaults:
    """Default settings for subpartitioning"""
    min_count: int = None  # Minimum subpartition count
    max_count: int = None  # Maximum subpartition count
    size_based_recommendations: Dict[str, Any] = field(default_factory=dict)  # Size-based subpartition recommendations

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "SubpartitionDefaults":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            min_count=data.get("min_count"),
            max_count=data.get("max_count"),
            size_based_recommendations=data.get("size_based_recommendations"),
        )


@dataclass
class EnvironmentConfig:
    """Environment-specific configuration for tablespaces and defaults"""
    name: str  # Environment name
    tablespaces: DataTablespaces
    subpartition_defaults: SubpartitionDefaults = None
    parallel_defaults: ParallelDefaults = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "EnvironmentConfig":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            name=data["name"],
            tablespaces=DataTablespaces.from_dict(data["tablespaces"]) if "tablespaces" in data else None,
            subpartition_defaults=SubpartitionDefaults.from_dict(data["subpartition_defaults"]) if "subpartition_defaults" in data and data["subpartition_defaults"] is not None else None,
            parallel_defaults=ParallelDefaults.from_dict(data["parallel_defaults"]) if "parallel_defaults" in data and data["parallel_defaults"] is not None else None,
        )


@dataclass
class MigrationConfig:
    """Comprehensive schema for Oracle table migration supporting all partition types and Oracle features"""
    metadata: Metadata
    environment_config: EnvironmentConfig
    tables: List[TableConfig]  # Array of table configurations

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "MigrationConfig":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            metadata=Metadata.from_dict(data["metadata"]) if "metadata" in data else None,
            environment_config=EnvironmentConfig.from_dict(data["environment_config"]) if "environment_config" in data else None,
            tables=[TableConfig.from_dict(x) for x in data.get("tables", [])],
        )


@dataclass
class SizeRecommendation:
    """Size-based partitioning recommendation"""
    max_gb: float  # Maximum size in GB for this recommendation
    count: int  # Recommended partition count

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization - explicit recursive conversion"""
        import dataclasses
        def convert(val):
            if isinstance(val, Enum):
                return val.value
            elif dataclasses.is_dataclass(val):
                return val.to_dict()
            elif isinstance(val, list):
                return [convert(v) for v in val]
            elif isinstance(val, dict):
                return {k: convert(v) for k, v in val.items()}
            else:
                return val
        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}
        return result
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "SizeRecommendation":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(
            max_gb=data["max_gb"],
            count=data["count"],
        )

