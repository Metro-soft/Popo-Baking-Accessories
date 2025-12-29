-- Add missing fields to suppliers table
ALTER TABLE suppliers
ADD COLUMN IF NOT EXISTS email VARCHAR(255),
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS tax_id VARCHAR(50); -- KRA PIN

-- Add index for search
CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name);
