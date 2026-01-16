const { Pool } = require('pg');
const pool = new Pool({
    user: 'postgres',
    host: 'localhost',
    database: 'popo_baking_erp',
    password: 'Metrotech@AD#09',
    port: 5432
});

async function check() {
    try {
        console.log('Checking Users Table Schema...');
        const res = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'users'
    `);
        console.log('Columns:', res.rows);
    } catch (err) {
        console.error('DB Error:', err);
    } finally {
        pool.end();
    }
}

check();
