const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
const productRoutes = require('./modules/inventory/product.routes');
const inventoryRoutes = require('./modules/inventory/inventory.routes');
const supplierRoutes = require('./modules/procurement/supplier.routes');
const salesRoutes = require('./modules/sales/sales.routes');
const customerRoutes = require('./modules/sales/customer.routes');
const securityRoutes = require('./modules/core/auth.routes');
const analyticsRoutes = require('./modules/analytics/analytics.routes');
const branchRoutes = require('./modules/core/branch.routes');
const cashRoutes = require('./modules/finance/cash.routes');

app.use('/api/products', productRoutes);
app.use('/api/inventory', inventoryRoutes);
app.use('/api/suppliers', supplierRoutes);
app.use('/api/sales', salesRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/security', securityRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/branches', branchRoutes);
app.use('/api/cash', cashRoutes);

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
