const db = require('../../config/db');

// Middleware for Auditing
exports.logAction = async (req, res, next) => {
    // We assume req.user is set by auth middleware (simulated for now if not fully enabled)
    // In a real app, this runs AFTER the action typically, but as middleware it runs BEFORE.
    // Ideally, we audit AFTER success.
    // For this simple implementation, we will export a helper function to call explicitly, 
    // OR use 'res.on("finish")' to log if successful.

    // Let's make an explicit helper we can call from other controllers
    next();
};

exports.createAuditLog = async (userId, action, details) => {
    try {
        await db.query(
            'INSERT INTO audit_logs (user_id, action, details) VALUES ($1, $2, $3)',
            [userId || null, action, details]
        );
    } catch (err) {
        console.error('Audit Log Error:', err);
    }
};

exports.openShift = async (req, res) => {
    const { userId, startingCash } = req.body;
    try {
        // Check if user already has open shift
        const openCheck = await db.query(
            "SELECT id FROM cash_drawers WHERE user_id = $1 AND status = 'open'",
            [userId]
        );
        if (openCheck.rows.length > 0) {
            return res.status(400).json({ error: 'User already has an open shift' });
        }

        const result = await db.query(
            `INSERT INTO cash_drawers (user_id, starting_cash, status) VALUES ($1, $2, 'open') RETURNING id`,
            [userId, startingCash]
        );
        res.status(201).json({ message: 'Shift Opened', drawerId: result.rows[0].id });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.closeShift = async (req, res) => {
    const { drawerId, actualCashAmount, notes } = req.body;

    // For MVP validation, we assume the user sending this is the owner of the drawer

    const client = await db.pool.connect();
    try {
        await client.query('BEGIN');

        // 1. Get Drawer Info
        const drawerQ = await client.query(
            "SELECT * FROM cash_drawers WHERE id = $1 AND status = 'open'",
            [drawerId]
        );

        if (drawerQ.rows.length === 0) {
            throw new Error('Active drawer not found');
        }

        const drawer = drawerQ.rows[0];
        const startingCash = parseFloat(drawer.starting_cash);
        const openingTime = drawer.opening_time;

        // 2. Calculate Cash Sales since Opening
        // We need to sum 'payments' where method='cash' and created_at > openingTime
        // Note: In a real multi-user system, filter by user, but here we assume 1 drawer per shop logic for simplicity or filter by user if needed.
        // Let's filter by the user who owns the drawer.
        // But sales are linked to orders. orders linked to users? 'customer_id' is for clients. 'user_id' (staff) on orders is needed.
        // Wait, orders table definition in Phase 3 didn't explicitly check for 'staff_user_id'. 
        // For this MVP, we will sum ALL cash payments globally since openingTime (assuming single register).

        const salesQ = await client.query(
            `SELECT SUM(amount) as total FROM payments 
             WHERE method = 'cash' AND created_at >= $1`,
            [openingTime]
        );

        const cashSales = parseFloat(salesQ.rows[0].total || 0);

        // 3. System Total
        const systemTotal = startingCash + cashSales; // - Expenses if we had them
        const actualCash = parseFloat(actualCashAmount);

        // 4. Difference
        const difference = systemTotal - actualCash; // Positive = Shortage (Missing money), Negative = Overage (Too much)
        // Wait, standard accounting: Actual - System = Variance.
        // If Actual (900) - System (1000) = -100 (Shortage).
        // Let's use Actual - System.
        const variance = actualCash - systemTotal;

        // 5. Critical Alert
        if (variance < -100) {
            console.warn(`[SECURITY ALERT] DRAWER SHORTAGE: ${variance}. User: ${drawer.user_id}`);
            // Logic to send SMS/Email would go here
        }

        // 6. Update Drawer
        await client.query(
            `UPDATE cash_drawers 
             SET closing_time = CURRENT_TIMESTAMP, 
                 system_calculated_cash = $1, 
                 actual_counted_cash = $2, 
                 difference = $3, 
                 status = 'closed',
                 notes = $4
             WHERE id = $5`,
            [systemTotal, actualCash, variance, notes || '', drawerId]
        );

        await client.query('COMMIT');

        // Blind Response: Don't show the difference
        res.json({ message: 'Shift Closed Successfully', varianceRecorded: true });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Close Shift Error:', err);
        res.status(500).json({ error: err.message });
    } finally {
        client.release();
    }
};

exports.getAuditLogs = async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM audit_logs ORDER BY timestamp DESC LIMIT 50');
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

exports.getShiftHistory = async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM cash_drawers ORDER BY closing_time DESC LIMIT 20');
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};
