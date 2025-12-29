const express = require('express');
const router = express.Router();
const partnersController = require('./partners.controller');
// Auth is handled in app.js via app.use('/api/partners', authenticateToken, ...)
// router.use(verifyToken);

// Suppliers
router.get('/suppliers', partnersController.getSuppliers);
router.post('/suppliers', partnersController.createSupplier);
router.put('/suppliers/:id', partnersController.updateSupplier);
router.delete('/suppliers/:id', partnersController.deleteSupplier);
router.get('/suppliers/:id/transactions', partnersController.getSupplierTransactions);

// Customers
router.get('/customers', partnersController.getCustomers);
router.post('/customers', partnersController.createCustomer);
router.put('/customers/:id', partnersController.updateCustomer);
router.delete('/customers/:id', partnersController.deleteCustomer);
router.get('/customers/:id/transactions', partnersController.getCustomerTransactions);

module.exports = router;
