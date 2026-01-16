const db = require('../config/db');

(async () => {
    try {
        console.log('--- Fixing Missing Supplier IDs in Payments ---');

        // Update supplier_payments by joining with purchase_orders
        const result = await db.query(`
            UPDATE supplier_payments sp
            SET supplier_id = po.supplier_id
            FROM purchase_orders po
            WHERE sp.purchase_order_id = po.id 
              AND sp.supplier_id IS NULL
        `);

        console.log(`✅ Updated ${result.rowCount} payment records.`);
        process.exit(0);
    } catch (err) {
        console.error('❌ Error fixing payments:', err);
        process.exit(1);
    }
})();
