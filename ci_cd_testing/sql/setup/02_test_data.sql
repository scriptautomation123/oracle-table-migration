-- Insert test data for Oracle database testing
-- This script populates the database with sample data

-- Insert test users
INSERT INTO users (username, email, first_name, last_name) VALUES ('john.doe', 'john.doe@example.com', 'John', 'Doe');
INSERT INTO users (username, email, first_name, last_name) VALUES ('jane.smith', 'jane.smith@example.com', 'Jane', 'Smith');
INSERT INTO users (username, email, first_name, last_name) VALUES ('bob.wilson', 'bob.wilson@example.com', 'Bob', 'Wilson');
INSERT INTO users (username, email, first_name, last_name) VALUES ('alice.brown', 'alice.brown@example.com', 'Alice', 'Brown');
INSERT INTO users (username, email, first_name, last_name) VALUES ('charlie.davis', 'charlie.davis@example.com', 'Charlie', 'Davis');

-- Insert test orders
INSERT INTO orders (user_id, order_number, total_amount, status) VALUES (1, 'ORD-001', 99.99, 'DELIVERED');
INSERT INTO orders (user_id, order_number, total_amount, status) VALUES (1, 'ORD-002', 149.50, 'SHIPPED');
INSERT INTO orders (user_id, order_number, total_amount, status) VALUES (2, 'ORD-003', 75.25, 'PROCESSING');
INSERT INTO orders (user_id, order_number, total_amount, status) VALUES (2, 'ORD-004', 200.00, 'PENDING');
INSERT INTO orders (user_id, order_number, total_amount, status) VALUES (3, 'ORD-005', 50.00, 'DELIVERED');
INSERT INTO orders (user_id, order_number, total_amount, status) VALUES (4, 'ORD-006', 300.75, 'SHIPPED');
INSERT INTO orders (user_id, order_number, total_amount, status) VALUES (5, 'ORD-007', 125.00, 'CANCELLED');

COMMIT;
