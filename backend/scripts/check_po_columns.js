const db = require('../src/config/db');
require('dotenv').config();

async function checkColumns() {
    try {
        const res = await db.pool.query(`
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'purchase_orders';
        `);
        console.log('Columns in purchase_orders:', res.rows.map(r => r.column_name));
    } catch (err) {
        console.error(err);
    } finally {
        process.exit();
    }
}

checkColumns();
