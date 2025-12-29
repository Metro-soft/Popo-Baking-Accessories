-- Migration: Add branch_id to stock_movements
-- allowing filtering of history/timeline by branch

ALTER TABLE stock_movements
ADD COLUMN branch_id INTEGER REFERENCES locations(id) DEFAULT 1;

-- Update existing records to default to 1 (Main Warehouse) if null
UPDATE stock_movements SET branch_id = 1 WHERE branch_id IS NULL;
