const express = require('express');
const router = express.Router();
const movieController = require('../controllers/movieController');
const { optionalAuth } = require('../middleware/auth');
const { apiLimiter } = require('../middleware/rateLimit');


router.get('/', apiLimiter, optionalAuth, movieController.getMovies);
router.get('/library', apiLimiter, optionalAuth, movieController.getLibrary); // New dashboard endpoint
router.get('/cache-stats', movieController.getCacheStats);
router.get('/:id', apiLimiter, optionalAuth, movieController.getMovie);
router.get('/:id/metadata', apiLimiter, optionalAuth, movieController.getMovieMetadata); // New endpoint
router.get('/:id/thumbnail', movieController.getThumbnail);
router.get('/:id/media-info', movieController.getMediaInfo);

module.exports = router;