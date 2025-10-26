# Oracle Table Migration Scripts

Generated on: 2025-10-25T22:09:23.587481
Environment: global
Source Schema: APP_DATA_OWNER

## Tables Processed: 4

### APP_DATA_OWNER.APP_CACHE
- **Directory**: `APP_DATA_OWNER_APP_CACHE/`
- **Migration Type**: add_interval_hash_partitioning
- **Main Script**: `APP_DATA_OWNER_APP_CACHE/master1.sql`

### APP_DATA_OWNER.JOB_QUEUE
- **Directory**: `APP_DATA_OWNER_JOB_QUEUE/`
- **Migration Type**: add_interval_hash_partitioning
- **Main Script**: `APP_DATA_OWNER_JOB_QUEUE/master1.sql`

### APP_DATA_OWNER.SESSION_DATA
- **Directory**: `APP_DATA_OWNER_SESSION_DATA/`
- **Migration Type**: add_interval_hash_partitioning
- **Main Script**: `APP_DATA_OWNER_SESSION_DATA/master1.sql`

### APP_DATA_OWNER.TEMP_CALCULATIONS
- **Directory**: `APP_DATA_OWNER_TEMP_CALCULATIONS/`
- **Migration Type**: add_interval_hash_partitioning
- **Main Script**: `APP_DATA_OWNER_TEMP_CALCULATIONS/master1.sql`

## Usage Instructions:

1. **Navigate to each table directory**
2. **Review the table-specific README.md**
3. **Execute the master1.sql script for each table**

Example:
```bash
cd APP_DATA_OWNER_ORDERS/
sqlplus user/pass@db @master1.sql

cd APP_DATA_OWNER_CUSTOMERS/  
sqlplus user/pass@db @master1.sql
```

## Directory Structure:
```
├── README.md (this file)
├── SCHEMA_TABLE1/
│   ├── README.md
│   ├── master1.sql ⭐ (MAIN SCRIPT)
│   ├── 10_create_table.sql
│   ├── 20_data_load.sql
│   └── ... (other scripts)
└── SCHEMA_TABLE2/
    ├── README.md  
    ├── master1.sql ⭐ (MAIN SCRIPT)
    └── ... (other scripts)
```

**CRITICAL**: Each master1.sql should run completely without manual intervention.
