const pool = require('../../config/db');

const up = async () => {
    const client = await pool.pool.connect();
    try {
        await client.query('BEGIN');

        // 1. Create supplier_payments table
        await client.query(`
            CREATE TABLE IF NOT EXISTS supplier_payments (
                id SERIAL PRIMARY KEY,
                supplier_id INTEGER REFERENCES suppliers(id) ON DELETE CASCADE,
                purchase_order_id INTEGER REFERENCES purchase_orders(id) ON DELETE SET NULL,
                amount DECIMAL(10, 2) NOT NULL,
                payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                method VARCHAR(50), 
                reference VARCHAR(100),
                notes TEXT
            )
        `);
        console.log('✅ Created supplier_payments table');

        // 2. Add current_balance to suppliers if not exists (Money Owed TO Supplier)
        // Check if column exists first to be safe
        const res = await client.query(`
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name='suppliers' AND column_name='current_balance'
        `);

        if (res.rows.length === 0) {
            await client.query(`
                ALTER TABLE suppliers 
                ADD COLUMN current_balance DECIMAL(10, 2) DEFAULT 0
            `);
            console.log('✅ Added current_balance column to suppliers');
        } else {
            console.log('ℹ️ current_balance column already exists on suppliers');
        }

        await client.query('COMMIT');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('❌ Migration failed:', err);
    } finally {
        client.release();
    }
};

up().then(() => process.exit());
