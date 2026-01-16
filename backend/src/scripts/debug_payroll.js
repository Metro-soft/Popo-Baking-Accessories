const db = require('../config/db');

const runDebug = async () => {
    try {
        console.log('--- DEBUGGING PAYROLL DATA ---');

        // 1. Check Payroll Items (Source for Dashboard Card currently)
        const items = await db.query(`
            SELECT pi.id, pi.net_pay, pi.status, pi.paid_at, e.name 
            FROM payroll_items pi
            JOIN employees e ON pi.employee_id = e.id
        `);
        console.log('\n[Payroll Items Table] (Used by Dashboard Card):');
        if (items.rows.length === 0) console.log('  <EMPTY>');
        items.rows.forEach(r => {
            console.log(`  ID: ${r.id} | Name: ${r.name} | Status: ${r.status} | PaidAt: ${r.paid_at} | Amount: ${r.net_pay}`);
        });

        // 2. Check Expenses (Source for Recenty Activity List)
        const expenses = await db.query(`
            SELECT id, description, amount, date, type 
            FROM expenses 
            WHERE description LIKE 'Payroll%'
        `);
        console.log('\n[Expenses Table] (Used by Activity List):');
        if (expenses.rows.length === 0) console.log('  <EMPTY>');
        expenses.rows.forEach(r => {
            console.log(`  ID: ${r.id} | Desc: ${r.description} | Type: ${r.type} | Amount: ${r.amount}`);
        });

        console.log('\n------------------------------');

    } catch (err) {
        console.error('Debug Error:', err);
    } finally {
        process.exit();
    }
};

runDebug();
