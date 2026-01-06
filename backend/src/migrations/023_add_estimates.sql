-- Migration: Add Estimates (Quotations) Support

-- 1. Estimates Table
CREATE TABLE IF NOT EXISTS estimates (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES users(id), -- Nullable for Guest/Walk-in Quotes, but recommended
    branch_id INT REFERENCES locations(id) DEFAULT 1,
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(20) DEFAULT 'pending', -- pending, accepted, rejected, converted
    valid_until DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Estimate Items
CREATE TABLE IF NOT EXISTS estimate_items (
    id SERIAL PRIMARY KEY,
    estimate_id INT REFERENCES estimates(id) ON DELETE CASCADE,
    product_id INT REFERENCES products(id),
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL, -- Price at the time of quote
    subtotal DECIMAL(10, 2) NOT NULL
);

-- 3. Index for performance
CREATE INDEX idx_estimates_branch ON estimates(branch_id);
CREATE INDEX idx_estimates_customer ON estimates(customer_id);
