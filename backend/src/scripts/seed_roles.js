const db = require('../config/db');

const ROLES_WITH_PERMISSIONS = {
    // --- SALES ---
    'Shop Attendant': ['sales', 'customers'],
    'Cashier': ['sales', 'finance_view'],
    'Online Sales Rep': ['sales', 'customers', 'orders'],
    'Account Manager': ['sales', 'customers', 'orders'],

    // --- OPERATIONS ---
    'Storekeeper': ['inventory', 'products'],
    'Packaging Assistant': ['inventory_view'],
    'Procurement Officer': ['inventory', 'suppliers', 'purchases'],
    'Cleaner': [],

    // --- LOGISTICS ---
    'Dispatch Coordinator': ['orders', 'dispatch'],
    'Delivery Rider': ['dispatch'],
    'Driver': ['dispatch'],
    'Loader': [],

    // --- MANAGEMENT ---
    'General Manager': ['admin', 'sales', 'inventory', 'finance', 'reports', 'settings', 'payroll'],
    'Accountant': ['finance', 'reports', 'payroll'],
    'HR Admin': ['settings', 'payroll']
};

const DEPARTMENTS = {
    'Sales': ['Shop Attendant', 'Cashier', 'Online Sales Rep', 'Account Manager'],
    'Operations': ['Storekeeper', 'Packaging Assistant', 'Procurement Officer', 'Cleaner'],
    'Logistics': ['Dispatch Coordinator', 'Delivery Rider', 'Driver', 'Loader'],
    'Management': ['General Manager', 'Accountant', 'HR Admin']
};

async function seed() {
    console.log('🌱 Seeding Roles & Permissions...');

    try {
        for (const [deptName, roles] of Object.entries(DEPARTMENTS)) {
            // 1. Ensure Department
            let deptRes = await db.query('SELECT id FROM departments WHERE name = $1', [deptName]);
            let deptId;

            if (deptRes.rows.length === 0) {
                deptRes = await db.query('INSERT INTO departments (name) VALUES ($1) RETURNING id', [deptName]);
                deptId = deptRes.rows[0].id;
            } else {
                deptId = deptRes.rows[0].id;
            }

            // 2. Ensure Roles & Update Permissions
            for (const roleName of roles) {
                const permissions = ROLES_WITH_PERMISSIONS[roleName] || [];

                // Check if role exists
                const roleRes = await db.query(
                    'SELECT id FROM job_roles WHERE name = $1 AND department_id = $2',
                    [roleName, deptId]
                );

                if (roleRes.rows.length === 0) {
                    await db.query(
                        'INSERT INTO job_roles (name, department_id, permissions) VALUES ($1, $2, $3)',
                        [roleName, deptId, permissions]
                    );
                    console.log(`   + Created: ${roleName} [${permissions.length} perms]`);
                } else {
                    // Update permissions just in case
                    await db.query(
                        'UPDATE job_roles SET permissions = $1 WHERE id = $2',
                        [permissions, roleRes.rows[0].id]
                    );
                    console.log(`   ~ Updated: ${roleName}`);
                }
            }
        }
        console.log('✅ Permissions Seeding Complete!');
        process.exit(0);
    } catch (err) {
        console.error('❌ Seeding Failed:', err);
        process.exit(1);
    }
}

seed();
