const db = require('../../config/db');

// GET /api/bills
// Supports filtering by status: 'overdue', 'upcoming', 'due_soon'
exports.getBills = async (req, res) => {
    try {
        const { status } = req.query;
        let query = `
      SELECT b.*, c.name as category_name
      FROM recurring_bills b
      LEFT JOIN expense_categories c ON b.category_id = c.id
      WHERE b.is_active = TRUE
    `;
        const params = [];

        // Simple status filtering logic
        // 'overdue': next_due_date < CURRENT_DATE
        // 'due_soon': next_due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7
        // 'upcoming': next_due_date >= CURRENT_DATE
        if (status === 'overdue') {
            query += ` AND b.next_due_date < CURRENT_DATE`;
        } else if (status === 'due_soon') {
            query += ` AND b.next_due_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '7 days')`;
        }

        query += ` ORDER BY b.next_due_date ASC`;

        const { rows } = await db.query(query, params);
        res.json(rows);
    } catch (err) {
        console.error('Error fetching bills:', err);
        res.status(500).json({ error: 'Failed to fetch bills' });
    }
};

// POST /api/bills
exports.createBill = async (req, res) => {
    try {
        const { name, vendor, amount, due_day, frequency, category_id, auto_pay, payment_instructions } = req.body;

        // Calculate initial next_due_date
        // If today is past the due_day, set to next month. Else this month.
        const today = new Date();
        let nextDue = new Date(today.getFullYear(), today.getMonth(), due_day);
        if (today.getDate() > due_day) {
            nextDue.setMonth(nextDue.getMonth() + 1); // Move to next month
        }

        // Format date as YYYY-MM-DD for SQL
        const nextDueDateStr = nextDue.toISOString().split('T')[0];

        const result = await db.query(
            `INSERT INTO recurring_bills 
       (name, vendor, amount, due_day, frequency, category_id, auto_pay, next_due_date, payment_instructions)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
            [name, vendor, amount, due_day, frequency || 'monthly', category_id, auto_pay || false, nextDueDateStr, payment_instructions]
        );

        res.status(201).json(result.rows[0]);
    } catch (err) {
        console.error('Error creating bill:', err);
        res.status(500).json({ error: 'Failed to create bill' });
    }
};

// POST /api/bills/:id/pay
// Records an expense and updates the bills next_due_date
exports.payBill = async (req, res) => {
    const client = await db.pool.connect(); // Use transaction
    try {
        await client.query('BEGIN');
        const { id } = req.params;
        const { amount, payment_method, reference, date } = req.body;
        const userId = req.user.id;
        const branchId = req.user.branch_id || 1; // Fallback to 1 if not set

        // 1. Fetch Bill details
        const billRes = await client.query('SELECT * FROM recurring_bills WHERE id = $1', [id]);
        if (billRes.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Bill not found' });
        }
        const bill = billRes.rows[0];

        // 2. Create Expense Record
        const expenseRes = await client.query(
            `INSERT INTO expenses 
       (date, amount, category_id, description, payment_method, reference_code, branch_id, created_by, type)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'BILL') -- Explicitly set type to BILL
       RETURNING *`,
            [
                date || new Date(),
                amount || bill.amount,
                bill.category_id,
                `Bill Payment: ${bill.name} - ${bill.vendor}`,
                payment_method || 'Bank Transfer',
                reference || 'AUTO-BILL',
                branchId, // branch_id param $7
                userId    // created_by param $8
            ]
        );

        // 3. Update Bill's next_due_date and last_paid_date
        // Assumes monthly frequency for now
        // 3. Update Bill's next_due_date and last_paid_date
        // Use CASE statement to handle dynamic frequency
        await client.query(
            `UPDATE recurring_bills 
       SET last_paid_date = CURRENT_DATE,
           next_due_date = next_due_date + CASE 
               WHEN frequency = 'weekly' THEN INTERVAL '1 week'
               WHEN frequency = 'yearly' THEN INTERVAL '1 year'
               WHEN frequency = 'quarterly' THEN INTERVAL '3 months'
               WHEN frequency = 'daily' THEN INTERVAL '1 day'
               ELSE INTERVAL '1 month'
           END,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
            [id]
        );

        await client.query('COMMIT');
        res.json({ success: true, expense: expenseRes.rows[0], message: 'Bill paid and updated.' });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error paying bill:', err);
        res.status(500).json({ error: 'Failed to pay bill' });
    } finally {
        client.release();
    }
};

// DELETE /api/bills/:id
exports.deleteBill = async (req, res) => {
    try {
        const { id } = req.params;
        await db.query('UPDATE recurring_bills SET is_active = FALSE WHERE id = $1', [id]);
        res.json({ message: 'Bill archived successfully' });
    } catch (err) {
        console.error('Error deleting bill:', err);
        res.status(500).json({ error: 'Failed to delete bill' });
    }
};
// Auto-Pay Job
exports.processAutoPayments = async () => {
    console.log('🔄 Auto-Pay Check Skipped (Feature Disabled by User Request)');
    return 0;
    /*
    console.log('🔄 Running Auto-Pay Check...');
    const client = await db.pool.connect();
    let processed = 0;
    */

    try {
        await client.query('BEGIN');

        // Find due bills with auto_pay enabled
        const dueBills = await client.query(`
            SELECT * FROM recurring_bills 
            WHERE is_active = TRUE 
            AND auto_pay = TRUE 
            AND next_due_date <= CURRENT_DATE
        `);

        for (const bill of dueBills.rows) {
            console.log(`💸 Auto-paying bill: ${bill.name} (${bill.amount})`);

            // 1. Create Expense
            await client.query(
                `INSERT INTO expenses 
                (date, amount, category_id, description, payment_method, reference_code, created_by, type)
                VALUES (CURRENT_DATE, $1, $2, $3, 'Bank Transfer', 'AUTO-PAY', 1, 'BILL')`,
                [bill.amount, bill.category_id, `Auto-Payment: ${bill.name}`]
            );

            // 2. Update Bill
            await client.query(
                `UPDATE recurring_bills 
                SET last_paid_date = CURRENT_DATE,
                    next_due_date = next_due_date + CASE 
                        WHEN frequency = 'weekly' THEN INTERVAL '1 week'
                        WHEN frequency = 'yearly' THEN INTERVAL '1 year'
                        WHEN frequency = 'quarterly' THEN INTERVAL '3 months'
                        ELSE INTERVAL '1 month'
                    END,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = $1`,
                [bill.id]
            );
            processed++;
        }

        await client.query('COMMIT');
        console.log(`✅ Auto-Pay complete. Processed ${processed} bills.`);
        return processed;
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('❌ Auto-Pay failed:', err);
        return 0;
    } finally {
        client.release();
    }
};

// Expose manually via API if needed
exports.triggerAutoPay = async (req, res) => {
    const count = await exports.processAutoPayments();
    res.json({ message: 'Auto-Pay process ran', processed_count: count });
};
