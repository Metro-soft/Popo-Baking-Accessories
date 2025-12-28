const express = require('express');
const router = express.Router();
const analyticsController = require('./analytics.controller');

router.get('/stats', analyticsController.getDashboardStats);
router.get('/top-products', analyticsController.getTopProducts);

module.exports = router;
