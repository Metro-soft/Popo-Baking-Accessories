const db = require('../../config/db');

exports.createProduct = async (req, res) => {
    const {
        name, sku, type, baseSellingPrice, rentalDeposit, reorderLevel,
        costPrice, category, wholesalePrice, minWholesaleQty, color
    } = req.body;

    // 1. Validation
    if (!name || !type || baseSellingPrice === undefined) {
        return res.status(400).json({ error: 'Missing required fields' });
    }

    let productSku = sku;
    if (!productSku || productSku.trim() === '') {
        // Auto-generate SKU
        const timestamp = Date.now().toString().slice(-6);
        const random = Math.floor(1000 + Math.random() * 9000).toString().slice(-3);
        productSku = `POPO-${timestamp}${random}`;
    }

    // Check if SKU already exists
    try {
        const skuCheck = await db.query('SELECT id FROM products WHERE sku = $1', [productSku]);
        if (skuCheck.rows.length > 0) {
            return res.status(409).json({ error: 'Product with this SKU already exists' });
        }
    } catch (err) {
        return res.status(500).json({ error: 'Database error checking SKU' });
    }

    // Validate Rental Deposit
    if (type === 'asset_rental' && (rentalDeposit === null || rentalDeposit === undefined)) {
        return res.status(400).json({ error: 'Rental Deposit is required for rental assets' });
    }

    const client = await db.pool.connect();

    try {
        // 2. Transaction Start
        await client.query('BEGIN');

        // 3. Insert Product
        const insertQuery = `
      INSERT INTO products (
        name, sku, type, description, base_selling_price, rental_deposit_amount, reorder_level,
        cost_price, category, wholesale_price, min_wholesale_qty, color, images
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
      RETURNING *
    `;

        const description = req.body.description || '';
        const depositValue = type === 'asset_rental' ? rentalDeposit : 0.00;

        const values = [
            name,
            productSku,
            type,
            description,
            baseSellingPrice,
            depositValue,
            reorderLevel || 10,
            costPrice || 0.00,
            category || 'General',
            wholesalePrice || null,
            minWholesaleQty || 0,
            color || null,
            req.body.images || []
        ];

        const result = await client.query(insertQuery, values);
        const newProduct = result.rows[0];

        // 4. Conditional Logic (The Split)
        if (type === 'asset_rental') {
            console.log(`[INFO] Asset Created: ID ${newProduct.id} (${newProduct.name})`);
            // Future: tracking individual assets
        }

        // 5. Commit
        await client.query('COMMIT');

        // 6. Response
        res.status(201).json(newProduct);

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Create Product Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    } finally {
        client.release();
    }
};

exports.getProducts = async (req, res) => {
    try {
        const { branchId, search } = req.query;

        let query = `
            SELECT p.*, COALESCE(SUM(ib.quantity_remaining), 0) as stock_level
            FROM products p
        `;

        const params = [];
        let whereClauses = ['p.is_active = true']; // [NEW] Soft Delete Filter

        // Join Logic
        if (branchId) {
            query += ` LEFT JOIN inventory_batches ib ON p.id = ib.product_id AND ib.branch_id = $1`;
            params.push(branchId);
        } else {
            query += ` LEFT JOIN inventory_batches ib ON p.id = ib.product_id`;
        }

        // Search Logic
        if (search) {
            const searchParamIndex = params.length + 1;
            whereClauses.push(`(LOWER(p.name) LIKE LOWER($${searchParamIndex}) OR LOWER(p.sku) LIKE LOWER($${searchParamIndex}))`);
            params.push(`%${search}%`);
        }

        // Apply Where Clauses
        if (whereClauses.length > 0) {
            query += ` WHERE ${whereClauses.join(' AND ')}`;
        }

        query += ` GROUP BY p.id ORDER BY p.created_at DESC`;

        const result = await db.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Get Products Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

exports.getProductById = async (req, res) => {
    const { id } = req.params;
    try {
        const result = await db.query(`
            SELECT p.*, COALESCE(SUM(ib.quantity_remaining), 0) as stock_level
            FROM products p
            LEFT JOIN inventory_batches ib ON p.id = ib.product_id
            WHERE p.id = $1 AND p.is_active = true
            GROUP BY p.id
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Product not found' });
        }
        res.json(result.rows[0]);
    } catch (err) {
        console.error('Get Product By ID Error:', err);
        res.status(500).json({ error: 'Database error' });
    }
};

exports.getProductByName = async (req, res) => {
    const { name } = req.query;
    if (!name) return res.status(400).json({ error: 'Name required' });

    try {
        const result = await db.query(
            'SELECT * FROM products WHERE LOWER(name) = LOWER($1) ORDER BY created_at DESC LIMIT 1',
            [name]
        );
        if (result.rows.length > 0) {
            res.json({ found: true, product: result.rows[0] });
        } else {
            res.json({ found: false });
        }
    } catch (err) {
        console.error('Check Name Error:', err);
        res.status(500).json({ error: 'Database error' });
    }
};

exports.updateProduct = async (req, res) => {
    const { id } = req.params;
    const {
        name, type, baseSellingPrice, rentalDeposit, reorderLevel,
        costPrice, category, wholesalePrice, minWholesaleQty, color, description, images
    } = req.body;

    try {
        const query = `
            UPDATE products 
            SET name = $1, type = $2, base_selling_price = $3, rental_deposit_amount = $4, 
                reorder_level = $5, cost_price = $6, category = $7, wholesale_price = $8, 
                min_wholesale_qty = $9, color = $10, description = $11, images = $12
            WHERE id = $13
            RETURNING *
        `;
        const values = [
            name, type, baseSellingPrice, rentalDeposit || 0, reorderLevel,
            costPrice || 0, category, wholesalePrice, minWholesaleQty, color, description || '',
            images || [], id
        ];

        const result = await db.query(query, values);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Product not found' });
        }
        res.json(result.rows[0]);
    } catch (err) {
        console.error('Update Product Error:', err);
        res.status(500).json({ error: 'Database error' });
    }
};

exports.deleteProduct = async (req, res) => {
    const { id } = req.params;
    try {
        // [NEW] Soft Delete Implementation
        const result = await db.query('UPDATE products SET is_active = false WHERE id = $1 RETURNING id', [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Product not found' });
        }
        res.json({ message: 'Product archived successfully' });
    } catch (err) {
        console.error('Delete Product Error:', err);
        res.status(500).json({ error: 'Database error' });
    }
};

exports.getTrashedProducts = async (req, res) => {
    try {
        // Fetch all inactive products
        const result = await db.query(`
            SELECT * FROM products 
            WHERE is_active = false 
            ORDER BY created_at DESC
        `);
        res.json(result.rows);
    } catch (err) {
        console.error('Get Trash Error:', err);
        res.status(500).json({ error: 'Database error' });
    }
};

exports.restoreProduct = async (req, res) => {
    const { id } = req.params;
    try {
        const result = await db.query('UPDATE products SET is_active = true WHERE id = $1 RETURNING *', [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Product not found' });
        }
        res.json({ message: 'Product restored successfully', product: result.rows[0] });
    } catch (err) {
        console.error('Restore Product Error:', err);
        res.status(500).json({ error: 'Database error' });
    }
};

exports.getStockHistory = async (req, res) => {
    const { id } = req.params;
    try {
        // Fetch movements
        const result = await db.query(`
            SELECT * FROM stock_movements 
            WHERE product_id = $1 
            ORDER BY created_at DESC 
            LIMIT 100
        `, [id]);

        res.json(result.rows);
    } catch (err) {
        console.error('Get History Error:', err);
        res.status(500).json({ error: 'Database error' });
    }
};
