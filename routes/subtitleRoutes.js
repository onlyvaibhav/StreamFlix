const express = require('express');
const router = express.Router();
const subtitleController = require('../controllers/subtitleController');
const { apiLimiter } = require('../middleware/rateLimit');

// Get subtitles for a movie (auto-searches external services)
router.get('/movie/:movieId', apiLimiter, subtitleController.getSubtitles);

// Download/serve a subtitle file by ID
router.get('/file/:subtitleId', subtitleController.getSubtitleFile);

// Search subtitles by custom query (e.g., user types movie name)
router.get('/search/:query', apiLimiter, subtitleController.searchSubtitles);

// Convert subtitle format
router.post('/convert', apiLimiter, subtitleController.convertSubtitle);

// TEST: Returns a sample VTT to verify subtitle rendering works
router.get('/test/sample.vtt', (req, res) => {
    const sampleVTT = `WEBVTT

1
00:00:01.000 --> 00:00:04.000
This is a test subtitle.
If you can see this, rendering works!

2
00:00:05.000 --> 00:00:08.000
Second subtitle line.
The renderer is working correctly.

3
00:00:10.000 --> 00:00:15.000
Third subtitle. Try seeking around
to verify sync works.

4
00:00:20.000 --> 00:00:25.000
Subtitles at 20 seconds mark.

5
00:00:30.000 --> 00:00:35.000
Subtitles at 30 seconds mark.

6
00:01:00.000 --> 00:01:05.000
One minute mark subtitle.

7
00:02:00.000 --> 00:02:05.000
Two minute mark subtitle.

8
00:05:00.000 --> 00:05:05.000
Five minute mark subtitle.
`;

    res.set({
        'Content-Type': 'text/vtt; charset=utf-8',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'no-cache',
    });
    res.send(sampleVTT);
});

module.exports = router;