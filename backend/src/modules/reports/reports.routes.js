const express = require('express');
const router = express.Router();
const reportsController = require('./reports.controller');
const { authenticateToken, requireRole } = require('../../middleware/auth.middleware');

// All reports restricted to Admin for now
router.get('/audit', authenticateToken, requireRole(['admin']), reportsController.getAuditReport);
router.get('/sales', authenticateToken, requireRole(['admin']), reportsController.getSalesReport);
router.get('/valuation', authenticateToken, requireRole(['admin']), reportsController.getInventoryValuation);
router.get('/low-stock', authenticateToken, requireRole(['admin']), reportsController.getLowStockReport);

module.exports = router;
