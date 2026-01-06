const db = require('../src/config/db');

async function testUpdate() {
    const client = await db.pool.connect();
    try {
        console.log('Testing UPDATE query on orders table...');
        // Try to update a dummy record ID 0 just to check if the query compiles/runs against schema
        await client.query(
            `UPDATE orders 
         SET total_amount = $1, total_deposit = $2, status = $3, discount_amount = $4, 
             discount_reason = $5, is_hold = $6, tax_amount = $7, dispatch_status = $8, delivery_details = $9, updated_at = NOW()
         WHERE id = $10`,
            [0, 0, 'completed', 0, 'test', false, 0, 'pending', {}, 0]
        );
        console.log('Update query executed successfully (0 rows expected)!');
    } catch (err) {
        console.error('Update query FAILED:', err);
    } finally {
        client.release();
        db.pool.end();
    }
}

testUpdate();
