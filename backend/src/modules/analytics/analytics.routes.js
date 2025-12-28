const express = require('express');
const router = express.Router();
const analyticsController = require('./analytics.controller');

const { requireRole } = require('../../middleware/auth.middleware');

router.get('/stats', requireRole(['admin', 'manager']), analyticsController.getDashboardStats);
router.get('/top-products', requireRole(['admin', 'manager']), analyticsController.getTopProducts);

module.exports = router;
