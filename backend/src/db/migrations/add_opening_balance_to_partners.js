const { pool } = require('../../config/db');

const runMigration = async () => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        // Add opening_balance to customers
        await client.query(`
            ALTER TABLE customers 
            ADD COLUMN IF NOT EXISTS opening_balance DECIMAL(10, 2) DEFAULT 0;
        `);

        // Add opening_balance to suppliers
        await client.query(`
            ALTER TABLE suppliers 
            ADD COLUMN IF NOT EXISTS opening_balance DECIMAL(10, 2) DEFAULT 0;
        `);

        await client.query('COMMIT');
        console.log('Migration: Opening balance columns added successfully');
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Migration failed:', error);
    } finally {
        client.release();
    }
};

module.exports = runMigration;
