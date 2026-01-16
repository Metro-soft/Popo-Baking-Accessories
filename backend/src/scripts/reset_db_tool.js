const fs = require('fs');
const path = require('path');
const db = require('../config/db');

async function resetDb() {
    try {
        const sqlPath = path.join(__dirname, '../migrations/reset_finance_data.sql');
        const sql = fs.readFileSync(sqlPath, 'utf8');

        console.log('Executing reset script...');
        await db.query(sql);
        console.log('✅ Finance data reset successfully.');
        process.exit(0);
    } catch (err) {
        console.error('❌ Error resetting database:', err);
        process.exit(1);
    }
}

resetDb();
