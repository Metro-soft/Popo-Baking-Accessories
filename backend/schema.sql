-- 1. ENUM TYPES (Defining the strict logic)
DROP TYPE IF EXISTS product_type CASCADE;
CREATE TYPE product_type AS ENUM ('retail', 'asset_rental', 'raw_material', 'service_print');

DROP TYPE IF EXISTS user_role CASCADE;
CREATE TYPE user_role AS ENUM ('admin', 'manager', 'cashier');

-- [REMOVED] stock_location ENUM (Replaced by dynamic locations table)

-- 2. LOCATIONS (Multi-Branch & Warehouse Support)
DROP TABLE IF EXISTS locations CASCADE;
CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('warehouse', 'branch')), -- Mother vs Child
    address TEXT,
    contact_phone VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed Default Data (Reference only)
-- INSERT INTO locations (name, type) VALUES ('Main Warehouse', 'warehouse');

-- 3. USERS TABLE (Staff Management)
DROP TABLE IF EXISTS users CASCADE;
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    role user_role DEFAULT 'cashier',
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    daily_expense_limit DECIMAL(10, 2) DEFAULT 200.00,
    branch_id INT REFERENCES locations(id) DEFAULT 1, -- [NEW] User assigned to a branch
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. PRODUCTS (The Catalogue - Source of Truth)
DROP TABLE IF EXISTS products CASCADE;
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    sku VARCHAR(50) UNIQUE NOT NULL,
    type product_type NOT NULL,
    description TEXT,
    base_selling_price DECIMAL(10, 2) NOT NULL,
    rental_deposit_amount DECIMAL(10, 2) DEFAULT 0.00,
    reorder_level INT DEFAULT 10,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. INVENTORY BATCHES (The "True Cost" Engine)
DROP TABLE IF EXISTS inventory_batches CASCADE;
CREATE TABLE inventory_batches (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    batch_number VARCHAR(50),
    branch_id INT REFERENCES locations(id) DEFAULT 1, -- [UPDATED] Replaces location ENUM
    quantity_initial INT NOT NULL,
    quantity_remaining INT NOT NULL,
    buying_price_unit DECIMAL(10, 2) NOT NULL,
    expiry_date DATE,
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. RENTAL ASSETS (Individual Tracking for Hires)
DROP TABLE IF EXISTS rental_assets CASCADE;
CREATE TABLE rental_assets (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    serial_number VARCHAR(50) UNIQUE NOT NULL,
    condition_notes TEXT DEFAULT 'New',
    status VARCHAR(20) DEFAULT 'available',
    current_location_id INT REFERENCES locations(id) DEFAULT 1 -- [UPDATED] Replaces location ENUM
);

-- 7. AUDIT LOGS
DROP TABLE IF EXISTS audit_logs CASCADE;
CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    action VARCHAR(50) NOT NULL,
    table_affected VARCHAR(50),
    record_id INT,
    old_value JSONB,
    new_value JSONB,
    ip_address VARCHAR(45),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. SUPPLY CHAIN (Suppliers & POs)
DROP TABLE IF EXISTS po_items CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;

CREATE TABLE suppliers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    contact_person VARCHAR(100),
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE purchase_orders (
    id SERIAL PRIMARY KEY,
    supplier_id INT REFERENCES suppliers(id),
    status VARCHAR(20) DEFAULT 'received',
    total_product_cost DECIMAL(10, 2) NOT NULL,
    transport_cost DECIMAL(10, 2) DEFAULT 0.00,
    packaging_cost DECIMAL(10, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE po_items (
    id SERIAL PRIMARY KEY,
    po_id INT REFERENCES purchase_orders(id),
    product_id INT REFERENCES products(id),
    quantity_received INT NOT NULL,
    supplier_unit_price DECIMAL(10, 2) NOT NULL
);

-- 9. SALES & ORDERS
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES users(id),
    total_amount DECIMAL(10, 2) NOT NULL,
    total_deposit DECIMAL(10, 2) DEFAULT 0.00,
    status VARCHAR(20) DEFAULT 'completed',
    branch_id INT REFERENCES locations(id), -- [NEW] Sales per branch
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id),
    product_id INT REFERENCES products(id),
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    type VARCHAR(20) NOT NULL,
    rental_serial_number VARCHAR(50), 
    rental_deposit DECIMAL(10, 2) DEFAULT 0.00,
    rental_return_status VARCHAR(20) DEFAULT 'pending'
);

CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id),
    method VARCHAR(20) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    reference_code VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 10. STOCK MOVEMENTS (History)
DROP TABLE IF EXISTS stock_movements CASCADE;
CREATE TABLE stock_movements (
    id BIGSERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    branch_id INT REFERENCES locations(id), -- [NEW] Movement per branch
    type VARCHAR(20) NOT NULL, -- sale, return, adjustment, transfer_in, transfer_out
    quantity INT NOT NULL, -- Positive or Negative
    reason TEXT,
    reference_id INT, -- Order ID or Transfer ID
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
