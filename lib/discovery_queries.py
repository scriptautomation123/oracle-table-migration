#!/usr/bin/env python3
"""
Discovery Queries Module
========================
SQL queries and logic to discover all tables in a schema and generate
JSON configuration for migration using typed dataclasses.

This module:
- Identifies ALL tables (partitioned and non-partitioned)
- Detects current partition type and configuration
- Finds timestamp columns suitable for interval partitioning
- Finds numeric/string columns suitable for hash subpartitioning
- Analyzes table size, row count, LOBs, indexes
- Generates intelligent migration recommendations
- Uses Python dataclasses for type safety and automatic serialization
"""

from datetime import datetime
from typing import Dict, List, Optional

from .environment_config import EnvironmentConfigManager
from .migration_models import (
    MigrationConfig, TableConfig, CurrentState, CommonSettings,
    TargetConfiguration, MigrationSettings, ColumnInfo, LobStorageInfo,
    StorageParameters, IndexInfo, GrantInfo, AvailableColumns, Metadata, 
    EnvironmentConfig, DataTablespaces, TablespaceConfig,
    SubpartitionDefaults, SizeRecommendation, ParallelDefaults,
    ConnectionDetails, PartitionType, IntervalType, SubpartitionType,
    MigrationAction
)


class TableDiscovery:
    """Discover tables and generate migration configuration"""

    def __init__(self, connection, environment: str = None, connection_string: str = None):
        """
        Initialize discovery with database connection

        Args:
            connection: Oracle database connection (oracledb or cx_Oracle)
            environment: Environment name for configuration
            connection_string: Connection string for metadata tracking
        """
        self.connection = connection
        self.connection_string = connection_string
        self.schema = None
        self.tables = []
        self.metadata = {}
        self.environment = environment or "global"
        self.env_manager = EnvironmentConfigManager()

    def discover_schema(
        self,
        schema_name: str,
        include_patterns: Optional[List[str]] = None,
        exclude_patterns: Optional[List[str]] = None,
    ) -> MigrationConfig:
        """
        Discover all tables in schema and generate JSON configuration

        Args:
            schema_name: Oracle schema name to analyze
            include_patterns: List of table name patterns to include (e.g., ['IE_%'])
            exclude_patterns: List of table name patterns to exclude (e.g., ['TEMP_%'])

        Returns:
            MigrationConfig dataclass with complete configuration
        """
        self.schema = schema_name.upper()

        print(f"\n{'='*70}")
        print(f"Discovering schema: {self.schema}")
        print(f"{'='*70}\n")

        # Step 1: Get all tables
        all_tables = self._get_all_tables(include_patterns, exclude_patterns)
        print(f"✓ Found {len(all_tables)} tables")

        # Step 2: Get partition information
        partition_info = self._get_partition_info()
        print("✓ Analyzed partition status")

        # Step 3: Get table sizes and stats
        table_sizes = self._get_table_sizes()
        table_stats = self._get_table_stats()
        print("✓ Retrieved table statistics")

        # Step 4: Get LOB and index counts
        lob_counts = self._get_lob_counts()
        index_counts = self._get_index_counts()
        print("✓ Analyzed LOBs and indexes")
        
        # Step 5: Get constraints and referential integrity
        constraint_info = self._get_constraint_info()
        referential_integrity = self._get_referential_integrity()
        print("✓ Analyzed constraints and referential integrity")

        # Step 5: For each table, get columns (timestamp, numeric, string)
        print("✓ Analyzing columns for each table...")

        tables_config = []
        for table_name in all_tables:
            table_config = self._analyze_table(
                table_name,
                partition_info.get(table_name),
                table_sizes.get(table_name, 0),
                table_stats.get(table_name, {}),
                lob_counts.get(table_name, 0),
                index_counts.get(table_name, 0),
            )
            tables_config.append(table_config)
            print(f"  • {table_name}: {table_config.common_settings.migration_action}")

        # Step 6: Build typed metadata
        connection_details = self._build_connection_details()
        metadata = Metadata(
            generated_date=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            environment=self.environment,
            source_schema=self.schema,
            source_database_service=self._extract_database_service(),
            source_connection_details=connection_details,
            discovery_criteria=self._format_criteria(include_patterns, exclude_patterns),
            total_tables_found=len(all_tables),
            tables_selected_for_migration=len([t for t in tables_config if t.enabled]),
            schema=self.schema,  # Keep legacy field for backward compatibility
        )

        # Build typed environment configuration
        environment_config = self._build_environment_config()

        # Create the complete typed configuration
        config = MigrationConfig(
            metadata=metadata,
            environment_config=environment_config,
            tables=tables_config
        )

        print(f"\n{'='*70}")
        print("Discovery complete!")
        print(f"  Total tables: {len(all_tables)}")
        print(
            f"  Enabled for migration: {metadata.tables_selected_for_migration}"
        )
        print(f"{'='*70}\n")

        return config

    def _get_all_tables(
        self,
        include_patterns: Optional[List[str]] = None,
        exclude_patterns: Optional[List[str]] = None,
    ) -> List[str]:
        """Get list of all table names in schema"""
        cursor = self.connection.cursor()

        # Build WHERE clause with patterns
        where_clauses = ["owner = :schema"]
        params = {"schema": self.schema}

        if include_patterns:
            include_clause = " OR ".join(
                [f"table_name LIKE :inc_{i}" for i in range(len(include_patterns))]
            )
            where_clauses.append(f"({include_clause})")
            for i, pattern in enumerate(include_patterns):
                params[f"inc_{i}"] = pattern.upper()

        if exclude_patterns:
            for i, pattern in enumerate(exclude_patterns):
                where_clauses.append(f"table_name NOT LIKE :exc_{i}")
                params[f"exc_{i}"] = pattern.upper()

        # Build query with dynamic WHERE clause from trusted list
        # SQL injection is prevented by:
        # 1. where_clauses contains only internally generated strings (not user input)
        # 2. All user values are passed via bind variables (params)
        where_clause = " AND ".join(where_clauses)
        query = f"""
            SELECT table_name
            FROM all_tables
            WHERE {where_clause}
            ORDER BY table_name
        """  # nosec B608

        cursor.execute(query, params)
        tables = [row[0] for row in cursor.fetchall()]
        cursor.close()

        return tables

    def _get_partition_info(self) -> Dict[str, Dict]:
        """Get partition information for all partitioned tables (Oracle 19c+)"""
        cursor = self.connection.cursor()

        query = """
            SELECT
                t.table_name,
                t.partitioning_type,
                t.subpartitioning_type,
                t.interval,
                t.partition_count,
                t.def_subpartition_count,
                CASE WHEN t.interval IS NOT NULL THEN 'Y' ELSE 'N' END AS is_interval
            FROM all_part_tables t
            WHERE t.owner = :schema
        """

        cursor.execute(query, schema=self.schema)

        partition_info = {}
        for row in cursor.fetchall():
            table_name = row[0]
            # Map database NONE to None/null for JSON schema compliance
            subpart_type = row[2]
            if subpart_type == "NONE":
                subpart_type = None

            partition_info[table_name] = {
                "partitioning_type": row[1],
                "subpartitioning_type": subpart_type,
                "interval_definition": row[3],
                "partition_count": row[4],
                "def_subpartition_count": row[5],
                "is_interval": row[6] == "Y",
            }

        cursor.close()
        return partition_info

    def _get_partition_keys(self, table_name: str) -> List[str]:
        """Get partition key columns for a table"""
        cursor = self.connection.cursor()

        query = """
            SELECT column_name
            FROM all_part_key_columns
            WHERE owner = :schema
              AND name = :table_name
              AND object_type = 'TABLE'
            ORDER BY column_position
        """

        cursor.execute(query, schema=self.schema, table_name=table_name)
        columns = [row[0] for row in cursor.fetchall()]
        cursor.close()

        return columns

    def _get_table_sizes(self) -> Dict[str, float]:
        """Get estimated size in GB for all tables using statistics (Oracle 19c+)"""
        cursor = self.connection.cursor()

        # Use ALL_TAB_STATISTICS which is accessible with basic SELECT privileges
        # Size estimation: num_rows * avg_row_len / (1024^3)
        query = """
            SELECT
                table_name,
                ROUND(NVL(num_rows, 0) * NVL(avg_row_len, 0) / POWER(1024, 3), 2) AS estimated_gb
            FROM all_tab_statistics
            WHERE owner = :schema
              AND NVL(num_rows, 0) > 0
        """

        cursor.execute(query, schema=self.schema)

        sizes = {}
        for row in cursor.fetchall():
            sizes[row[0]] = (
                row[1] if row[1] > 0 else 0.01
            )  # Minimum 0.01 GB for small tables

        cursor.close()
        return sizes

    def _get_table_stats(self) -> Dict[str, Dict]:
        """Get table statistics (row count, avg row length, etc.)"""
        cursor = self.connection.cursor()

        query = """
            SELECT
                table_name,
                NVL(num_rows, 0) AS num_rows,
                NVL(avg_row_len, 0) AS avg_row_len,
                NVL(blocks, 0) AS blocks,
                last_analyzed,
                tablespace_name
            FROM all_tables
            WHERE owner = :schema
        """

        cursor.execute(query, schema=self.schema)

        stats = {}
        for row in cursor.fetchall():
            table_name = row[0]
            stats[table_name] = {
                "num_rows": row[1],
                "avg_row_len": row[2],
                "blocks": row[3],
                "last_analyzed": row[4],
                "tablespace_name": row[5] or "USERS",
            }

        cursor.close()
        return stats

    def _get_lob_counts(self) -> Dict[str, int]:
        """Get count of LOB columns per table"""
        cursor = self.connection.cursor()

        query = """
            SELECT table_name, COUNT(*) AS lob_count
            FROM all_lobs
            WHERE owner = :schema
            GROUP BY table_name
        """

        cursor.execute(query, schema=self.schema)

        lob_counts = {}
        for row in cursor.fetchall():
            lob_counts[row[0]] = row[1]

        cursor.close()
        return lob_counts

    def _get_index_counts(self) -> Dict[str, int]:
        """Get count of indexes per table"""
        cursor = self.connection.cursor()

        query = """
            SELECT table_name, COUNT(*) AS index_count
            FROM all_indexes
            WHERE table_owner = :schema
            GROUP BY table_name
        """

        cursor.execute(query, schema=self.schema)

        index_counts = {}
        for row in cursor.fetchall():
            index_counts[row[0]] = row[1]

        cursor.close()
        return index_counts

    def _get_timestamp_columns(self, table_name: str) -> List[Dict]:
        """Get all timestamp/date columns for a table"""
        cursor = self.connection.cursor()

        query = """
            SELECT column_name, data_type, nullable
            FROM all_tab_columns
            WHERE owner = :schema
              AND table_name = :table_name
              AND data_type IN ('DATE', 'TIMESTAMP', 'TIMESTAMP(6)',
                               'TIMESTAMP(9)', 'TIMESTAMP WITH TIME ZONE',
                               'TIMESTAMP WITH LOCAL TIME ZONE')
            ORDER BY
                CASE column_name
                    WHEN 'CREATED_DATE' THEN 1
                    WHEN 'CREATE_DATE' THEN 2
                    WHEN 'AUDIT_CREATE_DATE' THEN 3
                    WHEN 'LAST_UPDATE_DATE' THEN 4
                    WHEN 'UPDATE_DATE' THEN 5
                    WHEN 'MODIFIED_DATE' THEN 6
                    WHEN 'PROCESS_DATE' THEN 7
                    ELSE 99
                END,
                column_id
        """

        cursor.execute(query, schema=self.schema, table_name=table_name)

        columns = []
        for row in cursor.fetchall():
            columns.append({"name": row[0], "type": row[1], "nullable": row[2]})

        cursor.close()
        return columns

    def _get_numeric_columns(self, table_name: str) -> List[Dict]:
        """Get numeric columns suitable for hash partitioning"""
        cursor = self.connection.cursor()

        query = """
            SELECT column_name, data_type, nullable
            FROM all_tab_columns
            WHERE owner = :schema
              AND table_name = :table_name
              AND data_type IN ('NUMBER', 'INTEGER', 'BINARY_INTEGER')
            ORDER BY
                CASE
                    WHEN column_name LIKE '%_ID' THEN 1
                    WHEN column_name LIKE '%ID' THEN 2
                    WHEN column_name LIKE '%_NUM' THEN 3
                    WHEN column_name LIKE '%_SEQ' THEN 4
                    ELSE 99
                END,
                column_id
        """

        cursor.execute(query, schema=self.schema, table_name=table_name)

        columns = []
        for row in cursor.fetchall():
            columns.append({"name": row[0], "type": row[1], "nullable": row[2]})

        cursor.close()
        return columns

    def _get_string_columns(self, table_name: str) -> List[Dict]:
        """Get string columns (alternative for hash partitioning)"""
        cursor = self.connection.cursor()

        query = """
            SELECT column_name, data_type || '(' || char_length || ')' AS data_type, nullable
            FROM all_tab_columns
            WHERE owner = :schema
              AND table_name = :table_name
              AND data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR')
              AND char_length <= 500
            ORDER BY
                CASE
                    WHEN column_name LIKE '%_CODE' THEN 1
                    WHEN column_name LIKE '%CODE' THEN 2
                    WHEN column_name LIKE '%_KEY' THEN 3
                    ELSE 99
                END,
                column_id
            FETCH FIRST 10 ROWS ONLY
        """

        cursor.execute(query, schema=self.schema, table_name=table_name)

        columns = []
        for row in cursor.fetchall():
            columns.append({"name": row[0], "type": row[1], "nullable": row[2]})

        cursor.close()
        return columns

    def _get_identity_columns(self, table_name: str) -> List[Dict]:
        """Get identity column information for a table"""
        cursor = self.connection.cursor()

        query = """
            SELECT 
                ic.column_name,
                ic.generation_type,
                ic.sequence_name,
                s.min_value,
                s.max_value,
                s.increment_by,
                s.cache_size,
                s.cycle_flag,
                s.order_flag,
                s.last_number as start_value
            FROM all_tab_identity_cols ic
            LEFT JOIN all_sequences s ON (s.sequence_name = ic.sequence_name 
                                        AND s.sequence_owner = :schema)
            WHERE ic.owner = :schema
              AND ic.table_name = :table_name
            ORDER BY ic.column_name
        """

        cursor.execute(query, schema=self.schema, table_name=table_name)

        identity_columns = []
        for row in cursor.fetchall():
            identity_columns.append({
                "column_name": row[0],
                "generation_type": row[1],  # 'ALWAYS', 'BY DEFAULT', 'BY DEFAULT ON NULL'
                "sequence_name": row[2],
                "min_value": row[3],
                "max_value": row[4],
                "increment_value": row[5] or 1,
                "cache_size": row[6],
                "cycle_flag": row[7] or 'N',
                "order_flag": row[8] or 'N',
                "start_value": row[9] or 1,
            })

        cursor.close()
        return identity_columns

    def _get_all_columns_metadata(self, table_name: str) -> List[Dict]:
        """Get complete column metadata for CREATE TABLE statement (Oracle 19c+)"""
        cursor = self.connection.cursor()
        
        # Get identity column information first
        identity_columns = self._get_identity_columns(table_name)
        identity_map = {col['column_name']: col for col in identity_columns}
        
        try:
            query = """
                SELECT
                    column_name,
                    data_type,
                    data_length,
                    data_precision,
                    data_scale,
                    nullable,
                    data_default,
                    char_length,
                    CASE WHEN virtual_column = 'YES' THEN 'YES' ELSE 'NO' END as is_virtual
                FROM all_tab_columns
                WHERE owner = :schema
                  AND table_name = :table_name
                ORDER BY column_id
            """
            cursor.execute(query, schema=self.schema, table_name=table_name)
        except Exception:
            query = """
                SELECT
                    column_name,
                    data_type,
                    data_length,
                    data_precision,
                    data_scale,
                    nullable,
                    data_default,
                    char_length,
                    'NO' as is_virtual
                FROM all_tab_columns
                WHERE owner = :schema
                  AND table_name = :table_name
                ORDER BY column_id
            """
            cursor.execute(query, schema=self.schema, table_name=table_name)

        columns = []
        for row in cursor.fetchall():
            col_name = row[0]
            data_type = row[1]
            data_length = row[2]
            data_precision = row[3]
            data_scale = row[4]
            nullable = row[5]
            data_default = row[6]
            char_length = row[7]
            is_virtual = row[8]

            if is_virtual == "YES":
                continue

            # Check if this is an identity column
            identity_info = identity_map.get(col_name)
            
            column_info = {
                "name": col_name,
                "type": data_type,
                "length": data_length,
                "precision": data_precision,
                "scale": data_scale,
                "nullable": nullable,
                "default": (
                    str(data_default).strip() if data_default is not None else None
                ),
                "char_length": char_length,
                "is_identity": identity_info is not None,
            }
            
            # Add identity column details if present
            if identity_info:
                column_info.update({
                    "identity_generation": identity_info['generation_type'],
                    "identity_sequence": identity_info['sequence_name'],
                    "identity_start_with": identity_info.get('start_value', 1),
                    "identity_increment_by": identity_info.get('increment_value', 1),
                    "identity_max_value": identity_info.get('max_value'),
                    "identity_min_value": identity_info.get('min_value'),
                    "identity_cache_size": identity_info.get('cache_size'),
                    "identity_cycle_flag": identity_info.get('cycle_flag', 'N'),
                    "identity_order_flag": identity_info.get('order_flag', 'N'),
                })

            columns.append(column_info)

        cursor.close()
        return columns

    def _get_lob_storage_details(self, table_name: str) -> List[Dict]:
        """Get LOB column storage details for proper DDL generation"""
        cursor = self.connection.cursor()

        query = """
            SELECT
                l.column_name,
                l.segment_name,
                l.tablespace_name,
                l.securefile,
                l.compression,
                l.deduplication,
                l.in_row,
                l.chunk,
                l.cache
            FROM all_lobs l
            WHERE l.owner = :schema
              AND l.table_name = :table_name
            ORDER BY l.column_name
        """

        cursor.execute(query, schema=self.schema, table_name=table_name)

        lob_details = []
        for row in cursor.fetchall():
            # Extract base tablespace name (remove _01, _02, etc. suffixes if present)
            tablespace_name = row[2]
            base_tablespace = tablespace_name
            if tablespace_name and "_" in tablespace_name:
                # Check if it ends with _\d\d pattern
                parts = tablespace_name.rsplit("_", 1)
                if len(parts) == 2 and parts[1].isdigit() and len(parts[1]) == 2:
                    base_tablespace = parts[0]

            lob_details.append(
                {
                    "column_name": row[0],
                    "segment_name": row[1],
                    "tablespace_name": base_tablespace,  # Use base tablespace name
                    "original_tablespace": row[2],  # Keep original for reference
                    "securefile": row[3],
                    "compression": row[4],
                    "deduplication": row[5],
                    "in_row": row[6],
                    "chunk": row[7],
                    "cache": row[8],
                }
            )

        cursor.close()
        return lob_details

    def _get_table_storage_params(self, table_name: str) -> Dict:
        """Get table storage parameters (COMPRESS, PCTFREE, etc.)"""
        cursor = self.connection.cursor()

        query = """
            SELECT
                compression,
                compress_for,
                pct_free,
                ini_trans,
                max_trans,
                initial_extent,
                next_extent,
                buffer_pool
            FROM all_tables
            WHERE owner = :schema
              AND table_name = :table_name
        """

        cursor.execute(query, schema=self.schema, table_name=table_name)
        row = cursor.fetchone()

        storage_params = {}
        if row:
            storage_params = {
                "compression": row[0],
                "compress_for": row[1],
                "pct_free": row[2],
                "ini_trans": row[3],
                "max_trans": row[4],
                "initial_extent": row[5],
                "next_extent": row[6],
                "buffer_pool": row[7],
            }

        cursor.close()
        return storage_params

    def _get_index_details(self, table_name: str) -> List[Dict]:
        """Get index definitions with columns and storage details from source table (Oracle 19c+)"""
        cursor = self.connection.cursor()

        # First, get column list for each index
        query_columns = """
            SELECT
                index_name,
                LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY column_position) AS index_columns
            FROM all_ind_columns
            WHERE index_owner = :schema
              AND table_name = :table_name
            GROUP BY index_name
        """

        cursor.execute(query_columns, schema=self.schema, table_name=table_name)
        index_columns_map = {row[0]: row[1] for row in cursor.fetchall()}

        # Get full index details with storage parameters
        # Note: LOCALITY is only in ALL_PART_INDEXES, not ALL_INDEXES
        # VISIBILITY may not exist in older Oracle versions (pre-11g)
        query = """
            SELECT
                i.index_name,
                i.index_type,
                i.uniqueness,
                i.tablespace_name,
                i.compression,
                i.pct_free,
                i.ini_trans,
                i.max_trans,
                i.degree,
                i.partitioned
            FROM all_indexes i
            WHERE i.table_owner = :schema
              AND i.table_name = :table_name
            ORDER BY i.index_name
        """

        cursor.execute(query, schema=self.schema, table_name=table_name)

        indexes = []
        for row in cursor.fetchall():
            idx_name = row[0]

            # Determine if REVERSE by checking index type
            is_reverse = "REVERSE" in str(row[1]) if row[1] else False

            index_info = {
                "index_name": idx_name,
                "index_type": row[1],
                "uniqueness": row[2],  # UNIQUE or NONUNIQUE
                "tablespace_name": row[3],
                "compression": row[4],  # ENABLED or DISABLED
                "pct_free": row[5],
                "ini_trans": row[6],
                "max_trans": row[7],
                "degree": row[8],  # Parallel degree
                "partitioned": row[9],  # YES or NO
                "columns": index_columns_map.get(idx_name, ""),
                "is_reverse": is_reverse,
            }

            # If index is partitioned, get LOCALITY from ALL_PART_INDEXES
            if row[9] == "YES":
                try:
                    locality_cursor = self.connection.cursor()
                    locality_query = """
                        SELECT locality
                        FROM all_part_indexes
                        WHERE owner = :schema
                          AND index_name = :index_name
                    """
                    locality_cursor.execute(
                        locality_query, schema=self.schema, index_name=idx_name
                    )
                    locality_row = locality_cursor.fetchone()
                    if locality_row:
                        index_info["locality"] = locality_row[0]
                    locality_cursor.close()
                except Exception as e:
                    # If ALL_PART_INDEXES is not accessible, skip locality
                    import logging

                    logging.warning(
                        f"Could not fetch locality for index {idx_name}: {e}"
                    )

            indexes.append(index_info)

        cursor.close()
        return indexes

    def _analyze_table(
        self,
        table_name: str,
        partition_info: Optional[Dict],
        size_gb: float,
        stats: Dict,
        lob_count: int,
        index_count: int,
    ) -> TableConfig:
        """
        Analyze a single table and generate migration configuration

        Returns:
            TableConfig dataclass with complete table configuration
        """
        # Determine current partition state
        is_partitioned = partition_info is not None

        if is_partitioned:
            current_partition_type = partition_info["partitioning_type"]
            is_interval = partition_info["is_interval"]
            has_subpartitions = partition_info["subpartitioning_type"] is not None
            partition_key_columns = self._get_partition_keys(table_name)
        else:
            current_partition_type = "NONE"
            is_interval = False
            has_subpartitions = False
            partition_key_columns = []

        # Get available columns
        timestamp_columns = self._get_timestamp_columns(table_name)
        numeric_columns = self._get_numeric_columns(table_name)
        string_columns = self._get_string_columns(table_name)

        # Determine migration action
        if not is_partitioned:
            migration_action = "add_interval_hash_partitioning"
        elif is_interval and not has_subpartitions:
            migration_action = "add_hash_subpartitions"
        elif is_interval and has_subpartitions:
            migration_action = "convert_interval_to_interval_hash"  # Re-configure
        else:
            migration_action = "convert_to_interval_hash"

        # Determine if table should be enabled (recommendations)
        # Enable by default if:
        # - Has timestamp column
        # - Has numeric/string column for hash
        # - Not already interval-hash
        should_enable = (
            len(timestamp_columns) > 0
            and (len(numeric_columns) > 0 or len(string_columns) > 0)
            and not (is_interval and has_subpartitions)
        )

        # Build current state
        current_state = {
            "is_partitioned": is_partitioned,
            "partition_type": current_partition_type,
            "size_gb": size_gb,
            "row_count": stats.get("num_rows", 0),
            "lob_count": lob_count,
            "index_count": index_count,
        }

        if is_partitioned:
            current_state.update(
                {
                    "is_interval": is_interval,
                    "interval_definition": partition_info.get("interval_definition"),
                    "current_partition_count": partition_info.get("partition_count"),
                    "current_partition_key": (
                        ", ".join(partition_key_columns)
                        if partition_key_columns
                        else None
                    ),
                    "has_subpartitions": has_subpartitions,
                    "subpartition_type": partition_info.get("subpartitioning_type"),
                    "subpartition_count": partition_info.get("def_subpartition_count"),
                }
            )

        # Determine recommended settings
        recommended_hash_count = self._recommend_hash_count(
            size_gb, stats.get("num_rows", 0)
        )
        recommended_interval = self._recommend_interval_type(
            size_gb, stats.get("num_rows", 0)
        )
        recommended_parallel = self.env_manager.get_parallel_degree(
            self.environment, size_gb
        )

        # Build target configuration
        target_partition_column = None
        if partition_key_columns:
            target_partition_column = partition_key_columns[0]  # Use existing
        elif timestamp_columns:
            target_partition_column = timestamp_columns[0]["name"]

        target_hash_column = None
        if numeric_columns:
            target_hash_column = numeric_columns[0]["name"]
        elif string_columns:
            target_hash_column = string_columns[0]["name"]

        # Get environment-specific tablespaces
        env_tablespaces = self.env_manager.get_tablespaces(self.environment)

        # Calculate subpartition count based on LOB tablespace count (2 per LOB tablespace)
        lob_tablespace_count = (
            len(env_tablespaces["lob"]) if env_tablespaces["lob"] else 0
        )
        if lob_tablespace_count > 0:
            # 2 subpartitions per LOB tablespace
            calculated_subpartition_count = lob_tablespace_count * 2
        else:
            # Fallback to environment recommendation
            calculated_subpartition_count = recommended_hash_count

        target_configuration = {
            "partition_type": "INTERVAL",
            "partition_column": target_partition_column,
            "interval_type": recommended_interval,
            "interval_value": 1,
            "initial_partition_value": "TO_DATE('2024-01-01', 'YYYY-MM-DD')",
            "subpartition_type": "HASH" if target_hash_column else "NONE",
            "subpartition_column": target_hash_column,
            "subpartition_count": calculated_subpartition_count,
            "tablespace": env_tablespaces["data"],
            "lob_tablespaces": env_tablespaces["lob"],
            "parallel_degree": recommended_parallel,
        }

        # Get complete typed column metadata and storage details
        try:
            columns_metadata = self._build_columns_metadata(table_name)
        except Exception as e:
            raise Exception(f"Error in _build_columns_metadata for {table_name}: {e}") from e
        
        try:
            lob_storage_details = self._build_lob_storage_details(table_name)
        except Exception as e:
            raise Exception(f"Error in _build_lob_storage_details for {table_name}: {e}") from e
        
        try:
            storage_params = self._build_storage_parameters(table_name)
        except Exception as e:
            raise Exception(f"Error in _build_storage_parameters for {table_name}: {e}") from e
        
        try:
            index_details = self._build_index_details(table_name)
        except Exception as e:
            raise Exception(f"Error in _build_index_details for {table_name}: {e}") from e
        
        try:
            grants_details = self._build_grants_details(table_name)
        except Exception as e:
            raise Exception(f"Error in _build_grants_details for {table_name}: {e}") from e

        # Build typed available columns
        available_columns = AvailableColumns(
            timestamp_columns=[
                ColumnInfo(name=col["name"], type=col["type"], nullable=col["nullable"])
                for col in timestamp_columns
            ],
            numeric_columns=[
                ColumnInfo(name=col["name"], type=col["type"], nullable=col["nullable"])
                for col in numeric_columns
            ],
            string_columns=[
                ColumnInfo(name=col["name"], type=col["type"], nullable=col["nullable"])
                for col in string_columns
            ]
        )

        # Build typed current state
        current_state_obj = CurrentState(
            is_partitioned=current_state["is_partitioned"],
            partition_type=current_state["partition_type"],
            size_gb=current_state["size_gb"],
            row_count=current_state["row_count"],
            lob_count=current_state["lob_count"],
            index_count=current_state["index_count"],
            columns=columns_metadata,
            lob_storage=lob_storage_details,
            storage_parameters=storage_params,
            indexes=index_details,
            available_columns=available_columns,
            grants=grants_details,
        )

        # Add optional fields if partitioned
        if is_partitioned:
            current_state_obj.is_interval = is_interval
            current_state_obj.interval_definition = partition_info.get("interval_definition")
            current_state_obj.current_partition_count = partition_info.get("partition_count")
            current_state_obj.current_partition_key = (
                ", ".join(partition_key_columns) if partition_key_columns else None
            )
            current_state_obj.has_subpartitions = has_subpartitions
            current_state_obj.subpartition_type = partition_info.get("subpartitioning_type")
            current_state_obj.subpartition_count = partition_info.get("def_subpartition_count")

        # Build typed target configuration
        target_config_obj = TargetConfiguration(
            partition_type=PartitionType(target_configuration["partition_type"]),
            partition_column=target_configuration["partition_column"],
            interval_type=IntervalType(target_configuration["interval_type"]),
            interval_value=target_configuration["interval_value"],
            initial_partition_value=target_configuration["initial_partition_value"],
            subpartition_type=SubpartitionType(target_configuration["subpartition_type"]),
            subpartition_column=target_configuration["subpartition_column"],
            subpartition_count=target_configuration["subpartition_count"],
            tablespace=target_configuration["tablespace"],
            lob_tablespaces=target_configuration["lob_tablespaces"],
            parallel_degree=target_configuration["parallel_degree"],
        )

        # Build typed migration settings
        migration_settings_obj = MigrationSettings(
            validate_data=True,
            backup_old_table=True,
            drop_old_after_days=7,
        )

        # Build typed common settings
        common_settings_obj = CommonSettings(
            new_table_name=f"{table_name}_NEW",
            old_table_name=f"{table_name}_OLD",
            migration_action=MigrationAction(migration_action),
            target_configuration=target_config_obj,
            migration_settings=migration_settings_obj,
        )

        # Build final typed table configuration
        table_config = TableConfig(
            enabled=should_enable,
            owner=self.schema,
            table_name=table_name,
            current_state=current_state_obj,
            common_settings=common_settings_obj,
        )

        return table_config

    def _recommend_hash_count(self, size_gb: float, row_count: int) -> int:
        """Recommend number of hash subpartitions based on size and environment"""
        return self.env_manager.calculate_subpartition_count(size_gb, self.environment)

    def _recommend_interval_type(self, size_gb: float, row_count: int) -> str:
        """Recommend interval type (HOUR, DAY, MONTH) based on data volume"""
        # Estimate rows per day (assume 1 year of data)
        if row_count > 0:
            rows_per_day = row_count / 365

            if rows_per_day > 1000000:  # > 1M rows/day
                return "HOUR"
            elif rows_per_day > 100000:  # > 100K rows/day
                return "DAY"
            else:
                return "MONTH"
        else:
            # Fall back to size-based
            if size_gb > 100:
                return "DAY"
            else:
                return "MONTH"

    def _recommend_parallel_degree(self, size_gb: float) -> int:
        """Recommend parallel degree for migration"""
        if size_gb > 100:
            return 8
        elif size_gb > 50:
            return 6
        elif size_gb > 10:
            return 4
        else:
            return 2

    def _extract_database_service(self) -> str:
        """Extract database service name from connection string"""
        if not self.connection_string:
            return "Unknown"

        try:
            # Parse connection string to extract service name
            # Format: user/pass@host:port/service or user/pass@host:port:sid
            if '@' in self.connection_string:
                conn_part = self.connection_string.split('@')[1]
                if '/' in conn_part:
                    # Service name format: host:port/service
                    service = conn_part.split('/')[-1]
                    return service
                elif ':' in conn_part and conn_part.count(':') == 2:
                    # SID format: host:port:sid
                    service = conn_part.split(':')[-1]
                    return service
                else:
                    return conn_part
            return "Unknown"
        except Exception:
            return "Unknown"

    def _extract_connection_details(self) -> Dict[str, str]:
        """Extract connection details for metadata tracking"""
        if not self.connection_string:
            return {"type": "Unknown", "host": "Unknown", "port": "Unknown", "service": "Unknown"}

        try:
            # Parse connection string: user/pass@host:port/service
            if '@' in self.connection_string:
                user_part, conn_part = self.connection_string.split('@', 1)
                user = user_part.split('/')[0] if '/' in user_part else user_part

                if '/' in conn_part:
                    # Service name format
                    host_port, service = conn_part.rsplit('/', 1)
                    if ':' in host_port:
                        host, port = host_port.rsplit(':', 1)
                    else:
                        host, port = host_port, "1521"

                    return {
                        "type": "Service Name",
                        "host": host,
                        "port": port,
                        "service": service,
                        "user": user
                    }
                elif ':' in conn_part and conn_part.count(':') == 2:
                    # SID format: host:port:sid
                    parts = conn_part.split(':')
                    return {
                        "type": "SID",
                        "host": parts[0],
                        "port": parts[1],
                        "service": parts[2],
                        "user": user
                    }

            return {"type": "Unknown", "connection_string": self.connection_string}
        except Exception as e:
            return {"type": "Error", "error": str(e)}

    def _format_criteria(
        self,
        include_patterns: Optional[List[str]],
        exclude_patterns: Optional[List[str]],
    ) -> str:
        """Format discovery criteria for metadata"""
        parts = [f"Schema: {self.schema}"]

        if include_patterns:
            parts.append(f"Include: {', '.join(include_patterns)}")

        if exclude_patterns:
            parts.append(f"Exclude: {', '.join(exclude_patterns)}")

        return ", ".join(parts)

    def _build_columns_metadata(self, table_name: str) -> List[ColumnInfo]:
        """Build typed column metadata"""
        raw_columns = self._get_all_columns_metadata(table_name)
        return [
            ColumnInfo(
                name=col["name"],
                type=col["type"],
                length=col.get("length"),
                precision=col.get("precision"),
                scale=col.get("scale"),
                nullable=col["nullable"],
                default=col.get("default"),
                char_length=col.get("char_length"),
                is_identity=col.get("is_identity", False),
                identity_generation=col.get("identity_generation"),
                identity_sequence=col.get("identity_sequence"),
                identity_start_with=col.get("identity_start_with"),
                identity_increment_by=col.get("identity_increment_by"),
                identity_max_value=col.get("identity_max_value"),
                identity_min_value=col.get("identity_min_value"),
                identity_cache_size=col.get("identity_cache_size"),
                identity_cycle_flag=col.get("identity_cycle_flag"),
                identity_order_flag=col.get("identity_order_flag"),
            )
            for col in raw_columns
        ]

    def _build_lob_storage_details(self, table_name: str) -> List[LobStorageInfo]:
        """Build typed LOB storage details"""
        raw_lobs = self._get_lob_storage_details(table_name)
        return [
            LobStorageInfo(
                column_name=lob["column_name"],
                segment_name=lob["segment_name"],
                tablespace_name=lob["tablespace_name"],
                original_tablespace=lob["original_tablespace"],
                securefile=lob["securefile"],
                compression=lob["compression"],
                deduplication=lob["deduplication"],
                in_row=lob["in_row"],
                chunk=lob["chunk"],
                cache=lob["cache"],
            )
            for lob in raw_lobs
        ]

    def _build_storage_parameters(self, table_name: str) -> StorageParameters:
        """Build typed storage parameters"""
        raw_params = self._get_table_storage_params(table_name)
        return StorageParameters(
            compression=raw_params.get("compression", "DISABLED"),
            compress_for=raw_params.get("compress_for", ""),
            pct_free=raw_params.get("pct_free", 10),
            ini_trans=raw_params.get("ini_trans", 1),
            max_trans=raw_params.get("max_trans", 255),
            initial_extent=raw_params.get("initial_extent"),
            next_extent=raw_params.get("next_extent"),
            buffer_pool=raw_params.get("buffer_pool", "DEFAULT"),
        )

    def _build_index_details(self, table_name: str) -> List[IndexInfo]:
        """Build typed index details"""
        raw_indexes = self._get_index_details(table_name)
        return [
            IndexInfo(
                index_name=idx["index_name"],
                index_type=idx["index_type"],
                uniqueness=idx["uniqueness"],
                tablespace_name=idx["tablespace_name"],
                compression=idx["compression"],
                pct_free=idx["pct_free"],
                ini_trans=idx["ini_trans"],
                max_trans=idx["max_trans"],
                degree=idx["degree"],
                partitioned=idx["partitioned"],
                columns=idx["columns"],
                is_reverse=idx.get("is_reverse", False),
                locality=idx.get("locality"),
            )
            for idx in raw_indexes
        ]

    def _build_grants_details(self, table_name: str) -> List[GrantInfo]:
        """Build typed grants details"""  
        raw_grants = self._get_table_grants(table_name)
        return [
            GrantInfo(
                grantee=grant["grantee"],
                privilege=grant["privilege"],
                grantable=grant["grantable"],
                grantor=grant["grantor"],
                grant_type=grant["grant_type"],
            )
            for grant in raw_grants
        ]

    def _build_connection_details(self) -> ConnectionDetails:
        """Build typed connection details"""
        if not self.connection_string:
            return ConnectionDetails(
                type="Unknown", host="Unknown", port="Unknown", 
                service="Unknown", user="Unknown"
            )

        try:
            if '@' in self.connection_string:
                user_part, conn_part = self.connection_string.split('@', 1)
                user = user_part.split('/')[0] if '/' in user_part else user_part

                if '/' in conn_part:
                    host_port, service = conn_part.rsplit('/', 1)
                    if ':' in host_port:
                        host, port = host_port.rsplit(':', 1)
                    else:
                        host, port = host_port, "1521"

                    return ConnectionDetails(
                        type="Service Name", host=host, port=port, 
                        service=service, user=user
                    )

            return ConnectionDetails(
                type="Unknown", host="Unknown", port="Unknown",
                service="Unknown", user="Unknown"
            )
        except Exception:
            return ConnectionDetails(
                type="Error", host="Unknown", port="Unknown",
                service="Unknown", user="Unknown"
            )

    def _build_environment_config(self) -> EnvironmentConfig:
        """Build typed environment configuration"""
        try:
            env_config = self.env_manager.load_environment_config(self.environment)
            return EnvironmentConfig(
                name=env_config.environment,
                tablespaces=DataTablespaces(
                    data=TablespaceConfig(
                        primary=env_config.tablespaces.primary,
                        lob=env_config.tablespaces.lob,
                    )
                ),
                subpartition_defaults=SubpartitionDefaults(
                    min_count=env_config.subpartition_defaults.min_count,
                    max_count=env_config.subpartition_defaults.max_count,
                    size_based_recommendations={
                        k: SizeRecommendation(max_gb=v["max_gb"], count=v["count"])
                        for k, v in env_config.subpartition_defaults.size_based_recommendations.items()
                    },
                ),
                parallel_defaults=ParallelDefaults(
                    min_degree=env_config.parallel_defaults.min_degree,
                    max_degree=env_config.parallel_defaults.max_degree,
                    default_degree=env_config.parallel_defaults.default_degree,
                ),
            )
        except Exception as e:
            print(f"Warning: Could not load environment config: {e}")
            # Use default environment config
            return EnvironmentConfig(
                name=self.environment,
                tablespaces=DataTablespaces(
                    data=TablespaceConfig(
                        primary="USERS",
                        lob=["GD_LOB_01", "GD_LOB_02", "GD_LOB_03", "GD_LOB_04"],
                    )
                ),
                subpartition_defaults=SubpartitionDefaults(
                    min_count=2,
                    max_count=16,
                    size_based_recommendations={
                        "small": SizeRecommendation(max_gb=1, count=2),
                        "medium": SizeRecommendation(max_gb=10, count=4),
                        "large": SizeRecommendation(max_gb=50, count=8),
                        "xlarge": SizeRecommendation(max_gb=100, count=12),
                        "xxlarge": SizeRecommendation(max_gb=999999, count=16),
                    },
                ),
                parallel_defaults=ParallelDefaults(
                    min_degree=1,
                    max_degree=8,
                    default_degree=4,
                ),
            )

    def _get_constraint_info(self) -> Dict[str, List[Dict]]:
        """Get all constraint information for tables in schema"""
        query = """
        SELECT 
            c.table_name,
            c.constraint_name,
            c.constraint_type,
            c.status,
            c.validated,
            c.deferrable,
            c.deferred,
            c.rely,
            c.search_condition_vc,
            c.delete_rule,
            CASE 
                WHEN c.constraint_type = 'R' THEN c.r_owner || '.' || 
                     (SELECT table_name FROM all_constraints WHERE constraint_name = c.r_constraint_name AND rownum = 1)
                ELSE NULL
            END as referenced_table,
            c.r_constraint_name as referenced_constraint,
            RTRIM(XMLAGG(XMLELEMENT(e, cc.column_name || ', ') ORDER BY cc.position).EXTRACT('//text()').getClobVal(), ', ') as columns,
            CASE 
                WHEN c.constraint_type = 'P' THEN 'Primary Key'
                WHEN c.constraint_type = 'R' THEN 'Foreign Key'
                WHEN c.constraint_type = 'U' THEN 'Unique'
                WHEN c.constraint_type = 'C' THEN 'Check'
                WHEN c.constraint_type = 'V' THEN 'View Check'
                WHEN c.constraint_type = 'O' THEN 'View Readonly'
                ELSE 'Other'
            END as constraint_description
        FROM all_constraints c
        LEFT JOIN all_cons_columns cc ON c.constraint_name = cc.constraint_name 
            AND c.owner = cc.owner
            AND c.table_name = cc.table_name
        WHERE c.owner = :schema_name
        AND c.table_name IN (SELECT table_name FROM all_tables WHERE owner = :schema_name)
        GROUP BY c.table_name, c.constraint_name, c.constraint_type, c.status, 
                 c.validated, c.deferrable, c.deferred, c.rely, c.search_condition_vc,
                 c.delete_rule, c.r_owner, c.r_constraint_name
        ORDER BY c.table_name, c.constraint_type, c.constraint_name
        """
        
        cursor = self.connection.cursor()
        cursor.execute(query, schema_name=self.schema)
        
        constraint_info = {}
        for row in cursor.fetchall():
            table_name = row[0]
            if table_name not in constraint_info:
                constraint_info[table_name] = []
            
            constraint_info[table_name].append({
                'constraint_name': row[1],
                'constraint_type': row[2],
                'constraint_description': row[13],  # constraint_description is the last column
                'status': row[3],
                'validated': row[4],
                'deferrable': row[5],
                'deferred': row[6],
                'rely': row[7],
                'search_condition': row[8],
                'delete_rule': row[9],
                'referenced_table': row[10],
                'referenced_constraint': row[11],
                'columns': row[12],  # columns from LISTAGG
            })
        
        cursor.close()
        return constraint_info

    def _get_referential_integrity(self) -> Dict[str, Dict]:
        """Get referential integrity relationships between tables"""
        query = """
        WITH fk_relationships AS (
            SELECT 
                p.table_name as parent_table,
                c.table_name as child_table,
                c.constraint_name,
                c.delete_rule,
                LISTAGG(pcc.column_name, ', ') WITHIN GROUP (ORDER BY pcc.position) as parent_columns,
                LISTAGG(ccc.column_name, ', ') WITHIN GROUP (ORDER BY ccc.position) as child_columns,
                COUNT(*) OVER (PARTITION BY c.table_name) as fk_count_in_child,
                COUNT(*) OVER (PARTITION BY p.table_name) as fk_count_from_parent
            FROM all_constraints c
            JOIN all_constraints p ON c.r_constraint_name = p.constraint_name
                AND c.owner = p.owner
            JOIN all_cons_columns ccc ON c.constraint_name = ccc.constraint_name
                AND c.owner = ccc.owner
                AND c.table_name = ccc.table_name
            JOIN all_cons_columns pcc ON p.constraint_name = pcc.constraint_name 
                AND p.owner = pcc.owner
                AND p.table_name = pcc.table_name
                AND ccc.position = pcc.position
            WHERE c.constraint_type = 'R'
            AND c.owner = :schema_name
            AND p.owner = :schema_name
            GROUP BY p.table_name, c.table_name, c.constraint_name, c.delete_rule
        )
        SELECT 
            parent_table,
            child_table, 
            constraint_name,
            delete_rule,
            parent_columns,
            child_columns,
            fk_count_in_child,
            fk_count_from_parent,
            CASE 
                WHEN fk_count_from_parent > 5 THEN 'High Dependency'
                WHEN fk_count_from_parent > 2 THEN 'Medium Dependency' 
                ELSE 'Low Dependency'
            END as dependency_level
        FROM fk_relationships
        ORDER BY parent_table, child_table
        """
        
        cursor = self.connection.cursor()
        cursor.execute(query, schema_name=self.schema)
        
        relationships = {
            'parent_child_relationships': [],
            'dependency_summary': {},
            'constraint_details': {}
        }
        
        for row in cursor.fetchall():
            parent_table, child_table = row[0], row[1]
            constraint_name = row[2]
            
            # Add to relationships
            relationships['parent_child_relationships'].append({
                'parent_table': parent_table,
                'child_table': child_table,
                'constraint_name': constraint_name,
                'delete_rule': row[3],
                'parent_columns': row[4],
                'child_columns': row[5],
                'dependency_level': row[8]
            })
            
            # Track dependency summary
            if parent_table not in relationships['dependency_summary']:
                relationships['dependency_summary'][parent_table] = {
                    'children_count': 0,
                    'children': [],
                    'dependency_level': 'Low Dependency'
                }
            
            relationships['dependency_summary'][parent_table]['children'].append(child_table)
            relationships['dependency_summary'][parent_table]['children_count'] = row[7]
            relationships['dependency_summary'][parent_table]['dependency_level'] = row[8]
            
            # Store constraint details
            relationships['constraint_details'][constraint_name] = {
                'parent_table': parent_table,
                'child_table': child_table,
                'parent_columns': row[4],
                'child_columns': row[5],
                'delete_rule': row[3]
            }
        
        cursor.close()
        return relationships

    def _get_composite_index_info(self) -> Dict[str, List[Dict]]:
        """Get detailed information about composite and function-based indexes"""
        query = """
        SELECT 
            i.table_name,
            i.index_name,
            i.index_type,
            i.uniqueness,
            i.tablespace_name,
            i.compression,
            i.pct_free,
            i.ini_trans,
            i.max_trans,
            i.degree,
            i.partitioned,
            LISTAGG(
                CASE 
                    WHEN ic.descend = 'DESC' THEN ic.column_name || ' DESC'
                    ELSE ic.column_name 
                END, 
                ', '
            ) WITHIN GROUP (ORDER BY ic.column_position) as columns,
            COUNT(ic.column_name) as column_count,
            ie.column_expression,
            CASE 
                WHEN COUNT(ic.column_name) > 1 THEN 'Composite'
                WHEN ie.column_expression IS NOT NULL THEN 'Function-Based'
                ELSE 'Simple'
            END as index_complexity
        FROM all_indexes i
        LEFT JOIN all_ind_columns ic ON i.index_name = ic.index_name
        LEFT JOIN all_ind_expressions ie ON i.index_name = ie.index_name 
            AND ic.column_position = ie.column_position
        WHERE i.table_owner = :schema_name
        AND i.table_name IN (SELECT table_name FROM all_tables WHERE owner = :schema_name)
        GROUP BY i.table_name, i.index_name, i.index_type, i.uniqueness, 
                 i.tablespace_name, i.compression, i.pct_free, i.ini_trans, 
                 i.max_trans, i.degree, i.partitioned, ie.column_expression
        ORDER BY i.table_name, index_complexity DESC, i.index_name
        """
        
        cursor = self.connection.cursor()
        cursor.execute(query, schema_name=self.schema)
        
        index_info = {}
        for row in cursor.fetchall():
            table_name = row[0]
            if table_name not in index_info:
                index_info[table_name] = []
            
            index_info[table_name].append({
                'index_name': row[1],
                'index_type': row[2],
                'uniqueness': row[3],
                'tablespace_name': row[4],
                'compression': row[5],
                'pct_free': row[6],
                'ini_trans': row[7],
                'max_trans': row[8],
                'degree': row[9],
                'partitioned': row[10],
                'columns': row[11],
                'column_count': row[12],
                'column_expression': row[13],
                'index_complexity': row[14]
            })
        
        cursor.close()
        return index_info

    def _get_table_grants(self, table_name: str) -> List[Dict]:
        """Get all grants/privileges for a specific table"""
        cursor = self.connection.cursor()
        
        query = """
        SELECT 
            grantee,
            privilege,
            grantable,
            grantor
        FROM all_tab_privs
        WHERE table_schema = :schema
        AND table_name = :table_name
        AND grantee NOT IN ('SYS', 'SYSTEM', 'PUBLIC')  -- Exclude system grantees
        ORDER BY grantee, privilege
        """
        
        cursor.execute(query, schema=self.schema, table_name=table_name)
        
        grants = []
        for row in cursor.fetchall():
            grants.append({
                'grantee': row[0],
                'privilege': row[1],
                'grantable': row[2],
                'grantor': row[3],
                'grant_type': 'OBJECT'
            })
        
        cursor.close()
        return grants

    def _get_all_table_grants(self) -> Dict[str, List[Dict]]:
        """Get grants information for all tables in schema"""
        cursor = self.connection.cursor()
        
        query = """
        SELECT 
            table_name,
            grantee,
            privilege,
            grantable,
            grantor
        FROM all_tab_privs
        WHERE table_schema = :schema
        AND grantee NOT IN ('SYS', 'SYSTEM', 'PUBLIC')  -- Exclude system grantees
        ORDER BY table_name, grantee, privilege
        """
        
        cursor.execute(query, schema=self.schema)
        
        grants_info = {}
        for row in cursor.fetchall():
            table_name = row[0]
            if table_name not in grants_info:
                grants_info[table_name] = []
            
            grants_info[table_name].append({
                'grantee': row[1],
                'privilege': row[2],
                'grantable': row[3],
                'grantor': row[4],
                'grant_type': 'OBJECT'
            })
        
        cursor.close()
        return grants_info

    def save_config(self, config: MigrationConfig, output_file: str = "migration_config.json"):
        """Save configuration to JSON file using automatic serialization"""
        config.save_to_file(output_file)
        print(f"✓ Configuration saved to: {output_file}")
        print("  Edit this file to customize migration settings")
        print(f"  Then run: python3 generate_scripts.py --config {output_file}")
