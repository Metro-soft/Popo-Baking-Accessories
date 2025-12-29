-- Add branch_id to users table
ALTER TABLE users 
ADD COLUMN branch_id INTEGER REFERENCES locations(id) DEFAULT 1;

-- Update existing users to have branch_id = 1 (Main Warehouse) just in case default didn't catch prior rows (Postgres usually handles it, but explicit is safe)
UPDATE users SET branch_id = 1 WHERE branch_id IS NULL;
