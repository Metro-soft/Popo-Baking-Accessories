const db = require('./src/config/db');
const fs = require('fs');
const path = require('path');

async function runMigration() {
    try {
        const sql = fs.readFileSync(path.join(__dirname, 'src/migrations/014_cleanup_inventory_batches.sql'), 'utf8');
        console.log('Running Migration 014...');
        await db.query(sql);
        console.log('Migration 014 Complete: Dropped legacy location column.');
        process.exit(0);
    } catch (err) {
        console.error('Migration Failed:', err);
        process.exit(1);
    }
}

runMigration();
