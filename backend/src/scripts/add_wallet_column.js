const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });
const db = require('../config/db');

async function migrate() {
    try {
        console.log('Adding wallet_balance to customers table...');

        // Check if column exists
        const check = await db.query(`
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name='customers' AND column_name='wallet_balance'
        `);

        if (check.rows.length === 0) {
            await db.query(`
                ALTER TABLE customers 
                ADD COLUMN wallet_balance DECIMAL(15,2) DEFAULT 0.00
            `);
            console.log('Column wallet_balance added successfully.');
        } else {
            console.log('Column wallet_balance already exists.');
        }

        process.exit(0);
    } catch (err) {
        console.error('Migration Failed:', err);
        process.exit(1);
    }
}

migrate();
