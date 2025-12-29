const db = require('./src/config/db');
const bcrypt = require('bcrypt');
require('dotenv').config();

async function checkAndFix() {
    try {
        console.log('Checking users...');
        const res = await db.query('SELECT id, email, role FROM users');
        console.log('Existing Users:', res.rows);

        const email = 'admin@popo.com';
        const password = 'pass234';
        const hash = await bcrypt.hash(password, 10);

        const user = res.rows.find(u => u.email === email);

        if (user) {
            console.log(`User ${email} found. Resetting password...`);
            await db.query('UPDATE users SET password_hash = $1 WHERE email = $2', [hash, email]);
            console.log('Password reset successfully.');
        } else {
            console.log(`User ${email} NOT found. Creating...`);
            await db.query(
                'INSERT INTO users (username, email, password_hash, role) VALUES ($1, $2, $3, $4)',
                ['Admin', email, hash, 'admin']
            );
            console.log('User created successfully.');
        }

        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

checkAndFix();
