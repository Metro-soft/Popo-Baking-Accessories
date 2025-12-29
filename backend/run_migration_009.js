const db = require('./src/config/db');
const fs = require('fs');
const path = require('path');

async function runMigration() {
    try {
        const sqlPath = path.join(__dirname, 'src', 'migrations', '009_locations_table.sql');
        const sql = fs.readFileSync(sqlPath, 'utf8');
        console.log('Executing migration...');
        await db.query(sql);
        console.log('Migration successful.');
    } catch (err) {
        console.error('Migration failed:', err);
    } finally {
        // We can't easily close single pool connection without closing pool, 
        // but for a script it's fine to just exit.
        process.exit();
    }
}

runMigration();
