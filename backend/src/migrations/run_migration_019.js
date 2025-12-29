const fs = require('fs');
const path = require('path');
const db = require('../config/db');

const runMigration = async () => {
    const sqlPath = path.join(__dirname, '019_enhance_suppliers.sql');
    const sql = fs.readFileSync(sqlPath).toString();

    console.log('Running Migration: 019_enhance_suppliers.sql ...');

    try {
        await db.query(sql);
        console.log('Migration SUCCESS!');
        process.exit(0);
    } catch (err) {
        if (err.code === '42701') {
            console.log('Migration SKIPPED (Column already exists)');
            process.exit(0);
        }
        console.error('Migration FAILED:', err);
        process.exit(1);
    }
};

runMigration();
