const { Pool } = require('pg');
const pool = new Pool({
    user: 'postgres',
    host: 'localhost',
    database: 'popo_baking_erp',
    password: 'Metrotech@AD#09',
    port: 5000
});
// NOTE: Port in .env is 5000 (APP port), but PG default is 5432. The .env usually specifies APP port.
// I will assume DB port is 5432 unless DB_PORT is strictly specified.
// Wait, checking .env again... no DB_PORT. DB_HOST=localhost.
// I will try 5432 first.

const poolConfig = {
    user: 'postgres',
    host: 'localhost',
    database: 'popo_baking_erp',
    password: 'Metrotech@AD#09',
    port: 5432
};

const client = new Pool(poolConfig);

async function check() {
    try {
        console.log('Connecting to DB...');
        // Check specific expense shown in screenshot (Amount 400, 'Meta', Jan 15)
        // Actually just search 'Meta'
        const res = await client.query(`
      SELECT e.id, e.description, e.created_by, u.username, u.first_name, u.last_name 
      FROM expenses e 
      LEFT JOIN users u ON e.created_by = u.id 
      WHERE e.description ILIKE '%Meta%' 
      LIMIT 5
    `);
        console.log('Expenses Found:', res.rows.length);
        res.rows.forEach(r => {
            console.log(`- Expense: ${r.description}, CreatedBy ID: ${r.created_by}, User: ${r.first_name} ${r.last_name} (${r.username})`);
        });

        // Also check if ANY user has names set
        const users = await client.query('SELECT id, username, first_name, last_name FROM users LIMIT 3');
        console.log('\nSample Users:', users.rows);
    } catch (err) {
        console.error('DB Error:', err);
    } finally {
        client.end();
    }
}

check();
