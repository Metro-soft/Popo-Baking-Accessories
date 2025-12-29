const db = require('./src/config/db');

async function inspect() {
    try {
        const res = await db.query(`
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'orders'
        `);
        console.log('Columns in orders table:', res.rows.map(r => r.column_name));

        // Check current values
        const vals = await db.query('SELECT id, branch_id FROM orders LIMIT 5');
        console.log('Sample content:', vals.rows);

        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

inspect();
