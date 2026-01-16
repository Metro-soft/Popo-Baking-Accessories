const db = require('../config/db');

async function checkConstraints() {
    try {
        const query = `
            SELECT cc.check_clause
            FROM information_schema.check_constraints cc
            JOIN information_schema.constraint_column_usage ccu ON cc.constraint_name = ccu.constraint_name
            WHERE ccu.table_name = 'expense_categories' AND ccu.column_name = 'type';
        `;
        const res = await db.query(query);
        console.log('Constraints:', JSON.stringify(res.rows, null, 2));
        process.exit(0);
    } catch (err) {
        console.error('Error:', err);
        process.exit(1);
    }
}

checkConstraints();
