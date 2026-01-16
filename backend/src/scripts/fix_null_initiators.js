const { Pool } = require('pg');
const pool = new Pool({
    user: 'postgres',
    host: 'localhost',
    database: 'popo_baking_erp',
    password: 'Metrotech@AD#09',
    port: 5432
});

async function run() {
    try {
        console.log('Fixing expenses with missing attributes...');

        // 1. Backfill NULL created_by with 1 (Admin/System)
        const res = await pool.query(`
      UPDATE expenses 
      SET created_by = 1 
      WHERE created_by IS NULL
    `);
        console.log(`Updated ${res.rowCount} expenses with missing Initiator.`);

        // 2. Also backfill NULL branch_id with 1 (Head Office) just in case
        const res2 = await pool.query(`
      UPDATE expenses 
      SET branch_id = 1 
      WHERE branch_id IS NULL
    `);
        console.log(`Updated ${res2.rowCount} expenses with missing Branch.`);

    } catch (err) {
        console.error('DB Error:', err);
    } finally {
        pool.end();
    }
}

run();
