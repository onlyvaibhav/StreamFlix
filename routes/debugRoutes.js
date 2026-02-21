const express = require('express');
const router = express.Router();
const { worker } = require('../services/metadataWorker');

router.get('/nearby/:movieId', async (req, res) => {
    try {
        const { movieId } = req.params;
        const range = parseInt(req.query.range) || 20;
        const messages = await telegramService.getDebugMessages(movieId, range);
        res.json({ success: true, messages });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Manual trigger for metadata retry
router.get('/retry-metadata', async (req, res) => {
    try {
        console.log('🔄 Manually triggering metadata retry...');
        // Run in background, don't await response
        worker.retryFailedLookups().catch(e => console.error(e));
        res.json({ success: true, message: 'Metadata retry started in background' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Manual trigger for image retry
router.get('/retry-images', async (req, res) => {
    try {
        console.log('🖼️ Manually triggering image retry...');
        worker.retryFailedImageDownloads().catch(e => console.error(e));
        res.json({ success: true, message: 'Image retry started in background' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;