const express = require('express');
const router = express.Router();
const customerController = require('./customer.controller');

router.get('/', customerController.getCustomers);
router.post('/', customerController.createCustomer);
router.post('/settle', customerController.settleDebt);

module.exports = router;
