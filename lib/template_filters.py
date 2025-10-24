#!/usr/bin/env python3
"""
Template Filters Module
======================
Custom Jinja2 filters for Oracle migration templates.
"""

def register_custom_filters(jinja_env):
    """Register custom Jinja2 filters"""
    
    @jinja_env.filter('upper')
    def upper_filter(value):
        """Convert value to uppercase"""
        return str(value).upper() if value else ''
    
    @jinja_env.filter('lower')
    def lower_filter(value):
        """Convert value to lowercase"""
        return str(value).lower() if value else ''
    
    @jinja_env.filter('quote')
    def quote_filter(value):
        """Quote a value for SQL"""
        if value is None:
            return 'NULL'
        return f"'{str(value)}'"
    
    @jinja_env.filter('comma_separated')
    def comma_separated_filter(value_list):
        """Convert list to comma-separated string"""
        if not value_list:
            return ''
        return ', '.join(str(item) for item in value_list)
    
    @jinja_env.filter('sql_identifier')
    def sql_identifier_filter(value):
        """Format as SQL identifier"""
        if not value:
            return ''
        return str(value).upper()