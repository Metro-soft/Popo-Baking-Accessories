const db = require('../config/db');

async function migrate() {
    console.log('🔄 Migrating: Adding permissions to job_roles...');
    try {
        // Add permissions column if it doesn't exist
        await db.query(`
            ALTER TABLE job_roles 
            ADD COLUMN IF NOT EXISTS permissions TEXT[] DEFAULT '{}';
        `);
        console.log('✅ Column `permissions` added successfully.');
        process.exit(0);
    } catch (err) {
        console.error('❌ Migration Failed:', err);
        process.exit(1);
    }
}

migrate();
