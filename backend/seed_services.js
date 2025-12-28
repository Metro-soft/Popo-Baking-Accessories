const db = require('./src/config/db');

async function seedServices() {
    const client = await db.pool.connect();
    try {
        console.log('Beginning Seeding...');
        await client.query('BEGIN');

        // 1. Update Enum (Safe approach if not exists, but we might need to recreate it if strict)
        // PostgreSQL ENUM updates are tricky. We will try to add the value if it doesn't exist
        // or we assume the user might have reset the DB. 
        // For now, let's just insert the data assuming the schema update was applied or will be applied.
        // Actually, simply running specific INSERTs.

        // We need to ensure the ENUM has 'service_print'. 
        // 'ALTER TYPE product_type ADD VALUE IF NOT EXISTS 'service_print';'
        await client.query("ALTER TYPE product_type ADD VALUE IF NOT EXISTS 'service_print'");

        const queries = [
            // 1. Raw Materials
            "INSERT INTO products (name, sku, type, base_selling_price) VALUES ('Edible Icing Sheets (Pack)', 'MAT-EDIBLE-A4', 'raw_material', 0.00) ON CONFLICT (sku) DO NOTHING",
            "INSERT INTO products (name, sku, type, base_selling_price) VALUES ('Glossy Photo Paper (Pack)', 'MAT-GLOSSY-A4', 'raw_material', 0.00) ON CONFLICT (sku) DO NOTHING",

            // 2. Edible Prints
            "INSERT INTO products (name, sku, type, base_selling_price) VALUES ('Edible Print (A4)', 'SVC-ED-A4', 'service_print', 600.00) ON CONFLICT (sku) DO NOTHING",
            "INSERT INTO products (name, sku, type, base_selling_price) VALUES ('Edible Print (A5)', 'SVC-ED-A5', 'service_print', 300.00) ON CONFLICT (sku) DO NOTHING",
            "INSERT INTO products (name, sku, type, base_selling_price) VALUES ('Edible Print (A6)', 'SVC-ED-A6', 'service_print', 150.00) ON CONFLICT (sku) DO NOTHING",

            // 3. Non-Edible Prints
            "INSERT INTO products (name, sku, type, base_selling_price) VALUES ('Non-Edible Print (A4)', 'SVC-NON-A4', 'service_print', 300.00) ON CONFLICT (sku) DO NOTHING",
            "INSERT INTO products (name, sku, type, base_selling_price) VALUES ('Non-Edible Print (A5)', 'SVC-NON-A5', 'service_print', 150.00) ON CONFLICT (sku) DO NOTHING",
            "INSERT INTO products (name, sku, type, base_selling_price) VALUES ('Non-Edible Print (A6)', 'SVC-NON-A6', 'service_print', 75.00) ON CONFLICT (sku) DO NOTHING"
        ];

        for (const q of queries) {
            await client.query(q);
        }

        await client.query('COMMIT');
        console.log('✅ Printing Services & Materials Seeded Successfully!');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('❌ Seeding Failed:', err);
    } finally {
        client.release();
        process.exit();
    }
}

seedServices();
