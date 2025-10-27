#!/usr/bin/env python3
"""Convert migration_config.json to Excel format"""
import json
import pandas as pd
from pathlib import Path
from datetime import datetime

def json_to_excel(json_file='migration_config.json', excel_file=None):
    if excel_file is None:
        excel_file = json_file.replace('.json', '.xlsx')
    
    print(f"📖 Reading {json_file}...")
    with open(json_file, 'r') as f:
        config = json.load(f)
    
    metadata = config.get('metadata', {})
    tables = config.get('tables', [])
    
    print(f"📊 Processing {len(tables)} tables...")
    
    # Create Excel writer
    with pd.ExcelWriter(excel_file, engine='openpyxl') as writer:
        # Sheet 1: Summary
        summary_data = {
            'Schema': [metadata.get('source_schema', '')],
            'Generated Date': [metadata.get('generated_date', '')],
            'Total Tables': [len(tables)],
            'Tables Selected': [metadata.get('tables_selected_for_migration', 0)],
            'Environment': [config.get('environment_config', {}).get('name', '')]
        }
        pd.DataFrame(summary_data).to_excel(writer, sheet_name='Summary', index=False)
        
        # Sheet 2: Tables Overview
        tables_data = []
        for table in tables:
            current = table.get('current_state', {})
            action = table.get('migration_action', {}).get('action', '')
            
            tables_data.append({
                'Owner': table.get('owner', ''),
                'Table Name': table.get('table_name', ''),
                'Enabled': table.get('enabled', False),
                'Partition Type': current.get('partition_type', 'N/A'),
                'Size (GB)': current.get('size_gb', 0),
                'Row Count': current.get('row_count', 0),
                'Column Count': len(current.get('columns', [])),
                'Index Count': current.get('index_count', 0),
                'LOB Count': current.get('lob_count', 0),
                'Migration Action': action
            })
        
        pd.DataFrame(tables_data).to_excel(writer, sheet_name='Tables', index=False)
        
        # Sheet 3: Columns (for each enabled table)
        columns_data = []
        for table in tables:
            if table.get('enabled'):
                table_name = table.get('table_name', '')
                for col in table.get('current_state', {}).get('columns', []):
                    # Only include key column info (omit identity details for space)
                    if not col.get('is_identity'):
                        columns_data.append({
                            'Table': table_name,
                            'Column Name': col.get('name', ''),
                            'Type': col.get('type', ''),
                            'Length': col.get('length', ''),
                            'Precision': col.get('precision', ''),
                            'Scale': col.get('scale', ''),
                            'Nullable': col.get('nullable', '')
                        })
        
        if columns_data:
            pd.DataFrame(columns_data).to_excel(writer, sheet_name='Columns', index=False)
    
    print(f"✅ Created {excel_file}")
    print(f"   - Summary sheet")
    print(f"   - Tables overview ({len(tables_data)} tables)")
    print(f"   - Columns details ({len(columns_data)} columns)")

if __name__ == '__main__':
    json_to_excel()