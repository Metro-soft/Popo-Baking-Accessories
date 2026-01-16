const express = require('express');
const router = express.Router();
const financeController = require('./finance.controller');

router.get('/stats/dashboard', financeController.getDashboardStats);

module.exports = router;
