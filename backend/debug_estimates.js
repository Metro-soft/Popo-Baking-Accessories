const db = require('./src/config/db');

async function testQuery() {
    try {
        console.log('Connecting...');
        const client = await db.pool.connect();
        console.log('Connected.');

        // 1. Check Tables
        console.log('Checking tables...');
        const tables = await client.query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name IN ('estimates', 'users')
        `);
        console.log('Tables found:', tables.rows.map(r => r.table_name));

        // 2. Check Users Columns
        console.log('Checking users columns...');
        const userCols = await client.query(`
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'users'
        `);
        console.log('User Columns:', userCols.rows.map(r => r.column_name));

        // 3. Test The Query
        console.log('Testing specific query...');
        try {
            const res = await client.query(`
                SELECT e.*, c.full_name as customer_name 
                FROM estimates e
                LEFT JOIN users c ON e.customer_id = c.id
                LIMIT 5
            `);
            console.log('Query Success! Rows scattered:', res.rowCount);
            console.log('Data:', res.rows);
        } catch (qErr) {
            console.error('QUERY FAILED:', qErr.message);
        }

        client.release();
    } catch (err) {
        console.error('General Error:', err);
    } finally {
        process.exit();
    }
}

testQuery();
