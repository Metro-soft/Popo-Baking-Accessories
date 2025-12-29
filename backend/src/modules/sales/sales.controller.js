const db = require('../../config/db');

exports.processTransaction = async (req, res) => {
    const { customerId, items, payments, discountAmount, discountReason, isHold } = req.body; // Added new fields

    // 1. Validation
    if (!items || !Array.isArray(items) || items.length === 0) {
        return res.status(400).json({ error: 'No items in cart' });
    }
    if (!isHold && (!payments || !Array.isArray(payments) || payments.length === 0)) {
        return res.status(400).json({ error: 'No payments provided for completed order' });
    }

    const client = await db.pool.connect();

    try {
        await client.query('BEGIN');

        // [NEW] Get User Branch or Default
        // We assume req.user is set by auth middleware. 
        const userId = req.user ? req.user.id : null;
        let branchId = 1; // Default to Head Office

        if (userId) {
            const userRes = await client.query('SELECT branch_id FROM users WHERE id = $1', [userId]);
            if (userRes.rows.length > 0) {
                branchId = userRes.rows[0].branch_id || 1;
            }
        }
        let orderTotal = 0;
        let depositTotal = 0;
        // Discount logic
        const discount = parseFloat(discountAmount) || 0;
        if (discount < 0) throw new Error('Discount cannot be negative');

        for (const item of items) {
            if (item.quantity === 0) throw new Error(`Invalid Quantity for Product ${item.productId}`);
            orderTotal += (item.quantity * item.unitPrice); // Quantity can be negative for returns
            if (item.type === 'asset_rental') {
                depositTotal += (item.depositAmount || 0);
                orderTotal += (item.depositAmount || 0);
            }
        }

        // Apply discount (ensure total doesn't go below 0 unless it's a net refund)
        // If orderTotal is negative (Net Return), discount shouldn't apply usually, but let's allow flexibility.
        orderTotal -= discount;

        // 3. Create Order
        // Status: 'held' if parking, else 'completed'
        const orderStatus = isHold ? 'held' : 'completed';

        const orderRes = await client.query(
            `INSERT INTO orders (customer_id, total_amount, total_deposit, status, discount_amount, discount_reason, is_hold, branch_id) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
            [customerId || null, orderTotal, depositTotal, orderStatus, discount, discountReason || null, isHold || false, branchId]
        );
        const orderId = orderRes.rows[0].id;

        // 4. Process Items (The "Smart Switch")
        for (const item of items) {
            const { productId, quantity, type, unitPrice, serialNumber, depositAmount } = item;
            const subtotal = (quantity * unitPrice) + (depositAmount || 0);

            // A. Insert Line Item
            await client.query(
                `INSERT INTO order_items 
                 (order_id, product_id, quantity, unit_price, subtotal, type, rental_serial_number, rental_deposit)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
                [orderId, productId, quantity, unitPrice, subtotal, type, serialNumber || null, depositAmount || 0]
            );

            // B. Inventory Logic Change based on Type
            // SKIP inventory deduction if order is HELD
            if (isHold) continue;

            if (type === 'retail') {
                // RETAIL LOGIC (Handle Returns: Negative Quantity)

                if (quantity < 0) {
                    // RETURN: INCREASE STOCK
                    const absQty = Math.abs(quantity);
                    const latestBatch = await client.query(
                        `SELECT id FROM inventory_batches WHERE product_id = $1 ORDER BY received_at DESC LIMIT 1`,
                        [productId]
                    );

                    if (latestBatch.rows.length > 0) {
                        await client.query(
                            `UPDATE inventory_batches SET quantity_remaining = quantity_remaining + $1 WHERE id = $2`,
                            [absQty, latestBatch.rows[0].id]
                        );
                    } else {
                        console.warn(`[RETURN] No batch found for returned product ${productId}`);
                    }

                    // [NEW] Log Return
                    await client.query(
                        `INSERT INTO stock_movements (product_id, type, quantity, reason, reference_id)
                         VALUES ($1, 'return', $2, 'Order Return', $3)`,
                        [productId, absQty, orderId]
                    );

                } else {
                    // SALE: DECREASE STOCK (Existing Logic)
                    // Find batches with stock
                    // SALE: DECREASE STOCK (Existing Logic)
                    // Use the branchId fetched at the start


                    // Find batches with stock AT THIS BRANCH
                    const batches = await client.query(
                        `SELECT id, quantity_remaining FROM inventory_batches 
                        WHERE product_id = $1 AND quantity_remaining > 0 AND branch_id = $2
                        ORDER BY received_at ASC`,
                        [productId, branchId]
                    );


                    let qtyToDeduct = quantity;
                    for (const batch of batches.rows) {
                        if (qtyToDeduct <= 0) break;

                        const deduct = Math.min(batch.quantity_remaining, qtyToDeduct);

                        await client.query(
                            `UPDATE inventory_batches SET quantity_remaining = quantity_remaining - $1 WHERE id = $2`,
                            [deduct, batch.id]
                        );

                        qtyToDeduct -= deduct;
                    }

                    if (qtyToDeduct > 0) {
                        console.warn(`[STOCK] Product ${productId} went negative by ${qtyToDeduct}`);
                    }

                    // [NEW] Log Sale (Negative Quantity)
                    // We log the FULL quantity as sold, even if partially deducted (accounting wise)
                    // or strictly what was deducted? Typically sold amount.
                    await client.query(
                        `INSERT INTO stock_movements (product_id, type, quantity, reason, reference_id)
                         VALUES ($1, 'sale', $2, 'Order Sale', $3)`,
                        [productId, -quantity, orderId]
                    );
                }
            } else if (type === 'asset_rental') {
                // UPDATE ASSET STATUS
                // Note: We need a rental_assets table for serials.
                // If serialNumber provided, mark it rented.
                if (serialNumber) {
                    // Check if exists first (if we have that table seeded)
                    // For MVP, we might skip strict FK if table empty.
                    // But let's assume strictness.
                    // await client.query(`UPDATE rental_assets SET status = 'rented' WHERE serial_number = $1`, [serialNumber]);
                }

            } else if (type === 'service_print') {
                // DEDUCT RAW MATERIALS
                // Hardcoded Logic for A4/A5/A6 based on SKU or Name
                // We need to fetch SKU to know what it is.
                const prodQ = await client.query('SELECT sku FROM products WHERE id = $1', [productId]);
                const sku = prodQ.rows[0]?.sku;

                let paperSku = 'MAT-EDIBLE-A4'; // Default
                let deduction = 1.0;

                if (sku.includes('A5')) deduction = 0.5;
                if (sku.includes('A6')) deduction = 0.25;
                if (sku.includes('NON')) paperSku = 'MAT-GLOSSY-A4';

                // Find Raw Material ID
                const rawMat = await client.query('SELECT id FROM products WHERE sku = $1', [paperSku]);
                if (rawMat.rows.length > 0) {
                    const rawId = rawMat.rows[0].id;
                    // Deduct from batches (Same logic as Retail)
                    // ... (Repeating the loop logic slightly simplified for brevity)
                    await client.query(
                        `UPDATE inventory_batches 
                         SET quantity_remaining = quantity_remaining - $1 
                         WHERE product_id = $2 AND quantity_remaining > 0 
                         AND id = (SELECT id FROM inventory_batches WHERE product_id = $2 AND quantity_remaining > 0 LIMIT 1)`,
                        [deduction * quantity, rawId]
                    );
                }
            }
        }

        // 5. Process Payments - SKIP IF HELD
        if (!isHold && payments) {
            for (const p of payments) {
                await client.query(
                    `INSERT INTO payments (order_id, method, amount, reference_code) VALUES ($1, $2, $3, $4)`,
                    [orderId, p.method, p.amount, p.referenceCode || null]
                );
            }
        }

        await client.query('COMMIT');
        res.status(201).json({ message: 'Transaction Successful', orderId });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Transaction Error:', err);
        res.status(500).json({ error: err.message });
    } finally {
        client.release();
    }
};

exports.getSalesHistory = async (req, res) => {
    try {
        const { rows } = await db.query(`
            SELECT o.id, o.created_at, o.total_amount, o.status, 
                   c.name as customer_name
            FROM orders o
            LEFT JOIN customers c ON o.customer_id = c.id
            ORDER BY o.created_at DESC
            LIMIT 50
        `);
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch sales history' });
    }
};

exports.getOrderDetails = async (req, res) => {
    const { id } = req.params;
    try {
        const orderRes = await db.query(`
            SELECT o.*, c.name as customer_name, c.email, c.phone
            FROM orders o
            LEFT JOIN customers c ON o.customer_id = c.id
            WHERE o.id = $1
        `, [id]);

        if (orderRes.rows.length === 0) return res.status(404).json({ error: 'Order not found' });

        const itemsRes = await db.query(`
            SELECT oi.*, p.name as product_name
            FROM order_items oi
            JOIN products p ON oi.product_id = p.id
            WHERE oi.order_id = $1
        `, [id]);

        res.json({ ...orderRes.rows[0], items: itemsRes.rows });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch order details' });
    }
};
