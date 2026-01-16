const db = require('../config/db');

const debugBranch = async () => {
    try {
        console.log('--- DEBUGGING BRANCH IDs ---');

        const user = await db.query("SELECT id, email, branch_id FROM users WHERE email = 'admin@popo.com'");
        console.log('User:', user.rows[0]);

        const expenses = await db.query("SELECT id, amount, type, branch_id, date FROM expenses LIMIT 5");
        console.log('Expenses Sample:', expenses.rows);

    } catch (err) {
        console.error('Debug Error:', err);
    } finally {
        process.exit();
    }
};

debugBranch();
