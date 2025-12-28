const db = require('../../config/db');

// Helper: Get Current Open Shift for Branch
const getOpenShift = async (branchId) => {
    const res = await db.query(
        `SELECT * FROM cash_shifts WHERE branch_id = $1 AND status = 'open' LIMIT 1`,
        [branchId]
    );
    return res.rows[0];
};

exports.getShiftStatus = async (req, res) => {
    try {
        const { branchId } = req.query;
        if (!branchId) return res.status(400).json({ error: 'Branch ID required' });

        const shift = await getOpenShift(branchId);

        if (!shift) {
            return res.json({ status: 'closed', message: 'No active shift' });
        }

        // Calculate current system balance live for display (Optional, but good for "Expected Cash")
        // Note: Performance heavy if lots of txns, but fine for MVP.
        const balance = await calculateSystemBalance(shift.id, shift.opening_balance, shift.start_time);

        res.json({ status: 'open', shift, currentBalance: balance });
    } catch (err) {
        console.error('Get Shift Error:', err);
        res.status(500).json({ error: 'Failed to get shift status' });
    }
};

exports.openShift = async (req, res) => {
    const client = await db.pool.connect();
    try {
        const { branchId, userId, openingBalance } = req.body;

        // Check if exists
        const existing = await getOpenShift(branchId);
        if (existing) {
            return res.status(400).json({ error: 'Shift already open for this branch' });
        }

        await client.query('BEGIN');
        const result = await client.query(
            `INSERT INTO cash_shifts (branch_id, user_id, opening_balance, status) 
             VALUES ($1, $2, $3, 'open') RETURNING *`,
            [branchId, userId, openingBalance]
        );
        await client.query('COMMIT');

        res.status(201).json(result.rows[0]);
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Open Shift Error:', err);
        res.status(500).json({ error: 'Failed to open shift' });
    } finally {
        client.release();
    }
};

exports.addTransaction = async (req, res) => {
    try {
        const { branchId, userId, type, amount, reason } = req.body;
        const shift = await getOpenShift(branchId);

        // Allow adding transaction even if shift closed? No, usually tied to shift.
        // Or maybe "Petty Cash" can happen anytime? 
        // For strict control, must have open shift.
        if (!shift) return res.status(400).json({ error: 'No open shift' });

        const result = await db.query(
            `INSERT INTO cash_transactions (branch_id, shift_id, user_id, type, amount, reason)
             VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
            [branchId, shift.id, userId, type, amount, reason]
        );

        res.status(201).json(result.rows[0]);
    } catch (err) {
        console.error('Add Cash Transaction Error:', err);
        res.status(500).json({ error: 'Failed to add transaction' });
    }
};

exports.closeShift = async (req, res) => {
    const client = await db.pool.connect();
    try {
        const { branchId, closingBalanceActual, notes } = req.body;

        const shift = await getOpenShift(branchId);
        if (!shift) return res.status(400).json({ error: 'No open shift to close' });

        await client.query('BEGIN');

        // 1. Calculate Expected System Balance
        const systemBalance = await calculateSystemBalance(shift.id, shift.opening_balance, shift.start_time);

        // 2. Variance
        const variance = parseFloat(closingBalanceActual) - parseFloat(systemBalance);

        // 3. Update Shift
        const result = await client.query(
            `UPDATE cash_shifts 
             SET closing_balance_system = $1, 
                 closing_balance_actual = $2, 
                 variance = $3, 
                 status = 'closed', 
                 end_time = NOW(),
                 notes = $4
             WHERE id = $5 RETURNING *`,
            [systemBalance, closingBalanceActual, variance, notes, shift.id]
        );

        await client.query('COMMIT');
        res.json(result.rows[0]);

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Close Shift Error:', err);
        res.status(500).json({ error: 'Failed to close shift' });
    } finally {
        client.release();
    }
};

// --- Helper Calculation Function ---
// Calculates what SHOULD be in the drawer
async function calculateSystemBalance(shiftId, openingBalance, startTime) {
    // 1. Get total Cash Payments since shift start
    // Note: This relies on 'payments' table having a timestamp > startTime.
    // Ideally we link payments to shift_id, but time-based is the MVP proxy.
    const paymentsRes = await db.query(
        `SELECT SUM(amount) as total FROM payments 
         WHERE method = 'Cash' 
         AND created_at >= $1`, // AND created_at <= NOW() implicit
        [startTime]
    );
    const totalSalesCash = parseFloat(paymentsRes.rows[0].total || 0);

    // 2. Get Cash Transactions (Deposits vs Withdrawals/Expenses) for THIS shift
    const txRes = await db.query(
        `SELECT type, SUM(amount) as total FROM cash_transactions 
         WHERE shift_id = $1 GROUP BY type`,
        [shiftId]
    );

    let totalDeposits = 0;
    let totalOut = 0;

    txRes.rows.forEach(row => {
        if (row.type === 'deposit') totalDeposits += parseFloat(row.total);
        else totalOut += parseFloat(row.total);
    });

    const expected = parseFloat(openingBalance) + totalSalesCash + totalDeposits - totalOut;
    return expected.toFixed(2);
}
