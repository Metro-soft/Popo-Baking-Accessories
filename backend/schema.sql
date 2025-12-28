-- 1. ENUM TYPES (Defining the strict logic)
DROP TYPE IF EXISTS product_type CASCADE;
CREATE TYPE product_type AS ENUM ('retail', 'asset_rental', 'raw_material', 'service_print');

DROP TYPE IF EXISTS user_role CASCADE;
CREATE TYPE user_role AS ENUM ('admin', 'manager', 'cashier');

DROP TYPE IF EXISTS stock_location CASCADE;
CREATE TYPE stock_location AS ENUM ('thika_store', 'cbd_store', 'warehouse');

-- 2. USERS TABLE (Staff Management)
DROP TABLE IF EXISTS users CASCADE;
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    role user_role DEFAULT 'cashier',
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    daily_expense_limit DECIMAL(10, 2) DEFAULT 200.00, -- "Remote Control" limit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. PRODUCTS (The Catalogue - Source of Truth)
DROP TABLE IF EXISTS products CASCADE;
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    sku VARCHAR(50) UNIQUE NOT NULL, -- Barcode/Manual Code
    type product_type NOT NULL, -- Crucial: Dictates if it can be rented
    description TEXT,
    base_selling_price DECIMAL(10, 2) NOT NULL,
    rental_deposit_amount DECIMAL(10, 2) DEFAULT 0.00, -- Only for rentals
    reorder_level INT DEFAULT 10, -- Low stock alert trigger
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. INVENTORY BATCHES (The "True Cost" Engine)
DROP TABLE IF EXISTS inventory_batches CASCADE;
CREATE TABLE inventory_batches (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    batch_number VARCHAR(50), -- From Supplier Invoice
    location stock_location NOT NULL,
    quantity_initial INT NOT NULL,
    quantity_remaining INT NOT NULL,
    buying_price_unit DECIMAL(10, 2) NOT NULL, -- Calculated Landed Cost
    expiry_date DATE, -- For Cream/Chocolate
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. RENTAL ASSETS (Individual Tracking for Hires)
DROP TABLE IF EXISTS rental_assets CASCADE;
CREATE TABLE rental_assets (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    serial_number VARCHAR(50) UNIQUE NOT NULL, -- e.g., "GS-001"
    condition_notes TEXT DEFAULT 'New',
    status VARCHAR(20) DEFAULT 'available', -- available, rented, maintenance
    current_location stock_location DEFAULT 'thika_store'
);

-- 6. AUDIT LOGS (The "Zero Trust" Black Box)
DROP TABLE IF EXISTS audit_logs CASCADE;
CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    action VARCHAR(50) NOT NULL, -- e.g., "VOID_SALE", "UPDATE_PRICE"
    table_affected VARCHAR(50),
    record_id INT,
    old_value JSONB, -- Stores the data before change
    new_value JSONB, -- Stores the data after change
    ip_address VARCHAR(45),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. PHASE 2: SUPPLY CHAIN (Suppliers & POs)
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

-- 8. PHASE 3: SALES & ORDERS
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES users(id), -- For Debt tracking later (nullable)
    total_amount DECIMAL(10, 2) NOT NULL,
    total_deposit DECIMAL(10, 2) DEFAULT 0.00,
    status VARCHAR(20) DEFAULT 'completed',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id),
    product_id INT REFERENCES products(id),
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    type VARCHAR(20) NOT NULL, -- retail, asset_rental, service_print
    
    -- Rental Specifics
    rental_serial_number VARCHAR(50), 
    rental_deposit DECIMAL(10, 2) DEFAULT 0.00,
    rental_return_status VARCHAR(20) DEFAULT 'pending' -- pending, returned, forfeited
);

CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id),
    method VARCHAR(20) NOT NULL, -- cash, mpesa, credit
    amount DECIMAL(10, 2) NOT NULL,
    reference_code VARCHAR(100), -- M-Pesa Code
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
