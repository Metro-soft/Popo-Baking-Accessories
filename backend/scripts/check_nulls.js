const db = require('../src/config/db');
require('dotenv').config();

async function checkNulls() {
    try {
        const res = await db.pool.query(`
            SELECT id, created_at, total_product_cost 
            FROM purchase_orders 
            WHERE created_at IS NULL OR total_product_cost IS NULL;
        `);
        console.log('Rows with NULL created_at or total_product_cost:', res.rows);
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}

checkNulls();
