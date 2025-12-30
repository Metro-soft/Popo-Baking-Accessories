const db = require('../config/db');

(async () => {
    try {
        console.log('Testing DB connection...');
        const res = await db.query('SELECT NOW()');
        console.log('DB Connection successful:', res.rows[0]);

        console.log('Checking users table...');
        const users = await db.query('SELECT id, email, role FROM users LIMIT 1');
        console.log('Users found:', users.rows);

        process.exit(0);
    } catch (err) {
        console.error('DB Test Failed:', err);
        process.exit(1);
    }
})();
