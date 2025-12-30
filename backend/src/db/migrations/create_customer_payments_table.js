const pool = require('../../config/db');

const createCustomerPaymentsTable = async () => {
    try {
        await pool.query(`
            CREATE TABLE IF NOT EXISTS customer_payments (
                id SERIAL PRIMARY KEY,
                customer_id INTEGER REFERENCES customers(id) ON DELETE CASCADE,
                order_id INTEGER REFERENCES orders(id) ON DELETE SET NULL,
                amount DECIMAL(10, 2) NOT NULL,
                payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                method TEXT,
                notes TEXT
            );
        `);
        console.log('Customer payments table created successfully');
    } catch (err) {
        console.error('Error creating customer payments table:', err);
    }
};

createCustomerPaymentsTable();
