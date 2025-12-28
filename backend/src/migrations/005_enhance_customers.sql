-- 1. Enhance Customers Table
ALTER TABLE customers 
ADD COLUMN IF NOT EXISTS email VARCHAR(255),
ADD COLUMN IF NOT EXISTS phone VARCHAR(50),
ADD COLUMN IF NOT EXISTS loyalty_points INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS credit_limit DECIMAL(10, 2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS current_balance DECIMAL(10, 2) DEFAULT 0.00;

-- 2. Add Unique Constraints (Optional but good for E-commerce sync)
ALTER TABLE customers ADD CONSTRAINT unique_email UNIQUE (email);
ALTER TABLE customers ADD CONSTRAINT unique_phone UNIQUE (phone);

-- 3. Create Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
