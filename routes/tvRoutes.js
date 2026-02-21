const express = require('express');
const router = express.Router();
const movieController = require('../controllers/movieController');
const { apiLimiter } = require('../middleware/rateLimit');

// /api/tv/*
router.get('/:id/details', apiLimiter, movieController.getTmdbTVDetails);
router.get('/:id/local', apiLimiter, movieController.getLocalTVDetails);
router.get('/:id/season/:season', apiLimiter, movieController.getTmdbSeasonDetails);

module.exports = router;
