-- 1. Create Branches Table
CREATE TABLE IF NOT EXISTS branches (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    location VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Insert Default Branch (Head Office) explicitly if not exists
INSERT INTO branches (name, location)
SELECT 'Head Office', 'Main Store'
WHERE NOT EXISTS (SELECT 1 FROM branches);

-- 3. Add branch_id to Users
ALTER TABLE users ADD COLUMN IF NOT EXISTS branch_id INTEGER REFERENCES branches(id);

-- 4. Add branch_id to Inventory Batches (replacing location string concept long-term, but keeping for now)
ALTER TABLE inventory_batches ADD COLUMN IF NOT EXISTS branch_id INTEGER REFERENCES branches(id);

-- 5. Add branch_id to Orders
ALTER TABLE orders ADD COLUMN IF NOT EXISTS branch_id INTEGER REFERENCES branches(id);

-- 6. Add branch_id to Cash Drawers
ALTER TABLE cash_drawers ADD COLUMN IF NOT EXISTS branch_id INTEGER REFERENCES branches(id);

-- 7. Backfill Data: Assign all existing orphaned records to the Default Branch (ID 1)
UPDATE users SET branch_id = 1 WHERE branch_id IS NULL;
UPDATE inventory_batches SET branch_id = 1 WHERE branch_id IS NULL;
UPDATE orders SET branch_id = 1 WHERE branch_id IS NULL;
UPDATE cash_drawers SET branch_id = 1 WHERE branch_id IS NULL;

-- 8. Enforce Not Null constraints now that backfill is done (Optional but recommended for strictness)
-- ALTER TABLE inventory_batches ALTER COLUMN branch_id SET NOT NULL;
-- ALTER TABLE orders ALTER COLUMN branch_id SET NOT NULL;
