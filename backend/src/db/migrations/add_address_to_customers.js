const db = require('../../config/db');

async function up() {
    await db.query(`
        ALTER TABLE customers 
        ADD COLUMN IF NOT EXISTS address TEXT;
    `);
}

up().then(() => {
    console.log('Migration Applied: Added address to customers');
    process.exit(0);
}).catch(err => {
    console.error(err);
    process.exit(1);
});
