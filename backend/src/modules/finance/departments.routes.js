const express = require('express');
const router = express.Router();
const controller = require('./departments.controller');

// Departments
router.get('/departments', controller.getDepartments);
router.post('/departments', controller.createDepartment);
router.delete('/departments/:id', controller.deleteDepartment);

// Roles
router.get('/roles', controller.getRoles);
router.post('/roles', controller.createRole);
router.delete('/roles/:id', controller.deleteRole);

module.exports = router;
