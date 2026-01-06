const fs = require('fs');
const path = require('path');
const db = require('./src/config/db');

async function runMigration() {
    try {
        const sqlPath = path.join(__dirname, 'src', 'migrations', '009_add_dispatch_fields.sql');
        const sql = fs.readFileSync(sqlPath, 'utf8');

        console.log('Running migration: 009_add_dispatch_fields.sql');

        const client = await db.pool.connect();
        try {
            await client.query(sql);
            console.log('Migration successful!');
        } catch (err) {
            console.error('Migration failed:', err.message);
        } finally {
            client.release();
        }
    } catch (err) {
        console.error('Error reading/setup:', err.message);
    } finally {
        process.exit();
    }
}

runMigration();
