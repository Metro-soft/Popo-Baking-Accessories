-- Fix FKs on inventory_transfers to point to locations instead of branches

-- 1. Drop old constraints
ALTER TABLE inventory_transfers DROP CONSTRAINT IF EXISTS inventory_transfers_from_branch_id_fkey;
ALTER TABLE inventory_transfers DROP CONSTRAINT IF EXISTS inventory_transfers_to_branch_id_fkey;

-- 2. Add new constraints referencing locations
ALTER TABLE inventory_transfers 
    ADD CONSTRAINT inventory_transfers_from_branch_id_fkey 
    FOREIGN KEY (from_branch_id) REFERENCES locations(id);

ALTER TABLE inventory_transfers 
    ADD CONSTRAINT inventory_transfers_to_branch_id_fkey 
    FOREIGN KEY (to_branch_id) REFERENCES locations(id);
