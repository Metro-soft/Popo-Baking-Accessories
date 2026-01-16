const db = require('../../config/db');

// --- EMPLOYEES ---

/**
 * Helper: Calculate Payroll Amount for an Employee
 */
const calculatePayrollAmount = (emp, runType) => {
    const base = parseFloat(emp.base_salary);
    let payAmount = 0;

    if (runType === 'MID_MONTH') {
        // MID_MONTH Logic
        const fixedAdv = parseFloat(emp.fixed_advance_amount || 0);
        if (fixedAdv > 0) {
            // SAFETY: Cap advance at base salary
            payAmount = Math.min(fixedAdv, base);
        } else {
            // Fallback to 40% if no fixed amount set
            payAmount = base * 0.40;
        }
    } else {
        // END_MONTH Logic
        if (emp.payment_preference === 'SPLIT') {
            const fixedAdv = parseFloat(emp.fixed_advance_amount || 0);
            if (fixedAdv > 0) {
                // END_MONTH: Pay remaining balance (Base - Cap(Advance))
                const paidAdvance = Math.min(fixedAdv, base);
                payAmount = Math.max(0, base - paidAdvance);
            } else {
                // Fallback to 60%
                payAmount = base * 0.60;
            }
        } else {
            // FULL (100%)
            payAmount = base;
        }
    }

    return Math.round(payAmount * 100) / 100;
};

// GET /api/payroll/employees
exports.getEmployees = async (req, res) => {
    try {
        const branchId = req.user.branch_id || 1;
        const result = await db.query('SELECT * FROM employees WHERE branch_id = $1 ORDER BY name ASC', [branchId]);
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching employees:', err);
        res.status(500).json({ error: 'Failed to fetch employees' });
    }
};

// POST /api/payroll/employees
exports.createEmployee = async (req, res) => {
    try {
        const { name, role, department, base_salary, phone, email, payment_preference, fixed_advance_amount } = req.body;
        const result = await db.query(
            `INSERT INTO employees (name, role, department, base_salary, phone, email, payment_preference, fixed_advance_amount, branch_id) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
            [name, role, department, base_salary || 0, phone, email, payment_preference || 'FULL', fixed_advance_amount || 0, req.body.branch_id || req.user?.branch_id || 1]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        console.error('Error creating employee:', err);
        res.status(500).json({ error: 'Failed to create employee' });
    }
};

// PUT /api/payroll/employees/:id
exports.updateEmployee = async (req, res) => {
    try {
        const { id } = req.params;
        const { name, role, department, base_salary, phone, email, status, payment_preference, fixed_advance_amount } = req.body;
        const result = await db.query(
            `UPDATE employees 
             SET name = $1, role = $2, department = $3, base_salary = $4, phone = $5, email = $6, status = $7, payment_preference = $8, fixed_advance_amount = $9, updated_at = CURRENT_TIMESTAMP
             WHERE id = $10 RETURNING *`,
            [name, role, department, base_salary, phone, email, status, payment_preference, fixed_advance_amount, id]
        );
        if (result.rows.length === 0) return res.status(404).json({ error: 'Employee not found' });
        res.json(result.rows[0]);
    } catch (err) {
        console.error('Error updating employee:', err);
        res.status(500).json({ error: 'Failed to update employee' });
    }
};

// --- PAYROLL RUNS ---

// GET /api/payroll/runs
exports.getRuns = async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM payroll_runs ORDER BY created_at DESC');
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching payroll runs:', err);
        res.status(500).json({ error: 'Failed to fetch payroll runs' });
    }
};

// POST /api/payroll/runs (Initialize a Draft Run)
exports.createRun = async (req, res) => {
    const client = await db.pool.connect();
    try {
        const { month, run_type } = req.body; // run_type: 'MID_MONTH' or 'END_MONTH'
        const userId = req.user?.id || 1;

        await client.query('BEGIN');

        // 1. Create Run Header
        const runRes = await client.query(
            `INSERT INTO payroll_runs (month, run_type, status, created_by, branch_id) VALUES ($1, $2, 'Draft', $3, $4) RETURNING *`,
            [month, run_type || 'END_MONTH', userId, req.user?.branch_id || 1]
        );
        const runId = runRes.rows[0].id;

        // 2. Fetch Active Employees
        let empQuery = `SELECT * FROM employees WHERE status = 'Active'`;
        // Optimization: If MID_MONTH, only fetch employees with SPLIT preference? 
        // Or fetch all but skip? Fetching all gives flexibility if logic changes.
        // Actually, for MID_MONTH, we strictly only pay SPLIT people.

        if (run_type === 'MID_MONTH') {
            empQuery += ` AND payment_preference = 'SPLIT'`;
        }

        const empRes = await client.query(empQuery);
        const employees = empRes.rows;

        // 3. Create Payroll Items
        let total = 0;
        for (const emp of employees) {
            const net = calculatePayrollAmount(emp, run_type);

            await client.query(
                `INSERT INTO payroll_items (run_id, employee_id, base_salary, net_pay) 
                 VALUES ($1, $2, $3, $4)`,
                [runId, emp.id, emp.base_salary, net]
            );
            total += net;
        }

        // 4. Update Header with Total
        await client.query(`UPDATE payroll_runs SET total_payout = $1 WHERE id = $2`, [total, runId]);

        await client.query('COMMIT');

        // Return full run with items
        const fullRun = await client.query(`SELECT * FROM payroll_runs WHERE id = $1`, [runId]);
        res.status(201).json(fullRun.rows[0]);

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error creating payroll run:', err);
        res.status(500).json({ error: 'Failed to create payroll run' });
    } finally {
        client.release();
    }
};

// GET /api/payroll/runs/:id (Get Run Details + Items)
exports.getRunDetails = async (req, res) => {
    try {
        const { id } = req.params;

        // Get Header
        const runRes = await db.query('SELECT * FROM payroll_runs WHERE id = $1', [id]);
        if (runRes.rows.length === 0) return res.status(404).json({ error: 'Run not found' });

        // Get Items with Employee names
        const itemsRes = await db.query(`
            SELECT pi.*, e.name as employee_name, e.role as employee_role, e.phone as employee_phone
            FROM payroll_items pi
            JOIN employees e ON pi.employee_id = e.id
            WHERE pi.run_id = $1
            ORDER BY e.name ASC
        `, [id]);

        res.json({ run: runRes.rows[0], items: itemsRes.rows });
    } catch (err) {
        console.error('Error fetching run details:', err);
        res.status(500).json({ error: 'Failed to fetch details' });
    }
};

// PUT /api/payroll/items/:id (Update Bonus/Deduction)
exports.updateItem = async (req, res) => {
    try {
        const { id } = req.params; // Item ID
        const { bonuses, deductions } = req.body;

        // Calculate new Net Pay
        // Need to get base salary first
        const current = await db.query('SELECT base_salary, run_id FROM payroll_items WHERE id = $1', [id]);
        if (current.rows.length === 0) return res.status(404).json({ error: 'Item not found' });

        const base = parseFloat(current.rows[0].base_salary);
        const b = parseFloat(bonuses || 0);
        const d = parseFloat(deductions || 0);
        const newNet = base + b - d;

        await db.query(
            `UPDATE payroll_items SET bonuses = $1, deductions = $2, net_pay = $3 WHERE id = $4`,
            [b, d, newNet, id]
        );

        // Update Run Total
        const runId = current.rows[0].run_id;
        await db.query(`
            UPDATE payroll_runs 
            SET total_payout = (SELECT SUM(net_pay) FROM payroll_items WHERE run_id = $1)
            WHERE id = $1
        `, [runId]);

        res.json({ message: 'Item updated', net_pay: newNet });

    } catch (err) {
        console.error('Error updating payroll item:', err);
        res.status(500).json({ error: 'Failed to update item' });
    }
};

// POST /api/payroll/items/:id/finalize (Pay Individual Employee)
exports.finalizeItem = async (req, res) => {
    const client = await db.pool.connect();
    try {
        const { id } = req.params;
        const { payment_method, notes } = req.body; // Optional: specific method per employee

        await client.query('BEGIN');

        // 1. Get Item Details
        const itemRes = await client.query(`
            SELECT pi.*, e.name as employee_name, pr.month, pr.run_type
            FROM payroll_items pi
            JOIN employees e ON pi.employee_id = e.id
            JOIN payroll_runs pr ON pi.run_id = pr.id
            WHERE pi.id = $1
        `, [id]);

        if (itemRes.rows.length === 0) throw new Error('Payroll item not found');
        const item = itemRes.rows[0];

        if (item.status === 'PAID') throw new Error('This employee has already been paid for this run.');

        const amount = parseFloat(item.net_pay);
        const description = `Payroll: ${item.employee_name} (${item.month})`;

        // Resolve Salary Category
        let salaryCatId = null;
        const catRes = await client.query("SELECT id FROM expense_categories WHERE name = 'Salary'");
        if (catRes.rows.length > 0) {
            salaryCatId = catRes.rows[0].id;
        } else {
            // Optional: Create if missing, or default to null
            // For now, let's just create it to be helpful
            const newCat = await client.query("INSERT INTO expense_categories (name, type) VALUES ('Salary', 'PAYROLL') RETURNING id");
            salaryCatId = newCat.rows[0].id;
        }

        // 2. Create Expense
        await client.query(
            `INSERT INTO expenses (date, amount, category_id, description, payment_method, reference_code, created_by, type)
             VALUES (CURRENT_DATE, $1, $2, $3, $4, $5, $6, 'PAYROLL')`,
            [amount, salaryCatId, description, payment_method || 'Bank Transfer', `PAY-ITEM-${id}`, req.user.id || 1]
        );

        // 3. Mark Item as PAID
        await client.query(
            `UPDATE payroll_items SET status = 'PAID', paid_at = CURRENT_TIMESTAMP WHERE id = $1`,
            [id]
        );

        // 4. Check if ALL items in this run are paid. If so, mark Run as PAID.
        const pendingCheck = await client.query(
            `SELECT COUNT(*) as count FROM payroll_items WHERE run_id = $1 AND status = 'PENDING'`,
            [item.run_id]
        );

        if (parseInt(pendingCheck.rows[0].count) === 0) {
            await client.query(
                `UPDATE payroll_runs SET status = 'PAID', payment_date = CURRENT_DATE WHERE id = $1`,
                [item.run_id]
            );
        }

        await client.query('COMMIT');
        res.json({ message: 'Payment recorded successfully', status: 'PAID' });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error finalizing item:', err);
        res.status(500).json({ error: err.message });
    } finally {
        client.release();
    }
};

// POST /api/payroll/runs/:id/finalize (Mark ALL Remaining as Paid)
exports.finalizeRun = async (req, res) => {
    const client = await db.pool.connect();
    try {
        const { id } = req.params;
        await client.query('BEGIN');

        // Check Run
        const runRes = await client.query('SELECT * FROM payroll_runs WHERE id = $1', [id]);
        if (runRes.rows.length === 0) throw new Error('Run not found');
        if (runRes.rows[0].status === 'Paid') throw new Error('Run is already fully paid');

        // Get Pending Items
        const pendingItems = await client.query(`
            SELECT pi.*, e.name as employee_name 
            FROM payroll_items pi
            JOIN employees e ON pi.employee_id = e.id
            WHERE pi.run_id = $1 AND pi.status = 'PENDING'
        `, [id]);

        if (pendingItems.rows.length === 0) throw new Error('No pending items to pay.');

        const month = runRes.rows[0].month;

        for (const item of pendingItems.rows) {
            const amount = parseFloat(item.net_pay);
            const description = `Payroll Bulk: ${item.employee_name} (${month})`;

            // Resolve Salary Category (do once before loop ideally, but this is safe)
            let salaryCatId = null;
            const catRes = await client.query("SELECT id FROM expense_categories WHERE name = 'Salary'");
            if (catRes.rows.length > 0) {
                salaryCatId = catRes.rows[0].id;
            } else {
                const newCat = await client.query("INSERT INTO expense_categories (name, type) VALUES ('Salary', 'PAYROLL') RETURNING id");
                salaryCatId = newCat.rows[0].id;
            }

            // Create Expense
            await client.query(
                `INSERT INTO expenses (date, amount, category_id, description, payment_method, reference_code, created_by, type)
                 VALUES (CURRENT_DATE, $1, $2, $3, 'Bank Transfer', $4, $5, 'PAYROLL')`,
                [amount, salaryCatId, description, `PAY-ITEM-BULK-${item.id}`, req.user.id || 1]
            );

            // Mark Item PAID
            await client.query(
                `UPDATE payroll_items SET status = 'PAID', paid_at = CURRENT_TIMESTAMP WHERE id = $1`,
                [item.id]
            );
        }

        // Mark Run PAID
        await client.query(`UPDATE payroll_runs SET status = 'Paid', payment_date = CURRENT_DATE WHERE id = $1`, [id]);

        await client.query('COMMIT');
        res.json({ message: 'Remaining payroll items finalized and expenses recorded' });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error finalizing payroll:', err);
        res.status(500).json({ error: err.message });
    } finally {
        client.release();
    }
};

// GET /api/payroll/employees/:id/history
exports.getEmployeeHistory = async (req, res) => {
    try {
        const { id } = req.params;
        const result = await db.query(
            `SELECT pi.*, pr.month, pr.status as run_status, pr.payment_date, pr.run_type
             FROM payroll_items pi
             JOIN payroll_runs pr ON pi.run_id = pr.id
             WHERE pi.employee_id = $1
             ORDER BY pr.created_at DESC`,
            [id]
        );
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching employee history:', err);
        res.status(500).json({ error: 'Failed to fetch history' });
    }
};
// POST /api/payroll/ensure-item
// Automatically ensures a run exists and creates an item for the specific employee if needed
exports.ensureRunAndItem = async (req, res) => {
    const client = await db.pool.connect();
    try {
        const { employee_id, month, run_type } = req.body;
        const userId = req.user?.id || 1;

        await client.query('BEGIN');

        // 1. Find or Create Run
        let runId;
        const runs = await client.query(
            `SELECT * FROM payroll_runs WHERE month = $1 AND run_type = $2`,
            [month, run_type]
        );

        if (runs.rows.length > 0) {
            runId = runs.rows[0].id;
        } else {
            // Create Draft Run
            const newRun = await client.query(
                `INSERT INTO payroll_runs (month, run_type, status, created_by, total_payout, branch_id) 
                 VALUES ($1, $2, 'Draft', $3, 0, $4) RETURNING id`,
                [month, run_type, userId, req.user?.branch_id || 1]
            );
            runId = newRun.rows[0].id;
        }

        // 2. Check if Item Exists
        const itemRes = await client.query(
            `SELECT * FROM payroll_items WHERE run_id = $1 AND employee_id = $2`,
            [runId, employee_id]
        );

        if (itemRes.rows.length > 0) {
            // Item exists, return it
            await client.query('COMMIT');
            return res.json(itemRes.rows[0]);
        }

        // 3. Create Item
        // Need employee details for calculation
        const empRes = await client.query(`SELECT * FROM employees WHERE id = $1`, [employee_id]);
        if (empRes.rows.length === 0) throw new Error('Employee not found');
        const emp = empRes.rows[0];

        const net = calculatePayrollAmount(emp, run_type);

        const newItem = await client.query(
            `INSERT INTO payroll_items (run_id, employee_id, base_salary, net_pay) 
             VALUES ($1, $2, $3, $4) RETURNING *`,
            [runId, emp.id, emp.base_salary, net]
        );

        // Update Run Total
        await client.query(
            `UPDATE payroll_runs 
             SET total_payout = (SELECT SUM(net_pay) FROM payroll_items WHERE run_id = $1)
             WHERE id = $1`,
            [runId]
        );

        await client.query('COMMIT');
        res.json(newItem.rows[0]);

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Error ensuring payroll item:', err);
        res.status(500).json({ error: err.message });
    } finally {
        client.release();
    }
};
