const pool = require('../../config/db');

// --- SUPPLIERS ---

exports.getSuppliers = async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM suppliers ORDER BY name ASC');
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.createSupplier = async (req, res) => {
    const { name, contact_person, phone, email, address, tax_id } = req.body;
    try {
        const result = await pool.query(
            'INSERT INTO suppliers (name, contact_person, phone, email, address, tax_id) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
            [name, contact_person, phone, email, address, tax_id]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.updateSupplier = async (req, res) => {
    const { id } = req.params;
    const { name, contact_person, phone, email, address, tax_id } = req.body;
    try {
        const result = await pool.query(
            `UPDATE suppliers 
             SET name = $1, contact_person = $2, phone = $3, email = $4, address = $5, tax_id = $6 
             WHERE id = $7 RETURNING *`,
            [name, contact_person, phone, email, address, tax_id, id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Supplier not found' });
        }
        res.json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.deleteSupplier = async (req, res) => {
    const { id } = req.params;
    try {
        await pool.query('DELETE FROM suppliers WHERE id = $1', [id]);
        res.json({ message: 'Supplier deleted' });
    } catch (err) {
        // Handle FK violations gracefully
        if (err.code === '23503') {
            return res.status(400).json({ error: 'Cannot delete supplier with linked records.' });
        }
        res.status(500).json({ error: err.message });
    }
};

exports.getSupplierTransactions = async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(
            `SELECT po.*, 
                    (SELECT COUNT(*) FROM po_items WHERE po_id = po.id) as item_count
             FROM purchase_orders po 
             WHERE po.supplier_id = $1 
             ORDER BY po.created_at DESC`,
            [id]
        );
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

// --- CUSTOMERS ---

exports.getCustomers = async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM customers ORDER BY name ASC');
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.createCustomer = async (req, res) => {
    const { name, phone, alt_phone, email, credit_limit, address } = req.body;
    try {
        const result = await pool.query(
            'INSERT INTO customers (name, phone, alt_phone, email, credit_limit, address, current_debt) VALUES ($1, $2, $3, $4, $5, $6, 0) RETURNING *',
            [name, phone, alt_phone || null, email, credit_limit || 0, address]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        if (err.code === '23505') { // Unique violation
            return res.status(409).json({ error: 'Customer with this phone number already exists.' });
        }
        res.status(500).json({ error: err.message });
    }
};

exports.updateCustomer = async (req, res) => {
    const { id } = req.params;
    const { name, phone, alt_phone, email, credit_limit, address } = req.body;
    try {
        const result = await pool.query(
            `UPDATE customers 
             SET name = $1, phone = $2, alt_phone = $3, email = $4, credit_limit = $5, address = $6
             WHERE id = $7 RETURNING *`,
            [name, phone, alt_phone || null, email, credit_limit, address, id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Customer not found' });
        }
        res.json(result.rows[0]);
    } catch (err) {
        if (err.code === '23505') {
            return res.status(409).json({ error: 'Phone number already assigned to another customer.' });
        }
        res.status(500).json({ error: err.message });
    }
};

exports.deleteCustomer = async (req, res) => {
    const { id } = req.params;
    try {
        await pool.query('DELETE FROM customers WHERE id = $1', [id]);
        res.json({ message: 'Customer deleted' });
    } catch (err) {
        if (err.code === '23503') {
            return res.status(400).json({ error: 'Cannot delete customer with linked transactions.' });
        }
        res.status(500).json({ error: err.message });
    }
};

exports.getCustomerTransactions = async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(
            `SELECT o.id, o.created_at, o.total_amount, o.status, 
                    (SELECT COUNT(*) FROM order_items WHERE order_id = o.id) as item_count
             FROM orders o 
             WHERE o.customer_id = $1 
             ORDER BY o.created_at DESC`,
            [id]
        );
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};
