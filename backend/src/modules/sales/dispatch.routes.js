const express = require('express');
const router = express.Router();
const controller = require('./dispatch.controller');

router.get('/pending', controller.getPendingDispatches);
router.put('/:id/status', controller.updateDispatchStatus);

module.exports = router;
