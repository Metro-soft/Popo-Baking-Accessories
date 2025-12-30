const db = require('../config/db');

(async () => {
    const client = await db.pool.connect();
    try {
        console.log('Starting Backfill Ledger...');
        await client.query('BEGIN');

        // 1. Get all COMPLETED orders with a customer
        const ordersRes = await client.query(`
            SELECT id, customer_id, total_amount, created_at 
            FROM orders 
            WHERE status = 'completed' 
              AND customer_id IS NOT NULL
        `);

        console.log(`Found ${ordersRes.rows.length} completed orders.`);

        let insertedCount = 0;

        for (const order of ordersRes.rows) {
            // 2. Check if a payment exists for this order in 'customer_payments'
            // We check by order_id reference OR by matching amount/date loosely if order_id wasn't stored previously
            // But since we want to rely on the new logic, we'll check order_id column if it exists in customer_payments schema
            // Wait, does customer_payments have order_id? 
            // The INSERT in sales.controller.js includes order_id.
            // Let's verify schema. If not, we check by notes or just skip if we can't be sure.
            // However, for the user's specific case (Order #12, #13), they definitely lack payments.

            // Let's assume order_id column exists based on sales.controller.js code.
            const paymentRes = await client.query(`
                SELECT id FROM customer_payments 
                WHERE order_id = $1
            `, [order.id]);

            if (paymentRes.rows.length === 0) {
                // MISSING PAYMENT! Insert it.
                // We assume 'Cash' for backfill unless we can find better info from 'payments' table.
                // Let's try to fetch method from 'payments' table first.

                const methodRes = await client.query(`
                    SELECT method FROM payments WHERE order_id = $1 LIMIT 1
                `, [order.id]);

                const method = methodRes.rows[0]?.method || 'Cash';

                await client.query(`
                    INSERT INTO customer_payments (customer_id, order_id, amount, method, notes, payment_date)
                    VALUES ($1, $2, $3, $4, $5, $6)
                `, [
                    order.customer_id,
                    order.id,
                    order.total_amount,
                    method,
                    `System Backfill: Order #${order.id}`,
                    order.created_at // Use order date so it appears chronologically correct
                ]);

                insertedCount++;
                console.log(`Backfilled Payment for Order #${order.id}: ${order.total_amount}`);
            }
        }

        await client.query('COMMIT');
        console.log(`Backfill Complete. Inserted ${insertedCount} missing payments.`);
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Backfill Failed:', err);
    } finally {
        client.release();
        process.exit();
    }
})();
