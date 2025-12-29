-- Fix FK on inventory_batches to point to locations instead of branches

-- 1. Drop old constraint
ALTER TABLE inventory_batches DROP CONSTRAINT IF EXISTS inventory_batches_branch_id_fkey;

-- 2. Add new constraint referencing locations
ALTER TABLE inventory_batches 
    ADD CONSTRAINT inventory_batches_branch_id_fkey 
    FOREIGN KEY (branch_id) REFERENCES locations(id);
