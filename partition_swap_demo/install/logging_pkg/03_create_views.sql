-- ============================================================================
-- Logging Views
-- ============================================================================
-- Purpose: Convenience views for common queries
-- Version: 1.0
-- ============================================================================

-- Recent logs (last 24 hours)
CREATE OR REPLACE VIEW v_app_log_recent AS
SELECT 
    log_id,
    log_timestamp,
    log_level,
    package_name,
    procedure_name,
    message,
    error_code,
    username
FROM app_log
WHERE log_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY log_timestamp DESC;

-- Error logs only
CREATE OR REPLACE VIEW v_app_log_errors AS
SELECT 
    log_id,
    log_timestamp,
    package_name,
    procedure_name,
    message,
    error_code,
    error_message,
    username
FROM app_log
WHERE log_level = 'ERROR'
ORDER BY log_timestamp DESC;

-- Summary by package (last 7 days)
CREATE OR REPLACE VIEW v_app_log_summary AS
SELECT 
    package_name,
    log_level,
    COUNT(*) as log_count,
    MIN(log_timestamp) as first_logged,
    MAX(log_timestamp) as last_logged
FROM app_log
WHERE log_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
GROUP BY package_name, log_level
ORDER BY package_name, log_level;
