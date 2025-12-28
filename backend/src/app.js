const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
// Routes
const authRoutes = require('./modules/core/auth.routes');
const productRoutes = require('./modules/inventory/product.routes');
const inventoryRoutes = require('./modules/inventory/inventory.routes');
const supplierRoutes = require('./modules/procurement/supplier.routes');
const salesRoutes = require('./modules/sales/sales.routes');
const customerRoutes = require('./modules/sales/customer.routes');
const analyticsRoutes = require('./modules/analytics/analytics.routes');
const branchRoutes = require('./modules/core/branch.routes');
const cashRoutes = require('./modules/finance/cash.routes');

const { authenticateToken } = require('./middleware/auth.middleware');

// Public Routes
app.use('/api/auth', authRoutes); // Login/Register

// Protected Routes
app.use('/api/products', authenticateToken, productRoutes);
app.use('/api/inventory', authenticateToken, inventoryRoutes);
app.use('/api/suppliers', authenticateToken, supplierRoutes);
app.use('/api/sales', authenticateToken, salesRoutes);
app.use('/api/customers', authenticateToken, customerRoutes);
app.use('/api/analytics', authenticateToken, analyticsRoutes);
app.use('/api/branches', authenticateToken, branchRoutes);
app.use('/api/cash', authenticateToken, cashRoutes);

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
