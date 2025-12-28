const db = require('../../config/db');

exports.getCustomers = async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM customers ORDER BY name ASC');
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.createCustomer = async (req, res) => {
    const { name, phone, creditLimit } = req.body;
    try {
        const result = await db.query(
            'INSERT INTO customers (name, phone, credit_limit) VALUES ($1, $2, $3) RETURNING *',
            [name, phone, creditLimit || 5000.00]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

// Settle Debt
exports.settleDebt = async (req, res) => {
    const { customerId, amount, paymentMethod } = req.body;
    if (!amount || amount <= 0) return res.status(400).json({ error: 'Invalid amount' });

    const client = await db.pool.connect();
    try {
        await client.query('BEGIN');

        // Update Debt
        await client.query(
            'UPDATE customers SET current_debt = current_debt - $1 WHERE id = $2',
            [amount, customerId]
        );

        // Record Payment (We might need a separate 'debt_payments' table or use 'payments' linked to a dummy order. 
        // For strictness, let's create a 'Debt Payment' record log in a future step. 
        // For now, updating the balance is crucial.)

        await client.query('COMMIT');
        res.json({ message: 'Debt settled successfully' });

    } catch (err) {
        await client.query('ROLLBACK');
        res.status(500).json({ error: err.message });
    } finally {
        client.release();
    }
};
