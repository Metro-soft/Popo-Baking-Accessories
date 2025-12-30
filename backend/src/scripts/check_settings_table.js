const pool = require('../config/db');

async function check() {
    try {
        console.log('Checking database connection...');
        const client = await pool.connect();
        console.log('Connected. Checking settings table...');

        const res = await client.query("SELECT to_regclass('public.settings')");
        if (res.rows[0].to_regclass) {
            console.log('Settings table EXISTS.');
            const count = await client.query('SELECT count(*) FROM settings');
            console.log('Row count:', count.rows[0].count);
        } else {
            console.error('Settings table DOES NOT EXIST.');
        }
        client.release();
    } catch (err) {
        console.error('Database Check Failed:', err);
    } finally {
        // Allow time for logs to flush
        setTimeout(() => process.exit(0), 500);
    }
}

check();
