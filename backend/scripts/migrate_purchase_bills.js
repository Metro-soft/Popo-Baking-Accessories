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
        console.log('Starting Purchase Bills Migration...');
        await client.query('BEGIN');

        // 1. Alter purchase_orders table
        console.log('Altering purchase_orders...');
        await client.query(`
      ALTER TABLE purchase_orders 
      ADD COLUMN IF NOT EXISTS bill_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      ADD COLUMN IF NOT EXISTS due_date TIMESTAMP,
      ADD COLUMN IF NOT EXISTS total_paid NUMERIC(15, 2) DEFAULT 0.00,
      ADD COLUMN IF NOT EXISTS payment_status VARCHAR(50) DEFAULT 'unpaid',
      ADD COLUMN IF NOT EXISTS reference_no VARCHAR(100)
    `);

        // 2. Create supplier_payments table
        console.log('Creating supplier_payments table...');
        await client.query(`
      CREATE TABLE IF NOT EXISTS supplier_payments (
        id SERIAL PRIMARY KEY,
        po_id INTEGER REFERENCES purchase_orders(id),
        amount NUMERIC(15, 2) NOT NULL,
        paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        method VARCHAR(50),
        reference VARCHAR(100),
        notes TEXT,
        created_by INTEGER REFERENCES users(id)
      )
    `);

        await client.query('COMMIT');
        console.log('Purchase Bills Migration Successful!');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Migration failed:', err);
    } finally {
        client.release();
        pool.end();
    }
}

migrate();
