const db = require('./src/config/db');
const fs = require('fs');
const path = require('path');

async function runMigration() {
    try {
        const sql = fs.readFileSync(path.join(__dirname, 'src', 'migrations', '016_add_branch_to_movements.sql'), 'utf8');
        console.log('Running Migration 016...');
        await db.query(sql);
        console.log('Migration 016 Complete: branch_id added to stock_movements.');
        process.exit(0);
    } catch (err) {
        console.error('Migration Failed:', err);
        process.exit(1);
    }
}

runMigration();
