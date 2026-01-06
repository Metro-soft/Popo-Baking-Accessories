ALTER TABLE products ADD COLUMN is_active BOOLEAN DEFAULT TRUE;

-- Update existing records to be active
UPDATE products SET is_active = TRUE;
