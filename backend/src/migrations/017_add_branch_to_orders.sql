-- Migration: Add branch_id to orders
-- allowing sales reporting per branch

ALTER TABLE orders
ADD COLUMN branch_id INTEGER REFERENCES locations(id) DEFAULT 1;

-- Update existing records to default to 1
UPDATE orders SET branch_id = 1 WHERE branch_id IS NULL;
