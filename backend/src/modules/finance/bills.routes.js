const express = require('express');
const router = express.Router();
const billsController = require('./bills.controller');
const { authenticateToken } = require('../../middleware/auth.middleware');

router.use(authenticateToken);

router.get('/', billsController.getBills);
router.post('/trigger', billsController.triggerAutoPay);
router.post('/', billsController.createBill);
router.post('/:id/pay', billsController.payBill);
router.delete('/:id', billsController.deleteBill);

module.exports = router;
