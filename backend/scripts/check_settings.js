const pool = require('../src/config/db');

async function checkSettings() {
    try {
        const res = await pool.query("SELECT * FROM settings WHERE key = 'delivery_regions'");
        console.log('delivery_regions:', res.rows);
    } catch (e) {
        console.error(e);
    } finally {
        await pool.end();
    }
}

checkSettings();
