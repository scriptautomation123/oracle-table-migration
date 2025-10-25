-- Insert test data for Oracle database testing
-- This script populates the database with sample data

-- Insert test users
INSERT INTO users (username, email, first_name, last_name) VALUES 
('john.doe', 'john.doe@example.com', 'John', 'Doe'),
('jane.smith', 'jane.smith@example.com', 'Jane', 'Smith'),
('bob.wilson', 'bob.wilson@example.com', 'Bob', 'Wilson'),
('alice.brown', 'alice.brown@example.com', 'Alice', 'Brown'),
('charlie.davis', 'charlie.davis@example.com', 'Charlie', 'Davis');

-- Insert test orders
INSERT INTO orders (user_id, order_number, total_amount, status) VALUES 
(1, 'ORD-001', 99.99, 'DELIVERED'),
(1, 'ORD-002', 149.50, 'SHIPPED'),
(2, 'ORD-003', 75.25, 'PROCESSING'),
(2, 'ORD-004', 200.00, 'PENDING'),
(3, 'ORD-005', 50.00, 'DELIVERED'),
(4, 'ORD-006', 300.75, 'SHIPPED'),
(5, 'ORD-007', 125.00, 'CANCELLED');

COMMIT;
