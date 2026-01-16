const db = require('../config/db');

const EMPLOYEES = [
    {
        name: 'John Salesman',
        role: 'Shop Attendant',
        department: 'Sales',
        base_salary: 18000,
        payment_preference: 'SPLIT',
        fixed_advance_amount: 5000
    },
    {
        name: 'Alice Cashier',
        role: 'Cashier',
        department: 'Sales',
        base_salary: 22000,
        payment_preference: 'FULL',
        fixed_advance_amount: 0
    },
    {
        name: 'Bob Packer',
        role: 'Packaging Assistant',
        department: 'Operations',
        base_salary: 15000,
        payment_preference: 'SPLIT',
        fixed_advance_amount: 6000
    },
    {
        name: 'Sarah Store',
        role: 'Storekeeper',
        department: 'Operations',
        base_salary: 25000,
        payment_preference: 'FULL',
        fixed_advance_amount: 0
    },
    {
        name: 'Mike Rider',
        role: 'Delivery Rider',
        department: 'Logistics',
        base_salary: 16000,
        payment_preference: 'SPLIT',
        fixed_advance_amount: 4000
    },
    {
        name: 'David Driver',
        role: 'Driver',
        department: 'Logistics',
        base_salary: 28000,
        payment_preference: 'FULL',
        fixed_advance_amount: 0
    },
    {
        name: 'Emma Admin',
        role: 'HR Admin',
        department: 'Management',
        base_salary: 35000,
        payment_preference: 'FULL',
        fixed_advance_amount: 0
    },
    {
        name: 'Peter Manager',
        role: 'General Manager',
        department: 'Management',
        base_salary: 60000,
        payment_preference: 'FULL',
        fixed_advance_amount: 0
    },
    {
        name: 'Chris Cleaner',
        role: 'Cleaner',
        department: 'Operations',
        base_salary: 12000,
        payment_preference: 'SPLIT',
        fixed_advance_amount: 3000
    }
];

async function seed() {
    console.log('🌱 Seeding Dummy Employees...');

    try {
        // 1. Clear Existing Data
        console.log('Cleaning up old records...');
        await db.query('DELETE FROM payroll_items');
        await db.query('DELETE FROM payroll_runs');
        await db.query('DELETE FROM employees');

        // 2. Insert New Employees
        for (const emp of EMPLOYEES) {
            await db.query(
                `INSERT INTO employees (name, role, department, base_salary, payment_preference, fixed_advance_amount, phone, email, status) 
                 VALUES ($1, $2, $3, $4, $5, $6, '0700000000', 'test@popo.com', 'Active')`,
                [emp.name, emp.role, emp.department, emp.base_salary, emp.payment_preference, emp.fixed_advance_amount]
            );
            console.log(`   + Added: ${emp.name} (${emp.role})`);
        }

        console.log('✅ Employee Seeding Complete!');
        process.exit(0);
    } catch (err) {
        console.error('❌ Seeding Failed:', err);
        process.exit(1);
    }
}

seed();
