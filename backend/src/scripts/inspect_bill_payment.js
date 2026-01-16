const { Pool } = require('pg');
const pool = new Pool({
    user: 'postgres',
    host: 'localhost',
    database: 'popo_baking_erp',
    password: 'Metrotech@AD#09',
    port: 5432
});

async function check() {
    try {
        console.log('Checking Bill Payments...');
        const res = await pool.query(`
      SELECT e.id, e.description, e.created_by, e.amount, e.date,
             u.username, u.full_name
      FROM expenses e 
      LEFT JOIN users u ON e.created_by = u.id 
      WHERE e.description ILIKE '%Laban Oyoo%'
    `);

        if (res.rows.length === 0) {
            console.log('No matching expense found for Laban Oyoo.');
        } else {
            res.rows.forEach(r => {
                console.log('--------------------------------------------------');
                console.log(`Expense ID: ${r.id}`);
                console.log(`Description: ${r.description}`);
                console.log(`Created By ID: ${r.created_by}`);
                console.log(`User Name: ${r.username || 'NULL'}`);
                console.log(`Full Name: ${r.full_name || 'NULL'}`);
                console.log('--------------------------------------------------');
            });
        }

        // Also check the recurring_bills table to see who created the bill definition? (Though expense is what matters)
    } catch (err) {
        console.error('DB Error:', err);
    } finally {
        pool.end();
    }
}

check();
