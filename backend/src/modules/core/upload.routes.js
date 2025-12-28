const express = require('express');
const router = express.Router();
const upload = require('../../middleware/upload.middleware');

// POST /api/upload
// Expects form-data with key 'images' (multiple)
router.post('/', upload.array('images', 3), (req, res) => {
    try {
        if (!req.files || req.files.length === 0) {
            return res.status(400).json({ error: 'No files uploaded' });
        }

        const info = req.files.map(file => {
            // Generate public URL (assuming server is running on localhost:5000)
            // In production, use env var for domain
            return `/uploads/${file.filename}`;
        });

        res.json({
            message: 'Files uploaded successfully',
            images: info
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
