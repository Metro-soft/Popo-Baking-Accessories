-- 1. Create Locations Table
CREATE TABLE IF NOT EXISTS locations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('warehouse', 'branch')), -- Mother vs Child
    address TEXT,
    contact_phone VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Seed Default Warehouse (if not exists)
-- We use ON CONFLICT to prevent errors if run multiple times
INSERT INTO locations (id, name, type, address) 
VALUES (1, 'Main Warehouse', 'warehouse', 'Head Office') 
ON CONFLICT (id) DO NOTHING;

-- Also handle name conflict just in case id 1 was deleted
INSERT INTO locations (name, type, address)
VALUES ('Main Warehouse', 'warehouse', 'Head Office')
ON CONFLICT (name) DO NOTHING;

-- 3. Update Inventory Batches to reference Locations (if not already done)
-- We check if the constraint exists first to avoid errors (PostgreSQL doesn't support IF NOT EXISTS on constraints easily, 
-- so we rely on the fact that if table was just created, it's fine. If it existed, we check columns).

-- Check if branch_id column exists (it might from previous manual changes or my assumptions)
-- If it doesn't exist, add it.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='inventory_batches' AND column_name='branch_id') THEN
        ALTER TABLE inventory_batches ADD COLUMN branch_id INT REFERENCES locations(id) DEFAULT 1;
    END IF;
END $$;
