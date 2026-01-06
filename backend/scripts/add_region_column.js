const pool = require('../src/config/db');

async function addRegionColumn() {
    try {
        // Check if column exists
        const check = await pool.query(`
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name='customers' AND column_name='region'
        `);

        if (check.rows.length === 0) {
            console.log('Adding region column...');
            await pool.query('ALTER TABLE customers ADD COLUMN region VARCHAR(255)');
            console.log('Region column added.');
        } else {
            console.log('Region column already exists.');
        }
    } catch (e) {
        console.error(e);
    } // Don't close pool just let it hang or exit manually if needed, or use proper teardown
    // actually pool.end() is fine if imported correctly
    process.exit(0);
}

addRegionColumn();
