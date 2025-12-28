const db = require('../config/db');

const testQuery = async () => {
    try {
        console.log('Testing Stock History Query...');
        // Try to select from the table with a dummy ID (e.g. 1)
        const result = await db.query(`
            SELECT * FROM stock_movements 
            WHERE product_id = 1 
            ORDER BY created_at DESC 
            LIMIT 10
        `);
        console.log('Query Successful!');
        console.log('Rows:', result.rows);
        process.exit(0);
    } catch (err) {
        console.error('Query Failed:', err);
        process.exit(1);
    }
};

testQuery();
