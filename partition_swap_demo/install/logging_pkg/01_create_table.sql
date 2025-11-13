-- ============================================================================
-- Logging Table
-- ============================================================================
-- Purpose: Store application logs with autonomous transaction support
-- Version: 1.0
-- ============================================================================

CREATE TABLE app_log (
    log_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    log_timestamp   TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    log_level       VARCHAR2(10) NOT NULL,
    package_name    VARCHAR2(128),
    procedure_name  VARCHAR2(128),
    message         VARCHAR2(4000) NOT NULL,
    error_code      NUMBER,
    error_message   VARCHAR2(4000),
    session_id      NUMBER DEFAULT SYS_CONTEXT('USERENV', 'SESSIONID'),
    username        VARCHAR2(128) DEFAULT USER,
    CONSTRAINT chk_log_level CHECK (log_level IN ('DEBUG', 'INFO', 'WARN', 'ERROR'))
);
