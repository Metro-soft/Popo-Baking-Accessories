-- Add discount columns to orders table
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(10, 2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS discount_reason TEXT,
ADD COLUMN IF NOT EXISTS is_hold BOOLEAN DEFAULT FALSE;

-- Add is_return to order_items for clarity
ALTER TABLE order_items
ADD COLUMN IF NOT EXISTS is_return BOOLEAN DEFAULT FALSE;
