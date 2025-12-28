const db = require('../../config/db');

exports.createProduct = async (req, res) => {
    const { name, sku, type, baseSellingPrice, rentalDeposit, reorderLevel } = req.body;

    // 1. Validation
    if (!name || !sku || !type || baseSellingPrice === undefined) {
        return res.status(400).json({ error: 'Missing required fields' });
    }

    // Check if SKU already exists
    try {
        const skuCheck = await db.query('SELECT id FROM products WHERE sku = $1', [sku]);
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
        // Note: Mapping frontend camelCase to DB snake_case
        const insertQuery = `
      INSERT INTO products (
        name, sku, type, description, base_selling_price, rental_deposit_amount, reorder_level
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *
    `;

        // Use default description if empty
        const description = req.body.description || '';

        // Rental deposit is 0 for retail, or provided value for asset
        const depositValue = type === 'asset_rental' ? rentalDeposit : 0.00;

        const values = [
            name,
            sku,
            type,
            description,
            baseSellingPrice,
            depositValue,
            reorderLevel || 10
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
        const result = await db.query('SELECT * FROM products ORDER BY created_at DESC');
        res.json(result.rows);
    } catch (err) {
        console.error('Get Products Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};
