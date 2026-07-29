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
router.get('/:id/file-info', streamController.getFileInfo); // Expose file metadata for client-side streaming

// Heartbeat — frontend pings every 20s while video is playing to keep session alive
router.get('/:id/heartbeat', (req, res) => {
    const fileId = req.params.id;
    const ip = req.ip || req.connection.remoteAddress || 'unknown';
    const userAgent = req.headers['user-agent'] || 'unknown';
    let userId = (req.cookies && req.cookies.auth_token) ? req.cookies.auth_token : null;
    if (!userId && req.headers.authorization && req.headers.authorization.startsWith('Bearer ')) {
        userId = req.headers.authorization.substring(7);
    }
    activityTracker.registerActivity(fileId, { ip, userAgent, userId });
    res.status(204).end();
});

// Phase C: New POST heartbeat
router.post('/heartbeat', express.json(), (req, res) => {
    const fileId = req.body.fileId;
    if (!fileId) return res.status(400).end();
    const ip = req.ip || req.connection.remoteAddress || 'unknown';
    const userAgent = req.headers['user-agent'] || 'unknown';
    let userId = (req.cookies && req.cookies.auth_token) ? req.cookies.auth_token : null;
    if (!userId && req.headers.authorization && req.headers.authorization.startsWith('Bearer ')) {
        userId = req.headers.authorization.substring(7);
    }
    activityTracker.registerActivity(fileId, { ip, userAgent, userId });
    
    // Check if there is an active telegram client for this stream and ping it to keep it alive
    // (If using server-side streaming)
    const telegramService = require('../services/telegramService');
    const telegramClient = telegramService.getClient();
    if (telegramClient && telegramClient.connected) {
        // Send a lightweight ping to Telegram to keep the connection warm
        try {
            const { Api } = require('telegram');
            telegramClient.invoke(new Api.updates.GetState()).catch(() => {});
        } catch (e) {
            // Ignore ping errors
        }
    }
    
    res.status(204).end();
});

module.exports = router;
