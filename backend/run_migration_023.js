const db = require('./src/config/db');
const fs = require('fs');
const path = require('path');

async function runMigration() {
    try {
        const sql = fs.readFileSync(path.join(__dirname, 'src', 'migrations', '023_add_estimates.sql'), 'utf8');
        console.log('Running Migration 023 (Add Estimates)...');
        await db.query(sql);
        console.log('Migration 023 Complete: Estimates tables created.');
        process.exit(0);
    } catch (err) {
        console.error('Migration Failed:', err);
        process.exit(1);
    }
}

runMigration();
