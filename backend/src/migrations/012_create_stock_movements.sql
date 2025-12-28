CREATE TABLE IF NOT EXISTS stock_movements (
  id SERIAL PRIMARY KEY,
  product_id INTEGER NOT NULL REFERENCES products(id),
  type VARCHAR(50) NOT NULL, -- 'sale', 'restock', 'adjustment', 'return'
  quantity DECIMAL(10, 2) NOT NULL,
  reason TEXT,
  reference_id INTEGER, -- Link to sale_id or batch_id if applicable
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_stock_movements_product ON stock_movements(product_id);
CREATE INDEX idx_stock_movements_created_at ON stock_movements(created_at);
