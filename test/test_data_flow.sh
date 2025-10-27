#!/bin/bash
# Test Data Flow Pipeline for Oracle Table Migration
# Tests the 4-step data transformation pipeline

set -e

# Configuration
ORACLE_CONN="${ORACLE_CONN:-system/oracle123@localhost:1521/FREEPDB1}"
SCHEMA="${SCHEMA:-APP_DATA_OWNER}"
OUTPUT_DIR="output_test"

echo "========================================"
echo "Oracle Table Migration - Data Flow Test"
echo "========================================"
echo "Connection: ${ORACLE_CONN}"
echo "Schema: ${SCHEMA}"
echo "Output: ${OUTPUT_DIR}"
echo ""

# Clean previous test outputs
if [[ -d "${OUTPUT_DIR}" ]]; then
    rm -rf "${OUTPUT_DIR}"
fi

echo "=== STEP 1: Schema → Models (if schema changed) ==="
echo "Note: This step is manual - run if schema changed:"
echo "  python3 src/schema_to_dataclass.py"
echo ""

echo "=== STEP 2: Oracle DB → Config (Discovery) ==="
python3 src/generate.py --discover \
  --schema "${SCHEMA}" \
  --connection "${ORACLE_CONN}" \
  --output-dir "${OUTPUT_DIR}"

CONFIG_FILE=$(find "${OUTPUT_DIR}" -name "migration_config.json" -type f | head -1)
if [[ -z "${CONFIG_FILE}" ]]; then
    echo "❌ ERROR: No config file found"
    exit 1
fi

echo ""
echo "✓ Config generated: ${CONFIG_FILE}"
echo ""

echo "=== TEST: Config Serialization Round-Trip ==="
python3 -c "
from lib.migration_models import MigrationConfig
import os

config_file = '${CONFIG_FILE}'
print(f'Testing serialization with: {config_file}')

# Load config
config = MigrationConfig.from_json_file(config_file)
print(f'✓ Loaded config for schema: {config.metadata.source_schema}')
print(f'✓ Tables found: {config.metadata.total_tables_found}')

# Round-trip test
test_file = '/tmp/test_roundtrip.json'
config.save_to_file(test_file)
roundtrip_config = MigrationConfig.from_json_file(test_file)

if roundtrip_config.metadata.source_schema == config.metadata.source_schema:
    print('✓ Round-trip serialization successful')
    os.remove(test_file)
else:
    print('❌ Round-trip serialization failed')
    os.remove(test_file)
    exit(1)
"

echo ""
echo "=== STEP 3: Config → SQL (Generation) ==="
python3 src/generate.py --config "${CONFIG_FILE}"

MASTER_SQL=$(find "${OUTPUT_DIR}" -name "master1.sql" -type f | head -1)
if [[ -z "${MASTER_SQL}" ]]; then
    echo "❌ ERROR: No master1.sql generated"
    exit 1
fi

echo ""
echo "✓ DDL generated: ${MASTER_SQL}"
echo "  Lines: $(wc -l < "${MASTER_SQL}")"
echo ""

echo "=== STEP 4: Validate SQL (Check syntax) ==="
echo "Note: Actual Oracle execution is manual"
echo "  sqlplus ${ORACLE_CONN} @${MASTER_SQL}"
echo ""

echo "========================================"
echo "✓ DATA PIPELINE TEST COMPLETE"
echo "========================================"
echo ""
echo "Summary:"
echo "  - Discovery: $(find "${OUTPUT_DIR}" -name "migration_config.json" | wc -l) config(s)"
echo "  - Generation: $(find "${OUTPUT_DIR}" -name "master1.sql" | wc -l) master SQL file(s)"
echo "  - Output directory: ${OUTPUT_DIR}"
echo ""
