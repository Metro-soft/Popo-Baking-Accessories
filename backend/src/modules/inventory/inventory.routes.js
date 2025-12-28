const express = require('express');
const router = express.Router();
const inventoryController = require('./inventory.controller');

// POST /api/inventory/receive
router.post('/receive', inventoryController.receiveStock);
router.get('/alerts', inventoryController.getLowStockItems);
router.post('/adjust', inventoryController.adjustStock);
router.post('/transfer', inventoryController.createTransfer);

module.exports = router;
