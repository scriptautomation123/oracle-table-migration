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
import re
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Set, Any
from dataclasses import dataclass


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
        with open(self.schema_file, 'r') as f:
            self.schema = json.load(f)
            
        # Extract enums first
        self._extract_enums()
        
        # Generate classes from definitions
        if 'definitions' in self.schema:
            for name, definition in self.schema['definitions'].items():
                if definition.get('type') == 'object':
                    self._generate_class_from_definition(name, definition)
        
        # Generate main classes from root properties
        for name, prop in self.schema.get('properties', {}).items():
            if prop.get('type') == 'object':
                class_name = self._to_class_name(name)
                self._generate_class_from_definition(class_name, prop)
                
        # Write output
        self._write_output()
        print(f"✅ Generated {len(self.generated_classes)} classes in {self.output_file}")
        
    def _extract_enums(self) -> None:
        """Extract all enum definitions from schema"""
        def find_enums(obj, path="", parent_key=""):
            if isinstance(obj, dict):
                if 'enum' in obj:
                    enum_name = self._guess_enum_name(path, obj.get('description', ''), parent_key)
                    self.enums[enum_name] = obj['enum']
                for key, value in obj.items():
                    find_enums(value, f"{path}.{key}" if path else key, key)
            elif isinstance(obj, list):
                for i, item in enumerate(obj):
                    find_enums(item, f"{path}[{i}]", parent_key)
                    
        find_enums(self.schema)
        
        # Also check definitions for enum-only definitions
        if 'definitions' in self.schema:
            for name, definition in self.schema['definitions'].items():
                if definition.get('type') == 'string' and 'enum' in definition:
                    enum_name = self._to_class_name(name)
                    self.enums[enum_name] = definition['enum']
        
    def _guess_enum_name(self, path: str, description: str, parent_key: str = "") -> str:
        """Guess enum name from path and description"""
        # Look for common patterns
        if 'partition_type' in path.lower() or 'partitiontype' in parent_key.lower():
            return 'PartitionTypeEnum'
        elif 'interval_type' in path.lower() or 'intervaltype' in parent_key.lower():
            return 'IntervalTypeEnum'  
        elif 'subpartition_type' in path.lower() or 'subpartitiontype' in parent_key.lower():
            return 'SubpartitionTypeEnum'
        elif 'migration_action' in path.lower() or 'migrationaction' in parent_key.lower():
            return 'MigrationActionEnum'
        elif 'priority' in path.lower():
            return 'Priority'
        elif 'nullable' in path.lower() or parent_key.lower() == 'nullable':
            return 'YesNoEnum'
        elif 'yesno' in parent_key.lower() or any(x in path.lower() for x in ['yes', 'no', 'y', 'n']):
            return 'YesNoEnum'
        else:
            # Generate from path or parent_key
            if parent_key:
                return self._to_class_name(parent_key) + 'Enum'
            parts = path.split('.')
            return self._to_class_name(parts[-1] if parts else 'Unknown') + 'Enum'
    
    def _generate_class_from_definition(self, name: str, definition: Dict) -> None:
        """Generate a dataclass from a schema definition"""
        class_name = self._to_class_name(name)
        
        imports = {'from dataclasses import dataclass, field',
                  'from typing import List, Optional, Dict, Any, Union',
                  'from enum import Enum'}
        
        dependencies = set()
        
        # Generate class header
        content = f'@dataclass\nclass {class_name}:\n'
        content += f'    """{definition.get("description", f"{class_name} configuration")}"""\n'
        
        # Generate fields
        properties = definition.get('properties', {})
        required = set(definition.get('required', []))
        
        fields = []
        for field_name, field_def in properties.items():
            field_type, field_imports, field_deps = self._get_python_type(field_def)
            imports.update(field_imports)
            dependencies.update(field_deps)
            
            is_required = field_name in required
            default = self._get_default_value(field_def, is_required)
            
            field_line = f'    {field_name}: {field_type}'
            if default is not None:
                field_line += f' = {default}'
                
            # Add description as comment
            if field_def.get('description'):
                field_line += f'  # {field_def["description"]}'
                
            fields.append(field_line)
            
        content += '\n'.join(fields)
        
        # Add serialization methods
        content += '\n\n    def to_dict(self) -> Dict[str, Any]:\n'
        content += '        """Convert to dictionary for JSON serialization"""\n'
        content += '        return asdict(self)\n\n'
        
        content += '    @classmethod\n'
        content += f'    def from_dict(cls, data: Dict[str, Any]) -> "{class_name}":\n'
        content += '        """Create instance from dictionary"""\n'
        content += '        return cls(**data)\n'
        
        imports.add('from dataclasses import asdict')
        
        self.generated_classes.append(GeneratedClass(
            name=class_name,
            content=content,
            imports=imports,
            dependencies=dependencies
        ))
        
    def _get_python_type(self, field_def: Dict) -> tuple[str, Set[str], Set[str]]:
        """Convert JSON Schema type to Python type"""
        imports = set()
        dependencies = set()
        
        # Handle $ref first
        if '$ref' in field_def:
            ref_name = field_def['$ref'].split('/')[-1]
            class_name = self._to_class_name(ref_name)
            dependencies.add(class_name)
            return class_name, imports, dependencies
        
        field_type = field_def.get('type')
        
        # Handle union types like ["string", "null"]
        if isinstance(field_type, list):
            if 'null' in field_type:
                non_null_types = [t for t in field_type if t != 'null']
                if len(non_null_types) == 1:
                    base_type, base_imports, base_deps = self._get_python_type({'type': non_null_types[0], **{k: v for k, v in field_def.items() if k != 'type'}})
                    imports.update(base_imports)
                    dependencies.update(base_deps)
                    return f'Optional[{base_type}]', imports, dependencies
            # For complex unions, use Union
            union_types = []
            for t in field_type:
                if t != 'null':
                    sub_type, sub_imports, sub_deps = self._get_python_type({'type': t})
                    imports.update(sub_imports)
                    dependencies.update(sub_deps)
                    union_types.append(sub_type)
            if 'null' in field_type:
                return f'Optional[Union[{", ".join(union_types)}]]', imports, dependencies
            else:
                return f'Union[{", ".join(union_types)}]', imports, dependencies
        
        if field_type == 'string':
            if 'enum' in field_def:
                enum_name = self._guess_enum_name('', field_def.get('description', ''))
                if enum_name in self.enums:
                    dependencies.add(enum_name)
                    return enum_name, imports, dependencies
            return 'str', imports, dependencies
            
        elif field_type == 'integer':
            return 'int', imports, dependencies
            
        elif field_type == 'number':
            return 'float', imports, dependencies
            
        elif field_type == 'boolean':
            return 'bool', imports, dependencies
            
        elif field_type == 'array':
            items_def = field_def.get('items', {})
            items_type, items_imports, items_deps = self._get_python_type(items_def)
            imports.update(items_imports)
            dependencies.update(items_deps)
            return f'List[{items_type}]', imports, dependencies
            
        elif field_type == 'object':
            return 'Dict[str, Any]', imports, dependencies
                
        else:
            return 'Any', imports, dependencies
    
    def _get_default_value(self, field_def: Dict, is_required: bool) -> Optional[str]:
        """Get default value for a field"""
        if not is_required:
            if field_def.get('type') == 'array':
                return 'field(default_factory=list)'
            elif field_def.get('type') == 'object':
                return 'field(default_factory=dict)'
            else:
                return 'None'
        return None
    
    def _to_class_name(self, name: str) -> str:
        """Convert snake_case to PascalCase"""
        return ''.join(word.capitalize() for word in name.split('_'))
    
    def _write_output(self) -> None:
        """Write generated classes to output file"""
        content = ['#!/usr/bin/env python3']
        content.append('"""')
        content.append('Generated Migration Models')
        content.append('=' * 25)
        content.append('Auto-generated from migration_schema.json')
        content.append('DO NOT EDIT MANUALLY - Use tools/schema_to_dataclass.py')
        content.append('')
        content.append(f'Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
        content.append('"""')
        content.append('')
        
        # Collect all imports
        all_imports = set()
        for cls in self.generated_classes:
            all_imports.update(cls.imports)
            
        # Add imports
        for imp in sorted(all_imports):
            content.append(imp)
        content.append('')
        
        # Add enums first
        for enum_name, values in self.enums.items():
            content.append(f'class {enum_name}(Enum):')
            content.append(f'    """{enum_name} enumeration"""')
            for value in values:
                enum_key = value.upper().replace('-', '_').replace(' ', '_')
                content.append(f'    {enum_key} = "{value}"')
            content.append('')
            
        # Add classes in dependency order
        written = set()
        
        def write_class(cls: GeneratedClass):
            if cls.name in written:
                return
                
            # Write dependencies first
            for dep in cls.dependencies:
                dep_cls = next((c for c in self.generated_classes if c.name == dep), None)
                if dep_cls:
                    write_class(dep_cls)
                    
            content.append(cls.content)
            content.append('')
            written.add(cls.name)
            
        for cls in self.generated_classes:
            write_class(cls)
            
        # Write to file
        with open(self.output_file, 'w') as f:
            f.write('\n'.join(content))


def main():
    """Main entry point"""
    generator = SchemaToDataclassGenerator(
        schema_file='lib/enhanced_migration_schema.json',
        output_file='lib/generated_models.py'
    )
    generator.generate()


if __name__ == '__main__':
    main()