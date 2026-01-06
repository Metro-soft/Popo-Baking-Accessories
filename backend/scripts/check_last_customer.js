const pool = require('../src/config/db');

async function checkLastCustomer() {
    try {
        const res = await pool.query('SELECT * FROM customers ORDER BY id DESC LIMIT 1');
        console.log(JSON.stringify(res.rows[0], null, 2));
    } catch (e) {
        console.error(e);
    } finally {
        await pool.end();
    }
}

checkLastCustomer();
