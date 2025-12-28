const fs = require('fs');
const path = require('path');
const db = require('../config/db');

const runMigration = async () => {
    const sqlPath = path.join(__dirname, '006_add_inventory_transfers.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('Running Migration: 006_add_inventory_transfers.sql ...');

    try {
        await db.query(sql);
        console.log('Migration SUCCESS!');
        process.exit(0);
    } catch (err) {
        console.error('Migration FAILED:', err);
        process.exit(1);
    }
};

runMigration();
