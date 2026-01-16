const db = require('../config/db');

const debugGraph = async () => {
    try {
        console.log('--- DEBUGGING GRAPH DATA ---');
        const branchId = 1;

        // The EXACT query currently in finance.controller.js
        const { rows: graphData } = await db.query(`
            WITH monthly_data AS (
                -- 1. Expenses & Payroll
                SELECT date::DATE as tx_date, amount FROM expenses 
                WHERE branch_id = $1 AND date >= CURRENT_DATE - INTERVAL '12 months'
                
                UNION ALL
                
                -- 2. Paid Bills
                SELECT last_paid_date::DATE as tx_date, amount FROM recurring_bills 
                WHERE branch_id = $1 AND last_paid_date >= CURRENT_DATE - INTERVAL '12 months'
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

        console.log('Graph Data Returned:');
        console.table(graphData);

    } catch (err) {
        console.error('Debug Error:', err);
    } finally {
        process.exit();
    }
};

debugGraph();
