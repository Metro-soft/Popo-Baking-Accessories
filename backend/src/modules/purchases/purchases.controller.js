const db = require('../../config/db');
const activityService = require('../core/activity.service');

// GET /api/purchases/bills
exports.getBills = async (req, res) => {
    try {
        const { supplierId, status, startDate, endDate } = req.query;
        let query = `
            SELECT 
                po.id, 
                po.created_at, 
                po.reference_no, 
                po.total_product_cost, 
                po.transport_cost, 
                po.packaging_cost,
                (po.total_product_cost + po.transport_cost + po.packaging_cost) as total_amount,
                po.total_paid,
                po.payment_status,
                po.due_date,
                s.name as supplier_name
            FROM purchase_orders po
            LEFT JOIN suppliers s ON po.supplier_id = s.id
            WHERE 1=1
        `;
        const params = [];
        let paramIdx = 1;

        if (supplierId) {
            query += ` AND po.supplier_id = $${paramIdx++}`;
            params.push(supplierId);
        }
        if (status) { // 'unpaid', 'partial', 'paid'
            query += ` AND po.payment_status = $${paramIdx++}`;
            params.push(status);
        }
        // Date filtering could be added here

        query += ` ORDER BY po.created_at DESC`;

        const result = await db.pool.query(query, params);
        res.json(result.rows);

    } catch (err) {
        console.error('Get Bills Error:', err);
        res.status(500).json({ error: 'Failed to fetch bills' });
    }
};

// POST /api/purchases/payments
exports.recordPayment = async (req, res) => {
    const { poId, amount, method, reference, notes } = req.body;
    const userId = req.user?.id;

    if (!poId || !amount || amount <= 0) {
        return res.status(400).json({ error: 'Invalid payment details' });
    }

    const client = await db.pool.connect();
    try {
        await client.query('BEGIN');

        // 1. Get PO current state
        const poRes = await client.query('SELECT total_product_cost, transport_cost, packaging_cost, total_paid FROM purchase_orders WHERE id = $1', [poId]);
        if (poRes.rows.length === 0) throw new Error('Purchase Order not found');

        const po = poRes.rows[0];
        const totalAmount = parseFloat(po.total_product_cost) + parseFloat(po.transport_cost) + parseFloat(po.packaging_cost);
        const currentPaid = parseFloat(po.total_paid);
        const newPaid = currentPaid + parseFloat(amount);

        // 2. Determine new status
        let newStatus = 'partial';
        if (newPaid >= totalAmount - 0.01) {
            newStatus = 'paid';
        }

        // 3. Insert Payment
        await client.query(
            `INSERT INTO supplier_payments (po_id, amount, method, reference, notes, created_by)
             VALUES ($1, $2, $3, $4, $5, $6)`,
            [poId, amount, method, reference, notes, userId]
        );

        // 4. Update PO
        await client.query(
            `UPDATE purchase_orders SET total_paid = $1, payment_status = $2 WHERE id = $3`,
            [newPaid, newStatus, poId]
        );

        // 5. Log Activity
        await activityService.logAction(userId, 'BILL_PAYMENT', 'purchase_orders', poId, {
            amount: amount,
            new_status: newStatus
        });

        await client.query('COMMIT');
        res.json({ message: 'Payment recorded', newStatus, newPaid });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Payment Error:', err);
        res.status(500).json({ error: err.message });
    } finally {
        client.release();
    }
};
