const pool = require('../../config/db');

// Get aggregated dashboard stats
exports.getDashboardStats = async (req, res) => {
    try {
        // Token usually sends 'branchId' (camelCase), but DB is snake_case. Handle both.
        const branchId = req.user.branchId || req.user.branch_id || 1;

        if (!branchId) {
            console.warn('⚠️ Warning: No Branch ID found in token. Defaulting to 1.');
        }

        // 1. Calculate Monthly Trends (Last 6 Months)
        // Expenses
        // Expenses (Operational Only - Exclude Payroll and Bill Payments to avoid double counting or mixing)
        // Expenses table has: 'Bill Payment: ...', 'Auto-Payment: ...', 'Payroll: ...'
        // Expenses (Operational Only - Exclude Payroll and Bill Payments to avoid double counting or mixing)
        // Expenses table has: 'Bill Payment: ...', 'Auto-Payment: ...', 'Payroll: ...'
        // 1. Unified Graph Data (Expenses + Payroll + Bills) - Last 12 Months
        // "Rewired" to use a single SQL query for accuracy and performance.
        const { rows: graphData } = await pool.query(`
            WITH monthly_data AS (
                -- 1. Expenses & Payroll & Bills (Single Source of Truth)
                SELECT date::DATE as tx_date, amount FROM expenses 
                WHERE branch_id = $1 AND date >= CURRENT_DATE - INTERVAL '12 months'
            )
            SELECT 
                TO_CHAR(d, 'Mon') as month,
                TO_CHAR(d, 'YYYY-MM') as sort_key,
                COALESCE(SUM(md.amount), 0) as total
            FROM generate_series(
                DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '11 months',
                DATE_TRUNC('month', CURRENT_DATE),
                '1 month'::interval
            ) d
            LEFT JOIN monthly_data md ON TO_CHAR(md.tx_date, 'YYYY-MM') = TO_CHAR(d, 'YYYY-MM')
            GROUP BY d
            ORDER BY d ASC
        `, [branchId]);

        // Map directly to chart format
        const chartData = graphData.map(r => ({
            month: r.month,
            amount: parseFloat(r.total)
        }));

        console.log('--- DASHBOARD ENDPOINT DEBUG ---');
        console.log('User Branch ID:', branchId);
        console.log('Graph Rows Found:', graphData.length);
        if (graphData.length > 0) {
            console.log('First Row:', graphData[0]);
            console.log('Last Row:', graphData[graphData.length - 1]);
        }
        console.log('--------------------------------');


        // 3. Calculate Period Growth (Current Month vs Previous Month)
        // We can use the last 2 entries of chartData to estimate
        // Or do a precise query. Let's start with chartData approximation for speed.
        let growth = 0;
        let currentMonthTotal = 0;
        let lastMonthTotal = 0;

        if (chartData.length >= 2) {
            currentMonthTotal = chartData[chartData.length - 1].amount;
            lastMonthTotal = chartData[chartData.length - 2].amount;

            if (lastMonthTotal > 0) {
                growth = ((currentMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;
            } else if (currentMonthTotal > 0) {
                growth = 100; // 0 to something is 100% growth
            }
        }

        // 4. Category Breakdown (This Month) for Pie Chart context? 
        // Maybe later.

        // 5. Payroll (Paid This Month - From Expenses)
        const { rows: paidPayrollRes } = await pool.query(`
            SELECT SUM(amount) as total
            FROM expenses
            WHERE branch_id = $1
            AND type = 'PAYROLL'
            AND TO_CHAR(date, 'YYYY-MM') = TO_CHAR(CURRENT_DATE, 'YYYY-MM')
        `, [branchId]);

        const paidPayroll = parseFloat(paidPayrollRes[0].total || 0);

        res.json({
            chartData,
            summary: {
                currentMonthTotal,
                lastMonthTotal,
                growthPercentage: parseFloat(growth.toFixed(1)),
                period: 'This Month'
            },
            payrollTotal: paidPayroll // Renamed from pendingPayroll
        });

    } catch (error) {
        console.error('Error fetching dashboard stats:', error);
        res.status(500).json({ error: error.message });
    }
};
