const express = require('express');
const router = express.Router();
const streamController = require('../controllers/streamController');
const { streamLimiter } = require('../middleware/rateLimit');
const { trackStream } = require('../middleware/streamTracker');
const activityTracker = require('../services/activityTracker');

router.get('/:id', streamLimiter, trackStream, streamController.stream);
router.get('/:id/transmux', streamLimiter, streamController.transmuxStream); // New endpoint for MKV/AVI
router.get('/:id/seek', streamLimiter, streamController.seek); // Time-based seeking for transmuxed streams
router.get('/:id/tracks', streamController.getTracks); // NEW: On-demand track detection


// Heartbeat — frontend pings every 20s while video is playing to keep session alive
router.get('/:id/heartbeat', (req, res) => {
    const fileId = req.params.id;
    const ip = req.ip || req.connection.remoteAddress || 'unknown';
    const userAgent = req.headers['user-agent'] || 'unknown';
    activityTracker.registerActivity(fileId, { ip, userAgent });
    res.status(204).end();
});

module.exports = router;
