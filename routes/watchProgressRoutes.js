const express = require('express');
const router = express.Router();
const watchProgressController = require('../controllers/watchProgressController');

router.get('/', watchProgressController.getWatchProgress);
router.post('/', watchProgressController.saveWatchProgress);

module.exports = router;
