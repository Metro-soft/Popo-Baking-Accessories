const express = require('express');
const router = express.Router();
const controller = require('./expenses.controller');
const { authenticateToken } = require('../../middleware/auth.middleware');

router.use(authenticateToken); // Protect all routes

// Categories
router.get('/categories', controller.getCategories);
router.post('/categories', controller.createCategory);
router.delete('/categories/:id', controller.deleteCategory);

// Expenses
router.get('/', controller.getExpenses);
router.post('/', controller.createExpense);
router.delete('/:id', controller.deleteExpense);

module.exports = router;
