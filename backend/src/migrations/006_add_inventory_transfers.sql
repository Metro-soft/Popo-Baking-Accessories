-- Inventory Transfers Table
CREATE TABLE IF NOT EXISTS inventory_transfers (
    id SERIAL PRIMARY KEY,
    reference_no VARCHAR(50) UNIQUE,
    from_branch_id INTEGER REFERENCES branches(id),
    to_branch_id INTEGER REFERENCES branches(id),
    status VARCHAR(20) DEFAULT 'pending', -- pending, completed, cancelled
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    notes TEXT
);

-- Transfer Items
CREATE TABLE IF NOT EXISTS inventory_transfer_items (
    id SERIAL PRIMARY KEY,
    transfer_id INTEGER REFERENCES inventory_transfers(id),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    subtotal DECIMAL(10,2) -- Optional cost tracking
);
