const { Pool } = require('pg');
const bcrypt = require('bcrypt');

const pool = new Pool({
    user: 'postgres',
    host: 'localhost',
    database: 'popo_baking_erp',
    password: 'Metrotech@AD#09',
    port: 5432
});

async function seed() {
    try {
        const email = 'admin@popo.com';
        const password = 'pass234';
        const fullName = 'System Admin'; // "The rest take care of"
        const username = 'admin';

        console.log(`Seeding Admin User: ${email}...`);
        const hashedPassword = await bcrypt.hash(password, 10);

        // 1. Resolve Conflict: Find a user with this email or this username
        // Ideally we want ONE user: {username: 'admin', email: 'admin@popo.com'}

        // Check if distinct users create a conflict
        // If User A has 'admin' username
        // And User B has 'admin@popo.com' email
        // We update User B to have 'admin' username... BUT we must remove User A first (or rename)

        // Simplest: Delete any user with 'admin' username OR 'admin@popo.com' email, then insert Fresh.
        // BUT we want to preserve ID 1 if possible.

        // Force delete conflict logic:
        // DELETE FROM users WHERE username = 'admin' OR email = 'admin@popo.com';
        // INSERT ...

        // BUT this changes ID, which might break foreign keys (expenses.created_by).
        // Better: Update ID 1 if it exists.

        const id1Check = await pool.query('SELECT * FROM users WHERE id = 1');
        if (id1Check.rows.length > 0) {
            console.log('User ID 1 exists. Updating it to be the Admin...');

            // Ensure no OTHER user holds the username 'admin' or email 'admin@popo.com'
            await pool.query("UPDATE users SET username = username || '_old', email = NULL WHERE (username = $1 OR email = $2) AND id != 1", [username, email]);

            await pool.query(
                `UPDATE users 
             SET email = $1, 
                 password_hash = $2, 
                 full_name = $3, 
                 branch_id = 1,
                 role = 'admin',
                 username = $4
             WHERE id = 1`,
                [email, hashedPassword, fullName, username]
            );
            console.log('User ID 1 updated to Admin.');
        } else {
            // ID 1 doesn't exist?
            // Just nuke conflicts and insert new
            console.log('ID 1 not found. Cleaning conflicts and creating new...');
            await pool.query('DELETE FROM users WHERE username = $1 OR email = $2', [username, email]);

            await pool.query(
                `INSERT INTO users (username, email, password_hash, full_name, role, branch_id, is_active)
             VALUES ($1, $2, $3, $4, 'admin', 1, true)`,
                [username, email, hashedPassword, fullName]
            );
            console.log('Admin created.');
        }

    } catch (err) {
        console.error('Error:', err);
    } finally {
        pool.end();
    }
}

seed();
