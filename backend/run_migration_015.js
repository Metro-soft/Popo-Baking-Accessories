const db = require('./src/config/db');
const fs = require('fs');
const path = require('path');

async function runMigration() {
    try {
        const sql = fs.readFileSync(path.join(__dirname, 'src/migrations/015_fix_batches_fk.sql'), 'utf8');
        console.log('Running Migration 015...');
        await db.query(sql);
        console.log('Migration 015 Complete: Inventory Batches FK updated to locations.');
        process.exit(0);
    } catch (err) {
        console.error('Migration Failed:', err);
        process.exit(1);
    }
}

runMigration();
