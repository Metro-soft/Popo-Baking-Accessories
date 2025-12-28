const { Pool } = require('pg');
require('dotenv').config();

// Construct connection config
// If DATABASE_URL is provided, use it, otherwise use individual vars
const poolConfig = process.env.DATABASE_URL
    ? { connectionString: process.env.DATABASE_URL }
    : {
        user: process.env.DB_USER,
        host: process.env.DB_HOST,
        database: process.env.DB_NAME,
        password: process.env.DB_PASSWORD, // Ensure quotes in .env are handled by dotenv
        port: 5432,
    };

const pool = new Pool(poolConfig);

module.exports = {
    query: (text, params) => pool.query(text, params),
    pool, // Export pool for transaction client connection
};
