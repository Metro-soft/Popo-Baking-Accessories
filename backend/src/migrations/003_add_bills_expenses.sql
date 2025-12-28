-- Expenses Table
CREATE TABLE IF NOT EXISTS expenses (
    id SERIAL PRIMARY KEY,
    branch_id INT REFERENCES branches(id),
    category VARCHAR(100), -- e.g. Rent, Salaries, Electricity
    amount DECIMAL(10, 2) NOT NULL,
    description TEXT,
    expense_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Bills Table (Payables)
CREATE TABLE IF NOT EXISTS bills (
    id SERIAL PRIMARY KEY,
    branch_id INT REFERENCES branches(id),
    vendor_name VARCHAR(255),
    amount DECIMAL(10, 2) NOT NULL,
    due_date DATE,
    status VARCHAR(50) DEFAULT 'pending', -- pending, paid, overdue
    type VARCHAR(50), -- purchase_order, utility, subscription
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed some dummy data for dashboard visualization
INSERT INTO expenses (branch_id, category, amount, description, expense_date)
VALUES 
(1, 'Electricity', 2500.00, 'KPLC Token', CURRENT_DATE),
(1, 'Transport', 500.00, 'Staff Fare', CURRENT_DATE);

INSERT INTO bills (branch_id, vendor_name, amount, due_date, status, type)
VALUES 
(1, 'Packaging Supplies Ltd', 15000.00, CURRENT_DATE + INTERVAL '5 days', 'pending', 'purchase_order'),
(1, 'Internet Provider', 3000.00, CURRENT_DATE + INTERVAL '2 days', 'pending', 'utility');
