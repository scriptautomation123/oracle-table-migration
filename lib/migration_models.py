#!/usr/bin/env python3
"""
Generated Migration Models
=========================
Auto-generated from migration_schema.json
DO NOT EDIT MANUALLY - Use tools/schema_to_dataclass.py

Generated: 2025-10-26 15:59:47
"""

from dataclasses import asdict
from dataclasses import dataclass, field
from enum import Enum
from typing import List, Optional, Dict, Any, Union

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
    ENABLED = "ENABLED"
    DISABLED = "DISABLED"

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
class ConnectionDetails:
    """Database connection details for metadata tracking"""
    type: str = None  # Oracle connection type
    host: str = None  # Database host
    port: str = None  # Database port
    service: str = None  # Oracle service name or SID
    user: str = None  # Database user

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ConnectionDetails":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


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
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Metadata":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


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
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "LobStorageInfo":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


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
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ColumnInfo":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


@dataclass
class AvailableColumns:
    """Columns available for different partitioning strategies"""
    timestamp_columns: List[ColumnInfo] = field(default_factory=list)  # Timestamp/date columns suitable for interval partitioning
    numeric_columns: List[ColumnInfo] = field(default_factory=list)  # Numeric columns suitable for hash/range partitioning
    string_columns: List[ColumnInfo] = field(default_factory=list)  # String columns suitable for hash/list partitioning

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "AvailableColumns":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


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
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "IndexInfo":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


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
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "StorageParameters":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


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
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "CurrentState":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


@dataclass
class MigrationSettings:
    """Migration execution and validation settings"""
    validate_data: bool = None  # Whether to validate data after migration
    backup_old_table: bool = None  # Whether to keep old table as backup
    drop_old_after_days: int = None  # Days to wait before dropping old table (0 = immediate)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "MigrationSettings":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


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

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "TargetConfiguration":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


@dataclass
class CommonSettings:
    """Common configurable settings for table migration"""
    new_table_name: str  # Name for the new partitioned table
    old_table_name: str  # Name for the old table backup
    migration_action: MigrationActionEnum
    target_configuration: TargetConfiguration
    migration_settings: MigrationSettings

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "CommonSettings":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


@dataclass
class TableConfig:
    """Complete table configuration for migration"""
    enabled: bool  # Whether this table should be migrated
    owner: str  # Table owner (schema)
    table_name: str  # Table name
    current_state: CurrentState
    common_settings: CommonSettings

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "TableConfig":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


@dataclass
class TablespaceConfig:
    """Tablespace names for data and LOB storage"""
    primary: str = None  # Primary tablespace for table data
    lob: List[str] = field(default_factory=list)  # Array of LOB tablespaces

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "TablespaceConfig":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


@dataclass
class DataTablespaces:
    """Tablespace configuration for data and LOB storage"""
    data: TablespaceConfig = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "DataTablespaces":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


@dataclass
class ParallelDefaults:
    """Default parallel execution settings"""
    min_degree: int = None  # Minimum parallel degree
    max_degree: int = None  # Maximum parallel degree
    default_degree: int = None  # Default parallel degree

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ParallelDefaults":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


@dataclass
class SubpartitionDefaults:
    """Default settings for subpartitioning"""
    min_count: int = None  # Minimum subpartition count
    max_count: int = None  # Maximum subpartition count
    size_based_recommendations: Dict[str, Any] = field(default_factory=dict)  # Size-based subpartition recommendations

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "SubpartitionDefaults":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


@dataclass
class EnvironmentConfig:
    """Environment-specific configuration for tablespaces and defaults"""
    name: str  # Environment name
    tablespaces: DataTablespaces
    subpartition_defaults: SubpartitionDefaults = None
    parallel_defaults: ParallelDefaults = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "EnvironmentConfig":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


@dataclass
class MigrationConfig:
    """Comprehensive schema for Oracle table migration supporting all partition types and Oracle features"""
    metadata: Metadata
    environment_config: EnvironmentConfig
    tables: List[TableConfig]  # Array of table configurations

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "MigrationConfig":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)


@dataclass
class SizeRecommendation:
    """Size-based partitioning recommendation"""
    max_gb: float  # Maximum size in GB for this recommendation
    count: int  # Recommended partition count

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        from dataclasses import asdict
        result = asdict(self)
        # Recursively convert enums and nested objects
        def convert_value(val):
            if isinstance(val, Enum):
                return val.value
            elif isinstance(val, dict):
                return {k: convert_value(v) for k, v in val.items()}
            elif isinstance(val, list):
                return [convert_value(item) for item in val]
            return val
        return convert_value(result)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "SizeRecommendation":
        """Create instance from dictionary with proper type conversions"""
        if data is None:
            return None
        return cls(**data)

