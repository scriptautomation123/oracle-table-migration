-- Cleanup script for Oracle database testing
-- This script removes all test data and objects

-- Disable foreign key constraints temporarily
ALTER TABLE orders DISABLE CONSTRAINT fk_orders_user;

-- Drop tables in correct order
DROP TABLE orders CASCADE CONSTRAINTS;
DROP TABLE users CASCADE CONSTRAINTS;

-- Drop triggers
DROP TRIGGER tr_users_updated_at;
DROP TRIGGER tr_orders_updated_at;

-- Purge recyclebin to ensure complete cleanup
PURGE RECYCLEBIN;

-- Show cleanup completion
SELECT 'Cleanup completed successfully' as status FROM DUAL;
