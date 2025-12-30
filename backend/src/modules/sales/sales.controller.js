const db = require('../../config/db');

exports.processTransaction = async (req, res) => {
    const { customerId, items, payments, discountAmount, discountReason, isHold } = req.body;
    console.log('Processing Transaction - Payload:', JSON.stringify(req.body, null, 2));
    console.log('Extracted CustomerID:', customerId, 'Type:', typeof customerId);

    // 1. Validation
    if (!items || !Array.isArray(items) || items.length === 0) {
        return res.status(400).json({ error: 'No items in cart' });
    }

    // Allow empty payments ONLY if it's a hold OR if a customer is selected (Credit Sale)
    if (!isHold && (!payments || !Array.isArray(payments) || payments.length === 0)) {
        if (!customerId) {
            return res.status(400).json({ error: 'No payments provided. For Credit/Pay Later, a customer must be selected.' });
        }
        // If customerId is present, we proceed (assuming it's a credit sale, logic below handles balance)
    }

    const client = await db.pool.connect();

    try {
        await client.query('BEGIN');

        // [NEW] Get User Branch or Default
        const userId = req.user ? req.user.id : null;
        let branchId = 1; // Default

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
            orderTotal += (item.quantity * item.unitPrice);
            if (item.type === 'asset_rental') {
                depositTotal += (item.depositAmount || 0);
                orderTotal += (item.depositAmount || 0);
            }
        }

        // Apply discount
        orderTotal -= discount;
        const totalPayable = orderTotal; // Keep track of final bill

        // 2. Validate Payment / Credit Logic
        // Calculate Total Paid
        let totalPaid = 0;
        if (payments && Array.isArray(payments)) {
            totalPaid = payments.reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);
        }

        const balance = totalPayable - totalPaid;
        const isCreditSale = balance > 0; // If they paid LESS than total, it's credit/debt.

        // [CRITICAL FIX] If Credit Sale, Customer is REQUIRED.
        if (isCreditSale && !customerId) {
            throw new Error('Customer is required for Credit/Pay Later sales. Please register "Walk-in" as a customer if you want to offer debt.');
        }

        // 3. Create Order
        // Status: 'held' if parking. 
        // If Credit Sale (balance > 0) -> 'pending_payment'
        // If Full Paid -> 'completed'
        let orderStatus = isHold ? 'held' : 'completed';
        if (!isHold && isCreditSale) {
            orderStatus = 'pending_payment';
        }

        const orderRes = await client.query(
            `INSERT INTO orders (customer_id, total_amount, total_deposit, status, discount_amount, discount_reason, is_hold, branch_id) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
            [customerId || null, orderTotal, depositTotal, orderStatus, discount, discountReason || null, isHold || false, branchId]
        );
        const orderId = orderRes.rows[0].id;

        // 4. Process Items (Inventory Deduction)
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
                    }
                    await client.query(
                        `INSERT INTO stock_movements (product_id, type, quantity, reason, reference_id)
                         VALUES ($1, 'return', $2, 'Order Return', $3)`,
                        [productId, absQty, orderId]
                    );

                } else {
                    // SALE: DECREASE STOCK
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

                    await client.query(
                        `INSERT INTO stock_movements (product_id, type, quantity, reason, reference_id)
                         VALUES ($1, 'sale', $2, 'Order Sale', $3)`,
                        [productId, -quantity, orderId]
                    );
                }
            } else if (type === 'service_print') {
                // DEDUCT RAW MATERIALS (Paper) logic same as before...
                // (Snippet omitted for brevity in diff, assume logic holds or copied if replacing block heavily)
                const prodQ = await client.query('SELECT sku FROM products WHERE id = $1', [productId]);
                const sku = prodQ.rows[0]?.sku;
                let paperSku = 'MAT-EDIBLE-A4';
                let deduction = 1.0;
                if (sku && sku.includes('A5')) deduction = 0.5;
                if (sku && sku.includes('A6')) deduction = 0.25;
                if (sku && sku.includes('NON')) paperSku = 'MAT-GLOSSY-A4';

                const rawMat = await client.query('SELECT id FROM products WHERE sku = $1', [paperSku]);
                if (rawMat.rows.length > 0) {
                    const rawId = rawMat.rows[0].id;
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

        // 5. Customer Profile Update (Steps: Debt & Points)
        if (!isHold && customerId) {
            // A. Update Debt if Balance > 0
            if (balance > 0) {
                await client.query(
                    `UPDATE customers SET current_debt = current_debt + $1 WHERE id = $2`,
                    [balance, customerId]
                );
            }

            // B. Add Points if Fully Paid (balance <= 0)
            // Logic: 1 Point per 100 KES spent
            if (balance <= 0 && totalPayable > 0) {
                const pointsEarned = Math.floor(totalPayable / 100);
                if (pointsEarned > 0) {
                    await client.query(
                        `UPDATE customers SET points = points + $1 WHERE id = $2`,
                        [pointsEarned, customerId]
                    );
                }
            }
        }

        // 6. Process Payments
        if (!isHold && payments) {
            for (const p of payments) {
                // A. Record in Order Payments (Link to specific order)
                await client.query(
                    `INSERT INTO payments (order_id, method, amount, reference_code) VALUES ($1, $2, $3, $4)`,
                    [orderId, p.method, p.amount, p.referenceCode || null]
                );

                // B. Record in Customer Ledger (Unified Transaction History)
                // We only record in ledger if there is a customer attached.
                // Note: We do NOT update debt here, because the "balance" logic above already handled the net debt change.
                if (customerId) {
                    await client.query(
                        `INSERT INTO customer_payments (customer_id, order_id, amount, method, notes, payment_date) 
                         VALUES ($1, $2, $3, $4, $5, NOW())`,
                        [customerId, orderId, p.amount, p.method, `POS Sale #${orderId}`]
                    );
                }
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
