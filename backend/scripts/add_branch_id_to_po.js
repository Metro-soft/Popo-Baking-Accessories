const db = require('../src/config/db');
require('dotenv').config();

async function addBranchId() {
    console.log('Adding branch_id to purchase_orders...');
    try {
        await db.pool.query(`
            ALTER TABLE purchase_orders 
            ADD COLUMN IF NOT EXISTS branch_id INTEGER REFERENCES locations(id) DEFAULT 1;
        `);
        console.log('✅ Added branch_id to purchase_orders');
    } catch (err) {
        console.error('❌ Migration failed:', err);
    } finally {
        // Close pool only if script handles closure
        process.exit();
    }
}

addBranchId();
