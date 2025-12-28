-- Backfill Restocks from Inventory Batches
INSERT INTO stock_movements (product_id, type, quantity, reason, reference_id, created_at)
SELECT 
    product_id, 
    'restock', 
    quantity_initial, 
    'Initial Batch', 
    id, 
    received_at
FROM inventory_batches
WHERE id NOT IN (SELECT reference_id FROM stock_movements WHERE type = 'restock');

-- Backfill Sales from Order Items
insert into stock_movements (product_id, type, quantity, reason, reference_id, created_at)
select 
    oi.product_id,
    'sale',
    -oi.quantity, -- Negative for sales
    'Backfilled Sale',
    oi.order_id,
    o.created_at
from order_items oi
join orders o on oi.order_id = o.id
where oi.type = 'retail' 
  and oi.order_id NOT IN (SELECT reference_id FROM stock_movements WHERE type = 'sale');
