const db = require('../../config/db');

// --- CATEGORIES ---

// GET /api/expenses/categories
exports.getCategories = async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM expense_categories ORDER BY type ASC, name ASC');
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching categories:', err);
        res.status(500).json({ error: 'Failed to fetch categories' });
    }
};

// POST /api/expenses/categories
exports.createCategory = async (req, res) => {
    try {
        const { name, type } = req.body;
        if (!name || !type) return res.status(400).json({ error: 'Name and Type required' });

        const result = await db.query(
            'INSERT INTO expense_categories (name, type) VALUES ($1, $2) RETURNING *',
            [name, type]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        if (err.code === '23505') {
            return res.status(400).json({ error: 'Category already exists' });
        }
        console.error('Error creating category:', err);
        res.status(500).json({ error: 'Failed to create category' });
    }
};

// DELETE /api/expenses/categories/:id
exports.deleteCategory = async (req, res) => {
    try {
        const { id } = req.params;
        // Check if system
        const check = await db.query('SELECT is_system FROM expense_categories WHERE id = $1', [id]);
        if (check.rows.length === 0) return res.status(404).json({ error: 'Category not found' });
        if (check.rows[0].is_system) return res.status(400).json({ error: 'Cannot delete default category' });

        await db.query('DELETE FROM expense_categories WHERE id = $1', [id]);
        res.json({ message: 'Category deleted' });
    } catch (err) {
        console.error('Error deleting category:', err);
        res.status(500).json({ error: 'Failed to delete category' });
    }
};

// --- EXPENSES ---

// GET: Fetch Expenses with Filters
exports.getExpenses = async (req, res) => {
    try {
        const { startDate, endDate, categoryId, search } = req.query;
        const user = req.user;

        // Security: Enforce Branch Isolation
        // If user is NOT admin, force their branch_id.
        // If user IS admin, allow them to filter by branchId query param, or see all if not specified.
        let targetBranchId;
        if (user.role === 'admin') {
            targetBranchId = req.query.branchId; // Admin can browse any branch
        } else {
            targetBranchId = user.branch_id; // Standard user restricted to their branch
        }

        let query = `
            SELECT e.*, 
                   c.name as category_name, 
                   c.type as category_type,
                   b.name as branch_name,
                   COALESCE(u.full_name, u.username) as created_by_name
            FROM expenses e
            LEFT JOIN expense_categories c ON e.category_id = c.id
            LEFT JOIN branches b ON e.branch_id = b.id
            LEFT JOIN users u ON e.created_by = u.id
            WHERE 1=1
        `;
        const params = [];
        let paramIdx = 1;

        if (targetBranchId) {
            query += ` AND e.branch_id = $${paramIdx++}`;
            params.push(targetBranchId);
        }

        if (startDate && endDate) {
            query += ` AND e.date BETWEEN $${paramIdx++} AND $${paramIdx++}`;
            params.push(startDate, endDate);
        }

        if (categoryId && categoryId !== 'null') {
            query += ` AND e.category_id = $${paramIdx++}`;
            params.push(categoryId);
        }

        if (search) {
            query += ` AND (e.description ILIKE $${paramIdx++} OR e.reference_code ILIKE $${paramIdx++})`;
            params.push(`%${search}%`, `%${search}%`); // Should use 2 placeholders if checking two fields with same value, or $idx for both.
            // Correct logic: `... ILIKE $4 OR ... ILIKE $4` but pg driver doesn't support named params.
            // So we push search twice or fix query.
            // Let's optimize: ILIKE $X 
            // Actually, params.push(`%${search}%`) acts as one value. 
            // So query should be: ILIKE $X OR ILIKE $Y.

            // Correction:
            // Since I pushed `%${search}%` once in line above? No, I pushed it twice.
            // Code above: `params.push(..., ...)` -> pushes 2 values.
            // So placeholders should be $X and $(X+1).
            // But let's verify paramIdx logic for search.
        }

        // Re-doing paramIdx logic cleanly for search:
        if (search) {
            query += ` AND (e.description ILIKE $${paramIdx} OR e.reference_code ILIKE $${paramIdx + 1})`;
            params.push(`%${search}%`, `%${search}%`);
            paramIdx += 2;
        }

        query += ` ORDER BY e.date DESC, e.created_at DESC`;

        const result = await db.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching expenses:', err);
        res.status(500).json({ error: 'Failed to fetch expenses' });
    }
};

// POST: Create Expense
exports.createExpense = async (req, res) => {
    try {
        const { date, category_id, description, amount, payment_method, reference_code, branch_id } = req.body;
        const userId = req.user?.id;

        if (!amount || !category_id || !date) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        const query = `
            INSERT INTO expenses (date, category_id, description, amount, payment_method, reference_code, branch_id, created_by)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING *
        `;
        const values = [date, category_id, description, amount, payment_method, reference_code, branch_id, userId];

        const result = await db.query(query, values);

        // Fetch full object with category name for UI immediately
        const newId = result.rows[0].id;
        const fullRes = await db.query(`
            SELECT e.*, c.name as category_name, c.type as category_type,
                   COALESCE(u.full_name, u.username) as created_by_name
            FROM expenses e
            LEFT JOIN expense_categories c ON e.category_id = c.id
            LEFT JOIN users u ON e.created_by = u.id
            WHERE e.id = $1
        `, [newId]);

        res.status(201).json(fullRes.rows[0]);
    } catch (err) {
        console.error('Error creating expense:', err);
        res.status(500).json({ error: 'Failed to create expense' });
    }
};

// DELETE: Delete Expense
exports.deleteExpense = async (req, res) => {
    try {
        const { id } = req.params;
        const user = req.user;

        // 1. Check existence and permissions
        const check = await db.query('SELECT * FROM expenses WHERE id = $1', [id]);
        if (check.rows.length === 0) return res.status(404).json({ error: 'Expense not found' });

        const expense = check.rows[0];

        // Authorization: Admin OR Same Branch
        // (Optional: Could also respect 'created_by' ownership if strictness is needed)
        if (user.role !== 'admin' && expense.branch_id !== user.branch_id) {
            return res.status(403).json({ error: 'Access denied: Cannot delete expense from another branch' });
        }

        await db.query('DELETE FROM expenses WHERE id = $1', [id]);
        res.json({ message: 'Expense deleted successfully' });
    } catch (err) {
        console.error('Error deleting expense:', err);
        res.status(500).json({ error: 'Failed to delete expense' });
    }
};
