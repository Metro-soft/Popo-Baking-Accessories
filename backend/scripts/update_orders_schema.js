const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: 5432,
});

async function migrate() {
    const client = await pool.connect();
    try {
        console.log('Starting migration...');
        console.log(`Connected to database: ${process.env.DB_NAME}`);
        await client.query('BEGIN');

        const columns = [
            'updated_at TIMESTAMP DEFAULT NOW()',
            'total_deposit NUMERIC(10, 2) DEFAULT 0',
            'discount_amount NUMERIC(10, 2) DEFAULT 0',
            'discount_reason TEXT',
            'is_hold BOOLEAN DEFAULT FALSE',
            'tax_amount NUMERIC(10, 2) DEFAULT 0',
            'dispatch_status VARCHAR(50)',
            'delivery_details JSONB'
        ];

        for (const col of columns) {
            const colName = col.split(' ')[0];
            console.log(`Checking ${colName}...`);
            await client.query(`
        ALTER TABLE orders 
        ADD COLUMN IF NOT EXISTS ${col};
      `);
        }

        await client.query('COMMIT');
        console.log('Migration successful!');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Migration failed:', err);
    } finally {
        client.release();
        pool.end();
    }
}

migrate();
