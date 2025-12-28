const db = require('./src/config/db');

async function updateSchemaPhase6() {
    const client = await db.pool.connect();
    try {
        console.log('Applying Phase 6 Schema Updates (Security)...');
        await client.query('BEGIN');

        const queries = [
            `DROP TABLE IF EXISTS cash_drawers CASCADE`,

            `CREATE TABLE cash_drawers (
        id SERIAL PRIMARY KEY,
        user_id INT REFERENCES users(id),
        opening_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        closing_time TIMESTAMP,
        starting_cash DECIMAL(10, 2) NOT NULL,
        system_calculated_cash DECIMAL(10, 2) DEFAULT 0.00,
        actual_counted_cash DECIMAL(10, 2),
        difference DECIMAL(10, 2),
        status VARCHAR(20) DEFAULT 'open',
        notes TEXT
      )`,

            `CREATE TABLE IF NOT EXISTS audit_logs (
        id SERIAL PRIMARY KEY,
        user_id INT REFERENCES users(id),
        action VARCHAR(50) NOT NULL,
        details TEXT,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )`
        ];

        for (const q of queries) {
            await client.query(q);
        }

        await client.query('COMMIT');
        console.log('✅ Phase 6 Tables Created Successfully!');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('❌ Update Failed:', err);
    } finally {
        client.release();
        process.exit();
    }
}

updateSchemaPhase6();
