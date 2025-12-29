const db = require('./src/config/db');
const fs = require('fs');
const path = require('path');

async function runMigration() {
    try {
        const sql = fs.readFileSync(path.join(__dirname, 'src/migrations/011_fix_transfer_fks.sql'), 'utf8');
        console.log('Running Migration 011...');
        await db.query(sql);
        console.log('Migration 011 Complete: Inventory Transfer FKs updated to locations.');
        process.exit(0);
    } catch (err) {
        console.error('Migration Failed:', err);
        process.exit(1);
    }
}

runMigration();
