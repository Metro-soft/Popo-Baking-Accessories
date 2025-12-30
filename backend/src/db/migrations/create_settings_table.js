const pool = require('../../config/db');

async function up() {
    const client = await pool.pool.connect();
    try {
        await client.query('BEGIN');

        await client.query(`
            CREATE TABLE IF NOT EXISTS settings (
                key VARCHAR(50) PRIMARY KEY,
                value TEXT
            );
        `);

        // Insert Defaults if not exist
        await client.query(`
            INSERT INTO settings (key, value) VALUES 
            ('company_name', 'Popo Baking Accessories'),
            ('company_address', 'Nairobi, Kenya'),
            ('company_phone', '+254 700 000 000'),
            ('company_email', 'info@popobaking.com')
            ON CONFLICT (key) DO NOTHING;
        `);

        await client.query('COMMIT');
        console.log('Settings table created successfully');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error creating settings table:', err);
        throw err;
    } finally {
        client.release();
    }
}

up().then(() => process.exit(0)).catch(() => process.exit(1));
