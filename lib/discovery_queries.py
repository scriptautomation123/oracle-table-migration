#!/usr/bin/env python3
"""
Discovery Queries Module
========================
SQL queries and logic to discover all tables in a schema and generate
JSON configuration for migration.

This module:
- Identifies ALL tables (partitioned and non-partitioned)
- Detects current partition type and configuration
- Finds timestamp columns suitable for interval partitioning
- Finds numeric/string columns suitable for hash subpartitioning
- Analyzes table size, row count, LOBs, indexes
- Generates intelligent migration recommendations
"""

import json
from datetime import datetime
from typing import Dict, List, Optional


class TableDiscovery:
    """Discover tables and generate migration configuration"""

    def __init__(self, connection):
        """
        Initialize discovery with database connection

        Args:
            connection: Oracle database connection (oracledb or cx_Oracle)
        """
        self.connection = connection
        self.schema = None
        self.tables = []
        self.metadata = {}

    def discover_schema(self, schema_name: str,
                       include_patterns: Optional[List[str]] = None,
                       exclude_patterns: Optional[List[str]] = None) -> Dict:
        """
        Discover all tables in schema and generate JSON configuration

        Args:
            schema_name: Oracle schema name to analyze
            include_patterns: List of table name patterns to include (e.g., ['IE_%'])
            exclude_patterns: List of table name patterns to exclude (e.g., ['TEMP_%'])

        Returns:
            Dictionary with migration configuration (ready to save as JSON)
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
                index_counts.get(table_name, 0)
            )
            tables_config.append(table_config)
            print(f"  • {table_name}: {table_config['migration_action']}")

        # Step 6: Generate metadata
        self.metadata = {
            "generated_date": datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            "schema": self.schema,
            "discovery_criteria": self._format_criteria(include_patterns, exclude_patterns),
            "total_tables_found": len(all_tables),
            "tables_selected_for_migration": len([t for t in tables_config if t['enabled']])
        }

        config = {
            "metadata": self.metadata,
            "tables": tables_config
        }

        print(f"\n{'='*70}")
        print("Discovery complete!")
        print(f"  Total tables: {len(all_tables)}")
        print(f"  Enabled for migration: {self.metadata['tables_selected_for_migration']}")
        print(f"{'='*70}\n")

        return config

    def _get_all_tables(self, include_patterns: Optional[List[str]] = None,
                       exclude_patterns: Optional[List[str]] = None) -> List[str]:
        """Get list of all table names in schema"""
        cursor = self.connection.cursor()

        # Build WHERE clause with patterns
        where_clauses = ["owner = :schema"]
        params = {'schema': self.schema}

        if include_patterns:
            include_clause = " OR ".join([f"table_name LIKE :inc_{i}" for i in range(len(include_patterns))])
            where_clauses.append(f"({include_clause})")
            for i, pattern in enumerate(include_patterns):
                params[f'inc_{i}'] = pattern.upper()

        if exclude_patterns:
            for i, pattern in enumerate(exclude_patterns):
                where_clauses.append(f"table_name NOT LIKE :exc_{i}")
                params[f'exc_{i}'] = pattern.upper()

        # Build query with dynamic WHERE clause from trusted list
        # SQL injection is prevented by:
        # 1. where_clauses contains only internally generated strings (not user input)
        # 2. All user values are passed via bind variables (params)
        where_clause = ' AND '.join(where_clauses)
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
                'partitioning_type': row[1],
                'subpartitioning_type': subpart_type,
                'interval_definition': row[3],
                'partition_count': row[4],
                'def_subpartition_count': row[5],
                'is_interval': row[6] == 'Y'
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
            sizes[row[0]] = row[1] if row[1] > 0 else 0.01  # Minimum 0.01 GB for small tables

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
                'num_rows': row[1],
                'avg_row_len': row[2],
                'blocks': row[3],
                'last_analyzed': row[4],
                'tablespace_name': row[5] or 'USERS'
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
            columns.append({
                'name': row[0],
                'type': row[1],
                'nullable': row[2]
            })

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
            columns.append({
                'name': row[0],
                'type': row[1],
                'nullable': row[2]
            })

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
              AND char_length <= 100
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
            columns.append({
                'name': row[0],
                'type': row[1],
                'nullable': row[2]
            })

        cursor.close()
        return columns

    def _get_all_columns_ddl(self, table_name: str) -> str:
        """Get complete column definitions as DDL for CREATE TABLE statement (Oracle 19c+)"""
        cursor = self.connection.cursor()

        # Try to check if VIRTUAL_COLUMN exists in all_tab_columns
        # Different Oracle versions may or may not have this column
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
            # If VIRTUAL_COLUMN doesn't exist, query without it
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

        column_defs = []
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

            # Skip virtual columns as they are computed
            if is_virtual == 'YES':
                continue

            # Build column definition
            col_def = f"    {col_name} "

            # Format data type with proper precision/scale
            if data_type in ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR'):
                col_def += f"{data_type}({char_length})"
            elif data_type == 'NUMBER':
                if data_precision is not None:
                    if data_scale is not None and data_scale > 0:
                        col_def += f"NUMBER({data_precision},{data_scale})"
                    else:
                        col_def += f"NUMBER({data_precision})"
                else:
                    col_def += "NUMBER"
            elif data_type in ('TIMESTAMP', 'TIMESTAMP WITH TIME ZONE', 'TIMESTAMP WITH LOCAL TIME ZONE'):
                col_def += data_type
            elif data_type == 'DATE':
                col_def += "DATE"
            elif data_type in ('CLOB', 'BLOB', 'NCLOB'):
                col_def += data_type
            elif data_type == 'RAW':
                col_def += f"RAW({data_length})"
            elif data_type == 'JSON':
                col_def += "JSON"  # Oracle 21c+
            else:
                col_def += data_type

            # Add default value if exists
            if data_default is not None:
                default_val = str(data_default).strip()
                col_def += f" DEFAULT {default_val}"

            # Add NULL/NOT NULL constraint
            if nullable == 'N':
                col_def += " NOT NULL"

            column_defs.append(col_def)

        cursor.close()
        return ",\n".join(column_defs) if column_defs else "    -- NO COLUMNS FOUND"

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
            lob_details.append({
                "column_name": row[0],
                "segment_name": row[1],
                "tablespace_name": row[2],
                "securefile": row[3],
                "compression": row[4],
                "deduplication": row[5],
                "in_row": row[6],
                "chunk": row[7],
                "cache": row[8]
            })

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
                "buffer_pool": row[7]
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
        # Oracle 19c supports LOCALITY column for partitioned indexes
        query = """
            SELECT
                i.index_name,
                i.index_type,
                i.uniqueness,
                i.tablespace_name,
                i.compression,
                i.prefix_length,
                i.locality,
                i.pct_free,
                i.ini_trans,
                i.max_trans,
                i.degree,
                i.partitioned,
                i.visibility
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
            is_reverse = 'REVERSE' in str(row[1]) if row[1] else False

            indexes.append({
                "index_name": idx_name,
                "index_type": row[1],
                "uniqueness": row[2],  # UNIQUE or NONUNIQUE
                "tablespace_name": row[3],
                "compression": row[4],  # ENABLED or DISABLED
                "prefix_length": row[5],  # Compression prefix length
                "locality": row[6],  # LOCAL or GLOBAL for partitioned tables
                "pct_free": row[7],
                "ini_trans": row[8],
                "max_trans": row[9],
                "degree": row[10],  # Parallel degree
                "partitioned": row[11],  # YES or NO
                "visibility": row[12],  # VISIBLE or INVISIBLE (Oracle 11g+)
                "columns": index_columns_map.get(idx_name, ""),
                "is_reverse": is_reverse
            })

        cursor.close()
        return indexes

    def _analyze_table(self, table_name: str, partition_info: Optional[Dict],
                      size_gb: float, stats: Dict, lob_count: int,
                      index_count: int) -> Dict:
        """
        Analyze a single table and generate migration configuration

        Returns:
            Dictionary with table configuration for JSON output
        """
        # Determine current partition state
        is_partitioned = partition_info is not None

        if is_partitioned:
            current_partition_type = partition_info['partitioning_type']
            is_interval = partition_info['is_interval']
            has_subpartitions = partition_info['subpartitioning_type'] is not None
            partition_key_columns = self._get_partition_keys(table_name)
        else:
            current_partition_type = 'NONE'
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
            len(timestamp_columns) > 0 and
            (len(numeric_columns) > 0 or len(string_columns) > 0) and
            not (is_interval and has_subpartitions)
        )

        # Build current state
        current_state = {
            "is_partitioned": is_partitioned,
            "partition_type": current_partition_type,
            "size_gb": size_gb,
            "row_count": stats.get('num_rows', 0),
            "lob_count": lob_count,
            "index_count": index_count
        }

        if is_partitioned:
            current_state.update({
                "is_interval": is_interval,
                "interval_definition": partition_info.get('interval_definition'),
                "current_partition_count": partition_info.get('partition_count'),
                "current_partition_key": ', '.join(partition_key_columns) if partition_key_columns else None,
                "has_subpartitions": has_subpartitions,
                "subpartition_type": partition_info.get('subpartitioning_type'),
                "subpartition_count": partition_info.get('def_subpartition_count')
            })

        # Determine recommended settings
        recommended_hash_count = self._recommend_hash_count(size_gb, stats.get('num_rows', 0))
        recommended_interval = self._recommend_interval_type(size_gb, stats.get('num_rows', 0))
        recommended_parallel = self._recommend_parallel_degree(size_gb)
        estimated_hours = self._estimate_migration_time(size_gb, index_count)
        priority = self._determine_priority(size_gb, lob_count)

        # Build target configuration
        target_partition_column = None
        if partition_key_columns:
            target_partition_column = partition_key_columns[0]  # Use existing
        elif timestamp_columns:
            target_partition_column = timestamp_columns[0]['name']

        target_hash_column = None
        if numeric_columns:
            target_hash_column = numeric_columns[0]['name']
        elif string_columns:
            target_hash_column = string_columns[0]['name']

        target_configuration = {
            "partition_type": "INTERVAL",
            "partition_column": target_partition_column,
            "interval_type": recommended_interval,
            "interval_value": 1,
            "initial_partition_value": "TO_DATE('2024-01-01', 'YYYY-MM-DD')",
            "subpartition_type": "HASH" if target_hash_column else "NONE",
            "subpartition_column": target_hash_column,
            "subpartition_count": recommended_hash_count,
            "tablespace": stats.get('tablespace_name', 'USERS'),
            "parallel_degree": recommended_parallel
        }

        # Get complete column DDL and storage details
        column_definitions_ddl = self._get_all_columns_ddl(table_name)
        lob_storage_details = self._get_lob_storage_details(table_name)
        storage_params = self._get_table_storage_params(table_name)
        index_details = self._get_index_details(table_name)

        # Build complete table config
        table_config = {
            "enabled": should_enable,
            "owner": self.schema,
            "table_name": table_name,
            "column_definitions": column_definitions_ddl,
            "lob_storage": lob_storage_details,
            "storage_parameters": storage_params,
            "indexes": index_details,
            "current_state": current_state,
            "available_columns": {
                "timestamp_columns": timestamp_columns,
                "numeric_columns": numeric_columns,
                "string_columns": string_columns
            },
            "migration_action": migration_action,
            "target_configuration": target_configuration,
            "migration_settings": {
                "estimated_hours": estimated_hours,
                "priority": priority,
                "validate_data": True,
                "backup_old_table": True,
                "drop_old_after_days": 7
            }
        }

        return table_config

    def _recommend_hash_count(self, size_gb: float, row_count: int) -> int:
        """Recommend number of hash subpartitions based on size"""
        if size_gb > 100:
            return 16
        elif size_gb > 50:
            return 12
        elif size_gb > 10:
            return 8
        elif size_gb > 1:
            return 4
        else:
            return 2

    def _recommend_interval_type(self, size_gb: float, row_count: int) -> str:
        """Recommend interval type (HOUR, DAY, MONTH) based on data volume"""
        # Estimate rows per day (assume 1 year of data)
        if row_count > 0:
            rows_per_day = row_count / 365

            if rows_per_day > 1000000:  # > 1M rows/day
                return 'HOUR'
            elif rows_per_day > 100000:  # > 100K rows/day
                return 'DAY'
            else:
                return 'MONTH'
        else:
            # Fall back to size-based
            if size_gb > 100:
                return 'DAY'
            else:
                return 'MONTH'

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

    def _estimate_migration_time(self, size_gb: float, index_count: int) -> float:
        """Estimate migration time in hours"""
        # Data load: 8 GB/hour (conservative)
        # Index creation: 0.75 hours per index
        load_time = size_gb / 8 if size_gb > 0 else 0.1
        index_time = index_count * 0.75
        total = load_time + index_time
        return round(total, 1)

    def _determine_priority(self, size_gb: float, lob_count: int) -> str:
        """Determine migration priority"""
        if size_gb > 50:
            return 'HIGH'
        elif lob_count > 0 or size_gb > 10:
            return 'MEDIUM'
        else:
            return 'LOW'

    def _format_criteria(self, include_patterns: Optional[List[str]],
                        exclude_patterns: Optional[List[str]]) -> str:
        """Format discovery criteria for metadata"""
        parts = [f"Schema: {self.schema}"]

        if include_patterns:
            parts.append(f"Include: {', '.join(include_patterns)}")

        if exclude_patterns:
            parts.append(f"Exclude: {', '.join(exclude_patterns)}")

        return ', '.join(parts)

    def save_config(self, config: Dict, output_file: str = 'migration_config.json'):
        """Save configuration to JSON file"""
        with open(output_file, 'w') as f:
            json.dump(config, f, indent=2, default=str)

        print(f"✓ Configuration saved to: {output_file}")
        print("  Edit this file to customize migration settings")
        print(f"  Then run: python3 generate_scripts.py --config {output_file}")
