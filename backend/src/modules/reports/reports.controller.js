const db = require('../../config/db');

// 1. Inventory Audit Report
exports.getAuditReport = async (req, res) => {
    try {
        const { branchId, startDate, endDate } = req.query;

        // Base Query: Fetch stock movements that are adjustments
        // We filter by 'adjustment', 'transfer_out', 'transfer_in' ?
        // Usually Audit refers to 'Stock Take' adjustments.
        // Let's broaden to all movements but highlight adjustments

        let query = `
            SELECT 
                sm.id, sm.created_at, sm.type, sm.quantity, sm.reason,
                p.name as product_name, p.sku,
                b.name as branch_name
            FROM stock_movements sm
            JOIN products p ON sm.product_id = p.id
            LEFT JOIN locations b ON sm.branch_id = b.id
            WHERE sm.type IN ('adjustment', 'transfer_out', 'transfer_in')
        `;

        const params = [];
        let paramIndex = 1;

        if (branchId) {
            query += ` AND sm.branch_id = $${paramIndex}`;
            params.push(branchId);
            paramIndex++;
        }

        if (startDate && endDate) {
            query += ` AND sm.created_at BETWEEN $${paramIndex} AND $${paramIndex + 1}`;
            params.push(startDate, endDate);
            paramIndex += 2;
        }

        query += ` ORDER BY sm.created_at DESC`;

        const result = await db.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Audit Report Error:', err);
        res.status(500).json({ error: 'Failed to generate audit report' });
    }
};

// 2. Sales Performance Report
exports.getSalesReport = async (req, res) => {
    try {
        const { branchId, startDate, endDate } = req.query;

        // Metrics: Total Revenue (Orders), Gross Profit (Revenue - Cost)
        // Cost comes from order_items -> inventory_batches interaction?
        // That's hard to trace strictly without logging cost at sale time.
        // Wait, inventory_batches stores 'buying_price_unit'.
        // To get TRUE profit, we need to know WHICH batch was sold.
        // But our system does FIFO.
        // For now, let's approximate or use a simplified "Revenue" report.
        // Or better: Current products have 'buying_price'? No, only batches.
        // Getting exact COGS is complex without a 'sold_items_cost' table.
        // PROPOSAL: Report Revenue for now. Profit requires deeper tracking.

        let query = `
            SELECT 
                o.branch_id,
                l.name as branch_name,
                COUNT(o.id) as total_orders,
                SUM(o.total_amount) as total_revenue,
                SUM(o.total_deposit) as total_deposits
            FROM orders o
            LEFT JOIN locations l ON o.branch_id = l.id
            WHERE o.status = 'completed'
        `;

        const params = [];
        let paramIndex = 1;

        if (branchId) {
            query += ` AND o.branch_id = $${paramIndex}`;
            params.push(branchId);
            paramIndex++;
        }

        if (startDate && endDate) {
            query += ` AND o.created_at BETWEEN $${paramIndex} AND $${paramIndex + 1}`;
            params.push(startDate, endDate);
            paramIndex += 2;
        }

        query += ` GROUP BY o.branch_id, l.name`;

        const result = await db.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Sales Report Error:', err);
        res.status(500).json({ error: 'Failed to generate sales report' });
    }
};

// 3. Inventory Valuation
exports.getInventoryValuation = async (req, res) => {
    try {
        const { branchId } = req.query;

        let query = `
            SELECT 
                ib.branch_id,
                l.name as branch_name,
                COUNT(DISTINCT ib.product_id) as unique_products,
                SUM(ib.quantity_remaining) as total_items,
                SUM(ib.quantity_remaining * ib.buying_price_unit) as total_asset_value
            FROM inventory_batches ib
            LEFT JOIN locations l ON ib.branch_id = l.id
            WHERE ib.quantity_remaining > 0
        `;

        const params = [];
        if (branchId) {
            query += ` AND ib.branch_id = $1`;
            params.push(branchId);
        }

        query += ` GROUP BY ib.branch_id, l.name`;

        const result = await db.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Valuation Report Error:', err);
        res.status(500).json({ error: 'Failed to generate valuation report' });
    }
};

// 4. Low Stock Report
exports.getLowStockReport = async (req, res) => {
    try {
        const { branchId } = req.query;

        // If branchId is provided, we check stock for that branch.
        // If not, we check GLOBAL stock (default behavior).
        // Products with type 'service_print' are excluded.

        let query = `
            SELECT 
                p.id, 
                p.name, 
                p.sku, 
                COALESCE(p.reorder_level, 10) as reorder_level,
                COALESCE(SUM(ib.quantity_remaining), 0) as current_stock
            FROM products p
            LEFT JOIN inventory_batches ib ON p.id = ib.product_id
        `;

        const params = [];
        if (branchId) {
            query += ` AND ib.branch_id = $1`;
            params.push(branchId);
        }

        query += `
            WHERE p.type != 'service_print'
            GROUP BY p.id, p.name, p.sku, p.reorder_level
            HAVING COALESCE(SUM(ib.quantity_remaining), 0) <= COALESCE(p.reorder_level, 10)
            ORDER BY current_stock ASC
        `;

        const result = await db.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Low Stock Report Error:', err);
        res.status(500).json({ error: 'Failed to generate low stock report' });
    }
};

// 5. Tax Report [NEW]
exports.getTaxReport = async (req, res) => {
    try {
        const { branchId, startDate, endDate } = req.query;

        let query = `
            SELECT 
                l.name as branch_name,
                COUNT(o.id) as total_txns,
                SUM(o.total_amount) as total_revenue,
                SUM(COALESCE(o.tax_amount, 0)) as total_tax,
                SUM(o.total_amount - COALESCE(o.tax_amount, 0)) as net_revenue
            FROM orders o
            LEFT JOIN locations l ON o.branch_id = l.id
            WHERE o.status = 'completed'
        `;

        const params = [];
        let paramIndex = 1;

        if (branchId) {
            query += ` AND o.branch_id = $${paramIndex}`;
            params.push(branchId);
            paramIndex++;
        }

        if (startDate && endDate) {
            query += ` AND o.created_at BETWEEN $${paramIndex} AND $${paramIndex + 1}`;
            params.push(startDate, endDate);
            paramIndex += 2;
        }

        query += ` GROUP BY o.branch_id, l.name`;

        const result = await db.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Tax Report Error:', err);
        res.status(500).json({ error: 'Failed to generate tax report' });
    }
};
