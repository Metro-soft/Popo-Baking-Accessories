const db = require('../../config/db');

exports.getSuppliers = async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM suppliers ORDER BY name ASC');
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.createSupplier = async (req, res) => {
    const { name, contact_person, phone } = req.body;
    if (!name) return res.status(400).json({ error: 'Name is required' });

    try {
        const result = await db.query(
            'INSERT INTO suppliers (name, contact_person, phone) VALUES ($1, $2, $3) RETURNING *',
            [name, contact_person, phone]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};
