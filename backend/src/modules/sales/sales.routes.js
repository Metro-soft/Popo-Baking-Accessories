const express = require('express');
const router = express.Router();
const salesController = require('./sales.controller');

router.post('/transaction', salesController.processTransaction);
router.get('/history', salesController.getSalesHistory);
router.get('/orders/:id', salesController.getOrderDetails);

module.exports = router;
