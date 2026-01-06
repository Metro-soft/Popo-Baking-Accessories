const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: 5432,
});

async function inspect() {
    const client = await pool.connect();
    try {
        console.log(`Connected to: ${process.env.DB_NAME}`);
        const res = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'orders'
    `);

        console.log('Columns in orders table:');
        res.rows.forEach(r => console.log(`- ${r.column_name} (${r.data_type})`));

    } catch (err) {
        console.error('Inspect failed:', err);
    } finally {
        client.release();
        pool.end();
    }
}

inspect();
