"""
POC Schema Discovery Module
==========================
Discovers schema information from source database for POC generation.
"""

import json
from typing import Dict, List, Optional, Any
from datetime import datetime


class POCSchemaDiscovery:
    """
    Discovers schema information from source database
    """

    def __init__(self, connection):
        """
        Initialize schema discovery

        Args:
            connection: Oracle database connection
        """
        self.connection = connection

    def discover_schema(
        self, 
        schema_name: str, 
        include_patterns: List[str] = None, 
        exclude_patterns: List[str] = None
    ) -> Dict[str, Any]:
        """
        Discover schema information

        Args:
            schema_name: Source schema name
            include_patterns: Table name patterns to include
            exclude_patterns: Table name patterns to exclude

        Returns:
            Dictionary containing schema information
        """
        print(f"Discovering schema: {schema_name}")

        # Get all tables
        tables = self._get_tables(schema_name, include_patterns, exclude_patterns)
        print(f"Found {len(tables)} tables")

        # Get detailed information for each table
        schema_info = {
            "schema_name": schema_name,
            "discovery_date": datetime.now().isoformat(),
            "tables": []
        }

        for table_name in tables:
            print(f"  Processing table: {table_name}")
            table_info = self._get_table_info(schema_name, table_name)
            schema_info["tables"].append(table_info)

        return schema_info

    def _get_tables(
        self, 
        schema_name: str, 
        include_patterns: List[str] = None, 
        exclude_patterns: List[str] = None
    ) -> List[str]:
        """Get list of tables matching criteria"""
        cursor = self.connection.cursor()

        # Build WHERE clause
        where_conditions = [f"owner = UPPER('{schema_name}')"]
        
        if include_patterns:
            include_conditions = []
            for pattern in include_patterns:
                include_conditions.append(f"table_name LIKE UPPER('{pattern}')")
            where_conditions.append(f"({' OR '.join(include_conditions)})")

        if exclude_patterns:
            exclude_conditions = []
            for pattern in exclude_patterns:
                exclude_conditions.append(f"table_name NOT LIKE UPPER('{pattern}')")
            where_conditions.extend(exclude_conditions)

        query = f"""
            SELECT table_name
            FROM all_tables
            WHERE {' AND '.join(where_conditions)}
            ORDER BY table_name
        """

        cursor.execute(query)
        tables = [row[0] for row in cursor.fetchall()]
        cursor.close()

        return tables

    def _get_table_info(self, schema_name: str, table_name: str) -> Dict[str, Any]:
        """Get detailed information for a table"""
        table_info = {
            "table_name": table_name,
            "columns": self._get_columns(schema_name, table_name),
            "constraints": self._get_constraints(schema_name, table_name),
            "indexes": self._get_indexes(schema_name, table_name),
            "partitioning": self._get_partitioning_info(schema_name, table_name),
            "storage": self._get_storage_info(schema_name, table_name),
            "grants": self._get_grants(schema_name, table_name),
            "triggers": self._get_triggers(schema_name, table_name)
        }

        return table_info

    def _get_columns(self, schema_name: str, table_name: str) -> List[Dict[str, Any]]:
        """Get column information"""
        cursor = self.connection.cursor()

        query = """
            SELECT 
                column_name,
                data_type,
                data_length,
                data_precision,
                data_scale,
                nullable,
                data_default,
                column_id
            FROM all_tab_columns
            WHERE owner = UPPER(:schema_name)
              AND table_name = UPPER(:table_name)
            ORDER BY column_id
        """

        cursor.execute(query, schema_name=schema_name, table_name=table_name)
        
        columns = []
        for row in cursor.fetchall():
            columns.append({
                "name": row[0],
                "type": row[1],
                "length": row[2],
                "precision": row[3],
                "scale": row[4],
                "nullable": row[5],
                "default": row[6],
                "position": row[7]
            })

        cursor.close()
        return columns

    def _get_constraints(self, schema_name: str, table_name: str) -> List[Dict[str, Any]]:
        """Get constraint information"""
        cursor = self.connection.cursor()

        query = """
            SELECT 
                constraint_name,
                constraint_type,
                status,
                deferrable,
                deferred,
                validated
            FROM all_constraints
            WHERE owner = UPPER(:schema_name)
              AND table_name = UPPER(:table_name)
            ORDER BY constraint_name
        """

        cursor.execute(query, schema_name=schema_name, table_name=table_name)
        
        constraints = []
        for row in cursor.fetchall():
            constraints.append({
                "name": row[0],
                "type": row[1],
                "status": row[2],
                "deferrable": row[3],
                "deferred": row[4],
                "validated": row[5]
            })

        cursor.close()
        return constraints

    def _get_indexes(self, schema_name: str, table_name: str) -> List[Dict[str, Any]]:
        """Get index information"""
        cursor = self.connection.cursor()

        query = """
            SELECT 
                index_name,
                index_type,
                uniqueness,
                status,
                tablespace_name,
                degree,
                partitioned
            FROM all_indexes
            WHERE owner = UPPER(:schema_name)
              AND table_name = UPPER(:table_name)
            ORDER BY index_name
        """

        cursor.execute(query, schema_name=schema_name, table_name=table_name)
        
        indexes = []
        for row in cursor.fetchall():
            indexes.append({
                "name": row[0],
                "type": row[1],
                "uniqueness": row[2],
                "status": row[3],
                "tablespace": row[4],
                "degree": row[5],
                "partitioned": row[6]
            })

        cursor.close()
        return indexes

    def _get_partitioning_info(self, schema_name: str, table_name: str) -> Dict[str, Any]:
        """Get partitioning information"""
        cursor = self.connection.cursor()

        query = """
            SELECT 
                partitioning_type,
                subpartitioning_type,
                partition_count,
                def_subpartition_count,
                interval
            FROM all_part_tables
            WHERE owner = UPPER(:schema_name)
              AND table_name = UPPER(:table_name)
        """

        cursor.execute(query, schema_name=schema_name, table_name=table_name)
        row = cursor.fetchone()
        cursor.close()

        if row:
            return {
                "is_partitioned": True,
                "partitioning_type": row[0],
                "subpartitioning_type": row[1],
                "partition_count": row[2],
                "subpartition_count": row[3],
                "interval": row[4]
            }
        else:
            return {
                "is_partitioned": False,
                "partitioning_type": None,
                "subpartitioning_type": None,
                "partition_count": 0,
                "subpartition_count": 0,
                "interval": None
            }

    def _get_storage_info(self, schema_name: str, table_name: str) -> Dict[str, Any]:
        """Get storage information"""
        cursor = self.connection.cursor()

        query = """
            SELECT 
                tablespace_name,
                pct_free,
                ini_trans,
                max_trans,
                initial_extent,
                next_extent,
                buffer_pool
            FROM all_tables
            WHERE owner = UPPER(:schema_name)
              AND table_name = UPPER(:table_name)
        """

        cursor.execute(query, schema_name=schema_name, table_name=table_name)
        row = cursor.fetchone()
        cursor.close()

        if row:
            return {
                "tablespace": row[0],
                "pct_free": row[1],
                "ini_trans": row[2],
                "max_trans": row[3],
                "initial_extent": row[4],
                "next_extent": row[5],
                "buffer_pool": row[6]
            }
        else:
            return {}

    def _get_grants(self, schema_name: str, table_name: str) -> List[Dict[str, Any]]:
        """Get grant information"""
        cursor = self.connection.cursor()

        query = """
            SELECT 
                grantee,
                privilege,
                grantable
            FROM all_tab_privs
            WHERE owner = UPPER(:schema_name)
              AND table_name = UPPER(:table_name)
            ORDER BY grantee, privilege
        """

        cursor.execute(query, schema_name=schema_name, table_name=table_name)
        
        grants = []
        for row in cursor.fetchall():
            grants.append({
                "grantee": row[0],
                "privilege": row[1],
                "grantable": row[2]
            })

        cursor.close()
        return grants

    def _get_triggers(self, schema_name: str, table_name: str) -> List[Dict[str, Any]]:
        """Get trigger information"""
        cursor = self.connection.cursor()

        query = """
            SELECT 
                trigger_name,
                trigger_type,
                triggering_event,
                status
            FROM all_triggers
            WHERE owner = UPPER(:schema_name)
              AND table_name = UPPER(:table_name)
            ORDER BY trigger_name
        """

        cursor.execute(query, schema_name=schema_name, table_name=table_name)
        
        triggers = []
        for row in cursor.fetchall():
            triggers.append({
                "name": row[0],
                "type": row[1],
                "event": row[2],
                "status": row[3]
            })

        cursor.close()
        return triggers
