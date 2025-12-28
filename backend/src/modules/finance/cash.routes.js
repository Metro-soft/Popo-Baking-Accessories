const express = require('express');
const router = express.Router();
const cashController = require('./cash.controller');

router.get('/status', cashController.getShiftStatus);
router.post('/open', cashController.openShift);
router.post('/close', cashController.closeShift);
router.post('/transaction', cashController.addTransaction);

module.exports = router;
