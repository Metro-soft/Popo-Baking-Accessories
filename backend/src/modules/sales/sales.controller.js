const db = require('../../config/db');
const activityService = require('../core/activity.service');

exports.processTransaction = async (req, res) => {
    const { customerId, items, payments, discountAmount, discountReason, isHold, depositChange } = req.body;
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
        // [NEW] Tax Logic
        const tax = parseFloat(req.body.taxAmount) || 0;

        const { isDispatch, deliveryFee = 0, packagingFee = 0 } = req.body; // [NEW] Dispatch Check

        let orderTotal = 0;
        let depositTotal = 0;
        // Discount logic
        const discount = parseFloat(discountAmount) || 0;
        if (discount < 0) throw new Error('Discount cannot be negative');

        for (const item of items) {
            if (item.quantity === 0) throw new Error(`Invalid Quantity for Product ${item.productId}`);
            const price = parseFloat(item.unitPrice); // Ensure float
            orderTotal += (item.quantity * price);
            if (item.type === 'asset_rental') {
                depositTotal += (item.depositAmount || 0);
                orderTotal += (item.depositAmount || 0);
            }
        }

        orderTotal += tax;
        orderTotal -= discount;

        const totalPayable = orderTotal; // Keep track of final bill

        // 2. Validate Payment / Credit Logic
        // Calculate Total Paid
        let totalPaid = 0;
        if (payments && Array.isArray(payments)) {
            totalPaid = payments.reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);
        }

        const balance = totalPayable - totalPaid;
        const isCreditSale = balance > 0.01; // Tolerance

        // [CRITICAL FIX] If Credit Sale, Customer is REQUIRED.
        if (isCreditSale && !customerId) {
            throw new Error('Customer is required for Credit/Pay Later sales. Please register "Walk-in" as a customer if you want to offer debt.');
        }

        // 3. Create Order
        // [MODIFIED] Dispatch & Payment Status Logic
        let orderStatus = isHold ? 'held' : 'completed';
        let dispatchStatus = null;
        let deliveryDetails = null;

        if (isDispatch) {
            dispatchStatus = 'pending'; // Moves to Dispatch Screen
            deliveryDetails = {
                delivery_fee: deliveryFee,
                packaging_fee: packagingFee,
                source: 'POS'
            };
        }

        if (!isHold) {
            // Logic: 
            // 1. Paid >= Total -> 'completed'
            // 2. 0 < Paid < Total -> 'partial_payment'
            // 3. Paid == 0 -> 'pending_payment' (Credit)

            // Tolerance for float comparison
            if (totalPaid >= totalPayable - 0.01) {
                orderStatus = 'completed';
            } else if (totalPaid > 0) {
                orderStatus = 'partial_payment';
            } else {
                orderStatus = 'pending_payment'; // Credit / Unpaid
            }
        }

        const orderRes = await client.query(
            `INSERT INTO orders (customer_id, total_amount, total_deposit, status, discount_amount, discount_reason, is_hold, branch_id, tax_amount, dispatch_status, delivery_details) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING id`,
            [customerId || null, orderTotal, depositTotal, orderStatus, discount, discountReason || null, isHold || false, branchId, tax, dispatchStatus, deliveryDetails]
        );
        const orderId = orderRes.rows[0].id;

        // ... [Items Processing Logic same as before] ...
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

            // B. Inventory Logic (Hold check etc.)
            if (isHold) continue;

            // [FIX] Skip Stock for Custom Items (ID -1)
            if (parseInt(productId) === -1) continue;

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
                        throw new Error(`Insufficient stock for Product ${productId}. Missing ${qtyToDeduct} items.`);
                    }

                    await client.query(
                        `INSERT INTO stock_movements (product_id, type, quantity, reason, reference_id)
                         VALUES ($1, 'sale', $2, 'Order Sale', $3)`,
                        [productId, -quantity, orderId]
                    );
                }
            } else if (type === 'service_print') {
                // Print Logic (Simplification: assuming same logic as original file)
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

        // 5. Customer Profile Update (Debt, Points, & Wallet)
        if (!isHold && customerId) {
            // A. Update Debt if Balance > 0
            if (balance > 0.01) {
                await client.query(
                    `UPDATE customers SET current_debt = current_debt + $1 WHERE id = $2`,
                    [balance, customerId]
                );
            }
            // [NEW] Pay Old Debt Logic
            else if (balance < -0.01) {
                // User Overpaid (Excess)
                let excess = Math.abs(balance);
                console.log(`Overpayment Detected: ${excess}. Checking Debt...`);

                // Get current debt
                const custRes = await client.query('SELECT current_debt FROM customers WHERE id = $1', [customerId]);
                let currentDebt = parseFloat(custRes.rows[0].current_debt) || 0;
                console.log(`Current Debt: ${currentDebt}`);

                if (currentDebt > 0) {
                    // Pay off debt first
                    const debtPayment = Math.min(excess, currentDebt);
                    await client.query(
                        `UPDATE customers SET current_debt = current_debt - $1 WHERE id = $2`,
                        [debtPayment, customerId]
                    );
                    excess -= debtPayment;
                    console.log(`Auto-paid Debt: ${debtPayment}. Remaining Excess: ${excess}`);
                }

                // Remaining Excess -> Wallet (if requested)
                console.log(`Checking Wallet Deposit. DepositChange: ${depositChange}, Excess > 0: ${excess > 0}`);
                if (depositChange && excess > 0) {
                    console.log(`Depositing Change ${excess} to Wallet for Customer ${customerId}`);
                    await client.query(
                        `UPDATE customers SET wallet_balance = COALESCE(wallet_balance, 0) + $1 WHERE id = $2`,
                        [excess, customerId]
                    );

                    await client.query(
                        `INSERT INTO customer_payments (customer_id, order_id, amount, method, notes, payment_date) 
                         VALUES ($1, $2, $3, 'Wallet Deposit', 'Change from Order #${orderId}', NOW())`,
                        [customerId, orderId, excess]
                    );
                }
            }

            // B. Add Points if Fully Paid (balance <= 0)
            if (balance <= 0.01 && totalPayable > 0) {
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
                // Combine Ref + Phone if provided
                let finalRef = p.referenceCode || null;
                if (p.phoneNumber && finalRef) {
                    finalRef = `${finalRef} (${p.phoneNumber})`;
                } else if (p.phoneNumber) {
                    finalRef = `Phone: ${p.phoneNumber}`;
                }

                // A. Record in Order Payments (Link to specific order)
                await client.query(
                    `INSERT INTO payments (order_id, method, amount, reference_code) VALUES ($1, $2, $3, $4)`,
                    [orderId, p.method, p.amount, finalRef]
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
                   c.name as customer_name,
                   (o.total_amount - COALESCE((SELECT SUM(amount) FROM payments WHERE order_id = o.id), 0)) as balance
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
            SELECT oi.*, 
                   p.name as product_name, p.sku, p.type, p.description, p.category, p.base_selling_price as unit_price_ref, p.cost_price, p.images
            FROM order_items oi
            JOIN products p ON oi.product_id = p.id
            WHERE oi.order_id = $1
        `, [id]);

        const paymentsRes = await db.query(`
            SELECT * FROM payments WHERE order_id = $1
        `, [id]);

        const payments = paymentsRes.rows;
        const totalPaid = payments.reduce((sum, p) => sum + parseFloat(p.amount), 0);
        const totalAmount = parseFloat(orderRes.rows[0].total_amount);
        const balance = totalAmount - totalPaid;

        res.json({
            ...orderRes.rows[0],
            items: itemsRes.rows,
            payments: payments,
            balance: balance,
            total_paid: totalPaid
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch order details' });
    }
};

exports.voidSale = async (req, res) => {
    const { id } = req.params;
    const client = await db.pool.connect();

    try {
        await client.query('BEGIN');

        // 1. Fetch Order
        const orderRes = await client.query('SELECT * FROM orders WHERE id = $1', [id]);
        if (orderRes.rows.length === 0) throw new Error('Order not found');
        const order = orderRes.rows[0];

        if (order.status === 'voided') throw new Error('Order is already voided');

        // 2. Update Status
        await client.query("UPDATE orders SET status = 'voided' WHERE id = $1", [id]);

        // 3. Reverse Stock
        const itemsRes = await client.query('SELECT * FROM order_items WHERE order_id = $1', [id]);

        for (const item of itemsRes.rows) {
            // Only Retail items affect stock (Service/Rental handled differently or ignored for stock)
            if (item.type === 'retail') {
                // Return to Inventory: Find latest batch and add back
                // We use ABS because quantity might be stored positively
                const qtyToReturn = parseFloat(item.quantity);

                // Find a batch to return to (Latest one)
                const latestBatch = await client.query(
                    `SELECT id FROM inventory_batches WHERE product_id = $1 ORDER BY received_at DESC LIMIT 1`,
                    [item.product_id]
                );

                if (latestBatch.rows.length > 0) {
                    await client.query(
                        `UPDATE inventory_batches SET quantity_remaining = quantity_remaining + $1 WHERE id = $2`,
                        [qtyToReturn, latestBatch.rows[0].id]
                    );
                } else {
                    // Critical: If no batch exists (rare), create a 'Returns' batch? 
                    // For now, if no batch exists, we can't increment. Log warning.
                    console.warn(`[VOID] No batch found for Product ${item.product_id}. Stock not restored.`);
                }

                // Log Movement
                await client.query(
                    `INSERT INTO stock_movements (product_id, type, quantity, reason, reference_id, branch_id)
                     VALUES ($1, 'adjustment', $2, 'Sale Voided', $3, $4)`,
                    [item.product_id, qtyToReturn, id, order.branch_id]
                );
            }
        }

        // 4. Finance Reversal (Optional: Clean up payments?)
        // Ideally, we mark payments as 'refunded' or create a negative transaction.
        // For simplicity now, we just void the order. The reports should filter out voided orders.
        // If we want cash drawer accuracy, we should insert a negative 'Refund' if it was paid?
        // Let's leave finance strict for now, just Voiding the Order removes it from Sales Reports usually.

        await client.query('COMMIT');
        res.json({ message: 'Sale voided successfully' });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Void Sale Error:', err);
        res.status(500).json({ error: err.message });
    } finally {
        client.release();
    }
};

exports.updateDispatchStatus = async (req, res) => {
    const { id } = req.params;
    const { status, deliveryDetails } = req.body;

    // Validate Status
    const validStatuses = ['pending', 'processing', 'released', 'delivered', 'cancelled'];
    if (!validStatuses.includes(status)) {
        return res.status(400).json({ error: 'Invalid dispatch status' });
    }

    try {
        // Update Query (Save delivery details if provided)
        let query = `UPDATE orders SET dispatch_status = $1`;
        let values = [status];
        let idx = 2;

        if (deliveryDetails) {
            // We merge existing details? Or overwrite? Overwrite is safer for now.
            query += `, delivery_details = $${idx}::jsonb`;
            values.push(JSON.stringify(deliveryDetails));
            idx++;
        }

        query += ` WHERE id = $${idx} RETURNING *`;
        values.push(id);

        const result = await db.query(query, values);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Order not found' });
        }

        res.json({ message: 'Dispatch status updated', order: result.rows[0] });

    } catch (err) {
        console.error('Update Dispatch Error:', err);
        res.status(500).json({ error: 'Server error updating dispatch' });
    }
};

exports.getDispatchOrders = async (req, res) => {
    try {
        const { rows } = await db.query(`
            SELECT o.*, c.name as customer_name, c.phone as customer_phone, c.address as customer_address, c.region as customer_region,
                   (SELECT json_agg(json_build_object('name', p.name, 'quantity', oi.quantity)) 
                    FROM order_items oi 
                    JOIN products p ON oi.product_id = p.id 
                    WHERE oi.order_id = o.id) as items_list,
                   (SELECT string_agg(CONCAT(p.name, ' x', oi.quantity), ', ') 
                    FROM order_items oi 
                    JOIN products p ON oi.product_id = p.id 
                    WHERE oi.order_id = o.id) as items_summary
            FROM orders o
            LEFT JOIN customers c ON o.customer_id = c.id
            WHERE o.dispatch_status IS NOT NULL
            ORDER BY o.created_at DESC
        `);
        res.json(rows);
    } catch (err) {
        console.error('Fetch Dispatch Error:', err);
        res.status(500).json({ error: 'Failed to fetch dispatch orders' });
    }
};

exports.updateSale = async (req, res) => {
    const { id } = req.params;
    const { customerId, items, payments, discountAmount, discountReason, isHold, depositChange, taxAmount } = req.body;

    // [NEW] Get User Branch
    const userId = req.user ? req.user.id : null;
    let branchId = 1;

    const client = await db.pool.connect();

    try {
        await client.query('BEGIN');

        // 1. Fetch Current Branch
        if (userId) {
            const userRes = await client.query('SELECT branch_id FROM users WHERE id = $1', [userId]);
            if (userRes.rows.length > 0) branchId = userRes.rows[0].branch_id || 1;
        }

        // 2. Snapshot Old State
        const oldOrderRes = await client.query('SELECT * FROM orders WHERE id = $1', [id]);
        if (oldOrderRes.rows.length === 0) throw new Error('Order not found');
        const oldOrder = oldOrderRes.rows[0];

        if (oldOrder.status === 'voided') throw new Error('Cannot update a voided order');

        // Calculate Old Debt Impact
        // Old Balance = Total - Paid
        const oldPaymentsRes = await client.query('SELECT amount FROM payments WHERE order_id = $1', [id]);
        const oldTotalPaid = oldPaymentsRes.rows.reduce((sum, p) => sum + parseFloat(p.amount), 0);
        const oldBalance = parseFloat(oldOrder.total_amount) - oldTotalPaid;

        // 3. Revert Old Impact

        // A. Stock Reversal (Retail Items Only)
        const oldItemsRes = await client.query('SELECT * FROM order_items WHERE order_id = $1', [id]);
        for (const item of oldItemsRes.rows) {
            if (item.type === 'retail') {
                // Find batch to return to
                const latestBatch = await client.query(
                    `SELECT id FROM inventory_batches WHERE product_id = $1 ORDER BY received_at DESC LIMIT 1`,
                    [item.product_id]
                );
                if (latestBatch.rows.length > 0) {
                    await client.query(
                        `UPDATE inventory_batches SET quantity_remaining = quantity_remaining + $1 WHERE id = $2`,
                        [item.quantity, latestBatch.rows[0].id]
                    );
                }

                await client.query(
                    `INSERT INTO stock_movements (product_id, type, quantity, reason, reference_id, branch_id)
                     VALUES ($1, 'correction_in', $2, 'Order Update Reversal', $3, $4)`,
                    [item.product_id, item.quantity, id, branchId]
                );
            }
            // Handle Print Service/Rentals if needed (Skipping for brevity as they are less strictly tracked or handled via simpler logic)
        }

        // B. Finance Reversal (Debt & Points)
        if (oldOrder.customer_id) {
            // Reverse Debt
            if (oldBalance > 0.01) {
                await client.query(
                    `UPDATE customers SET current_debt = current_debt - $1 WHERE id = $2`,
                    [oldBalance, oldOrder.customer_id]
                );
            }
            // Reverse Excess Payment (if OldBalance < 0, we assume it was handled, but ideally we reverse 'wallet' deposit if it happened? Too complex, let's assume debt only for now)

            // Reverse Points
            if (oldBalance <= 0.01 && oldOrder.total_amount > 0) {
                const pointsEarned = Math.floor(oldOrder.total_amount / 100);
                if (pointsEarned > 0) {
                    await client.query(
                        `UPDATE customers SET points = points - $1 WHERE id = $2`,
                        [pointsEarned, oldOrder.customer_id]
                    );
                }
            }
        }

        // 4. Calculate New State

        // Calculations
        const tax = parseFloat(taxAmount) || 0;
        const { isDispatch, deliveryFee = 0, packagingFee = 0 } = req.body;
        let orderTotal = 0;
        let depositTotal = 0;
        const discount = parseFloat(discountAmount) || 0;

        for (const item of items) {
            const price = parseFloat(item.unitPrice);
            orderTotal += (item.quantity * price);
            if (item.type === 'asset_rental') {
                depositTotal += (item.depositAmount || 0);
                orderTotal += (item.depositAmount || 0);
            }
        }
        orderTotal += tax;
        orderTotal -= discount;

        // Payments
        let newTotalPaid = oldTotalPaid; // Start with old payments
        // Add NEW payments if any
        if (payments && Array.isArray(payments)) {
            newTotalPaid += payments.reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);
        }

        const newBalance = orderTotal - newTotalPaid;

        // Status
        let orderStatus = isHold ? 'held' : 'completed';
        if (!isHold) {
            if (newTotalPaid >= orderTotal - 0.01) orderStatus = 'completed';
            else if (newTotalPaid > 0) orderStatus = 'partial_payment';
            else orderStatus = 'pending_payment';
        }

        // Dispatch
        let dispatchStatus = oldOrder.dispatch_status; // Keep old unless changed? Or re-evaluate?
        let deliveryDetails = oldOrder.delivery_details;
        if (isDispatch) {
            dispatchStatus = 'pending';
            deliveryDetails = {
                delivery_fee: deliveryFee,
                packaging_fee: packagingFee,
                source: 'POS_UPDATE'
            };
        }

        // 5. Update Order Record
        await client.query(
            `UPDATE orders 
             SET total_amount = $1, total_deposit = $2, status = $3, discount_amount = $4, 
                 discount_reason = $5, is_hold = $6, tax_amount = $7, dispatch_status = $8, delivery_details = $9, updated_at = NOW()
             WHERE id = $10`,
            [orderTotal, depositTotal, orderStatus, discount, discountReason || null, isHold || false, tax, dispatchStatus, deliveryDetails, id]
        );

        // 6. Replace Items
        await client.query('DELETE FROM order_items WHERE order_id = $1', [id]);

        for (const item of items) {
            const { productId, quantity, type, unitPrice, serialNumber, depositAmount } = item;
            const subtotal = (quantity * unitPrice) + (depositAmount || 0);

            // Insert
            await client.query(
                `INSERT INTO order_items 
                 (order_id, product_id, quantity, unit_price, subtotal, type, rental_serial_number, rental_deposit)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
                [id, productId, quantity, unitPrice, subtotal, type, serialNumber || null, depositAmount || 0]
            );

            // Deduct Stock
            if (!isHold && parseInt(productId) !== -1 && type === 'retail') {
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

                await client.query(
                    `INSERT INTO stock_movements (product_id, type, quantity, reason, reference_id, branch_id)
                         VALUES ($1, 'correction_out', $2, 'Order Update', $3, $4)`,
                    [productId, -quantity, id, branchId]
                );
            }
        }

        // 7. Apply New Finance Impact
        // Note: We use the OLD customer ID if provided, or the NEW one if changed (Support customer change?)
        // For simplicity, let's assume customer ID is same or updated.
        const finalCustomerId = customerId || oldOrder.customer_id;

        if (!isHold && finalCustomerId) {
            // Update Debt
            if (newBalance > 0.01) {
                await client.query(
                    `UPDATE customers SET current_debt = current_debt + $1 WHERE id = $2`,
                    [newBalance, finalCustomerId]
                );
            }

            // Update Points
            if (newBalance <= 0.01 && orderTotal > 0) {
                const pointsEarned = Math.floor(orderTotal / 100);
                if (pointsEarned > 0) {
                    await client.query(
                        `UPDATE customers SET points = points + $1 WHERE id = $2`,
                        [pointsEarned, finalCustomerId]
                    );
                }
            }
        }

        // 8. Record NEW Payments
        if (!isHold && payments) {
            for (const p of payments) {
                // Combine Ref + Phone
                let finalRef = p.referenceCode || null;
                if (p.phoneNumber && finalRef) finalRef = `${finalRef} (${p.phoneNumber})`;
                else if (p.phoneNumber) finalRef = `Phone: ${p.phoneNumber}`;

                await client.query(
                    `INSERT INTO payments (order_id, method, amount, reference_code) VALUES ($1, $2, $3, $4)`,
                    [id, p.method, p.amount, finalRef]
                );

                if (finalCustomerId) {
                    await client.query(
                        `INSERT INTO customer_payments (customer_id, order_id, amount, method, notes, payment_date) 
                         VALUES ($1, $2, $3, $4, $5, NOW())`,
                        [finalCustomerId, id, p.amount, p.method, `POS Update #${id}`]
                    );
                }
            }
        }

        // Log Activity
        await activityService.logAction(
            userId,
            'SALE_CREATED',
            'orders',
            orderId,
            { total: orderTotal, customer: customerId, items: items.length }
        );

        await client.query('COMMIT');

        console.log('Transaction Successfully Committed. Order ID:', orderId);

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Update Sale Error:', err);
        res.status(500).json({ error: err.message });
    } finally {
        client.release();
    }
};
