const express = require('express');
const router = express.Router();
const purchasesController = require('./purchases.controller');

router.get('/bills', purchasesController.getBills);
router.post('/payments', purchasesController.recordPayment);

module.exports = router;
