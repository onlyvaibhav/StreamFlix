const express = require('express');
const router = express.Router();
const watchProgressController = require('../controllers/watchProgressController');
const { requireDeviceAuth } = require('../middleware/deviceAuth');

router.get('/', requireDeviceAuth, watchProgressController.getWatchProgress);
router.post('/', requireDeviceAuth, watchProgressController.saveWatchProgress);

module.exports = router;
