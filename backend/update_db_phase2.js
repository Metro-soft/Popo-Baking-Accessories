const db = require('./src/config/db');

async function updateSchema() {
    const client = await db.pool.connect();
    try {
        console.log('Applying Phase 2 Schema Updates...');
        await client.query('BEGIN');

        const queries = [
            `DROP TABLE IF EXISTS po_items CASCADE`,
            `DROP TABLE IF EXISTS purchase_orders CASCADE`,
            `DROP TABLE IF EXISTS suppliers CASCADE`,

            `CREATE TABLE suppliers (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        contact_person VARCHAR(100),
        phone VARCHAR(20),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )`,

            `CREATE TABLE purchase_orders (
        id SERIAL PRIMARY KEY,
        supplier_id INT REFERENCES suppliers(id),
        status VARCHAR(20) DEFAULT 'received',
        total_product_cost DECIMAL(10, 2) NOT NULL,
        transport_cost DECIMAL(10, 2) DEFAULT 0.00,
        packaging_cost DECIMAL(10, 2) DEFAULT 0.00,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )`,

            `CREATE TABLE po_items (
        id SERIAL PRIMARY KEY,
        po_id INT REFERENCES purchase_orders(id),
        product_id INT REFERENCES products(id),
        quantity_received INT NOT NULL,
        supplier_unit_price DECIMAL(10, 2) NOT NULL
      )`,

            // Seed a default supplier
            `INSERT INTO suppliers (name, contact_person, phone) VALUES ('General Market', 'N/A', 'N/A')`
        ];

        for (const q of queries) {
            await client.query(q);
        }

        await client.query('COMMIT');
        console.log('✅ Phase 2 Tables Created Successfully!');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('❌ Update Failed:', err);
    } finally {
        client.release();
        process.exit();
    }
}

updateSchema();
