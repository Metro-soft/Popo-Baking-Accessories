const express = require('express');
const router = express.Router();
const productController = require('./product.controller');

// POST /api/products
router.post('/', productController.createProduct);

// GET /api/products
router.get('/', productController.getProducts);

module.exports = router;
