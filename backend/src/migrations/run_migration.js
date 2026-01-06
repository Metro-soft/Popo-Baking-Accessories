const fs = require('fs');
const path = require('path');
const db = require('../config/db');

const runMigration = async () => {
    const sqlPath = path.join(__dirname, '022_add_branch_to_payments.sql');
    const sql = fs.readFileSync(sqlPath).toString();

    console.log('Running Migration: 022_add_branch_to_payments.sql ...');

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
