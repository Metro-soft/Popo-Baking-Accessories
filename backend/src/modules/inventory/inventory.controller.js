const db = require('../../config/db');

exports.receiveStock = async (req, res) => {
    const { supplierId, transportCost, packagingCost, items, branchId } = req.body;

    // 1. Validation
    if (!items || !Array.isArray(items) || items.length === 0) {
        return res.status(400).json({ error: 'No items provided' });
    }
    if (!supplierId) {
        return res.status(400).json({ error: 'Supplier is required' });
    }

    // Default to Branch 1 (Head Office) if not specified
    const targetBranchId = branchId || 1;

    const tCost = parseFloat(transportCost) || 0;
    const pCost = parseFloat(packagingCost) || 0;
    const totalExtraCost = tCost + pCost;

    const client = await db.pool.connect();

    try {
        await client.query('BEGIN');

        // 2. Step A: Calculate Total Product Value (Invoice Subtotal)
        let totalProductValue = 0;
        for (const item of items) {
            totalProductValue += (item.quantity * item.unitPrice);
        }

        if (totalProductValue <= 0) {
            throw new Error('Total product value must be greater than zero');
        }

        // 3. Create Purchase Order
        const poResult = await client.query(
            `INSERT INTO purchase_orders 
            (supplier_id, total_product_cost, transport_cost, packaging_cost, status, branch_id) 
            VALUES ($1, $2, $3, $4, 'received', $5) 
            RETURNING id`,
            [supplierId, totalProductValue, tCost, pCost, targetBranchId]
        );
        const poId = poResult.rows[0].id;

        const processedBatches = [];

        // 4. Step C: The Loop (Weighted Cost Distribution)
        for (const item of items) {
            const { productId, quantity, unitPrice, expiryDate } = item;

            // Current Item Value
            const itemTotalValue = quantity * unitPrice;

            // WEIGHT: (Item Value / Invoice Total)
            const weight = itemTotalValue / totalProductValue;

            // Allocated Extra Cost
            const allocatedExtraCost = totalExtraCost * weight;

            // Extra Cost Per Unit
            const extraCostPerUnit = allocatedExtraCost / quantity;

            // FINAL TRUE COST (LANDED COST)
            const finalTrueCost = unitPrice + extraCostPerUnit;

            // Insert PO Item
            await client.query(
                `INSERT INTO po_items (po_id, product_id, quantity_received, supplier_unit_price) 
                 VALUES ($1, $2, $3, $4)`,
                [poId, productId, quantity, unitPrice]
            );

            // Insert Inventory Batch (using FINAL TRUE COST)
            const batchResult = await client.query(
                `INSERT INTO inventory_batches (
                    product_id, 
                    batch_number, 
                    branch_id, 
                    quantity_initial, 
                    quantity_remaining, 
                    buying_price_unit, 
                    expiry_date
                ) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
                [
                    productId,
                    `PO-${poId}`,
                    targetBranchId,
                    quantity,
                    quantity,
                    finalTrueCost.toFixed(2),
                    expiryDate || null
                ]
            );
            processedBatches.push(batchResult.rows[0]);
        }

        // 5. Commit
        await client.query('COMMIT');

        console.log(`[INVENTORY] PO #${poId} processed. ${processedBatches.length} batches created.`);
        res.status(201).json({
            message: 'Stock received & Landed Cost calculated',
            poId,
            batches: processedBatches.length
        });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Landed Cost Error:', err);
        res.status(500).json({ error: err.message || 'Internal Server Error' });
    } finally {
        client.release();
    }
};

exports.getLowStockItems = async (req, res) => {
    try {
        const threshold = 10; // Default threshold, could be dynamic per product later
        const result = await db.query(`
            SELECT p.id, p.name, p.sku, COALESCE(SUM(ib.quantity_remaining), 0) as total_quantity
            FROM products p
            LEFT JOIN inventory_batches ib ON p.id = ib.product_id
            GROUP BY p.id, p.name, p.sku
            HAVING COALESCE(SUM(ib.quantity_remaining), 0) <= $1
            ORDER BY total_quantity ASC
        `, [threshold]);
        res.json(result.rows);
    } catch (err) {
        console.error('Low Stock Error:', err);
        res.status(500).json({ error: 'Failed to fetch low stock items' });
    }
};

exports.adjustStock = async (req, res) => {
    const { productId, quantityChange, reason } = req.body;
    // quantityChange: negative for shrinkage, positive for found stock
    if (!productId || !quantityChange || quantityChange === 0 || !reason) {
        return res.status(400).json({ error: 'Invalid adjustment data' });
    }

    const client = await db.pool.connect();
    try {
        await client.query('BEGIN');

        if (quantityChange < 0) {
            // REDUCE STOCK (FIFO - Oldest Batches First)
            let qtyToDeduct = Math.abs(quantityChange);

            const batches = await client.query(
                `SELECT id, quantity_remaining FROM inventory_batches 
                 WHERE product_id = $1 AND quantity_remaining > 0 
                 ORDER BY received_at ASC`,
                [productId]
            );

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
                // Force negative on the last batch or create a dummy negative batch?
                // For now, let's just warn but allow strict accounting if we wanted.
                // We will update the last batch to negative if needed to keep totals correct?
                // Or better yet, we just log the discrepancy.
                // Ideally systems block this, but for "Adjustment" we might need to force it.
                // Let's stop at 0 for batches but log the total.
            }

        } else {
            // INCREASE STOCK (Create a new "Adjustment" batch)
            await client.query(
                `INSERT INTO inventory_batches (
                    product_id, batch_number, location, 
                    quantity_initial, quantity_remaining, 
                    buying_price_unit, expiry_date
                ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
                [
                    productId,
                    `ADJ-${Date.now()}`,
                    'thika_store',
                    quantityChange,
                    quantityChange,
                    0.00, // Zero cost for found items? Or weighted avg? 0 for now.
                    null
                ]
            );
        }

        // Log the Transaction
        // Assuming we might have a stock_transactions table later, for now just console log.
        // Or if we want to be fancy, insert into a simple log table if exists.

        await client.query('COMMIT');
        res.json({ message: 'Stock adjusted successfully' });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Stock Adjustment Error:', err);
        res.status(500).json({ error: err.message });
    } finally {
        client.release();
    }
};

exports.createTransfer = async (req, res) => {
    const { fromBranchId, toBranchId, items, notes } = req.body;
    // items: [{ productId, quantity }]

    if (!fromBranchId || !toBranchId || !items || items.length === 0) {
        return res.status(400).json({ error: 'Missing transfer details' });
    }

    const client = await db.pool.connect();
    try {
        await client.query('BEGIN');

        // 1. Create Transfer Record
        const refNo = `TRF-${Date.now()}`;
        const trfRes = await client.query(
            `INSERT INTO inventory_transfers (reference_no, from_branch_id, to_branch_id, status, notes)
             VALUES ($1, $2, $3, 'completed', $4) RETURNING id`,
            [refNo, fromBranchId, toBranchId, notes]
        );
        const transferId = trfRes.rows[0].id;

        // 2. Process Items
        for (const item of items) {
            const { productId, quantity } = item;

            // A. Check Source Availability
            const stockRes = await client.query(
                `SELECT COALESCE(SUM(quantity_remaining), 0) as total 
                 FROM inventory_batches 
                 WHERE product_id = $1 AND branch_id = $2`,
                [productId, fromBranchId]
            );

            if (parseInt(stockRes.rows[0].total) < quantity) {
                throw new Error(`Insufficient stock for product ID ${productId} at source branch`);
            }

            // B. Insert Transfer Item
            await client.query(
                `INSERT INTO inventory_transfer_items (transfer_id, product_id, quantity)
                 VALUES ($1, $2, $3)`,
                [transferId, productId, quantity]
            );

            // C. Move Stock (Direct Transfer Logic)

            // 1. Deduct from Source (FIFO)
            let qtyToDeduct = quantity;
            const sourceBatches = await client.query(
                `SELECT id, quantity_remaining, buying_price_unit, expiry_date 
                 FROM inventory_batches 
                 WHERE product_id = $1 AND branch_id = $2 AND quantity_remaining > 0
                 ORDER BY received_at ASC`,
                [productId, fromBranchId]
            );

            for (const batch of sourceBatches.rows) {
                if (qtyToDeduct <= 0) break;
                const deduct = Math.min(batch.quantity_remaining, qtyToDeduct);

                await client.query(
                    `UPDATE inventory_batches SET quantity_remaining = quantity_remaining - $1 WHERE id = $2`,
                    [deduct, batch.id]
                );

                // 2. Add to Destination (Create new batch per deduction to preserve cost/expiry)
                // In reality, we might aggregate, but preserving trace is better.
                await client.query(
                    `INSERT INTO inventory_batches (
                        product_id, batch_number, branch_id, 
                        quantity_initial, quantity_remaining, 
                        buying_price_unit, expiry_date, received_at
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
                    [
                        productId,
                        `TRF-${transferId}-${batch.id}`, // Traceable Batch Number
                        toBranchId,
                        deduct,
                        deduct,
                        batch.buying_price_unit,
                        batch.expiry_date
                    ]
                );

                qtyToDeduct -= deduct;
            }
        }

        await client.query('COMMIT');
        res.status(201).json({ message: 'Transfer successful', transferId });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Transfer Error:', err);
        res.status(500).json({ error: err.message });
    } finally {
        client.release();
    }
};
