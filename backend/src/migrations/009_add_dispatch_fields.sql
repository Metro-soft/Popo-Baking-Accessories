-- Migration: Add Dispatch Fields to Orders Table
-- Description: Adds dispatch_status, delivery_method, and delivery_details to track logistics.

BEGIN;

-- 1. Add dispatch_status with default 'pending'
-- We assume 'pending' means "Waiting for Dispatch Action".
-- For Walk-ins, we might want to auto-set this to 'released' or null, but for now we stick to 3 states.
-- Let's use a CHECK constraint to enforce the 3 states + delivered/cancelled.
ALTER TABLE orders 
ADD COLUMN dispatch_status VARCHAR(20) DEFAULT 'pending',
ADD COLUMN delivery_method VARCHAR(50),
ADD COLUMN delivery_details JSONB;

-- 2. Add Constraint
ALTER TABLE orders
ADD CONSTRAINT check_dispatch_status 
CHECK (dispatch_status IN ('pending', 'processing', 'released', 'delivered', 'cancelled'));

-- 3. Update existing orders to 'released' (assuming past orders are done)
UPDATE orders SET dispatch_status = 'released' WHERE created_at < NOW();

COMMIT;
