const db = require('../../config/db');

async function up() {
    const client = await db.pool.connect();
    try {
        await client.query('BEGIN');

        console.log('Fixing orders foreign key...');

        // 1. Drop the incorrect constraint
        await client.query(`
            ALTER TABLE orders 
            DROP CONSTRAINT IF EXISTS orders_customer_id_fkey
        `);

        // 2. Add the correct constraint (referencing customers, NOT users)
        await client.query(`
            ALTER TABLE orders 
            ADD CONSTRAINT orders_customer_id_fkey 
            FOREIGN KEY (customer_id) 
            REFERENCES customers(id)
            ON DELETE SET NULL
        `);

        await client.query('COMMIT');
        console.log('Migration Corrected: orders.customer_id now references customers(id).');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Migration Failed:', err);
    } finally {
        client.release();
    }
}

up();
