const db = require('./src/config/db');

async function updateSchemaPhase4() {
    const client = await db.pool.connect();
    try {
        console.log('Applying Phase 4 Schema Updates (Customers & Credit)...');
        await client.query('BEGIN');

        const queries = [
            `DROP TABLE IF EXISTS customers CASCADE`,

            `CREATE TABLE customers (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        phone VARCHAR(20) UNIQUE,
        current_debt DECIMAL(10, 2) DEFAULT 0.00,
        credit_limit DECIMAL(10, 2) DEFAULT 5000.00,
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )`,

            // Seed a sample customer
            `INSERT INTO customers (name, phone, current_debt, credit_limit) 
       VALUES ('Mama Njoroge', '0700000001', 1000.00, 5000.00)`
        ];

        for (const q of queries) {
            await client.query(q);
        }

        await client.query('COMMIT');
        console.log('✅ Phase 4 Tables Created Successfully!');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('❌ Update Failed:', err);
    } finally {
        client.release();
        process.exit();
    }
}

updateSchemaPhase4();
