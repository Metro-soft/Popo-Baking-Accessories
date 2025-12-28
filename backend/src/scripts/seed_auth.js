const db = require('../config/db');
const bcrypt = require('bcrypt');

const seedAuth = async () => {
    try {
        console.log('Seeding Test User...');

        const email = 'admin@popo.com';
        const password = 'pass234';
        const hashedPassword = await bcrypt.hash(password, 10);

        // Upsert User
        const query = `
            INSERT INTO users (username, email, password_hash, role, branch_id)
            VALUES ($1, $2, $3, 'admin', 1)
            ON CONFLICT (email) 
            DO UPDATE SET password_hash = $3, role = 'admin';
        `;

        await db.query(query, ['Admin User', email, hashedPassword]);

        console.log('Test User Created/Updated:');
        console.log('Email: admin@popo.com');
        console.log('Password: pass234');
        console.log('Role: admin');

        process.exit(0);
    } catch (error) {
        console.error('Seeding Failed:', error);
        process.exit(1);
    }
};

seedAuth();
