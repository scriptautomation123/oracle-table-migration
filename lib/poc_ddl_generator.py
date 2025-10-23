"""
POC DDL Generator Module
========================
Generates DDL scripts for POC environment setup.
"""

import json
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime
from jinja2 import Environment


class POCDDLGenerator:
    """
    Generates DDL scripts for POC environment
    """

    def __init__(self, jinja_env: Environment, output_dir: Path):
        """
        Initialize DDL generator

        Args:
            jinja_env: Jinja2 environment
            output_dir: Output directory for generated scripts
        """
        self.jinja_env = jinja_env
        self.output_dir = output_dir

    def generate_ddl_scripts(
        self, 
        schema_info: Dict[str, Any], 
        target_schema: str,
        cleanup_existing: bool = True
    ) -> List[str]:
        """
        Generate DDL scripts for POC environment

        Args:
            schema_info: Schema information from discovery
            target_schema: Target schema name
            cleanup_existing: Whether to include cleanup scripts

        Returns:
            List of generated script filenames
        """
        generated_scripts = []

        # Create target schema directory
        target_dir = self.output_dir / "ddl"
        target_dir.mkdir(parents=True, exist_ok=True)

        # 1. Cleanup script
        if cleanup_existing:
            cleanup_script = self._generate_cleanup_script(schema_info, target_schema, target_dir)
            generated_scripts.append(cleanup_script)

        # 2. Create schema script
        create_script = self._generate_create_schema_script(schema_info, target_schema, target_dir)
        generated_scripts.append(create_script)

        # 3. Create constraints script
        constraints_script = self._generate_constraints_script(schema_info, target_schema, target_dir)
        generated_scripts.append(constraints_script)

        # 4. Create indexes script
        indexes_script = self._generate_indexes_script(schema_info, target_schema, target_dir)
        generated_scripts.append(indexes_script)

        # 5. Create grants script
        grants_script = self._generate_grants_script(schema_info, target_schema, target_dir)
        generated_scripts.append(grants_script)

        return generated_scripts

    def generate_data_scripts(self, sample_data: Dict[str, Any]) -> List[str]:
        """
        Generate data loading scripts

        Args:
            sample_data: Sampled data information

        Returns:
            List of generated script filenames
        """
        generated_scripts = []

        # Create data directory
        data_dir = self.output_dir / "data"
        data_dir.mkdir(parents=True, exist_ok=True)

        # Generate INSERT statements for each table
        for table_info in sample_data["tables"]:
            table_name = table_info["table_name"]
            sample_data_rows = table_info["sample_data"]

            if not sample_data_rows:
                continue

            # Generate INSERT script for this table
            insert_script = self._generate_table_insert_script(
                table_info, data_dir
            )
            generated_scripts.append(insert_script)

        return generated_scripts

    def _generate_cleanup_script(
        self, 
        schema_info: Dict[str, Any], 
        target_schema: str, 
        target_dir: Path
    ) -> str:
        """Generate cleanup script"""
        script_content = f"""-- ==================================================================
-- POC CLEANUP SCRIPT
-- ==================================================================
-- Purpose: Clean up existing objects in target schema
-- Target Schema: {target_schema}
-- Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT POC Cleanup: {target_schema}
PROMPT ================================================================

-- Drop tables in reverse dependency order
"""

        # Add DROP TABLE statements
        for table_info in schema_info["tables"]:
            table_name = table_info["table_name"]
            script_content += f"DROP TABLE {target_schema}.{table_name} CASCADE CONSTRAINTS;\n"

        script_content += """
PROMPT Cleanup completed
"""

        # Write script
        script_path = target_dir / "01_cleanup_target.sql"
        with open(script_path, 'w') as f:
            f.write(script_content)

        return str(script_path)

    def _generate_create_schema_script(
        self, 
        schema_info: Dict[str, Any], 
        target_schema: str, 
        target_dir: Path
    ) -> str:
        """Generate CREATE TABLE script"""
        script_content = f"""-- ==================================================================
-- POC CREATE SCHEMA SCRIPT
-- ==================================================================
-- Purpose: Create tables in target schema
-- Target Schema: {target_schema}
-- Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT POC Schema Creation: {target_schema}
PROMPT ================================================================
"""

        # Generate CREATE TABLE statements
        for table_info in schema_info["tables"]:
            table_name = table_info["table_name"]
            columns = table_info["columns"]
            
            script_content += f"\n-- Table: {table_name}\n"
            script_content += f"CREATE TABLE {target_schema}.{table_name} (\n"
            
            # Add columns
            column_definitions = []
            for column in columns:
                col_def = f"    {column['name']} {column['type']}"
                
                # Add length/precision
                if column['length']:
                    if column['type'] in ['VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR']:
                        col_def += f"({column['length']})"
                    elif column['type'] == 'NUMBER' and column['precision']:
                        col_def += f"({column['precision']}"
                        if column['scale'] is not None:
                            col_def += f",{column['scale']}"
                        col_def += ")"
                
                # Add constraints
                if column['nullable'] == 'N':
                    col_def += " NOT NULL"
                
                if column['default']:
                    col_def += f" DEFAULT {column['default']}"
                
                column_definitions.append(col_def)
            
            script_content += ",\n".join(column_definitions)
            script_content += "\n);\n"

        script_content += """
PROMPT Schema creation completed
"""

        # Write script
        script_path = target_dir / "02_create_schema.sql"
        with open(script_path, 'w') as f:
            f.write(script_content)

        return str(script_path)

    def _generate_constraints_script(
        self, 
        schema_info: Dict[str, Any], 
        target_schema: str, 
        target_dir: Path
    ) -> str:
        """Generate constraints script"""
        script_content = f"""-- ==================================================================
-- POC CONSTRAINTS SCRIPT
-- ==================================================================
-- Purpose: Create constraints in target schema
-- Target Schema: {target_schema}
-- Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT POC Constraints: {target_schema}
PROMPT ================================================================
"""

        # Generate constraint statements
        for table_info in schema_info["tables"]:
            table_name = table_info["table_name"]
            constraints = table_info["constraints"]
            
            if constraints:
                script_content += f"\n-- Constraints for {table_name}\n"
                
                for constraint in constraints:
                    constraint_name = constraint["name"]
                    constraint_type = constraint["type"]
                    
                    if constraint_type == "P":
                        script_content += f"ALTER TABLE {target_schema}.{table_name} ADD CONSTRAINT {constraint_name} PRIMARY KEY (...);\n"
                    elif constraint_type == "U":
                        script_content += f"ALTER TABLE {target_schema}.{table_name} ADD CONSTRAINT {constraint_name} UNIQUE (...);\n"
                    elif constraint_type == "R":
                        script_content += f"ALTER TABLE {target_schema}.{table_name} ADD CONSTRAINT {constraint_name} FOREIGN KEY (...) REFERENCES ...;\n"
                    elif constraint_type == "C":
                        script_content += f"ALTER TABLE {target_schema}.{table_name} ADD CONSTRAINT {constraint_name} CHECK (...);\n"

        script_content += """
PROMPT Constraints creation completed
"""

        # Write script
        script_path = target_dir / "04_create_constraints.sql"
        with open(script_path, 'w') as f:
            f.write(script_content)

        return str(script_path)

    def _generate_indexes_script(
        self, 
        schema_info: Dict[str, Any], 
        target_schema: str, 
        target_dir: Path
    ) -> str:
        """Generate indexes script"""
        script_content = f"""-- ==================================================================
-- POC INDEXES SCRIPT
-- ==================================================================
-- Purpose: Create indexes in target schema
-- Target Schema: {target_schema}
-- Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT POC Indexes: {target_schema}
PROMPT ================================================================
"""

        # Generate index statements
        for table_info in schema_info["tables"]:
            table_name = table_info["table_name"]
            indexes = table_info["indexes"]
            
            if indexes:
                script_content += f"\n-- Indexes for {table_name}\n"
                
                for index in indexes:
                    index_name = index["name"]
                    index_type = index["type"]
                    uniqueness = index["uniqueness"]
                    
                    unique_keyword = "UNIQUE " if uniqueness == "UNIQUE" else ""
                    script_content += f"CREATE {unique_keyword}INDEX {target_schema}.{index_name} ON {target_schema}.{table_name} (...);\n"

        script_content += """
PROMPT Indexes creation completed
"""

        # Write script
        script_path = target_dir / "05_create_indexes.sql"
        with open(script_path, 'w') as f:
            f.write(script_content)

        return str(script_path)

    def _generate_grants_script(
        self, 
        schema_info: Dict[str, Any], 
        target_schema: str, 
        target_dir: Path
    ) -> str:
        """Generate grants script"""
        script_content = f"""-- ==================================================================
-- POC GRANTS SCRIPT
-- ==================================================================
-- Purpose: Create grants in target schema
-- Target Schema: {target_schema}
-- Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT POC Grants: {target_schema}
PROMPT ================================================================
"""

        # Generate grant statements
        for table_info in schema_info["tables"]:
            table_name = table_info["table_name"]
            grants = table_info["grants"]
            
            if grants:
                script_content += f"\n-- Grants for {table_name}\n"
                
                for grant in grants:
                    grantee = grant["grantee"]
                    privilege = grant["privilege"]
                    grantable = grant["grantable"]
                    
                    with_grant = " WITH GRANT OPTION" if grantable == "YES" else ""
                    script_content += f"GRANT {privilege} ON {target_schema}.{table_name} TO {grantee}{with_grant};\n"

        script_content += """
PROMPT Grants creation completed
"""

        # Write script
        script_path = target_dir / "06_create_grants.sql"
        with open(script_path, 'w') as f:
            f.write(script_content)

        return str(script_path)

    def _generate_table_insert_script(
        self, 
        table_info: Dict[str, Any], 
        data_dir: Path
    ) -> str:
        """Generate INSERT script for a specific table"""
        table_name = table_info["table_name"]
        columns = table_info["columns"]
        sample_data_rows = table_info["sample_data"]
        
        script_content = f"""-- ==================================================================
-- POC DATA LOADING: {table_name}
-- ==================================================================
-- Purpose: Load sample data for {table_name}
-- Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
-- ==================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ================================================================
PROMPT Loading sample data: {table_name}
PROMPT ================================================================
"""

        # Generate INSERT statements
        for row in sample_data_rows:
            values = []
            for column in columns:
                value = row.get(column)
                if value is None:
                    values.append("NULL")
                elif isinstance(value, str):
                    escaped_value = value.replace("'", "''")
                    values.append(f"'{escaped_value}'")
                else:
                    values.append(str(value))
            
            insert_sql = f"INSERT INTO {table_name} ({', '.join(columns)}) VALUES ({', '.join(values)});"
            script_content += insert_sql + "\n"

        script_content += f"""
COMMIT;

PROMPT Sample data loading completed for {table_name}
"""

        # Write script
        script_path = data_dir / f"load_{table_name.lower()}.sql"
        with open(script_path, 'w') as f:
            f.write(script_content)

        return str(script_path)
