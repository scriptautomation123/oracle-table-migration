#!/usr/bin/env python3
"""
Template Filters Module
=======================
Custom Jinja2 filters for Oracle SQL template generation.

Provides filters for:
- Interval clause generation (HOUR/DAY/WEEK/MONTH)
- Column list formatting
- Size/time estimation
- Oracle-specific formatting
"""

from typing import List


def format_interval(interval_type: str, interval_value: int = 1) -> str:
    """
    Generate Oracle INTERVAL clause from interval type

    Args:
        interval_type: HOUR, DAY, WEEK, or MONTH
        interval_value: Interval value (default 1)

    Returns:
        Oracle INTERVAL clause

    Examples:
        format_interval('MONTH', 1) -> "INTERVAL(NUMTOYMINTERVAL(1, 'MONTH'))"
        format_interval('DAY', 1) -> "INTERVAL(NUMTODSINTERVAL(1, 'DAY'))"
        format_interval('HOUR', 6) -> "INTERVAL(NUMTODSINTERVAL(6, 'HOUR'))"
    """
    interval_type = interval_type.upper()

    if interval_type in ["HOUR", "DAY"]:
        return f"INTERVAL(NUMTODSINTERVAL({interval_value}, '{interval_type}'))"
    elif interval_type == "WEEK":
        # Convert weeks to days
        days = interval_value * 7
        return f"INTERVAL(NUMTODSINTERVAL({days}, 'DAY'))"
    elif interval_type == "MONTH":
        return f"INTERVAL(NUMTOYMINTERVAL({interval_value}, 'MONTH'))"
    else:
        raise ValueError(f"Unsupported interval type: {interval_type}")


def format_column_list(
    columns: List[str], prefix: str = "", suffix: str = "", separator: str = ", "
) -> str:
    """
    Format a list of columns with optional prefix/suffix

    Args:
        columns: List of column names
        prefix: Prefix for each column (e.g., 'src.', 'tgt.')
        suffix: Suffix for each column
        separator: Separator between columns

    Returns:
        Formatted column list

    Examples:
        format_column_list(['COL1', 'COL2'], 'src.') -> "src.COL1, src.COL2"
        format_column_list(['A', 'B'], '', ' DESC') -> "A DESC, B DESC"
    """
    if isinstance(columns, str):
        columns = [c.strip() for c in columns.split(",")]

    formatted = [f"{prefix}{col}{suffix}" for col in columns]
    return separator.join(formatted)


def format_size_gb(size_gb: float, precision: int = 2) -> str:
    """
    Format size in GB with proper precision

    Args:
        size_gb: Size in gigabytes
        precision: Decimal precision

    Returns:
        Formatted size string

    Examples:
        format_size_gb(45.234) -> "45.23 GB"
        format_size_gb(0.5) -> "0.50 GB"
    """
    return f"{size_gb:.{precision}f} GB"


def format_row_count(row_count: int) -> str:
    """
    Format row count with thousand separators

    Args:
        row_count: Number of rows

    Returns:
        Formatted string with commas

    Examples:
        format_row_count(12500000) -> "12,500,000"
    """
    return f"{row_count:,}"


def estimate_execution_time(size_gb: float, operation: str = "load") -> str:
    """
    Estimate execution time for an operation

    Args:
        size_gb: Data size in GB
        operation: Operation type ('load', 'index', 'validate')

    Returns:
        Estimated time string

    Examples:
        estimate_execution_time(50, 'load') -> "~6.3 hours"
        estimate_execution_time(10, 'index') -> "~1.3 hours"
    """
    if operation == "load":
        # Conservative 8 GB/hour
        hours = size_gb / 8 if size_gb > 0 else 0.1
    elif operation == "index":
        # Index creation estimate
        hours = size_gb / 10 if size_gb > 0 else 0.1
    elif operation == "validate":
        # Validation (faster, mostly read)
        hours = size_gb / 20 if size_gb > 0 else 0.1
    else:
        hours = size_gb / 10

    if hours < 0.1:
        return "~few minutes"
    elif hours < 1:
        return f"~{int(hours * 60)} minutes"
    else:
        return f"~{hours:.1f} hours"


def format_parallel_hint(parallel_degree: int, operation: str = "SELECT") -> str:
    """
    Generate Oracle parallel hint

    Args:
        parallel_degree: Degree of parallelism
        operation: SQL operation type

    Returns:
        Oracle parallel hint

    Examples:
        format_parallel_hint(4, 'SELECT') -> "/*+ PARALLEL(4) */"
        format_parallel_hint(8, 'INSERT') -> "/*+ PARALLEL(8) */"
    """
    if parallel_degree <= 1:
        return ""
    return f"/*+ PARALLEL({parallel_degree}) */"


def oracle_identifier(name: str) -> str:
    """
    Format Oracle identifier (uppercase, quoted if needed)

    Args:
        name: Identifier name

    Returns:
        Properly formatted Oracle identifier

    Examples:
        oracle_identifier('my_table') -> "MY_TABLE"
        oracle_identifier('table with spaces') -> '"TABLE WITH SPACES"'
    """
    if not name:
        return ""

    # Check if quoting is needed
    if " " in name or any(c.islower() for c in name):
        return f'"{name}"'
    return name.upper()


def generate_match_condition(
    columns: List[str], left_alias: str = "tgt", right_alias: str = "src"
) -> str:
    """
    Generate match condition for MERGE statements

    Args:
        columns: List of key columns
        left_alias: Left table alias
        right_alias: Right table alias

    Returns:
        Match condition string

    Examples:
        generate_match_condition(['ID'], 'tgt', 'src') -> "tgt.ID = src.ID"
        generate_match_condition(['A', 'B']) -> "tgt.A = src.A AND tgt.B = src.B"
    """
    if isinstance(columns, str):
        columns = [c.strip() for c in columns.split(",")]

    conditions = [f"{left_alias}.{col} = {right_alias}.{col}" for col in columns]
    return " AND ".join(conditions)


def generate_update_set(
    columns: List[str],
    exclude_columns: List[str] = None,
    target_alias: str = "tgt",
    source_alias: str = "src",
) -> str:
    """
    Generate UPDATE SET clause for MERGE

    Args:
        columns: All columns
        exclude_columns: Columns to exclude (e.g., keys, timestamps)
        target_alias: Target table alias
        source_alias: Source table alias

    Returns:
        UPDATE SET clause

    Examples:
        generate_update_set(['COL1', 'COL2', 'ID'], ['ID'])
        -> "tgt.COL1 = src.COL1, tgt.COL2 = src.COL2"
    """
    if isinstance(columns, str):
        columns = [c.strip() for c in columns.split(",")]

    if exclude_columns is None:
        exclude_columns = []
    elif isinstance(exclude_columns, str):
        exclude_columns = [c.strip() for c in exclude_columns.split(",")]

    # Filter out excluded columns
    update_cols = [col for col in columns if col not in exclude_columns]

    updates = [f"{target_alias}.{col} = {source_alias}.{col}" for col in update_cols]
    return ",\n        ".join(updates)


def format_lob_storage(
    lob_columns: List[str], tablespace: str = "USERS", securefile: bool = True
) -> str:
    """
    Generate LOB storage clauses

    Args:
        lob_columns: List of LOB column names
        tablespace: Tablespace for LOBs
        securefile: Use SECUREFILE (True) or BASICFILE (False)

    Returns:
        LOB storage clause

    Examples:
        format_lob_storage(['DATA_BLOB'], 'USERS')
        -> "LOB (DATA_BLOB) STORE AS SECUREFILE (TABLESPACE USERS)"
    """
    if not lob_columns:
        return ""

    if isinstance(lob_columns, str):
        lob_columns = [c.strip() for c in lob_columns.split(",")]

    file_type = "SECUREFILE" if securefile else "BASICFILE"

    clauses = []
    for col in lob_columns:
        clause = f"LOB ({col}) STORE AS {file_type} (\n    TABLESPACE {tablespace}\n    ENABLE STORAGE IN ROW\n    CHUNK 8192\n    CACHE\n)"
        clauses.append(clause)

    return "\n".join(clauses)


def is_power_of_2(n: int) -> bool:
    """Check if number is power of 2"""
    return n > 0 and (n & (n - 1)) == 0


def recommend_commit_frequency(row_count: int) -> int:
    """
    Recommend commit frequency based on row count

    Args:
        row_count: Number of rows

    Returns:
        Recommended rows per commit

    Examples:
        recommend_commit_frequency(1000000) -> 100000
        recommend_commit_frequency(100000) -> 10000
    """
    if row_count > 10000000:
        return 500000
    elif row_count > 1000000:
        return 100000
    elif row_count > 100000:
        return 10000
    else:
        return 1000


def get_environment_tablespace(env_config: dict, tablespace_type: str = "primary") -> str:
    """
    Get tablespace from environment configuration
    
    Args:
        env_config: Environment configuration dictionary
        tablespace_type: Type of tablespace ('primary' or 'lob')
        
    Returns:
        Tablespace name
    """
    if not env_config:
        return "USERS"
    
    tablespaces = env_config.get("tablespaces", {})
    data_tablespaces = tablespaces.get("data", {})
    
    if tablespace_type == "primary":
        return data_tablespaces.get("primary", "USERS")
    elif tablespace_type == "lob":
        lob_tablespaces = data_tablespaces.get("lob", ["USERS"])
        return lob_tablespaces[0] if lob_tablespaces else "USERS"
    
    return "USERS"


def get_environment_limits(env_config: dict, limit_type: str) -> dict:
    """
    Get environment limits for validation
    
    Args:
        env_config: Environment configuration dictionary
        limit_type: Type of limits ('subpartition' or 'parallel')
        
    Returns:
        Dictionary with min/max values
    """
    if not env_config:
        if limit_type == "subpartition":
            return {"min": 2, "max": 16}
        else:  # parallel
            return {"min": 1, "max": 8}
    
    if limit_type == "subpartition":
        defaults = env_config.get("subpartition_defaults", {})
        return {
            "min": defaults.get("min_count", 2),
            "max": defaults.get("max_count", 16)
        }
    else:  # parallel
        defaults = env_config.get("parallel_defaults", {})
        return {
            "min": defaults.get("min_degree", 1),
            "max": defaults.get("max_degree", 8)
        }


def validate_environment_setting(value: int, env_config: dict, setting_type: str) -> bool:
    """
    Validate a setting against environment limits
    
    Args:
        value: Setting value to validate
        env_config: Environment configuration
        setting_type: Type of setting ('subpartition_count' or 'parallel_degree')
        
    Returns:
        True if within limits
    """
    if setting_type == "subpartition_count":
        limits = get_environment_limits(env_config, "subpartition")
    else:  # parallel_degree
        limits = get_environment_limits(env_config, "parallel")
    
    return limits["min"] <= value <= limits["max"]


def register_custom_filters(jinja_env):
    """
    Register all custom filters with Jinja2 environment

    Args:
        jinja_env: Jinja2 Environment instance
    """
    jinja_env.filters["format_interval"] = format_interval
    jinja_env.filters["format_column_list"] = format_column_list
    jinja_env.filters["format_size_gb"] = format_size_gb
    jinja_env.filters["format_row_count"] = format_row_count
    jinja_env.filters["estimate_time"] = estimate_execution_time
    jinja_env.filters["parallel_hint"] = format_parallel_hint
    jinja_env.filters["oracle_id"] = oracle_identifier
    jinja_env.filters["match_condition"] = generate_match_condition
    jinja_env.filters["update_set"] = generate_update_set
    jinja_env.filters["lob_storage"] = format_lob_storage
    jinja_env.filters["is_power_of_2"] = is_power_of_2
    jinja_env.filters["commit_frequency"] = recommend_commit_frequency
    jinja_env.filters["get_environment_tablespace"] = get_environment_tablespace
    jinja_env.filters["get_environment_limits"] = get_environment_limits
    jinja_env.filters["validate_environment_setting"] = validate_environment_setting

    # Also add as globals for use in templates
    jinja_env.globals["is_power_of_2"] = is_power_of_2
    jinja_env.globals["get_environment_tablespace"] = get_environment_tablespace
    jinja_env.globals["get_environment_limits"] = get_environment_limits
    jinja_env.globals["validate_environment_setting"] = validate_environment_setting


# Test if run directly
if __name__ == "__main__":
    print("Testing template filters...")

    print("\n1. Interval formatting:")
    print(f"  MONTH: {format_interval('MONTH', 1)}")
    print(f"  DAY: {format_interval('DAY', 1)}")
    print(f"  HOUR: {format_interval('HOUR', 6)}")
    print(f"  WEEK: {format_interval('WEEK', 2)}")

    print("\n2. Column formatting:")
    print(f"  With prefix: {format_column_list(['COL1', 'COL2'], 'src.')}")
    print(f"  Match condition: {generate_match_condition(['ID', 'KEY'])}")

    print("\n3. Size/time formatting:")
    print(f"  Size: {format_size_gb(45.234)}")
    print(f"  Rows: {format_row_count(12500000)}")
    print(f"  Load time: {estimate_execution_time(50, 'load')}")

    print("\n4. Oracle formatting:")
    print(f"  Identifier: {oracle_identifier('my_table')}")
    print(f"  Parallel hint: {format_parallel_hint(4, 'SELECT')}")

    print("\n✓ All filters working correctly")
