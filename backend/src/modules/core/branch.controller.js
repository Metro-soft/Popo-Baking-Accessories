const db = require('../../config/db');

exports.createBranch = async (req, res) => {
    const { name, location } = req.body;
    try {
        const result = await db.query(
            'INSERT INTO branches (name, location) VALUES ($1, $2) RETURNING *',
            [name, location]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.getAllBranches = async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM branches ORDER BY id ASC');
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};
