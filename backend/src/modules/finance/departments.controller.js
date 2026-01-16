const db = require('../../config/db');

// --- DEPARTMENTS ---

exports.getDepartments = async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM departments ORDER BY name ASC');
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching departments:', err);
        res.status(500).json({ error: 'Failed to fetch departments' });
    }
};

exports.createDepartment = async (req, res) => {
    try {
        const { name } = req.body;
        const result = await db.query(
            'INSERT INTO departments (name) VALUES ($1) RETURNING *',
            [name]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        if (err.code === '23505') { // Unique constraint violation
            return res.status(400).json({ error: 'Department already exists' });
        }
        console.error('Error creating department:', err);
        res.status(500).json({ error: 'Failed to create department' });
    }
};

exports.deleteDepartment = async (req, res) => {
    try {
        const { id } = req.params;
        await db.query('DELETE FROM departments WHERE id = $1', [id]);
        res.json({ message: 'Department deleted' });
    } catch (err) {
        console.error('Error deleting department:', err);
        res.status(500).json({ error: 'Failed to delete department' });
    }
};

// --- ROLES ---

exports.getRoles = async (req, res) => {
    try {
        const { department_id } = req.query;
        let query = 'SELECT r.*, d.name as department_name FROM job_roles r JOIN departments d ON r.department_id = d.id';
        const params = [];

        if (department_id) {
            query += ' WHERE r.department_id = $1';
            params.push(department_id);
        }

        query += ' ORDER BY r.name ASC';

        const result = await db.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching roles:', err);
        res.status(500).json({ error: 'Failed to fetch roles' });
    }
};

exports.createRole = async (req, res) => {
    try {
        const { name, department_id, permissions } = req.body;
        const result = await db.query(
            'INSERT INTO job_roles (name, department_id, permissions) VALUES ($1, $2, $3) RETURNING *',
            [name, department_id, permissions || []]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        if (err.code === '23505') {
            return res.status(400).json({ error: 'Role already exists in this department' });
        }
        console.error('Error creating role:', err);
        res.status(500).json({ error: 'Failed to create role' });
    }
};

exports.deleteRole = async (req, res) => {
    try {
        const { id } = req.params;
        await db.query('DELETE FROM job_roles WHERE id = $1', [id]);
        res.json({ message: 'Role deleted' });
    } catch (err) {
        console.error('Error deleting role:', err);
        res.status(500).json({ error: 'Failed to delete role' });
    }
};
