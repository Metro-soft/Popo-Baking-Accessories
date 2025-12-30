const runMigration = require('../db/migrations/add_opening_balance_to_partners');

(async () => {
    console.log('Starting migration...');
    await runMigration();
    console.log('Migration finished.');
    process.exit(0);
})();
