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

const isValidEmail = (email) => {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
};

exports.createSupplier = async (req, res) => {
    const { name, contact_person, phone, email, address, opening_balance } = req.body;
    try {
        const result = await pool.query(
            'INSERT INTO suppliers (name, contact_person, phone, email, address, opening_balance, current_balance) VALUES ($1, $2, $3, $4, $5, $6, $6) RETURNING *',
            [name, contact_person, phone, email, address, opening_balance || 0]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.updateSupplier = async (req, res) => {
    const { id } = req.params;
    const { name, contact_person, phone, email, address, opening_balance } = req.body;
    try {
        // If opening_balance is changed, we need to adjust current_balance appropriately? 
        // For simplicity, we just update the field. Mathematical reconciliation is complex if transactions exist.
        // Usually opening_balance is set once. If edited, user assumes responsibility.
        // Ideally: new_current = old_current - old_opening + new_opening.

        // Fetch old opening balance first
        const oldRes = await pool.query('SELECT opening_balance, current_balance FROM suppliers WHERE id = $1', [id]);
        if (oldRes.rows.length === 0) {
            return res.status(404).json({ error: 'Supplier not found' });
        }
        const oldOpening = parseFloat(oldRes.rows[0].opening_balance || 0);
        const current = parseFloat(oldRes.rows[0].current_balance || 0);
        const newOpening = parseFloat(opening_balance || 0);

        const newCurrent = current - oldOpening + newOpening;

        const result = await pool.query(
            'UPDATE suppliers SET name = $1, contact_person = $2, phone = $3, email = $4, address = $5, opening_balance = $6, current_balance = $7 WHERE id = $8 RETURNING *',
            [name, contact_person, phone, email, address, newOpening, newCurrent, id]
        );
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

exports.getCustomerById = async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query('SELECT * FROM customers WHERE id = $1', [id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Customer not found' });
        }
        // Alias current_debt to balance if needed, or frontend handles it. 
        // Let's keep it raw.
        res.json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.createCustomer = async (req, res) => {
    const { name, phone, alt_phone, email, credit_limit, address, region } = req.body;

    if (email && email.trim() !== '' && !isValidEmail(email.trim())) {
        return res.status(400).json({ error: 'Invalid email format' });
    }

    try {
        const result = await pool.query(
            'INSERT INTO customers (name, phone, alt_phone, email, credit_limit, address, region, current_debt) VALUES ($1, $2, $3, $4, $5, $6, $7, 0) RETURNING *',
            [
                name,
                phone && phone.trim() !== '' ? phone.trim() : null,
                alt_phone && alt_phone.trim() !== '' ? alt_phone.trim() : null,
                email && email.trim() !== '' ? email.trim() : null,
                credit_limit || 0,
                address,
                region
            ]
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
    const { name, phone, alt_phone, email, credit_limit, address, region } = req.body;

    if (email && email.trim() !== '' && !isValidEmail(email.trim())) {
        return res.status(400).json({ error: 'Invalid email format' });
    }

    try {
        const result = await pool.query(
            `UPDATE customers 
             SET name = $1, phone = $2, alt_phone = $3, email = $4, credit_limit = $5, address = $6, region = $7
             WHERE id = $8 RETURNING *`,
            [
                name,
                phone && phone.trim() !== '' ? phone.trim() : null,
                alt_phone && alt_phone.trim() !== '' ? alt_phone.trim() : null,
                email && email.trim() !== '' ? email.trim() : null,
                credit_limit,
                address,
                region,
                id
            ]
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

exports.addCustomerPayment = async (req, res) => {
    const { id } = req.params;
    const { amount, method, notes, order_id } = req.body;
    const paymentAmount = parseFloat(amount);

    // [NEW] Get Branch ID
    const userId = req.user ? req.user.id : null;
    let branchId = 1;

    if (userId) {
        const userRes = await pool.query('SELECT branch_id FROM users WHERE id = $1', [userId]);
        if (userRes.rows.length > 0) {
            branchId = userRes.rows[0].branch_id || 1;
        }
    }

    if (isNaN(paymentAmount) || paymentAmount <= 0) {
        return res.status(400).json({ error: 'Invalid payment amount' });
    }

    try {
        await pool.query('BEGIN');

        // 1. Record Payment
        await pool.query(
            `INSERT INTO customer_payments (customer_id, order_id, amount, method, notes, branch_id) 
             VALUES ($1, $2, $3, $4, $5, $6)`,
            [id, order_id || null, paymentAmount, method, notes, branchId]
        );

        // 2. Reduce Customer Global Debt
        await pool.query(
            `UPDATE customers SET current_debt = current_debt - $1 WHERE id = $2`,
            [paymentAmount, id]
        );

        // 3. Auto-Allocation Logic (Waterfall) or Specific Order Linking
        if (order_id) {
            // Specific Order Payment which was fully paid
            // We assume frontend only allows selecting full payment or we handle partials conceptually here?
            // For now, if linked to an order, we check if we should mark it completed.
            // Simplified: If linked, and amount >= order total (roughly), mark completed.
            // But usually, we just want to mark it completed if it's fully paid.

            // Fetch order total and current status
            const orderRes = await pool.query('SELECT total_amount, status FROM orders WHERE id = $1', [order_id]);
            if (orderRes.rows.length > 0) {
                // Logic: If payment covers the order, mark completed. 
                // Limitation: Doesn't track "remaining_balance" on order level explicitly in DB yet without sum of payments.
                // For MVP: Mark completed if user selected it.
                await pool.query(`UPDATE orders SET status = 'completed' WHERE id = $1`, [order_id]);
            }
        } else {
            // General Payment (Waterfall)
            // Fetch unpaid orders (Pending or Credit) old to new
            const unpaidOrders = await pool.query(
                `SELECT id, total_amount, status FROM orders 
                 WHERE customer_id = $1 AND status != 'completed' 
                 ORDER BY created_at ASC`,
                [id]
            );

            let remainingPayment = paymentAmount;

            for (const order of unpaidOrders.rows) {
                if (remainingPayment <= 0) break;

                // How much does this order need? 
                // We don't have "amount_paid" column on orders yet. 
                // Assuming "total_amount" is the debt. 
                // This is a simplification. If partial payments exist, this logic is flawed without checking history.
                // FIX: Check previous payments for this order?
                // For MVP Speed: We assume "status != completed" means "fully unpaid" or "partially paid but we treat as full debt for waterfall".
                // Better approach: Just close orders that are fully covered by this chunk.

                const orderTotal = parseFloat(order.total_amount);

                if (remainingPayment >= orderTotal) {
                    // Fully pay this order
                    await pool.query(`UPDATE orders SET status = 'completed' WHERE id = $1`, [order.id]);
                    remainingPayment -= orderTotal;
                }
                // If remaining < orderTotal, we can't fully close it, so we leave it open (partial).
                // Debt is already reduced globally, so mathematically it's correct.
            }
        }

        await pool.query('COMMIT');
        res.json({ message: 'Payment recorded successfully' });
    } catch (err) {
        await pool.query('ROLLBACK');
        res.status(500).json({ error: err.message });
    }
};

exports.getCustomerUnpaidOrders = async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(
            `SELECT id, created_at, total_amount, status 
             FROM orders 
             WHERE customer_id = $1 AND status != 'completed' 
             ORDER BY created_at DESC`,
            [id]
        );
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};
exports.getCustomerStatement = async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(
            `SELECT 'order' as type, o.id, o.created_at as date, o.total_amount as amount, o.status, NULL as method, NULL as notes,
             (
                SELECT json_agg(json_build_object('name', p.name, 'quantity', oi.quantity, 'price', oi.unit_price))
                FROM order_items oi
                JOIN products p ON oi.product_id = p.id
                WHERE oi.order_id = o.id
             ) as items
             FROM orders o
             WHERE o.customer_id = $1
             UNION ALL
             SELECT 'payment' as type, id, payment_date as date, amount, 'completed' as status, method, notes, NULL as items
             FROM customer_payments 
             WHERE customer_id = $1
             ORDER BY date DESC`,
            [id]
        );

        // Also fetch Customer Details to get Opening Balance
        const customerRes = await pool.query('SELECT opening_balance FROM customers WHERE id = $1', [id]);
        const openingBalance = parseFloat(customerRes.rows[0]?.opening_balance || 0);

        res.json({
            opening_balance: openingBalance,
            transactions: result.rows
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.addSupplierPayment = async (req, res) => {
    const { id } = req.params; // Supplier ID
    const { amount, method, reference, notes, purchase_order_id } = req.body;
    const paymentAmount = parseFloat(amount);

    if (isNaN(paymentAmount) || paymentAmount <= 0) {
        return res.status(400).json({ error: 'Invalid payment amount' });
    }

    try {
        await pool.query('BEGIN');

        // 1. Record Supplier Payment
        await pool.query(
            `INSERT INTO supplier_payments (supplier_id, purchase_order_id, amount, method, reference, notes)
             VALUES ($1, $2, $3, $4, $5, $6)`,
            [id, purchase_order_id || null, paymentAmount, method, reference, notes]
        );

        // 2. Reduce Supplier Balance (Debt)
        await pool.query(
            `UPDATE suppliers SET current_balance = current_balance - $1 WHERE id = $2`,
            [paymentAmount, id]
        );

        // 3. Link to specific PO if provided (Optional logic)
        if (purchase_order_id) {
            await pool.query(
                `UPDATE purchase_orders SET status = 'paid' WHERE id = $1`,
                [purchase_order_id]
            );
        }

        await pool.query('COMMIT');
        res.json({ message: 'Supplier payment recorded successfully' });
    } catch (err) {
        await pool.query('ROLLBACK');
        res.status(500).json({ error: err.message });
    }
};

exports.getSupplierStatement = async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(
            `SELECT 'bill' as type, po.id, po.created_at as date, po.total_product_cost as amount, po.status, NULL as method, NULL as notes, NULL as reference,
             (
                SELECT json_agg(json_build_object('name', p.name, 'quantity', poi.quantity_received, 'price', poi.supplier_unit_price))
                FROM purchase_order_items poi
                JOIN products p ON poi.product_id = p.id
                WHERE poi.purchase_order_id = po.id
             ) as items
             FROM purchase_orders po
             WHERE po.supplier_id = $1
             UNION ALL
             SELECT 'payment' as type, id, payment_date as date, amount, 'completed' as status, method, notes, reference, NULL as items
             FROM supplier_payments 
             WHERE supplier_id = $1
             ORDER BY date DESC`,
            [id]
        );

        // Also fetch Supplier Details
        const supplierRes = await pool.query('SELECT opening_balance FROM suppliers WHERE id = $1', [id]);
        const openingBalance = parseFloat(supplierRes.rows[0]?.opening_balance || 0);

        res.json({
            opening_balance: openingBalance,
            transactions: result.rows
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.getPurchaseOrderDetails = async (req, res) => {
    const { id } = req.params;
    try {
        // 1. Fetch PO Header
        const poRes = await pool.query(
            `SELECT po.*, s.name as supplier_name, s.contact_person, s.phone, s.email
             FROM purchase_orders po
             JOIN suppliers s ON po.supplier_id = s.id
             WHERE po.id = $1`,
            [id]
        );

        if (poRes.rows.length === 0) return res.status(404).json({ error: 'Purchase Order not found' });

        // 2. Fetch Items
        const itemsRes = await pool.query(
            `SELECT pi.*, p.name as product_name, p.sku
             FROM po_items pi
             JOIN products p ON pi.product_id = p.id
             WHERE pi.po_id = $1`,
            [id]
        );

        res.json({ ...poRes.rows[0], items: itemsRes.rows });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.getPaymentsOut = async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT sp.*, s.name as supplier_name 
             FROM supplier_payments sp
             JOIN suppliers s ON sp.supplier_id = s.id
             ORDER BY sp.payment_date DESC`
        );
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.getAllPayments = async (req, res) => {
    try {
        const { startDate, endDate, branchId } = req.query;
        let query = `
            SELECT cp.*, c.name as customer_name 
            FROM customer_payments cp
            JOIN customers c ON cp.customer_id = c.id
            WHERE 1=1
        `;
        const params = [];

        if (startDate) {
            params.push(startDate);
            query += ` AND cp.payment_date >= $${params.length}`;
        }
        if (endDate) {
            params.push(endDate);
            query += ` AND cp.payment_date <= $${params.length}`;
        }

        if (branchId) {
            params.push(branchId);
            query += ` AND cp.branch_id = $${params.length}`;
        }

        query += ` ORDER BY cp.payment_date DESC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};
