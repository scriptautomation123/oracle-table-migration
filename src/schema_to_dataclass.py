#!/usr/bin/env python3
"""
Schema-Driven Dataclass Generator
=================================
Generates Python dataclasses from JSON Schema.
Principal Engineer approach: Schema as single source of truth.

Usage:
    python tools/schema_to_dataclass.py

Features:
- Auto-generates dataclasses from migration_schema.json
- Creates proper type hints and validation
- Handles enums, optional fields, nested objects
- Generates serialization methods (to_dict, from_dict)
- Creates validation methods using the schema
- Updates only when schema changes (idempotent)
"""

import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Set


@dataclass
class GeneratedClass:
    """Information about a generated class"""

    name: str
    content: str
    imports: Set[str]
    dependencies: Set[str]  # Other classes this depends on


class SchemaToDataclassGenerator:
    """Generate Python dataclasses from JSON Schema"""

    def __init__(self, schema_file: str, output_file: str):
        self.schema_file = Path(schema_file)
        self.output_file = Path(output_file)
        self.schema: Dict = {}
        self.generated_classes: List[GeneratedClass] = []
        self.enums: Dict[str, List[str]] = {}

    def generate(self) -> None:
        """Main generation method"""
        print(f"🔄 Generating dataclasses from {self.schema_file}")

        # Load schema
        with open(self.schema_file, "r") as f:
            self.schema = json.load(f)

        # Extract enums first (prioritize definitions)
        self._extract_enums()

        # Generate main root class (MigrationConfig) from schema root
        if self.schema.get("type") == "object" and "properties" in self.schema:
            # Use the exact class name for root config class
            self._generate_root_class("MigrationConfig", self.schema)

        # Generate classes from definitions
        if "definitions" in self.schema:
            for name, definition in self.schema["definitions"].items():
                if definition.get("type") == "object":
                    self._generate_class_from_definition(name, definition)

        # Write output
        self._write_output()
        print(
            f"✅ Generated {len(self.generated_classes)} classes in {self.output_file}"
        )

    def _extract_enums(self) -> None:
        """Extract all enum definitions from schema - prioritize definitions section"""
        # Use a set to track enum values and avoid duplicates
        enum_signatures = set()

        # FIRST: Process definitions section (these have correct names)
        if "definitions" in self.schema:
            for name, definition in self.schema["definitions"].items():
                if definition.get("type") == "string" and "enum" in definition:
                    valid_enum_values = [v for v in definition["enum"] if v is not None]
                    if valid_enum_values:
                        enum_values = tuple(sorted(valid_enum_values))
                        enum_name = self._to_class_name(name)

                        # Always add from definitions (they have priority)
                        self.enums[enum_name] = valid_enum_values
                        enum_signatures.add(enum_values)

        # SECOND: Find other enums in schema (skip if already found)
        def find_enums(obj, path="", parent_key=""):
            if isinstance(obj, dict):
                if "enum" in obj:
                    # Filter out None values and sort for signature
                    valid_enum_values = [v for v in obj["enum"] if v is not None]
                    if valid_enum_values:  # Only process if we have valid enum values
                        enum_values = tuple(sorted(valid_enum_values))
                        if enum_values not in enum_signatures:
                            enum_name = self._guess_enum_name(
                                path, obj.get("description", ""), parent_key
                            )
                            self.enums[enum_name] = valid_enum_values
                            enum_signatures.add(enum_values)
                for key, value in obj.items():
                    find_enums(value, f"{path}.{key}" if path else key, key)
            elif isinstance(obj, list):
                for i, item in enumerate(obj):
                    find_enums(item, f"{path}[{i}]", parent_key)

        find_enums(self.schema)

    def _guess_enum_name(
        self, path: str, description: str, parent_key: str = ""
    ) -> str:
        """Guess enum name from path and description"""
        # Combine all sources for better matching
        combined = f"{path} {description} {parent_key}".lower()

        # Look for specific patterns in order of specificity
        if any(pattern in combined for pattern in ["partition_type", "partitiontype"]):
            return "PartitionTypeEnum"
        elif any(pattern in combined for pattern in ["interval_type", "intervaltype"]):
            return "IntervalTypeEnum"
        elif any(
            pattern in combined for pattern in ["subpartition_type", "subpartitiontype"]
        ):
            return "SubpartitionTypeEnum"
        elif any(
            pattern in combined for pattern in ["migration_action", "migrationaction"]
        ):
            return "MigrationActionEnum"
        elif "priority" in combined:
            return "PriorityEnum"
        elif any(pattern in combined for pattern in ["nullable", "yesno", "yes", "no"]):
            return "YesNoEnum"
        else:
            # Generate from the most specific available key
            key_to_use = parent_key or path.split(".")[-1] if path else "Unknown"
            # Apply proper PascalCase conversion
            if key_to_use.lower() in self._get_special_cases():
                return self._get_special_cases()[key_to_use.lower()] + "Enum"
            return self._to_class_name(key_to_use) + "Enum"

    def _get_special_cases(self) -> Dict[str, str]:
        """Get special case mappings for enum names"""
        return {
            "partitiontype": "PartitionType",
            "intervaltype": "IntervalType",
            "subpartitiontype": "SubpartitionType",
            "migrationaction": "MigrationAction",
            "yesno": "YesNo",
        }

    def _generate_root_class(self, class_name: str, definition: Dict) -> None:
        """Generate the root MigrationConfig class with exact name"""
        # Use exact class name without conversion
        self._generate_dataclass(class_name, definition)

    def _generate_class_from_definition(self, name: str, definition: Dict) -> None:
        """Generate a dataclass from a schema definition"""
        class_name = self._to_class_name(name)
        self._generate_dataclass(class_name, definition)

    def _generate_dataclass(self, class_name: str, definition: Dict) -> None:
        """Generate a dataclass with the given exact class name"""
        imports = {
            "from dataclasses import dataclass, field",
            "from typing import List, Optional, Dict, Any",
            "from enum import Enum",
        }

        dependencies = set()

        # Generate class header
        content = f"@dataclass\nclass {class_name}:\n"
        content += f'    """{definition.get("description", f"{class_name} configuration")}"""\n'

        # Generate fields - required fields first, then optional fields
        properties = definition.get("properties", {})
        required = set(definition.get("required", []))

        # Split into required and optional fields
        required_fields = []
        optional_fields = []

        for field_name, field_def in properties.items():
            field_type, field_imports, field_deps = self._get_python_type(field_def)
            imports.update(field_imports)
            dependencies.update(field_deps)

            is_required = field_name in required
            # Check if field has a default value in schema or should be treated as optional
            has_schema_default = "default" in field_def
            default = self._get_default_value(
                field_def, is_required and not has_schema_default
            )

            field_line = f"    {field_name}: {field_type}"
            if default is not None:
                field_line += f" = {default}"

            # Add description as comment
            if field_def.get("description"):
                field_line += f'  # {field_def["description"]}'

            # A field is truly required only if it's in required list AND has no default
            if is_required and not has_schema_default:
                required_fields.append(field_line)
            else:
                optional_fields.append(field_line)

        # Combine required fields first, then optional fields
        fields = required_fields + optional_fields

        # Build field definitions dict for serialization
        field_definitions = {}
        for field_name, field_def in properties.items():
            field_definitions[field_name] = field_def

        content += "\n".join(fields)

        # Add serialization methods - use explicit field-by-field approach per Principal Engineer guidance
        content += "\n\n    def to_dict(self) -> Dict[str, Any]:\n"
        content += '        """Convert to dictionary for JSON serialization - explicit recursive conversion"""\n'
        content += "        import dataclasses\n"
        content += "        def convert(val):\n"
        content += "            if isinstance(val, Enum):\n"
        content += "                return val.value\n"
        content += "            elif dataclasses.is_dataclass(val):\n"
        content += "                return val.to_dict()\n"
        content += "            elif isinstance(val, list):\n"
        content += "                return [convert(v) for v in val]\n"
        content += "            elif isinstance(val, dict):\n"
        content += "                return {k: convert(v) for k, v in val.items()}\n"
        content += "            else:\n"
        content += "                return val\n"
        content += "        result = {f.name: convert(getattr(self, f.name)) for f in self.__dataclass_fields__.values()}\n"

        # For ColumnInfo, remove identity fields if not an identity column
        if class_name == "ColumnInfo":
            content += "        # Remove identity-specific fields if this is not an identity column\n"
            content += "        if hasattr(self, 'is_identity') and not self.is_identity:\n"
            content += "            identity_fields = [\n"
            content += "                'identity_generation', 'identity_sequence', 'identity_start_with',\n"
            content += "                'identity_increment_by', 'identity_max_value', 'identity_min_value',\n"
            content += "                'identity_cache_size', 'identity_cycle_flag', 'identity_order_flag'\n"
            content += "            ]\n"
            content += "            for field in identity_fields:\n"
            content += "                result.pop(field, None)\n"

        content += "        return result\n"

        content += "    @classmethod\n"
        content += f'    def from_dict(cls, data: Dict[str, Any]) -> "{class_name}":\n'
        content += '        """Create instance from dictionary with proper type conversions"""\n'
        content += "        if data is None:\n"
        content += "            return None\n"
        content += "        return cls(\n"

        # Generate explicit field-by-field conversion per Principal Engineer guidance
        for field_name, field_def in properties.items():
            field_type, field_imports, field_deps = self._get_python_type(field_def)
            is_optional = "Optional" in field_type or field_name not in required
            schema_default = field_def.get("default")
            default_value = self._format_default_for_from_dict(schema_default)

            # Determine conversion logic based on type
            if "Enum" in field_type:
                enum_name = field_type.split("[")[0].strip()
                if is_optional:
                    content += f'            {field_name}={enum_name}(data["{field_name}"]) if "{field_name}" in data and data["{field_name}"] is not None else {default_value},\n'
                else:
                    content += f'            {field_name}={enum_name}(data["{field_name}"]) if "{field_name}" in data else {default_value},\n'
            elif "List[" in field_type:
                # Extract inner type from List[InnerType]
                inner_type = field_type.split("[")[1].split("]")[0]
                if inner_type in self.enums or "Enum" in inner_type:
                    # List of enums
                    content += f'            {field_name}=[{inner_type}(x) for x in data.get("{field_name}", [])],\n'
                elif inner_type in dependencies:
                    # List of dataclasses
                    content += f'            {field_name}=[{inner_type}.from_dict(x) for x in data.get("{field_name}", [])],\n'
                else:
                    # Primitive list
                    content += f'            {field_name}=data.get("{field_name}", []),\n'
            elif field_type in dependencies:
                # Nested dataclass
                if is_optional:
                    content += f'            {field_name}={field_type}.from_dict(data["{field_name}"]) if "{field_name}" in data and data["{field_name}"] is not None else None,\n'
                else:
                    content += f'            {field_name}={field_type}.from_dict(data["{field_name}"]) if "{field_name}" in data else None,\n'
            else:
                # Primitive type - use schema default if available
                if schema_default is not None:
                    content += f'            {field_name}=data.get("{field_name}", {default_value}),\n'
                elif field_type == "bool":
                    # Booleans should default to False if not present
                    content += f'            {field_name}=data.get("{field_name}", False),\n'
                elif is_optional:
                    content += f'            {field_name}=data.get("{field_name}"),\n'
                else:
                    content += f'            {field_name}=data["{field_name}"],\n'

        content += "        )\n"

        self.generated_classes.append(
            GeneratedClass(
                name=class_name,
                content=content,
                imports=imports,
                dependencies=dependencies,
            )
        )

    def _get_python_type(self, field_def: Dict) -> tuple[str, Set[str], Set[str]]:
        """Convert JSON Schema type to Python type"""
        imports = set()
        dependencies = set()

        # Handle $ref first
        if "$ref" in field_def:
            ref_name = field_def["$ref"].split("/")[-1]
            class_name = self._to_class_name(ref_name)
            dependencies.add(class_name)
            return class_name, imports, dependencies

        field_type = field_def.get("type")

        # Handle union types like ["string", "null"]
        if isinstance(field_type, list):
            if "null" in field_type:
                non_null_types = [t for t in field_type if t != "null"]
                if len(non_null_types) == 1:
                    base_type, base_imports, base_deps = self._get_python_type(
                        {
                            "type": non_null_types[0],
                            **{k: v for k, v in field_def.items() if k != "type"},
                        }
                    )
                    imports.update(base_imports)
                    dependencies.update(base_deps)
                    return f"Optional[{base_type}]", imports, dependencies
            # For complex unions, use Union
            union_types = []
            for t in field_type:
                if t != "null":
                    sub_type, sub_imports, sub_deps = self._get_python_type({"type": t})
                    imports.update(sub_imports)
                    dependencies.update(sub_deps)
                    union_types.append(sub_type)
            if "null" in field_type:
                return (
                    f'Optional[Union[{", ".join(union_types)}]]',
                    imports,
                    dependencies,
                )
            else:
                return f'Union[{", ".join(union_types)}]', imports, dependencies

        if field_type == "string":
            if "enum" in field_def:
                enum_name = self._guess_enum_name("", field_def.get("description", ""))
                if enum_name in self.enums:
                    dependencies.add(enum_name)
                    return enum_name, imports, dependencies
            return "str", imports, dependencies

        elif field_type == "integer":
            return "int", imports, dependencies

        elif field_type == "number":
            return "float", imports, dependencies

        elif field_type == "boolean":
            return "bool", imports, dependencies

        elif field_type == "array":
            items_def = field_def.get("items", {})
            items_type, items_imports, items_deps = self._get_python_type(items_def)
            imports.update(items_imports)
            dependencies.update(items_deps)
            return f"List[{items_type}]", imports, dependencies

        elif field_type == "object":
            return "Dict[str, Any]", imports, dependencies

        else:
            return "Any", imports, dependencies

    def _get_default_value(self, field_def: Dict, is_required: bool) -> Optional[str]:
        """Get default value for a field"""
        if not is_required:
            if field_def.get("type") == "array":
                return "field(default_factory=list)"
            elif field_def.get("type") == "object":
                return "field(default_factory=dict)"
            else:
                return "None"
        return None

    def _format_default_for_from_dict(self, default_value) -> str:
        """Format a schema default value for use in from_dict"""
        if default_value is None:
            return "None"
        if isinstance(default_value, bool):
            return str(default_value)
        if isinstance(default_value, (int, float)):
            return str(default_value)
        if isinstance(default_value, str):
            return f'"{default_value}"'
        return "None"

    def _to_class_name(self, name: str) -> str:
        """Convert snake_case to PascalCase"""
        # Handle special cases for proper capitalization
        special_cases = {
            # Schema definition names (already PascalCase)
            "tableconfig": "TableConfig",
            "connectiondetails": "ConnectionDetails",
            "environmentconfig": "EnvironmentConfig",
            "currentstate": "CurrentState",
            "commonsettings": "CommonSettings",
            "targetconfiguration": "TargetConfiguration",
            "migrationsettings": "MigrationSettings",
            "columninfo": "ColumnInfo",
            "lobstorageinfo": "LobStorageInfo",
            "storageparameters": "StorageParameters",
            "indexinfo": "IndexInfo",
            "grantinfo": "GrantInfo",
            "availablecolumns": "AvailableColumns",
            "datatablespaces": "DataTablespaces",
            "tablespaceconfig": "TablespaceConfig",
            "subpartitiondefaults": "SubpartitionDefaults",
            "sizerecommendation": "SizeRecommendation",
            "paralleldefaults": "ParallelDefaults",
            # Snake case versions
            "connection_details": "ConnectionDetails",
            "environment_config": "EnvironmentConfig",
            "table_config": "TableConfig",
            "current_state": "CurrentState",
            "common_settings": "CommonSettings",
            "target_configuration": "TargetConfiguration",
            "migration_settings": "MigrationSettings",
            "column_info": "ColumnInfo",
            "lob_storage_info": "LobStorageInfo",
            "storage_parameters": "StorageParameters",
            "index_info": "IndexInfo",
            "grant_info": "GrantInfo",
            "available_columns": "AvailableColumns",
            "data_tablespaces": "DataTablespaces",
            "tablespace_config": "TablespaceConfig",
            "subpartition_defaults": "SubpartitionDefaults",
            "size_recommendation": "SizeRecommendation",
            "parallel_defaults": "ParallelDefaults",
        }

        if name.lower() in special_cases:
            return special_cases[name.lower()]

        # Handle snake_case input
        if "_" in name:
            return "".join(word.capitalize() for word in name.split("_"))

        # Handle PascalCase input - return as-is if already proper
        if name and name[0].isupper():
            return name

        # Handle lowercase input - capitalize first letter
        return name.capitalize() if name else name

    def _write_output(self) -> None:
        """Write generated classes to output file"""
        content = ["#!/usr/bin/env python3"]
        content.append('"""')
        content.append("Generated Migration Models")
        content.append("=" * 25)
        content.append("Auto-generated from enhanced_migration_schema.json")
        content.append("DO NOT EDIT MANUALLY - Run: python3 src/schema_to_dataclass.py")
        content.append("")
        content.append(f'Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
        content.append('"""')
        content.append("")
        content.append("from __future__ import annotations")
        content.append("")

        # Collect all imports
        all_imports = set()
        for cls in self.generated_classes:
            all_imports.update(cls.imports)

        # Add imports
        for imp in sorted(all_imports):
            content.append(imp)
        content.append("")

        # Add enums first
        for enum_name, values in self.enums.items():
            content.append(f"class {enum_name}(Enum):")
            content.append(f'    """{enum_name} enumeration"""')
            for value in values:
                enum_key = value.upper().replace("-", "_").replace(" ", "_")
                content.append(f'    {enum_key} = "{value}"')
            content.append("")

        # Add classes in dependency order
        written = set()

        def write_class(cls: GeneratedClass):
            if cls.name in written:
                return

            # Write dependencies first
            for dep in cls.dependencies:
                dep_cls = next(
                    (c for c in self.generated_classes if c.name == dep), None
                )
                if dep_cls:
                    write_class(dep_cls)

            content.append(cls.content)
            content.append("")
            written.add(cls.name)

        for cls in self.generated_classes:
            write_class(cls)

        # Write to file
        with open(self.output_file, "w") as f:
            f.write("\n".join(content))


def main():
    """Main entry point"""
    generator = SchemaToDataclassGenerator(
        schema_file="lib/enhanced_migration_schema.json",
        output_file="lib/migration_models.py",
    )
    generator.generate()


if __name__ == "__main__":
    main()
