const db = require('../config/db');

const products = [
    {
        name: 'Baking Flour (Premium)',
        sku: 'POPO-FLOUR-5KG',
        type: 'retail',
        description: 'High quality all-purpose flour',
        base_selling_price: 850.00,
        cost_price: 650.00,
        category: 'Ingredients',
        stock: 50,
        reorder: 10,
        wholesale_price: 800.00,
        min_wholesale_qty: 10,
        color: 'White'
    },
    {
        name: 'Red Velvet Cake Mix',
        sku: 'POPO-MIX-RED',
        type: 'retail',
        description: 'Instant red velvet mix',
        base_selling_price: 1200.00,
        cost_price: 800.00,
        category: 'Ingredients',
        stock: 15,
        reorder: 20,
        wholesale_price: 1100.00,
        min_wholesale_qty: 5,
        color: 'Red'
    },
    {
        name: 'Cake Box 10x10',
        sku: 'POPO-BOX-10',
        type: 'retail',
        description: 'White sturdy cake box',
        base_selling_price: 50.00,
        cost_price: 25.00,
        category: 'Packaging',
        stock: 500,
        reorder: 100,
        wholesale_price: 45.00,
        min_wholesale_qty: 50,
        color: 'White'
    },
    {
        name: 'Cake Board 12 Inch',
        sku: 'POPO-BOARD-12',
        type: 'retail',
        description: 'Gold foil cake board',
        base_selling_price: 80.00,
        cost_price: 40.00,
        category: 'Packaging',
        stock: 200,
        reorder: 50,
        wholesale_price: 70.00,
        min_wholesale_qty: 20,
        color: 'Gold'
    },
    {
        name: 'Wedding Cake Stand (3 Tier)',
        sku: 'ASSET-STAND-001',
        type: 'asset_rental',
        description: 'Gold plated rental stand',
        base_selling_price: 1500.00, // Rental Price
        rental_deposit_amount: 5000.00,
        cost_price: 15000.00, // Asset Value
        category: 'Rentals',
        stock: 3,
        reorder: 1,
        color: 'Gold'
    },
    {
        name: 'Cookie Cutter Set',
        sku: 'POPO-CUTTER-SET',
        type: 'retail',
        description: 'Set of 12 shapes',
        base_selling_price: 450.00,
        cost_price: 200.00,
        category: 'Tools',
        stock: 8,
        reorder: 5,
        wholesale_price: 400.00,
        min_wholesale_qty: 5,
        color: 'Metal'
    },
    {
        name: 'Edible Gold Dust',
        sku: 'POPO-DUST-GLD',
        type: 'retail',
        description: 'Decorating lustre dust',
        base_selling_price: 300.00,
        cost_price: 100.00,
        category: 'Decorations',
        stock: 100,
        reorder: 10,
        color: 'Gold'
    },
    {
        name: 'Chocolate Dark 1kg',
        sku: 'POPO-CHOC-DARK',
        type: 'retail',
        description: 'Cooking chocolate',
        base_selling_price: 1100.00,
        cost_price: 850.00,
        category: 'Ingredients',
        stock: 0, // OUT OF STOCK TEST
        reorder: 5,
        wholesale_price: 1050.00,
        min_wholesale_qty: 10,
        color: 'Dark'
    },
    {
        name: 'Birthday Candles (Pack)',
        sku: 'POPO-CANDLE-PK',
        type: 'retail',
        description: 'Assorted colors',
        base_selling_price: 100.00,
        cost_price: 30.00,
        category: 'Decorations',
        stock: 300,
        reorder: 50,
        color: 'Multi'
    },
    {
        name: 'Wrapping Paper Roll',
        sku: 'POPO-WRAP-ROLL',
        type: 'raw_material',
        description: 'For internal packaging use',
        base_selling_price: 0.00,
        cost_price: 200.00,
        category: 'Supplies',
        stock: 5,
        reorder: 2,
        color: 'Brown'
    }
];

async function seed() {
    try {
        console.log('🌱 Seeding Products...');

        for (const p of products) {
            // Check if exists
            const check = await db.query('SELECT id FROM products WHERE sku = $1', [p.sku]);
            let productId;

            if (check.rows.length > 0) {
                console.log(`Skipping ${p.sku} (Already exists)`);
                continue; // Or update? Skipping for now.
            } else {
                // Insert Product
                const res = await db.query(`
                    INSERT INTO products (
                        name, sku, type, description, base_selling_price, rental_deposit_amount, 
                        cost_price, category, wholesale_price, min_wholesale_qty, color, reorder_level
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                    RETURNING id
                `, [
                    p.name, p.sku, p.type, p.description, p.base_selling_price, p.rental_deposit_amount || 0,
                    p.cost_price, p.category, p.wholesale_price || null, p.min_wholesale_qty || 0, p.color, p.reorder
                ]);
                productId = res.rows[0].id;
                console.log(`✅ Created Product: ${p.name}`);
            }

            await db.query(`
                    INSERT INTO inventory_batches (
                        product_id, batch_number, branch_id, quantity_initial, quantity_remaining, 
                        buying_price_unit, expiry_date, received_at, location
                    ) VALUES ($1, $2, $3, $4, $5, $6, NULL, NOW(), 'thika_store')
                `, [productId, `SEED-${Date.now()}`, 1, p.stock, p.stock, p.cost_price]);
            console.log(`   📦 Added Stock: ${p.stock} units`);
        }

        console.log('✨ Seeding Completed!');
        process.exit(0);
    } catch (e) {
        console.error('❌ Seeding Failed:', e);
        process.exit(1);
    }
}

seed();
