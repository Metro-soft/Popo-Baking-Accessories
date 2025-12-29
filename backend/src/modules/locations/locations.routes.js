const express = require('express');
const router = express.Router();
const locationsController = require('./locations.controller');
const { requireRole } = require('../../middleware/auth.middleware');

// Public read (needed for dropdowns), but write restricted to Admin/Manager
router.get('/', locationsController.getAllLocations);
router.post('/', requireRole(['admin']), locationsController.createLocation);
router.put('/:id', requireRole(['admin']), locationsController.updateLocation);

module.exports = router;
