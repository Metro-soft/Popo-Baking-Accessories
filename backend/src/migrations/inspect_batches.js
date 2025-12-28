const db = require('../config/db');

const inspect = async () => {
    try {
        const result = await db.query('SELECT * FROM inventory_batches LIMIT 1');
        if (result.rows.length > 0) {
            console.log('Batch Columns:', Object.keys(result.rows[0]));
        } else {
            console.log('No batches found, cannot inspect columns easily without schema.');
            // Fallback: Query system catalog
            const result2 = await db.query(`
                SELECT column_name, data_type 
                FROM information_schema.columns 
                WHERE table_name = 'inventory_batches'
             `);
            console.log('Schema:', result2.rows);
        }
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
};

inspect();
