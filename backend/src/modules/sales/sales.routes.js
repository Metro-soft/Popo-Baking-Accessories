const express = require('express');
const router = express.Router();
const salesController = require('./sales.controller');

const { authenticateToken } = require('../../middleware/auth.middleware');
const authorize = require('../../middleware/rbac.middleware');

router.post('/transaction', authenticateToken, salesController.processTransaction); // Protected check
router.get('/history', authenticateToken, salesController.getSalesHistory);
router.get('/orders/:id', authenticateToken, salesController.getOrderDetails);

// [NEW] Void Sale (Admin/Manager Only)
router.post('/orders/:id/void', authenticateToken, authorize(['admin', 'manager']), salesController.voidSale);
// [NEW] Update Sale (True Edit)
router.put('/transaction/:id', authenticateToken, salesController.updateSale);

// [NEW] Dispatch Status Update
router.put('/orders/:id/dispatch', authenticateToken, salesController.updateDispatchStatus);

// [NEW] Get Dispatch Orders
router.get('/orders/dispatch/list', authenticateToken, salesController.getDispatchOrders);

module.exports = router;
