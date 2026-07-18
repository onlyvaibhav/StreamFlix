const express = require('express');
const router = express.Router();
const telegramAuthController = require('../controllers/telegramAuthController');
const { apiLimiter } = require('../middleware/rateLimit');

const { requireDeviceAuth } = require('../middleware/deviceAuth');

// Initiate Telegram Authentication
router.post('/send-code', apiLimiter, telegramAuthController.sendCode);

// Submit verification code (OTP)
router.post('/verify-code', apiLimiter, telegramAuthController.verifyCode);

// Submit 2-Step Verification password (optional)
router.post('/verify-password', apiLimiter, telegramAuthController.verifyPassword);

// Retrieve active session validation status
router.get('/status', apiLimiter, requireDeviceAuth, telegramAuthController.getStatus);
router.post('/status', apiLimiter, requireDeviceAuth, telegramAuthController.getStatus);

// Log out and revoke active session
router.post('/logout', apiLimiter, requireDeviceAuth, telegramAuthController.logout);
router.post('/logout-all', apiLimiter, requireDeviceAuth, telegramAuthController.logoutAll);

// Client-side session sync for native apps (Flutter)
router.post('/sync-client-session', apiLimiter, telegramAuthController.syncClientSession);

// Client-side pre-login session cleanup by device ID
router.post('/pre-login-device-logout', apiLimiter, telegramAuthController.preLoginDeviceLogout);

// Client-side streaming support
router.get('/streaming-config', requireDeviceAuth, telegramAuthController.getStreamingConfig);
router.get('/session-string', requireDeviceAuth, telegramAuthController.getSessionString);

module.exports = router;
