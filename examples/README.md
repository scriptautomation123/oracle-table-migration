# Examples Directory

This directory contains sample configurations and generated outputs to help you understand how to use the Oracle table migration tool.

## Directory Structure

- `configs/` - Sample configuration files
- `generated/` - Example generated migration scripts (for reference)

## Sample Configurations

### migration_config.json
Basic migration configuration for a partitioned table.

### schema_discovery_config.json  
Configuration for automatic schema discovery.

## Generated Examples

The `generated/` directory contains sample outputs showing what the tool produces for various table configurations. These are provided as examples only - your actual output will be placed in the `output/` directory (not tracked by git).

## Usage

1. Copy a sample config from `configs/` to the project root
2. Modify it for your specific table
3. Run: `python src/generate.py --config your_config.json`
4. Review generated scripts in `output/` directory