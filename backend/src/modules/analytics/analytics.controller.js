const db = require('../../config/db');

exports.getDashboardStats = async (req, res) => {
    try {
        const { branchId } = req.query;
        let branchFilter = '';
        let params = [];

        if (branchId && branchId !== 'null') {
            branchFilter = 'AND branch_id = $1';
            params.push(branchId);
        }

        // 1. Total Revenue
        const revenueRes = await db.query(
            `SELECT SUM(total_amount) as total FROM orders WHERE status = 'completed' ${branchFilter}`,
            params
        );
        const totalRevenue = revenueRes.rows[0].total || 0;

        // 2. Total Orders
        const ordersRes = await db.query(
            `SELECT COUNT(*) as count FROM orders WHERE 1=1 ${branchFilter}`,
            params
        );
        const totalOrders = ordersRes.rows[0].count || 0;

        // 3. Total Customers (Global, not per branch usually, but maybe sales per branch?)
        // Customers are shared usually. Let's keep it global for now.
        const customersRes = await db.query("SELECT COUNT(*) as count FROM customers");
        const totalCustomers = customersRes.rows[0].count || 0;

        // 4. Sales Trend (Last 7 Days)
        const trendRes = await db.query(`
            SELECT TO_CHAR(created_at, 'Day') as day_name, SUM(total_amount) as total
            FROM orders 
            WHERE status = 'completed' AND created_at >= NOW() - INTERVAL '7 days' ${branchFilter}
            GROUP BY day_name, DATE(created_at)
            ORDER BY DATE(created_at) ASC
        `, params);

        // 5. Monthly Expenses
        const expensesRes = await db.query(
            `SELECT SUM(amount) as total FROM expenses WHERE expense_date >= DATE_TRUNC('month', CURRENT_DATE) ${branchFilter}`,
            params
        );
        const totalExpenses = expensesRes.rows[0].total || 0;

        // 6. Pending Bills (Total Payables - Utils + POs)
        const billsRes = await db.query(
            `SELECT SUM(amount) as total FROM bills WHERE status = 'pending' ${branchFilter}`,
            params
        );
        const totalPendingBills = billsRes.rows[0].total || 0;

        // 7. Purchases Stats
        // A) Monthly Completed Purchases (Paid)
        const monthlyPurchasesRes = await db.query(
            `SELECT SUM(amount) as total FROM bills 
             WHERE type = 'purchase_order' AND status = 'paid' 
             AND created_at >= DATE_TRUNC('month', CURRENT_DATE) ${branchFilter}`,
            params
        );
        const monthlyPurchases = monthlyPurchasesRes.rows[0].total || 0;

        // B) Purchases Payable (To Give) - All time liability
        const purchasesPayableRes = await db.query(
            `SELECT SUM(amount) as total FROM bills 
             WHERE type = 'purchase_order' AND status = 'pending' ${branchFilter}`,
            params
        );
        const purchasesPayable = purchasesPayableRes.rows[0].total || 0;

        // 8. Goods on Credit (Receivables) - You will Get
        // Total Sales (Completed) - Total Payments Received
        // Note: Filters by branch if needed.
        // Complex query: Select (Total Orders Amount) - (Total Payments Amount)
        // We need to join or do subqueries.
        // Let's do it in two steps for simplicity or one CTE.
        const receivablesRes = await db.query(`
            WITH OrderTotals AS (
                SELECT SUM(total_amount) as total_sales 
                FROM orders 
                WHERE status = 'completed' ${branchFilter}
            ),
            PaymentTotals AS (
                SELECT SUM(p.amount) as total_paid
                FROM payments p
                JOIN orders o ON p.order_id = o.id
                WHERE o.status = 'completed' ${branchFilter.replace('branch_id', 'o.branch_id')}
            )
            SELECT 
                (COALESCE((SELECT total_sales FROM OrderTotals), 0) - COALESCE((SELECT total_paid FROM PaymentTotals), 0)) as total_receivables
        `, params);

        // Wait, replacements in params might be tricky if branchFilter changes index.
        // existing branchFilter uses $1.
        // If I use params again, it's fine.
        // But `branchFilter.replace` is risky string manipulation.
        // Better to write the query safely.

        let receivablesQuery = `
            SELECT 
                (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed' ${branchFilter}) - 
                (SELECT COALESCE(SUM(p.amount), 0) FROM payments p JOIN orders o ON p.order_id = o.id WHERE o.status = 'completed' ${branchFilter.replace('branch_id', 'o.branch_id')}) 
            as total_receivables
        `;

        // Actually, branch_id column name is unique enough? 
        // orders has branch_id.
        // branchFilter is "AND branch_id = $1".
        // In the second subquery, it's "AND o.branch_id = $1" to be safe against ambiguity if payments had branch_id (it doesn't, but good practice).
        // Let's manually reconstruct the filter for the join.

        let paymentBranchFilter = '';
        if (branchId && branchId !== 'null') {
            paymentBranchFilter = 'AND o.branch_id = $1';
        }

        const receivablesResFinal = await db.query(`
            SELECT 
                (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed' ${branchFilter}) - 
                (SELECT COALESCE(SUM(p.amount), 0) FROM payments p JOIN orders o ON p.order_id = o.id WHERE o.status = 'completed' ${paymentBranchFilter}) 
            as total_receivables
        `, params);

        const totalReceivables = receivablesResFinal.rows[0].total_receivables || 0;

        res.json({
            totalRevenue: parseFloat(totalRevenue),
            totalOrders: parseInt(totalOrders),
            totalCustomers: parseInt(totalCustomers),
            totalExpenses: parseFloat(totalExpenses),
            totalPendingBills: parseFloat(totalPendingBills),
            monthlyPurchases: parseFloat(monthlyPurchases),
            purchasesPayable: parseFloat(purchasesPayable),
            totalReceivables: parseFloat(totalReceivables),
            salesTrend: trendRes.rows
        });

    } catch (err) {
        console.error('Analytics Error:', err);
        res.status(500).json({ error: 'Failed to fetch analytics' });
    }
};

exports.getTopProducts = async (req, res) => {
    try {
        const result = await db.query(`
            SELECT p.name, p.sku, SUM(oi.quantity) as total_sold
            FROM order_items oi
            JOIN products p ON oi.product_id = p.id
            GROUP BY p.id, p.name, p.sku
            ORDER BY total_sold DESC
            LIMIT 5
        `);
        res.json(result.rows);
    } catch (err) {
        console.error('Top Products Error:', err);
        res.status(500).json({ error: 'Failed to fetch top products' });
    }
};
