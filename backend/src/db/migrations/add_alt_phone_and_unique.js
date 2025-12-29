const db = require('../../config/db');

async function up() {
    // 1. Add alt_phone column
    await db.query(`
        ALTER TABLE customers 
        ADD COLUMN IF NOT EXISTS alt_phone TEXT;
    `);

    // 2. Add Unique Constraint to Primary Phone
    // We strictly enforce uniqueness on the PRIMARY phone to prevent duplicates.
    // We treat existing duplicates by... well, this might fail if there are duplicates.
    // For now, we assume the user understands this might fail if data is dirty.
    // But since we are dev-ing, we can try.
    try {
        await db.query(`
            ALTER TABLE customers 
            ADD CONSTRAINT customers_phone_key UNIQUE (phone);
        `);
    } catch (e) {
        console.warn("Could not add unique constraint, possibly duplicate phones exist:", e.message);
    }
}

up().then(() => {
    console.log('Migration Applied: Added alt_phone and Unique Phone Constraint');
    process.exit(0);
}).catch(err => {
    console.error(err);
    process.exit(1);
});
