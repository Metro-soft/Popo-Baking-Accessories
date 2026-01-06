const db = require('../../config/db');
const activityService = require('../core/activity.service');

// GET /api/dispatch/pending
// Returns orders that are in the dispatch pipeline (pending, processing, released)
// We exclude 'delivered' and 'cancelled' from the default view
exports.getPendingDispatches = async (req, res) => {
    try {
        const branchId = req.user.branch_id || 1;

        // Fetch orders where dispatch_status is NOT null and NOT 'delivered'/'cancelled'
        // Also fetch Customer Name (from partners/users)
        // If customer is from `users` (old logic) or `partners` (new logic), we might need to join differently.
        // For now, assuming `users` table for customers based on schema.sql.

        const query = `
            SELECT 
                o.id, 
                o.created_at, 
                o.total_amount, 
                o.dispatch_status, 
                o.delivery_method, 
                o.delivery_details,
                u.full_name as customer_name, 
                u.phone as customer_phone,
                l.name as branch_name,
                (
                    SELECT string_agg(CONCAT(p.name, ' x', oi.quantity), ', ')
                    FROM order_items oi
                    JOIN products p ON p.id = oi.product_id
                    WHERE oi.order_id = o.id
                ) as items_summary
            FROM orders o
            LEFT JOIN users u ON o.customer_id = u.id
            LEFT JOIN locations l ON o.branch_id = l.id
            WHERE o.branch_id = $1
            AND o.dispatch_status IN ('pending', 'processing', 'released')
            ORDER BY o.created_at ASC
        `;

        const result = await db.query(query, [branchId]);
        res.json(result.rows);

    } catch (err) {
        console.error('Error fetching dispatches:', err);
        res.status(500).json({ error: 'Failed to fetch pending dispatches' });
    }
};

// PUT /api/dispatch/:id/status
// Updates the status and optional delivery details (driver info)
exports.updateDispatchStatus = async (req, res) => {
    const { id } = req.params;
    const { status, deliveryDetails, deliveryMethod } = req.body;

    // Status validation
    const allowedStatuses = ['pending', 'processing', 'released', 'delivered', 'cancelled'];
    if (!allowedStatuses.includes(status)) {
        return res.status(400).json({ error: 'Invalid status' });
    }

    try {
        const client = await db.pool.connect();
        try {
            await client.query('BEGIN');

            let query = `UPDATE orders SET dispatch_status = $1`;
            const params = [status];
            let paramIdx = 2;

            if (deliveryDetails) {
                query += `, delivery_details = $${paramIdx}`;
                params.push(deliveryDetails); // JSON
                paramIdx++;
            }

            if (deliveryMethod) {
                query += `, delivery_method = $${paramIdx}`;
                params.push(deliveryMethod);
                paramIdx++;
            }

            if (status === 'released') {
                // We could set a 'dispatched_at' timestamp here if we had the column, 
                // but schema didn't include it in migration. JSON 'delivery_details' can hold timestamp.
            }

            query += ` WHERE id = $${paramIdx}`;
            params.push(id);

            await client.query(query, params);

            // Log Activity
            await activityService.logAction(
                req.user?.id,
                'DISPATCH_UPDATED',
                'orders',
                id,
                { status, deliveryMethod, updated_by_user: true }
            );

            await client.query('COMMIT');

            res.json({ message: 'Dispatch status updated', id, status });

        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }

    } catch (err) {
        console.error('Error updating dispatch status:', err);
        res.status(500).json({ error: 'Failed to update dispatch status' });
    }
};
