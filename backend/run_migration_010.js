const db = require('./src/config/db');
const fs = require('fs');
const path = require('path');

async function runMigration() {
    try {
        const sqlPath = path.join(__dirname, 'src', 'migrations', '010_users_branch_id.sql');
        const sql = fs.readFileSync(sqlPath, 'utf8');
        console.log('Executing migration 010...');
        await db.query(sql);
        console.log('Migration 010 successful.');
    } catch (err) {
        // If column exists, it might error, but we can ignore or log.
        console.error('Migration failed:', err.message);
    } finally {
        process.exit();
    }
}

runMigration();
