const crypto = require('crypto');
const telegramAuthService = require('../services/telegramAuthService');
const supabaseService = require('../services/supabaseService');
const cryptoUtils = require('../utils/cryptoUtils');
const telegramConfig = require('../config/telegram');

/**
 * Helper to extract Session Token from request headers
 */
function getSessionToken(req) {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7);
  }
  return req.body.sessionToken || req.query.sessionToken;
}

/**
 * Translates standard Telegram MTProto errors into readable messages
 */
function formatTelegramError(error) {
  const msg = error.message || String(error);
  
  if (msg.includes('FLOOD_WAIT_')) {
    const seconds = msg.split('_').pop() || 'some';
    return `Too many attempts. Please wait ${seconds} seconds before trying again.`;
  }
  if (msg.includes('PHONE_NUMBER_INVALID')) {
    return 'The phone number you entered is invalid. Please check the country code and digits.';
  }
  if (msg.includes('PHONE_CODE_EXPIRED')) {
    return 'The verification code has expired. Please request a new one.';
  }
  if (msg.includes('PHONE_CODE_INVALID')) {
    return 'The verification code is incorrect. Please check the code and try again.';
  }
  if (msg.includes('PASSWORD_HASH_INVALID') || msg.includes('SRP_PASSWORD_INVALID')) {
    return 'The 2-Step Verification password you entered is incorrect.';
  }
  if (msg.includes('SIGNUP_REQUIRED')) {
    return 'Account registration is not supported on StreamFlix. Please register via the official Telegram app first.';
  }
  
  return msg || 'An unknown error occurred during Telegram authentication.';
}

/**
 * POST /api/auth/telegram/send-code
 * Body: { phoneNumber }
 */
async function sendCode(req, res) {
  try {
    const { phoneNumber } = req.body;
    if (!phoneNumber) {
      return res.status(400).json({ success: false, error: 'Phone number is required' });
    }

    const data = await telegramAuthService.sendCode(phoneNumber);
    return res.json({
      success: true,
      loginSessionId: data.loginSessionId,
      isCodeViaApp: data.isCodeViaApp
    });
  } catch (error) {
    console.error('❌ sendCode Controller Error:', error);
    return res.status(400).json({
      success: false,
      error: formatTelegramError(error)
    });
  }
}

/**
 * POST /api/auth/telegram/verify-code
 * Body: { loginSessionId, code, device }
 */
async function verifyCode(req, res) {
  try {
    const { loginSessionId, code, device } = req.body;
    if (!loginSessionId || !code) {
      return res.status(400).json({ success: false, error: 'Session ID and verification code are required' });
    }
    if (!device || !device.deviceId) {
      return res.status(400).json({ success: false, error: 'Device details are required for identification' });
    }

    const result = await telegramAuthService.verifyCode(loginSessionId, code);

    // If 2FA is needed, tell the client to show the password screen
    if (result.requiresPassword) {
      return res.json({
        success: true,
        requiresPassword: true
      });
    }

    // Otherwise, we got sessionString & user details! Sync to Supabase (or memory fallback)
    const { sessionString, user } = result;
    const encryptedSession = cryptoUtils.encrypt(sessionString);
    const sessionToken = crypto.randomUUID();

    // Perform database synchronization (always — memory fallback handles DB failures)
    await supabaseService.syncUser(user);
    await supabaseService.syncDevice({
      deviceId: device.deviceId,
      telegramId: user.telegramId,
      browser: device.browser,
      os: device.os,
      platform: device.platform,
      userAgent: device.userAgent
    });
    await supabaseService.syncSession({
      sessionId: sessionToken,
      telegramId: user.telegramId,
      deviceId: device.deviceId,
      telegramSession: encryptedSession,
      expiresAt: Date.now() + 30 * 24 * 60 * 60 * 1000 // 30 Days expiry
    });

    // Verify channel membership for zero-trust login
    const isMember = await telegramAuthService.checkChannelMembership(user.telegramId);
    const inviteLink = isMember ? null : await telegramAuthService.getChannelInviteLink();

    return res.json({
      success: true,
      sessionToken,
      user,
      requiresMembership: !isMember,
      inviteLink: inviteLink || `https://t.me/joinchat/${process.env.TELEGRAM_CHANNEL_ID}`
    });
  } catch (error) {
    console.error('❌ verifyCode Controller Error:', error);
    return res.status(400).json({
      success: false,
      error: formatTelegramError(error)
    });
  }
}

/**
 * POST /api/auth/telegram/verify-password
 * Body: { loginSessionId, password, device }
 */
async function verifyPassword(req, res) {
  try {
    const { loginSessionId, password, device } = req.body;
    if (!loginSessionId || !password) {
      return res.status(400).json({ success: false, error: 'Session ID and password are required' });
    }
    if (!device || !device.deviceId) {
      return res.status(400).json({ success: false, error: 'Device details are required for identification' });
    }

    const result = await telegramAuthService.verifyPassword(loginSessionId, password);

    const { sessionString, user } = result;
    const encryptedSession = cryptoUtils.encrypt(sessionString);
    const sessionToken = crypto.randomUUID();

    // Sync database records (always — memory fallback handles DB failures)
    await supabaseService.syncUser(user);
    await supabaseService.syncDevice({
      deviceId: device.deviceId,
      telegramId: user.telegramId,
      browser: device.browser,
      os: device.os,
      platform: device.platform,
      userAgent: device.userAgent
    });
    await supabaseService.syncSession({
      sessionId: sessionToken,
      telegramId: user.telegramId,
      deviceId: device.deviceId,
      telegramSession: encryptedSession,
      expiresAt: Date.now() + 30 * 24 * 60 * 60 * 1000 // 30 Days expiry
    });

    // Verify channel membership for zero-trust login
    const isMember = await telegramAuthService.checkChannelMembership(user.telegramId);
    const inviteLink = isMember ? null : await telegramAuthService.getChannelInviteLink();

    return res.json({
      success: true,
      sessionToken,
      user,
      requiresMembership: !isMember,
      inviteLink: inviteLink || `https://t.me/joinchat/${process.env.TELEGRAM_CHANNEL_ID}`
    });
  } catch (error) {
    console.error('❌ verifyPassword Controller Error:', error);
    return res.status(400).json({
      success: false,
      error: formatTelegramError(error)
    });
  }
}

/**
 * GET/POST /api/auth/telegram/status
 * Headers: Authorization: Bearer <sessionToken>
 */
async function getStatus(req, res) {
  try {
    // Prevent browser from caching status responses (avoids stale 304s)
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, private');
    res.set('Pragma', 'no-cache');
    res.set('Expires', '0');

    const sessionToken = getSessionToken(req);
    if (!sessionToken) {
      return res.status(401).json({ success: false, authorized: false, error: 'No session token provided' });
    }

    // Try finding the session in database or in-memory fallback
    const dbSession = await supabaseService.getSession(sessionToken);
    if (!dbSession) {
      return res.status(401).json({ success: false, authorized: false, error: 'Session invalid or expired' });
    }

    // 1. Verify session validity on Telegram servers (Zero Trust)
    const sessionString = cryptoUtils.decrypt(dbSession.telegram_session);
    const isValid = await telegramAuthService.validateSession(sessionString);
    if (!isValid) {
      console.log(`[Status] Session token ${sessionToken} was revoked in Telegram, deleting from DB...`);
      await supabaseService.deleteSession(sessionToken);
      return res.status(401).json({
        success: false,
        authorized: false,
        error: 'Telegram session has been revoked'
      });
    }

    // 2. Verify channel membership (Zero Trust)
    const telegramId = dbSession.telegram_id || (dbSession.users && dbSession.users.telegram_id);
    const isMember = await telegramAuthService.checkChannelMembership(telegramId);
    if (!isMember) {
      const inviteLink = await telegramAuthService.getChannelInviteLink();
      return res.status(403).json({
        success: false,
        authorized: false,
        error: 'MEMBERSHIP_REQUIRED',
        inviteLink: inviteLink || `https://t.me/joinchat/${process.env.TELEGRAM_CHANNEL_ID}`
      });
    }

    // Trust the session stored in database/memory directly
    const dbUser = dbSession.users;
    if (!dbUser) {
      return res.status(401).json({ success: false, authorized: false, error: 'User profile not found' });
    }

    const user = {
      telegramId: dbUser.telegram_id ? dbUser.telegram_id.toString() : dbSession.telegram_id.toString(),
      username: dbUser.username || '',
      firstName: dbUser.first_name || 'Telegram User',
      lastName: dbUser.last_name || '',
      phone: dbUser.phone || '',
      premium: !!dbUser.premium,
      language: dbUser.language || 'en',
      profilePhoto: dbUser.profile_photo || null
    };

    // Async update last_used in DB (don't block response)
    supabaseService.syncSession({
      sessionId: dbSession.session_id,
      telegramId: dbSession.telegram_id,
      deviceId: dbSession.device_id,
      telegramSession: dbSession.telegram_session,
      expiresAt: dbSession.expires_at
    }).catch(err => console.error('[Status] Failed to refresh session time:', err.message));

    return res.json({
      success: true,
      authorized: true,
      user
    });
  } catch (error) {
    console.error('❌ getStatus Controller Error:', error);
    return res.status(500).json({
      success: false,
      authorized: false,
      error: 'Failed to retrieve session status: ' + error.message
    });
  }
}

/**
 * POST /api/auth/telegram/logout
 * Headers: Authorization: Bearer <sessionToken>
 */
async function logout(req, res) {
  try {
    const sessionToken = getSessionToken(req);
    if (!sessionToken) {
      return res.status(400).json({ success: false, error: 'No session token provided' });
    }

    if (supabaseService.isEnabled()) {
      const dbSession = await supabaseService.getSession(sessionToken);
      if (dbSession) {
        // Decrypt and log out from Telegram
        const sessionString = cryptoUtils.decrypt(dbSession.telegram_session);
        await telegramAuthService.logoutSession(sessionString);
        
        // Remove from database
        await supabaseService.deleteSession(sessionToken);
      }
    }

    return res.json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error) {
    console.error('❌ logout Controller Error:', error);
    return res.status(500).json({
      success: false,
      error: 'Logout failed: ' + error.message
    });
  }
}

/**
 * GET /api/auth/telegram/streaming-config
 * Returns Telegram API credentials needed by the browser-side GramJS worker.
 * apiId and apiHash identify the app (not the user) — same pattern as Telegram Web.
 * Gated behind session auth to prevent scraping.
 */
async function getStreamingConfig(req, res) {
  try {
    const sessionToken = getSessionToken(req);
    if (!sessionToken) {
      return res.status(401).json({ success: false, error: 'No session token provided' });
    }

    const dbSession = await supabaseService.getSession(sessionToken);
    if (!dbSession) {
      return res.status(401).json({ success: false, error: 'Session invalid or expired' });
    }

    return res.json({
      success: true,
      apiId: telegramConfig.apiId,
      apiHash: telegramConfig.apiHash
    });
  } catch (error) {
    console.error('❌ getStreamingConfig Controller Error:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to get streaming config: ' + error.message
    });
  }
}

/**
 * GET /api/auth/telegram/session-string
 * Decrypts and returns the user's Telegram session string for client-side streaming.
 * The session string is equivalent to full account credentials — treat with extreme care.
 * Response has no-store caching to prevent browser/proxy caching.
 */
async function getSessionString(req, res) {
  try {
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, private');
    res.set('Pragma', 'no-cache');

    const sessionToken = getSessionToken(req);
    if (!sessionToken) {
      return res.status(401).json({ success: false, error: 'No session token provided' });
    }

    const dbSession = await supabaseService.getSession(sessionToken);
    if (!dbSession) {
      return res.status(401).json({ success: false, error: 'Session invalid or expired' });
    }

    const sessionString = cryptoUtils.decrypt(dbSession.telegram_session);
    if (!sessionString) {
      return res.status(500).json({ success: false, error: 'Failed to decrypt session' });
    }

    return res.json({
      success: true,
      sessionString
    });
  } catch (error) {
    console.error('❌ getSessionString Controller Error:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to get session string: ' + error.message
    });
  }
}

module.exports = {
  sendCode,
  verifyCode,
  verifyPassword,
  getStatus,
  logout,
  getStreamingConfig,
  getSessionString
};
