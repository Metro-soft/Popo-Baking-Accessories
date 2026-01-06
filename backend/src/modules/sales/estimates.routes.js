const router = require('express').Router();
const controller = require('./estimates.controller');

router.post('/', controller.createEstimate);
router.get('/', controller.getEstimates);
router.get('/:id', controller.getEstimateDetails);
router.delete('/:id', controller.deleteEstimate);
router.put('/:id', controller.updateEstimate);
router.post('/:id/convert', controller.convertToOrder);

module.exports = router;
