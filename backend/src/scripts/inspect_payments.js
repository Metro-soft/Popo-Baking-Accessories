const db = require('../config/db');

(async () => {
    try {
        console.log('--- Orders (Completed, with Customer) ---');
        const orders = await db.query(`
            SELECT id, customer_id, total_amount, status, created_at 
            FROM orders 
            WHERE customer_id IS NOT NULL AND status = 'completed'
            ORDER BY id DESC LIMIT 5
        `);
        console.table(orders.rows);

        console.log('\n--- Customer Payments ---');
        // Check if table exists first/schema might differ
        try {
            const payments = await db.query(`
                SELECT * FROM customer_payments ORDER BY id DESC LIMIT 5
            `);
            console.table(payments.rows);
        } catch (e) {
            console.log('Error reading customer_payments:', e.message);
        }

        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
})();
