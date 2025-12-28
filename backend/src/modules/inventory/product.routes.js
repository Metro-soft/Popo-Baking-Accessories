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

// DELETE /api/products/:id
router.delete('/:id', productController.deleteProduct);

// GET /api/products/:id/history
router.get('/:id/history', productController.getStockHistory);

// GET /api/products/:id
router.get('/:id', productController.getProductById);

module.exports = router;
