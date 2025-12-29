const db = require('../../config/db');

exports.createLocation = async (req, res) => {
    const { name, type, address, contact_phone } = req.body;

    if (!name || !type) {
        return res.status(400).json({ error: 'Name and Type are required' });
    }
    if (!['warehouse', 'branch'].includes(type)) {
        return res.status(400).json({ error: 'Invalid Type. Must be "warehouse" or "branch"' });
    }

    try {
        const result = await db.query(
            `INSERT INTO locations (name, type, address, contact_phone) 
             VALUES ($1, $2, $3, $4) RETURNING *`,
            [name, type, address, contact_phone]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        console.error('Create Location Error:', err);
        if (err.code === '23505') { // Unique violation
            return res.status(409).json({ error: 'Location name already exists' });
        }
        res.status(500).json({ error: 'Failed to create location' });
    }
};

exports.getAllLocations = async (req, res) => {
    try {
        const result = await db.query(`
            SELECT * FROM locations 
            WHERE is_active = TRUE 
            ORDER BY id ASC
        `);
        res.json(result.rows);
    } catch (err) {
        console.error('Get Locations Error:', err);
        res.status(500).json({ error: 'Failed to fetch locations' });
    }
};

exports.updateLocation = async (req, res) => {
    const { id } = req.params;
    const { name, address, contact_phone } = req.body;

    // We don't allow changing TYPE (Mother cannot become Child easily without logic checks)
    try {
        const result = await db.query(
            `UPDATE locations 
             SET name = COALESCE($1, name), 
                 address = COALESCE($2, address), 
                 contact_phone = COALESCE($3, contact_phone)
             WHERE id = $4 RETURNING *`,
            [name, address, contact_phone, id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Location not found' });
        }
        res.json(result.rows[0]);
    } catch (err) {
        console.error('Update Location Error:', err);
        res.status(500).json({ error: 'Failed to update location' });
    }
};
