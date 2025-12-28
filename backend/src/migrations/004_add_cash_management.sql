-- 1. Cash Shifts Table
CREATE TABLE IF NOT EXISTS cash_shifts (
    id SERIAL PRIMARY KEY,
    branch_id INT REFERENCES branches(id),
    user_id INT REFERENCES users(id), -- Who opened it
    opening_balance DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    closing_balance_system DECIMAL(10, 2), -- Calculated expected cash
    closing_balance_actual DECIMAL(10, 2), -- What they counted
    variance DECIMAL(10, 2), -- Difference
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    status VARCHAR(50) DEFAULT 'open', -- open, closed
    notes TEXT
);

-- 2. Cash Transactions (Petty Cash, Drops, Adjustments)
CREATE TABLE IF NOT EXISTS cash_transactions (
    id SERIAL PRIMARY KEY,
    branch_id INT REFERENCES branches(id),
    shift_id INT REFERENCES cash_shifts(id), -- Linked to specific shift
    user_id INT REFERENCES users(id),
    type VARCHAR(50) NOT NULL, -- 'deposit', 'withdrawal', 'expense'
    amount DECIMAL(10, 2) NOT NULL,
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Note: We link 'payments' to shifts implicitly by time or we could add shift_id to payments table?
-- For MVP, "Current Shift" is the one with status='open' for this branch/user.
-- We aggregate payments between start_time and NOW() for system calculation.
