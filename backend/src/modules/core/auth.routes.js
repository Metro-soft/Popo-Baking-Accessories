const express = require('express');
const router = express.Router();
const securityController = require('./security.controller');

router.post('/shift/open', securityController.openShift);
router.post('/shift/close', securityController.closeShift);
router.get('/history', securityController.getShiftHistory);
router.get('/audit', securityController.getAuditLogs);

module.exports = router;
