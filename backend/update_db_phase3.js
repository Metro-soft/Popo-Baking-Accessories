const db = require('./src/config/db');

async function updateSchemaPhase3() {
    const client = await db.pool.connect();
    try {
        console.log('Applying Phase 3 Schema Updates (Orders & Payments)...');
        await client.query('BEGIN');

        const queries = [
            `DROP TABLE IF EXISTS payments CASCADE`,
            `DROP TABLE IF EXISTS order_items CASCADE`,
            `DROP TABLE IF EXISTS orders CASCADE`,

            `CREATE TABLE orders (
        id SERIAL PRIMARY KEY,
        customer_id INT REFERENCES users(id), 
        total_amount DECIMAL(10, 2) NOT NULL,
        total_deposit DECIMAL(10, 2) DEFAULT 0.00,
        status VARCHAR(20) DEFAULT 'completed',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )`,

            `CREATE TABLE order_items (
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
      )`,

            `CREATE TABLE payments (
        id SERIAL PRIMARY KEY,
        order_id INT REFERENCES orders(id),
        method VARCHAR(20) NOT NULL,
        amount DECIMAL(10, 2) NOT NULL,
        reference_code VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )`
        ];

        for (const q of queries) {
            await client.query(q);
        }

        await client.query('COMMIT');
        console.log('✅ Phase 3 Tables Created Successfully!');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('❌ Update Failed:', err);
    } finally {
        client.release();
        process.exit();
    }
}

updateSchemaPhase3();
