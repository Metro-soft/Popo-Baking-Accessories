const db = require('./src/config/db');
const bcrypt = require('bcrypt');

async function resetAdmin() {
    try {
        const hash = await bcrypt.hash('admin123', 10);
        console.log('Resetting admin password to "admin123"...');

        // Update or Insert admin
        // We assume the username is 'admin'

        // First check if admin exists
        const res = await db.query("SELECT id FROM users WHERE username = 'admin'");

        if (res.rows.length > 0) {
            await db.query("UPDATE users SET password_hash = $1 WHERE username = 'admin'", [hash]);
            console.log('✅ Admin password updated.');
        } else {
            await db.query("INSERT INTO users (username, password_hash, role) VALUES ('admin', $1, 'admin')", [hash]);
            console.log('✅ Admin user created.');
        }

    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}

resetAdmin();
