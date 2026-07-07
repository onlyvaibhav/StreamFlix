const express = require('express');
const router = express.Router();
const telegramAuthController = require('../controllers/telegramAuthController');

// Initiate Telegram Authentication
router.post('/send-code', telegramAuthController.sendCode);

// Submit verification code (OTP)
router.post('/verify-code', telegramAuthController.verifyCode);

// Submit 2-Step Verification password (optional)
router.post('/verify-password', telegramAuthController.verifyPassword);

// Retrieve active session validation status
router.get('/status', telegramAuthController.getStatus);
router.post('/status', telegramAuthController.getStatus);

// Log out and revoke active session
router.post('/logout', telegramAuthController.logout);

// Client-side streaming support
router.get('/streaming-config', telegramAuthController.getStreamingConfig);
router.get('/session-string', telegramAuthController.getSessionString);

module.exports = router;
