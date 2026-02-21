const express = require('express');
const router = express.Router();
const movieController = require('../controllers/movieController');
const { apiLimiter } = require('../middleware/rateLimit');

// /api/home/*
router.get('/trending', apiLimiter, movieController.getTrending);
router.get('/top-rated', apiLimiter, movieController.getTopRated);
router.get('/popular', apiLimiter, movieController.getPopular);
router.get('/genres', apiLimiter, movieController.getGenres);
router.get('/genre/:id', apiLimiter, movieController.getByGenre);

module.exports = router;
