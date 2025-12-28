const db = require('../../config/db');

// Create Category
exports.createCategory = async (req, res) => {
    const { name, slug, description } = req.body;

    if (!name) return res.status(400).json({ error: 'Name is required' });

    // Auto-generate slug if missing
    const finalSlug = slug || name.toLowerCase().replace(/ /g, '-').replace(/[^\w-]+/g, '');

    try {
        const result = await db.query(
            'INSERT INTO categories (name, slug, description) VALUES ($1, $2, $3) RETURNING *',
            [name, finalSlug, description]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        if (err.code === '23505') { // Unique violation
            return res.status(409).json({ error: 'Category already exists' });
        }
        res.status(500).json({ error: 'Database error' });
    }
};

// Get All Categories
exports.getCategories = async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM categories ORDER BY name ASC');
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: 'Database error' });
    }
};

// Update Category
exports.updateCategory = async (req, res) => {
    const { id } = req.params;
    const { name, slug, description } = req.body;

    try {
        const result = await db.query(
            'UPDATE categories SET name = COALESCE($1, name), slug = COALESCE($2, slug), description = COALESCE($3, description) WHERE id = $4 RETURNING *',
            [name, slug, description, id]
        );
        if (result.rows.length === 0) return res.status(404).json({ error: 'Category not found' });
        res.json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: 'Database error' });
    }
};

// Delete Category
exports.deleteCategory = async (req, res) => {
    const { id } = req.params;
    try {
        const result = await db.query('DELETE FROM categories WHERE id = $1 RETURNING *', [id]);
        if (result.rows.length === 0) return res.status(404).json({ error: 'Category not found' });
        res.json({ message: 'Category deleted' });
    } catch (err) {
        res.status(500).json({ error: 'Database error' });
    }
};
