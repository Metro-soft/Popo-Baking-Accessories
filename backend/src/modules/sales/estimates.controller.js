const db = require('../../config/db');

exports.createEstimate = async (req, res) => {
    const { customerId, items, notes, validUntil } = req.body;
    const branchId = req.user.branch_id || 1; // Default to user's branch

    if (!items || !Array.isArray(items) || items.length === 0) {
        return res.status(400).json({ error: 'No items in estimate' });
    }

    const client = await db.pool.connect();
    try {
        await client.query('BEGIN');

        // 1. Calculate Total (Snapshot Prices)
        let totalAmount = 0;
        const processedItems = [];

        for (const item of items) {
            const { productId, quantity, unitPrice } = item;
            const subtotal = quantity * unitPrice;
            totalAmount += subtotal;
            processedItems.push({ productId, quantity, unitPrice, subtotal });
        }

        // 2. Insert Estimate
        const estRes = await client.query(
            `INSERT INTO estimates (customer_id, branch_id, total_amount, notes, valid_until, status) 
             VALUES ($1, $2, $3, $4, $5, 'pending') RETURNING id`,
            [customerId || null, branchId, totalAmount, notes, validUntil]
        );
        const estimateId = estRes.rows[0].id;

        // 3. Insert Items
        for (const item of processedItems) {
            await client.query(
                `INSERT INTO estimate_items (estimate_id, product_id, quantity, unit_price, subtotal)
                 VALUES ($1, $2, $3, $4, $5)`,
                [estimateId, item.productId, item.quantity, item.unitPrice, item.subtotal]
            );
        }

        await client.query('COMMIT');
        res.status(201).json({ message: 'Estimate Created', id: estimateId });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Create Estimate Error:', err);
        res.status(500).json({ error: 'Failed to create estimate' });
    } finally {
        client.release();
    }
};

exports.getEstimates = async (req, res) => {
    try {
        const { branchId, startDate, endDate, status } = req.query;
        let query = `
            SELECT e.*, c.full_name as customer_name 
            FROM estimates e
            LEFT JOIN users c ON e.customer_id = c.id
            WHERE 1=1
        `;
        const params = [];
        let pIdx = 1;

        if (branchId) {
            query += ` AND e.branch_id = $${pIdx++}`;
            params.push(branchId);
        }
        if (status) {
            query += ` AND e.status = $${pIdx++}`;
            params.push(status);
        }
        if (startDate) {
            query += ` AND e.created_at >= $${pIdx++}`;
            params.push(startDate);
        }

        query += ` ORDER BY e.created_at DESC LIMIT 50`;

        const result = await db.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Get Estimates Error:', err);
        res.status(500).json({ error: 'Failed to fetch estimates' });
    }
};

exports.getEstimateDetails = async (req, res) => {
    const { id } = req.params;
    try {
        const estRes = await db.query(`
            SELECT e.*, c.full_name as customer_name, c.phone, c.email
            FROM estimates e
            LEFT JOIN users c ON e.customer_id = c.id
            WHERE e.id = $1
        `, [id]);

        if (estRes.rows.length === 0) return res.status(404).json({ error: 'Estimate not found' });

        const itemsRes = await db.query(`
            SELECT ei.*, p.name as product_name, p.sku
            FROM estimate_items ei
            JOIN products p ON ei.product_id = p.id
            WHERE ei.estimate_id = $1
        `, [id]);

        res.json({ ...estRes.rows[0], items: itemsRes.rows });
    } catch (err) {
        console.error('Get Details Error:', err);
        res.status(500).json({ error: 'Failed to load estimate details' });
    }
};

exports.deleteEstimate = async (req, res) => {
    const { id } = req.params;
    try {
        // Only allow deleting pending estimates?
        await db.query(`DELETE FROM estimates WHERE id = $1`, [id]);
        res.json({ message: 'Estimate deleted' });
    } catch (err) {
        console.error('Delete Estimate Error:', err);
        res.status(500).json({ error: 'Failed to delete estimate' });
    }
};

exports.convertToOrder = async (req, res) => {
    const { id } = req.params;
    const { paymentMethod, amountPaid } = req.body; // Basic info needed to start the order

    // This is complex. We essentially just call the main sales transaction logic...
    // BUT since we have that large `processTransaction` in sales.controller.js, 
    // we should ideally reuse it or call it internally.
    // For now, let's just mark it converted and return the items so Frontend can populate POS?
    // User requested "Convert to Sale" Action.

    // Strategy:
    // 1. Updates status to 'converted'.
    // 2. Returns the items payload so the Frontend receives it and instantly populates the POS cart.
    //    This is safer than duplicating the complex "process transaction" logic here.

    try {
        await db.query(`UPDATE estimates SET status = 'converted' WHERE id = $1`, [id]);

        // Fetch items to return to FE
        const itemsRes = await db.query(`
            SELECT ei.product_id, ei.quantity, ei.unit_price 
            FROM estimate_items ei 
            WHERE ei.estimate_id = $1
        `, [id]);

        res.json({
            message: 'Estimate Converted',
            items: itemsRes.rows.map(i => ({
                productId: i.product_id,
                quantity: i.quantity,
                unitPrice: parseFloat(i.unit_price) // Ensure float
            }))
        });

    } catch (err) {
        console.error('Convert Error:', err);
        res.status(500).json({ error: 'Failed to convert estimate' });
    }
};

exports.updateEstimate = async (req, res) => {
    const { id } = req.params;
    const { customerId, items, notes, validUntil } = req.body;
    const branchId = req.user.branch_id || 1;

    if (!items || !Array.isArray(items) || items.length === 0) {
        return res.status(400).json({ error: 'No items in estimate' });
    }

    const client = await db.pool.connect();
    try {
        await client.query('BEGIN');

        // 1. Calculate New Total
        let totalAmount = 0;
        const processedItems = [];
        for (const item of items) {
            const { productId, quantity, unitPrice } = item;
            const subtotal = quantity * unitPrice;
            totalAmount += subtotal;
            processedItems.push({ productId, quantity, unitPrice, subtotal });
        }

        // 2. Update Estimate Record
        await client.query(
            `UPDATE estimates 
             SET customer_id = $1, total_amount = $2, notes = $3, valid_until = $4, updated_at = NOW()
             WHERE id = $5`,
            [customerId || null, totalAmount, notes, validUntil, id]
        );

        // 3. Replace Items (Delete all & Re-insert)
        await client.query(`DELETE FROM estimate_items WHERE estimate_id = $1`, [id]);

        for (const item of processedItems) {
            await client.query(
                `INSERT INTO estimate_items (estimate_id, product_id, quantity, unit_price, subtotal)
                 VALUES ($1, $2, $3, $4, $5)`,
                [id, item.productId, item.quantity, item.unitPrice, item.subtotal]
            );
        }

        await client.query('COMMIT');
        res.json({ message: 'Estimate Updated', id });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Update Estimate Error:', err);
        res.status(500).json({ error: 'Failed to update estimate' });
    } finally {
        client.release();
    }
};
