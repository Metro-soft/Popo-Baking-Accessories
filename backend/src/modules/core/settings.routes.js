const express = require('express');
const router = express.Router();
const settingsController = require('./settings.controller');
const { authenticateToken } = require('../../middleware/auth.middleware');

// Both get and update require at least being logged in.
// Updating might require admin role, but for now we allow any authorized user (or Manager/Admin).
router.get('/', authenticateToken, settingsController.getSettings);
router.put('/', authenticateToken, settingsController.updateSettings);

module.exports = router;
