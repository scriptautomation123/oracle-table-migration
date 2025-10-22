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

    def discover_schema(
        self,
        schema_name: str,
        include_patterns: Optional[List[str]] = None,
        exclude_patterns: Optional[List[str]] = None,
    ) -> Dict:
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
                index_counts.get(table_name, 0),
            )
            tables_config.append(table_config)
            print(f"  • {table_name}: {table_config['migration_action']}")

        # Step 6: Generate metadata
        self.metadata = {
            "generated_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "schema": self.schema,
            "discovery_criteria": self._format_criteria(
                include_patterns, exclude_patterns
            ),
            "total_tables_found": len(all_tables),
            "tables_selected_for_migration": len(
                [t for t in tables_config if t["enabled"]]
            ),
        }

        config = {"metadata": self.metadata, "tables": tables_config}

        print("\n" + "=" * 70)
        print("Discovery complete!")
        print(f"  Total tables: {len(all_tables)}")
        print(
            f"  Enabled for migration: {self.metadata['tables_selected_for_migration']}"
        )
        print("=" * 70 + "\n")

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
        """Get partition information for all partitioned tables"""
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
            partition_info[table_name] = {
                "partitioning_type": row[1],
                "subpartitioning_type": row[2],
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
        """Get size in GB for all tables"""
        cursor = self.connection.cursor()

        query = """
            SELECT segment_name, ROUND(SUM(bytes) / POWER(1024, 3), 2) AS size_gb
            FROM all_segments
            WHERE owner = :schema
              AND segment_type IN ('TABLE', 'TABLE PARTITION')
            GROUP BY segment_name
        """

        cursor.execute(query, schema=self.schema)

        sizes = {}
        for row in cursor.fetchall():
            sizes[row[0]] = row[1]

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
            columns.append({"name": row[0], "type": row[1], "nullable": row[2]})

        cursor.close()
        return columns

    def _analyze_table(
        self,
        table_name: str,
        partition_info: Optional[Dict],
        size_gb: float,
        stats: Dict,
        lob_count: int,
        index_count: int,
    ) -> Dict:
        """
        Analyze a single table and generate migration configuration

        Returns:
            Dictionary with table configuration for JSON output
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
        recommended_parallel = self._recommend_parallel_degree(size_gb)
        estimated_hours = self._estimate_migration_time(size_gb, index_count)
        priority = self._determine_priority(size_gb, lob_count)

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

        target_configuration = {
            "partition_type": "INTERVAL",
            "partition_column": target_partition_column,
            "interval_type": recommended_interval,
            "interval_value": 1,
            "initial_partition_value": "TO_DATE('2024-01-01', 'YYYY-MM-DD')",
            "subpartition_type": "HASH" if target_hash_column else "NONE",
            "subpartition_column": target_hash_column,
            "subpartition_count": recommended_hash_count,
            "tablespace": stats.get("tablespace_name", "USERS"),
            "parallel_degree": recommended_parallel,
        }

        # Build complete table config
        table_config = {
            "enabled": should_enable,
            "owner": self.schema,
            "table_name": table_name,
            "current_state": current_state,
            "available_columns": {
                "timestamp_columns": timestamp_columns,
                "numeric_columns": numeric_columns,
                "string_columns": string_columns,
            },
            "migration_action": migration_action,
            "target_configuration": target_configuration,
            "migration_settings": {
                "estimated_hours": estimated_hours,
                "priority": priority,
                "validate_data": True,
                "backup_old_table": True,
                "drop_old_after_days": 7,
            },
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
            return "HIGH"
        elif lob_count > 0 or size_gb > 10:
            return "MEDIUM"
        else:
            return "LOW"

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

    def save_config(self, config: Dict, output_file: str = "migration_config.json"):
        """Save configuration to JSON file"""
        with open(output_file, "w") as f:
            json.dump(config, f, indent=2, default=str)

        print(f"✓ Configuration saved to: {output_file}")
        print("  Edit this file to customize migration settings")
        print(f"  Then run: python3 generate_scripts.py --config {output_file}")
