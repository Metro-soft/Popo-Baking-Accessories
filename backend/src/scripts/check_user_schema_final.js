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
        const res = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'users'
    `);
        console.log('Users Table Columns:', res.rows.map(r => r.column_name));

        const sample = await pool.query('SELECT * FROM users LIMIT 1');
        console.log('Sample User:', sample.rows[0]);
    } catch (err) {
        console.error('DB Error:', err);
    } finally {
        pool.end();
    }
}

check();
