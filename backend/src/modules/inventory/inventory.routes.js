const express = require('express');
const router = express.Router();
const inventoryController = require('./inventory.controller');

const { requireRole } = require('../../middleware/auth.middleware');

// POST /api/inventory/receive
// Receive is common, but maybe restrict to staff+ (already protected by authMiddleware in app.js)
router.post('/receive', inventoryController.receiveStock);

router.get('/alerts', inventoryController.getLowStockItems);

// Sensitive Actions
router.post('/adjust', requireRole(['admin', 'manager']), inventoryController.adjustStock);
router.post('/transfer', requireRole(['admin', 'manager']), inventoryController.createTransfer);
router.get('/product/:productId/branches', inventoryController.getStockByBranch);

module.exports = router;
