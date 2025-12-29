-- Cleanup inventory_batches table
-- 1. Drop the legacy 'location' column which is causing NOT NULL violations
ALTER TABLE inventory_batches DROP COLUMN IF EXISTS location;

-- 2. Ensure branch_id is robust
-- Set nulls to 1 (Head Office)
UPDATE inventory_batches SET branch_id = 1 WHERE branch_id IS NULL;

-- Enforce NOT NULL and Default 1
ALTER TABLE inventory_batches ALTER COLUMN branch_id SET DEFAULT 1;
ALTER TABLE inventory_batches ALTER COLUMN branch_id SET NOT NULL;
