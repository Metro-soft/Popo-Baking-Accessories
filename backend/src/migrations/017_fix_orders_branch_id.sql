-- Data Fix: Populate NULL branch_id in orders
UPDATE orders SET branch_id = 1 WHERE branch_id IS NULL;
