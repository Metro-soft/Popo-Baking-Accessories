const authorize = require('../../middleware/rbac.middleware');
const { authenticateToken } = require('../../middleware/auth.middleware'); // Assuming you have this

const express = require('express');
const router = express.Router();
const productController = require('./product.controller');

// POST /api/products
router.post('/', productController.createProduct);

// GET /api/products/check-name
router.get('/check-name', productController.getProductByName);

// GET /api/products
router.get('/', productController.getProducts);

// PUT /api/products/:id
router.put('/:id', productController.updateProduct);

// DELETE /api/products/:id (Admin Only)
router.delete('/:id', authenticateToken, authorize('admin'), productController.deleteProduct);

// GET /api/products/trash (Admin Only, placed before /:id)
router.get('/trash', authenticateToken, authorize('admin'), productController.getTrashedProducts);

// GET /api/products/:id/history
router.get('/:id/history', productController.getStockHistory);

// PUT /api/products/:id/restore (Admin Only)
router.put('/:id/restore', authenticateToken, authorize('admin'), productController.restoreProduct);

// GET /api/products/:id
router.get('/:id', productController.getProductById);

module.exports = router;
