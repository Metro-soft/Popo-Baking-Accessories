const db = require('./src/config/db');
const fs = require('fs');
const path = require('path');

async function runMigration() {
    try {
        const sql = fs.readFileSync(path.join(__dirname, 'src', 'migrations', '017_fix_orders_branch_id.sql'), 'utf8');
        console.log('Running Migration 017 (Fix)...');
        await db.query(sql);
        console.log('Migration 017 Complete: branch_id added to orders.');
        process.exit(0);
    } catch (err) {
        console.error('Migration Failed:', err);
        process.exit(1);
    }
}

runMigration();
