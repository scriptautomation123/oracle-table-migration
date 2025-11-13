-- ============================================================================
-- Logging Table Indexes
-- ============================================================================
-- Purpose: Optimize common query patterns
-- Version: 1.0
-- ============================================================================

-- Query by timestamp (most recent first)
CREATE INDEX idx_app_log_timestamp ON app_log(log_timestamp DESC);

-- Query by level and timestamp
CREATE INDEX idx_app_log_level ON app_log(log_level, log_timestamp DESC);

-- Query by package and timestamp
CREATE INDEX idx_app_log_package ON app_log(package_name, log_timestamp DESC);
