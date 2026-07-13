const express = require('express');
const router = express.Router();
const telegramAuthController = require('../controllers/telegramAuthController');
const { apiLimiter } = require('../middleware/rateLimit');

// Initiate Telegram Authentication
router.post('/send-code', apiLimiter, telegramAuthController.sendCode);

// Submit verification code (OTP)
router.post('/verify-code', apiLimiter, telegramAuthController.verifyCode);

// Submit 2-Step Verification password (optional)
router.post('/verify-password', apiLimiter, telegramAuthController.verifyPassword);

// Retrieve active session validation status
router.get('/status', apiLimiter, telegramAuthController.getStatus);
router.post('/status', apiLimiter, telegramAuthController.getStatus);

// Log out and revoke active session
router.post('/logout', apiLimiter, telegramAuthController.logout);

// Client-side session sync for native apps (Flutter)
router.post('/sync-client-session', apiLimiter, telegramAuthController.syncClientSession);

// Client-side streaming support
router.get('/streaming-config', telegramAuthController.getStreamingConfig);
router.get('/session-string', telegramAuthController.getSessionString);

module.exports = router;
