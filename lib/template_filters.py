#!/usr/bin/env python3
"""
Template Filters Module
======================
Custom Jinja2 filters for Oracle migration templates.
"""


def register_custom_filters(jinja_env):
    """Register custom Jinja2 filters"""

    def upper_filter(value):
        """Convert value to uppercase"""
        return str(value).upper() if value else ""

    def lower_filter(value):
        """Convert value to lowercase"""
        return str(value).lower() if value else ""

    def quote_filter(value):
        """Quote a value for SQL"""
        if value is None:
            return "NULL"
        return f"'{str(value)}'"

    def comma_separated_filter(value_list):
        """Convert list to comma-separated string"""
        if not value_list:
            return ""
        return ", ".join(str(item) for item in value_list)

    def sql_identifier_filter(value):
        """Format as SQL identifier"""
        if not value:
            return ""
        return str(value).upper()

    def format_interval_filter(interval_type, interval_value=1):
        """Format interval for Oracle partitioning"""
        if interval_type.upper() == "HOUR":
            return f"INTERVAL '{interval_value}' HOUR"
        elif interval_type.upper() == "DAY":
            return f"INTERVAL '{interval_value}' DAY"
        elif interval_type.upper() == "WEEK":
            return f"INTERVAL '{interval_value * 7}' DAY"
        elif interval_type.upper() == "MONTH":
            return f"INTERVAL '{interval_value}' MONTH"
        else:
            return f"INTERVAL '{interval_value}' DAY"

    def estimate_time_filter(size_gb, operation_type="load"):
        """Estimate operation time based on table size"""
        if not size_gb or size_gb <= 0:
            return "< 1 minute"

        if operation_type == "load":
            # Estimate ~100MB/minute for data loading
            minutes = int(size_gb * 1024 / 100)
        elif operation_type == "index":
            # Estimate ~200MB/minute for index creation
            minutes = int(size_gb * 1024 / 200)
        else:
            # Default: general operation
            minutes = int(size_gb * 1024 / 150)

        if minutes < 1:
            return "< 1 minute"
        elif minutes < 60:
            return f"~{minutes} minutes"
        else:
            hours = minutes // 60
            remaining_minutes = minutes % 60
            if remaining_minutes == 0:
                return f"~{hours} hour{'s' if hours > 1 else ''}"
            else:
                return f"~{hours}h {remaining_minutes}m"

    def format_size_gb_filter(size_gb):
        """Format size in GB for display"""
        if not size_gb or size_gb <= 0:
            return "< 0.01 GB"
        elif size_gb < 1:
            return f"{size_gb:.2f} GB"
        else:
            return f"{size_gb:.1f} GB"

    def format_row_count_filter(row_count):
        """Format row count for display"""
        if not row_count or row_count <= 0:
            return "0 rows"
        elif row_count < 1000:
            return f"{row_count:,} rows"
        elif row_count < 1000000:
            return f"{row_count/1000:.1f}K rows"
        elif row_count < 1000000000:
            return f"{row_count/1000000:.1f}M rows"
        else:
            return f"{row_count/1000000000:.1f}B rows"

    def parallel_hint_filter(parallel_degree, operation_type="SELECT"):
        """Generate Oracle parallel hint"""
        if not parallel_degree or parallel_degree <= 1:
            return ""

        if operation_type.upper() == "INSERT":
            return f"/*+ PARALLEL({parallel_degree}) APPEND */"
        elif operation_type.upper() == "SELECT":
            return f"/*+ PARALLEL({parallel_degree}) */"
        elif operation_type.upper() == "CREATE":
            return f"/*+ PARALLEL({parallel_degree}) */"
        else:
            return f"/*+ PARALLEL({parallel_degree}) */"

    def match_condition_filter(columns, table_alias1="src", table_alias2="tgt"):
        """Generate SQL match condition for MERGE statements"""
        if not columns:
            return "1=1"

        if isinstance(columns, str):
            columns = [columns]

        conditions = []
        for col in columns:
            conditions.append(f"{table_alias1}.{col} = {table_alias2}.{col}")

        return " AND ".join(conditions)

    def format_column_list_filter(columns, prefix="", exclude_identity=False):
        """Format column list for SQL statements"""
        if not columns:
            return "*"

        if isinstance(columns, str):
            return columns

        # Handle list of column dictionaries
        column_names = []
        for col in columns:
            if isinstance(col, dict):
                # Skip identity columns if requested
                if exclude_identity and col.get("is_identity", False):
                    continue
                column_name = col.get("name", str(col))
            else:
                column_name = str(col)

            if prefix:
                column_names.append(f"{prefix}.{column_name}")
            else:
                column_names.append(column_name)

        return ", ".join(column_names) if column_names else "*"

    def yesno_filter(value, yes_text="YES", no_text="NO"):
        """Convert boolean value to YES/NO text"""
        if value is None:
            return no_text
        if isinstance(value, str):
            value = value.lower() in ("true", "yes", "1", "on", "enabled")
        return yes_text if value else no_text

    # Register filters with the environment
    jinja_env.filters["upper"] = upper_filter
    jinja_env.filters["lower"] = lower_filter
    jinja_env.filters["quote"] = quote_filter
    jinja_env.filters["comma_separated"] = comma_separated_filter
    jinja_env.filters["sql_identifier"] = sql_identifier_filter
    jinja_env.filters["format_interval"] = format_interval_filter
    jinja_env.filters["estimate_time"] = estimate_time_filter
    jinja_env.filters["format_size_gb"] = format_size_gb_filter
    jinja_env.filters["format_row_count"] = format_row_count_filter
    jinja_env.filters["parallel_hint"] = parallel_hint_filter
    jinja_env.filters["match_condition"] = match_condition_filter
    jinja_env.filters["format_column_list"] = format_column_list_filter
    jinja_env.filters["yesno"] = yesno_filter
