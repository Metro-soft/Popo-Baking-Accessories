const express = require('express');
const router = express.Router();
const payrollController = require('./payroll.controller');
const { authenticateToken } = require('../../middleware/auth.middleware');

router.use(authenticateToken);

// Employees
router.get('/employees', payrollController.getEmployees);
router.post('/employees', payrollController.createEmployee);
router.put('/employees/:id', payrollController.updateEmployee);
router.get('/employees/:id/history', payrollController.getEmployeeHistory);

// Runs
router.get('/runs', payrollController.getRuns);
router.post('/runs', payrollController.createRun); // Calculate & Draft
router.post('/ensure-item', payrollController.ensureRunAndItem); // On-Demand Item Gen
router.get('/runs/:id', payrollController.getRunDetails);
router.put('/items/:id', payrollController.updateItem); // Update single item bonus/deduction
router.post('/items/:id/finalize', payrollController.finalizeItem); // Pay Individual Item
router.post('/runs/:id/finalize', payrollController.finalizeRun); // Pay & Record Expense

module.exports = router;
