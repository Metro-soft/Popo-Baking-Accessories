const db = require('../config/db');

async function fixConstraint() {
    try {
        console.log('Forcing constraint update...');
        // 1. Drop the old constraint (try multiple potential names to be safe)
        await db.query(`ALTER TABLE expense_categories DROP CONSTRAINT IF EXISTS expense_categories_type_check`);

        // 2. Add the new constraint
        // Allowing legacy 'direct'/'indirect' AND new 'OPERATIONAL', 'PAYROLL', 'BILL'
        await db.query(`
            ALTER TABLE expense_categories 
            ADD CONSTRAINT expense_categories_type_check 
            CHECK (type IN ('direct', 'indirect', 'OPERATIONAL', 'PAYROLL', 'BILL'))
        `);

        console.log('✅ Constraint updated successfully.');
        process.exit(0);
    } catch (err) {
        console.error('❌ Error updating constraint:', err);
        process.exit(1);
    }
}

fixConstraint();
