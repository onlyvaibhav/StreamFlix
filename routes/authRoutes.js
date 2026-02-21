const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authLimiter } = require('../middleware/rateLimit');

router.post('/login', authLimiter, authController.login);
router.get('/guest-token', authController.guestToken);

module.exports = router;