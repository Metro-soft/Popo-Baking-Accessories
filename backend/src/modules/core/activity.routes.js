const express = require('express');
const router = express.Router();
const activityController = require('./activity.controller');
// const authMiddleware = require('../../middleware/authMiddleware'); // Assuming authentication exists

// router.use(authMiddleware); // Protect all activity routes

router.get('/', activityController.getLogs);

module.exports = router;
