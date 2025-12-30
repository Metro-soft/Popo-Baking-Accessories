const db = require('../../config/db');

async function up() {
    const client = await db.pool.connect();
    try {
        await client.query('BEGIN');

        // Add points column (Default 0)
        await client.query(`
            ALTER TABLE customers 
            ADD COLUMN IF NOT EXISTS points INTEGER DEFAULT 0
        `);

        await client.query('COMMIT');
        console.log('Migration: Added points column to customers table.');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Migration Failed:', err);
    } finally {
        client.release();
    }
}

up();
