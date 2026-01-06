ALTER TABLE customer_payments ADD COLUMN IF NOT EXISTS branch_id INTEGER DEFAULT 1;
CREATE INDEX IF NOT EXISTS idx_payments_branch ON customer_payments(branch_id);
