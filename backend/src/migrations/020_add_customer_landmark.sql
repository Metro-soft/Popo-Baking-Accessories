-- 20. Add Delivery Landmark to Customers
ALTER TABLE customers
ADD COLUMN IF NOT EXISTS delivery_landmark VARCHAR(255);

-- Optional: Add index if we plan to search by it (unlikely for now)
-- CREATE INDEX idx_customers_landmark ON customers(delivery_landmark);
