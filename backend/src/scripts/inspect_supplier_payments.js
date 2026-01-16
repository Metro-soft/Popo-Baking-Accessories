const db = require('../config/db');

(async () => {
    try {
        console.log('\n--- Supplier Payments ---');
        const payments = await db.query(`
            SELECT * FROM supplier_payments ORDER BY id DESC LIMIT 10
        `);
        console.table(payments.rows);

        console.log('\n--- Purchase Orders (Paid/Partial) ---');
        const pos = await db.query(`
            SELECT id, supplier_id, total_paid, payment_status 
            FROM purchase_orders 
            WHERE payment_status != 'unpaid'
            ORDER BY id DESC LIMIT 5
        `);
        console.table(pos.rows);

        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
})();
