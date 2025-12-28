const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

process.on('exit', (code) => {
    console.log(`Process exiting with code: ${code}`);
});

process.on('uncaughtException', (err) => {
    console.error('Uncaught Exception:', err);
});

// Middleware
const corsOptions = {
    origin: ['http://localhost:3000', 'http://localhost:8000', 'http://127.0.0.1:3000'], // Add Frontend ports
    optionsSuccessStatus: 200
};
app.use(cors(corsOptions));
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
const categoryRoutes = require('./modules/inventory/category.routes');

const { authenticateToken } = require('./middleware/auth.middleware');

const path = require('path');
const uploadRoutes = require('./modules/core/upload.routes');

// Serve uploaded files statically
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Public Routes
app.use('/api/auth', authRoutes); // Login/Register

// Protected Routes
app.use('/api/upload', authenticateToken, uploadRoutes);
app.use('/api/products', authenticateToken, productRoutes);
app.use('/api/inventory', authenticateToken, inventoryRoutes);
app.use('/api/suppliers', authenticateToken, supplierRoutes);
app.use('/api/sales', authenticateToken, salesRoutes);
app.use('/api/customers', authenticateToken, customerRoutes);
app.use('/api/analytics', authenticateToken, analyticsRoutes);
app.use('/api/branches', authenticateToken, branchRoutes);
app.use('/api/cash', authenticateToken, cashRoutes);
app.use('/api/categories', authenticateToken, categoryRoutes); // New Category Route

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});

// Force Keep-Alive to prevent premature exit (Debugging)
setInterval(() => {
    // console.log('Heartbeat...'); 
}, 10000);
