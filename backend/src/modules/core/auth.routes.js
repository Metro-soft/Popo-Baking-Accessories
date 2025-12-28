const express = require('express');
const router = express.Router();
const AuthController = require('./auth.controller');
const { authenticateToken } = require('../../middleware/auth.middleware');

// Public Routes
router.post('/register', AuthController.register); // Ideally protect this for Admin only later
router.post('/login', AuthController.login);

// Protected Routes
router.get('/profile', authenticateToken, AuthController.getProfile);

module.exports = router;
