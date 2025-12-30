const pool = require('../../config/db');

// Get all settings as a key-value map
exports.getSettings = async (req, res) => {
    try {
        const result = await pool.query('SELECT key, value FROM settings');
        const settings = {};
        result.rows.forEach(row => {
            settings[row.key] = row.value;
        });
        res.json(settings);
    } catch (err) {
        console.error('Error fetching settings:', err);
        res.status(500).json({ error: 'Failed to fetch settings' });
    }
};

// Update settings (upsert)
exports.updateSettings = async (req, res) => {
    const settings = req.body; // Expecting { key: value, key2: value2 }
    const client = await pool.pool.connect();

    try {
        await client.query('BEGIN');

        for (const [key, value] of Object.entries(settings)) {
            await client.query(`
                INSERT INTO settings (key, value)
                VALUES ($1, $2)
                ON CONFLICT (key)
                DO UPDATE SET value = EXCLUDED.value
            `, [key, value]);
        }

        await client.query('COMMIT');
        res.json({ message: 'Settings updated successfully' });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error updating settings:', err);
        res.status(500).json({ error: 'Failed to update settings' });
    } finally {
        client.release();
    }
};
