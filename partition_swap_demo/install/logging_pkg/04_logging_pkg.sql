-- ============================================================================
-- Logging Package Specification
-- ============================================================================
-- Purpose: Centralized logging with autonomous transactions
-- Usage: Call from any package/procedure for audit trail
-- Version: 1.0
-- ============================================================================

CREATE OR REPLACE PACKAGE logging_pkg AS
    
    -- Log levels
    LEVEL_DEBUG CONSTANT VARCHAR2(10) := 'DEBUG';
    LEVEL_INFO  CONSTANT VARCHAR2(10) := 'INFO';
    LEVEL_WARN  CONSTANT VARCHAR2(10) := 'WARN';
    LEVEL_ERROR CONSTANT VARCHAR2(10) := 'ERROR';
    
    -- Main logging procedures
    PROCEDURE log_message(
        p_level          IN VARCHAR2,
        p_package_name   IN VARCHAR2,
        p_procedure_name IN VARCHAR2,
        p_message        IN VARCHAR2,
        p_error_code     IN NUMBER DEFAULT NULL,
        p_error_message  IN VARCHAR2 DEFAULT NULL
    );
    
    -- Convenience wrappers
    PROCEDURE info(
        p_package_name   IN VARCHAR2,
        p_procedure_name IN VARCHAR2,
        p_message        IN VARCHAR2
    );
    
    PROCEDURE error(
        p_package_name   IN VARCHAR2,
        p_procedure_name IN VARCHAR2,
        p_message        IN VARCHAR2,
        p_error_code     IN NUMBER DEFAULT SQLCODE,
        p_error_message  IN VARCHAR2 DEFAULT SQLERRM
    );
    
    -- Cleanup old logs
    PROCEDURE purge_old_logs(
        p_retention_days IN NUMBER DEFAULT 90
    );
    
END logging_pkg;
/

CREATE OR REPLACE PACKAGE BODY logging_pkg AS
    
    -- ========================================================================
    -- Main logging procedure with autonomous transaction
    -- ========================================================================
    PROCEDURE log_message(
        p_level          IN VARCHAR2,
        p_package_name   IN VARCHAR2,
        p_procedure_name IN VARCHAR2,
        p_message        IN VARCHAR2,
        p_error_code     IN NUMBER DEFAULT NULL,
        p_error_message  IN VARCHAR2 DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO app_log (
            log_level,
            package_name,
            procedure_name,
            message,
            error_code,
            error_message
        ) VALUES (
            p_level,
            p_package_name,
            p_procedure_name,
            SUBSTR(p_message, 1, 4000),
            p_error_code,
            SUBSTR(p_error_message, 1, 4000)
        );
        
        COMMIT;  -- Autonomous transaction requires explicit commit
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Logging failure should not break application
            ROLLBACK;
    END log_message;
    
    -- ========================================================================
    -- Info level logging
    -- ========================================================================
    PROCEDURE info(
        p_package_name   IN VARCHAR2,
        p_procedure_name IN VARCHAR2,
        p_message        IN VARCHAR2
    ) IS
    BEGIN
        log_message(
            p_level          => LEVEL_INFO,
            p_package_name   => p_package_name,
            p_procedure_name => p_procedure_name,
            p_message        => p_message
        );
    END info;
    
    -- ========================================================================
    -- Error level logging
    -- ========================================================================
    PROCEDURE error(
        p_package_name   IN VARCHAR2,
        p_procedure_name IN VARCHAR2,
        p_message        IN VARCHAR2,
        p_error_code     IN NUMBER DEFAULT SQLCODE,
        p_error_message  IN VARCHAR2 DEFAULT SQLERRM
    ) IS
    BEGIN
        log_message(
            p_level          => LEVEL_ERROR,
            p_package_name   => p_package_name,
            p_procedure_name => p_procedure_name,
            p_message        => p_message,
            p_error_code     => p_error_code,
            p_error_message  => p_error_message
        );
    END error;
    
    -- ========================================================================
    -- Purge old logs (for scheduled maintenance)
    -- ========================================================================
    PROCEDURE purge_old_logs(
        p_retention_days IN NUMBER DEFAULT 90
    ) IS
        v_deleted_count NUMBER;
    BEGIN
        DELETE FROM app_log
        WHERE log_timestamp < SYSTIMESTAMP - INTERVAL '1' DAY * p_retention_days;
        
        v_deleted_count := SQL%ROWCOUNT;
        COMMIT;
        
        log_message(
            p_level          => LEVEL_INFO,
            p_package_name   => 'LOGGING_PKG',
            p_procedure_name => 'PURGE_OLD_LOGS',
            p_message        => 'Purged ' || v_deleted_count || ' old log entries'
        );
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END purge_old_logs;
    
END logging_pkg;
/
