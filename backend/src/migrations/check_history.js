const db = require('../config/db');

const check = async () => {
    try {
        const res = await db.query(`
            SELECT p.name, sm.type, sm.quantity, sm.reference_id, sm.created_at 
            FROM stock_movements sm
            JOIN products p ON sm.product_id = p.id
            ORDER BY sm.created_at DESC
            LIMIT 10
        `);
        console.table(res.rows);
        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
};
check();
