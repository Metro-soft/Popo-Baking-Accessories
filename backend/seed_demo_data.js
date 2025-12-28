const db = require('./src/config/db');

async function seedDemoData() {
    const client = await db.pool.connect();
    try {
        console.log('🌱 Starting Demo Data Seed...');
        await client.query('BEGIN');

        // 1. Clear existing data (optional, but good for clean slate testing)
        // Be careful with CASCADE in production!
        console.log('🧹 Clearing old data...');
        await client.query('TRUNCATE TABLE order_items, payments, orders, inventory_batches, purchase_po_items, purchase_orders, customers, products, suppliers CASCADE');

        // 2. Suppliers
        console.log('🚚 Seeding Suppliers...');
        const suppliers = await client.query(`
      INSERT INTO suppliers (name, contact_person, phone, email) VALUES 
      ('Kenafric Industries', 'John Kamau', '0711000000', 'sales@kenafric.co.ke'),
      ('Top Serve Ltd', 'Mary Wanjiku', '0722000000', 'orders@topserve.co.ke'),
      ('Alibhai Shariff', 'Ahmed', '0733000000', 'info@alibhai.com')
      RETURNING id, name
    `);
        const s1 = suppliers.rows[0].id;
        const s2 = suppliers.rows[1].id;

        // 3. Products
        console.log('🎂 Seeding Products...');
        // Retail
        const p1 = await client.query(`INSERT INTO products (name, sku, type, base_selling_price, reorder_level) VALUES ('Cake Box 10x10', 'BOX-1010', 'retail', 50.00, 100) RETURNING id`);
        const p2 = await client.query(`INSERT INTO products (name, sku, type, base_selling_price, reorder_level) VALUES ('Whipping Cream 1L', 'ING-CR-1L', 'retail', 450.00, 20) RETURNING id`);

        // Rental
        const p3 = await client.query(`INSERT INTO products (name, sku, type, base_selling_price, rental_deposit) VALUES ('Gold Cake Stand', 'RNT-STD-GLD', 'asset_rental', 500.00, 1500.00) RETURNING id`);
        const p4 = await client.query(`INSERT INTO products (name, sku, type, base_selling_price, rental_deposit) VALUES ('Wedding Arch', 'RNT-ARC-001', 'asset_rental', 2500.00, 5000.00) RETURNING id`);

        // Service
        const p5 = await client.query(`INSERT INTO products (name, sku, type, base_selling_price) VALUES ('Edible Print A4', 'SVC-PRT-A4', 'service_print', 350.00) RETURNING id`);

        // Raw Material (for Prints)
        const p6 = await client.query(`INSERT INTO products (name, sku, type, base_selling_price) VALUES ('Edible Paper Sheet', 'MAT-EDIBLE-A4', 'raw_material', 0.00) RETURNING id`);

        // 4. Initial Inventory (Landed Cost Logic Simulation)
        console.log('📦 Seeding Inventory (Batches)...');
        // We simulate a received PO
        const po = await client.query(`INSERT INTO purchase_orders (supplier_id, total_product_value, transport_cost, packaging_cost) VALUES ($1, 10000, 500, 0) RETURNING id`, [s1]);

        // Add stock
        await client.query(`INSERT INTO inventory_batches (product_id, quantity_received, quantity_remaining, buying_price, landed_cost, supplier_id, po_id) VALUES 
      ($1, 500, 500, 30.00, 32.50, $2, $3),
      ($4, 50, 50, 300.00, 310.00, $2, $3),
      ($5, 100, 100, 50.00, 55.00, $2, $3)
    `, [p1.rows[0].id, s1, po.rows[0].id, p2.rows[0].id, p6.rows[0].id]); // Stocking Boxes, Cream, and Paper

        // 5. Customers (Credit Logic)
        console.log('👥 Seeding Customers...');
        await client.query(`INSERT INTO customers (name, phone, credit_limit, current_debt) VALUES 
      ('Mama Njoro (Good)', '0712345678', 10000.00, 0.00),
      ('Bakery A (Limit Reached)', '0787654321', 5000.00, 4800.00),
      ('Unknown Walk-in', '0700000000', 0.00, 0.00)
    `);

        // 6. Security (Cash Drawer)
        console.log('🔒 Seeding Active Shift...');
        // Ensure we have a user first (if relying on seed_users.js or init_db.js, let's assume user id 1 exists or create dummy)
        // Check for user
        let userId = 1;
        const userCheck = await client.query('SELECT id FROM users LIMIT 1');
        if (userCheck.rows.length === 0) {
            const newUser = await client.query(`INSERT INTO users (username, password_hash, role) VALUES ('admin', 'dummy_hash', 'admin') RETURNING id`);
            userId = newUser.rows[0].id;
        } else {
            userId = userCheck.rows[0].id;
        }

        // Open a drawer
        // Close any open ones first
        await client.query(`UPDATE cash_drawers SET status='closed', closing_time=NOW() WHERE status='open'`);
        await client.query(`INSERT INTO cash_drawers (user_id, starting_cash, status) VALUES ($1, 2000.00, 'open')`, [userId]);

        await client.query('COMMIT');
        console.log('✅ Demo Data Seeded Successfully!');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('❌ Seeding Failed:', err);
    } finally {
        client.release();
        process.exit();
    }
}

seedDemoData();
