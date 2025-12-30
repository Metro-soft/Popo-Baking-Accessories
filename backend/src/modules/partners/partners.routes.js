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
router.get('/customers/:id/statement', partnersController.getCustomerStatement);
router.post('/customers/:id/payments', partnersController.addCustomerPayment);
router.get('/customers/:id/unpaid-orders', partnersController.getCustomerUnpaidOrders);

// Supplier Payments & Details
router.post('/suppliers/:id/payments', partnersController.addSupplierPayment);
router.get('/suppliers/:id/statement', partnersController.getSupplierStatement);
router.get('/suppliers/orders/:id', partnersController.getPurchaseOrderDetails);

// Payments Layout
router.get('/payments', partnersController.getAllPayments);
router.get('/payments-out', partnersController.getPaymentsOut);

module.exports = router;
