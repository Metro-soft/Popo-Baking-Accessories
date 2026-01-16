const db = require('../config/db');

(async () => {
    try {
        console.log('--- Wiping Purchase Module Data ---');

        const client = await db.pool.connect();
        try {
            await client.query('BEGIN');

            console.log('Deleting supplier_payments...');
            await client.query('DELETE FROM supplier_payments');

            // Determine correct items table
            const res = await client.query(`
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema='public' 
                  AND table_name IN ('po_items', 'purchase_order_items')
            `);

            for (const row of res.rows) {
                console.log(`Deleting ${row.table_name}...`);
                await client.query(`DELETE FROM "${row.table_name}"`);
            }

            console.log('Deleting stock_movements (restock)...');
            await client.query("DELETE FROM stock_movements WHERE type = 'restock'");

            console.log('Deleting inventory_batches (PO related)...');
            await client.query("DELETE FROM inventory_batches WHERE batch_number LIKE 'PO-%'");

            console.log('Deleting purchase_orders...');
            await client.query('DELETE FROM purchase_orders');

            // Also reset Current Balance of Suppliers to Opening Balance?
            // Users usually expect "Delete Data" to reset balances derived from that data.
            // If we delete all payments and bills, current_balance should ideally revert to opening_balance.
            console.log('Resetting Supplier Balances to Opening Balance...');
            await client.query(`
                UPDATE suppliers 
                SET current_balance = opening_balance
            `);

            await client.query('COMMIT');
            console.log('✅ Purchase Module data wiped successfully.');
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }

        process.exit(0);
    } catch (err) {
        console.error('❌ Error wiping data:', err);
        process.exit(1);
    }
})();
