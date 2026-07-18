const crypto = require('crypto');
const telegramAuthService = require('../services/telegramAuthService');
const supabaseService = require('../services/supabaseService');
const cryptoUtils = require('../utils/cryptoUtils');
const alertBot = require('../services/bot/alertBot');
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

    alertBot.notifyOtpRequest(phoneNumber, req.ip || req.connection.remoteAddress);

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
    
    const rawToken = crypto.randomBytes(32).toString('base64url');
    const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');

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
      tokenHash,
      status: 'active',
      expiresAt: Date.now() + 30 * 24 * 60 * 60 * 1000 // 30 Days expiry
    });

    // Verify channel membership for zero-trust login
    const isMember = await telegramAuthService.checkChannelMembership(user.telegramId);
    const inviteLink = isMember ? null : await telegramAuthService.getChannelInviteLink();

    res.cookie('auth_token', rawToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 30 * 24 * 60 * 60 * 1000 // 30 Days
    });

    // Alert
    if (!isMember) {
      alertBot.notifyNonMemberLogin(user, { ...device, ip: req.ip || req.connection.remoteAddress });
    } else {
      alertBot.notifyLogin(user, { ...device, ip: req.ip || req.connection.remoteAddress });
    }

    return res.json({
      success: true,
      sessionToken,
      token: rawToken,
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

    const rawToken = crypto.randomBytes(32).toString('base64url');
    const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');

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
      tokenHash,
      status: 'active',
      expiresAt: Date.now() + 30 * 24 * 60 * 60 * 1000 // 30 Days expiry
    });

    // Verify channel membership for zero-trust login
    const isMember = await telegramAuthService.checkChannelMembership(user.telegramId);
    const inviteLink = isMember ? null : await telegramAuthService.getChannelInviteLink();

    res.cookie('auth_token', rawToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 30 * 24 * 60 * 60 * 1000 // 30 Days
    });

    // Alert
    if (!isMember) {
      alertBot.notifyNonMemberLogin(user, { ...device, ip: req.ip || req.connection.remoteAddress });
    } else {
      alertBot.notifyLogin(user, { ...device, ip: req.ip || req.connection.remoteAddress });
    }

    return res.json({
      success: true,
      sessionToken,
      token: rawToken,
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

    const { sessionId, telegramId, telegramSession } = req.deviceAuth;
    const dbUser = req.user;

    // 1. Verify session validity on Telegram servers (Zero Trust)
    const sessionString = cryptoUtils.decrypt(telegramSession);
    const isValid = await telegramAuthService.validateSession(sessionString);
    if (!isValid) {
      console.log(`[Status] Session token ${sessionId} was revoked in Telegram, marking in DB...`);
      await supabaseService.markSessionRevoked(sessionId, 'revoked');
      return res.status(401).json({
        success: false,
        authorized: false,
        error: 'Telegram session has been revoked'
      });
    }

    // 2. Verify channel membership (Zero Trust)
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
    if (!dbUser) {
      return res.status(401).json({ success: false, authorized: false, error: 'User profile not found' });
    }

    const user = {
      telegramId: dbUser.telegram_id ? dbUser.telegram_id.toString() : telegramId.toString(),
      username: dbUser.username || '',
      firstName: dbUser.first_name || 'Telegram User',
      lastName: dbUser.last_name || '',
      phone: dbUser.phone || '',
      premium: !!dbUser.premium,
      language: dbUser.language || 'en',
      profilePhoto: dbUser.profile_photo || null
    };

    // Async update last_used in DB is already handled by deviceAuth middleware


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
 * Requires: requireDeviceAuth middleware
 */
async function logout(req, res) {
  try {
    const { sessionId, telegramSession } = req.deviceAuth;

    if (supabaseService.isEnabled()) {
      // Decrypt and log out from Telegram
      const sessionString = cryptoUtils.decrypt(telegramSession);
      const status = req.body.status === 'revoked' ? 'revoked' : 'logout';
      
      // If the session was already revoked externally, don't attempt to connect to GramJS
      if (status !== 'revoked') {
        await telegramAuthService.logoutSession(sessionString);
      }
      
      // Mark as logout in database
      await supabaseService.markSessionRevoked(sessionId, status);
      
      // Alert
      const alertMsg = status === 'revoked' ? 'Session Revoked' : 'Logged Out';
      alertBot.notifyLogout(req.user, alertMsg, req.deviceAuth.deviceId);
    }

    // Clear web cookie
    res.clearCookie('auth_token', {
      httpOnly: true,
      secure: true,
      sameSite: 'strict'
    });

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
 * POST /api/auth/telegram/logout-all
 * Requires: requireDeviceAuth middleware
 */
async function logoutAll(req, res) {
  try {
    const { telegramId, sessionId } = req.deviceAuth;

    if (supabaseService.isEnabled()) {
      // Find all active sessions for this user EXCEPT the current one
      const { data: sessions, error } = await supabaseService.supabase
        .from('sessions')
        .select('*')
        .eq('telegram_id', telegramId)
        .eq('status', 'active')
        .neq('session_id', sessionId);

      if (!error && sessions && sessions.length > 0) {
        for (const session of sessions) {
           await supabaseService.markSessionRevoked(session.session_id, 'revoked');
           // Note: We are not aggressively logging them out from Telegram servers here 
           // to save API calls, since revoking our DB token kills their API access anyway. 
           // If true Telegram logout is needed, we'd loop and do telegramAuthService.logoutSession.
        }
        
        // Alert
        alertBot.notifyLogout(req.user, `Logged out all OTHER devices (${sessions.length} devices)`, req.deviceAuth.deviceId);
      }
    }

    return res.json({
      success: true,
      message: 'Other devices logged out successfully'
    });
  } catch (error) {
    console.error('❌ logoutAll Controller Error:', error);
    return res.status(500).json({
      success: false,
      error: 'Logout all failed: ' + error.message
    });
  }
}

/**
 * GET /api/auth/telegram/streaming-config
 * Requires: requireDeviceAuth middleware
 * Returns Telegram API credentials needed by the browser-side GramJS worker.
 * apiId and apiHash identify the app (not the user) — same pattern as Telegram Web.
 * Gated behind session auth to prevent scraping.
 */
async function getStreamingConfig(req, res) {
  try {
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
 * Requires: requireDeviceAuth middleware
 * Decrypts and returns the user's Telegram session string for client-side streaming.
 * The session string is equivalent to full account credentials — treat with extreme care.
 * Response has no-store caching to prevent browser/proxy caching.
 */
async function getSessionString(req, res) {
  try {
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, private');
    res.set('Pragma', 'no-cache');

    const sessionString = cryptoUtils.decrypt(req.deviceAuth.telegramSession);
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

/**
 * POST /api/auth/telegram/sync-client-session
 * Body: { sessionString, device }
 * Used by native apps (like Flutter) that handle GramJS login directly on the device.
 * Syncs the newly created session with the backend so Supabase matches.
 */
async function syncClientSession(req, res) {
  try {
    const { sessionString, device, user } = req.body;
    if (!sessionString) {
      return res.status(400).json({ success: false, error: 'Session string is required' });
    }
    if (!device || !device.deviceId) {
      return res.status(400).json({ success: false, error: 'Device details are required for identification' });
    }
    if (!user || !user.telegramId) {
      return res.status(400).json({ success: false, error: 'User details are required' });
    }

    const encryptedSession = cryptoUtils.encrypt(sessionString);
    const sessionToken = crypto.randomUUID();

    const rawToken = crypto.randomBytes(32).toString('base64url');
    const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');

    // Sync database records
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
      tokenHash,
      status: 'active',
      expiresAt: Date.now() + 30 * 24 * 60 * 60 * 1000 // 30 Days expiry
    });

    // Verify channel membership for zero-trust login
    const isMember = await telegramAuthService.checkChannelMembership(user.telegramId);
    const inviteLink = isMember ? null : await telegramAuthService.getChannelInviteLink();

    res.cookie('auth_token', rawToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 30 * 24 * 60 * 60 * 1000 // 30 Days
    });

    // Alert
    if (!isMember) {
      alertBot.notifyNonMemberLogin(user, { ...device, ip: req.ip || req.connection.remoteAddress });
    } else {
      alertBot.notifyLogin(user, { ...device, ip: req.ip || req.connection.remoteAddress });
    }

    return res.json({
      success: true,
      sessionToken,
      token: rawToken,
      user,
      requiresMembership: !isMember,
      inviteLink: inviteLink || `https://t.me/joinchat/${process.env.TELEGRAM_CHANNEL_ID}`
    });
  } catch (error) {
    console.error('❌ syncClientSession Controller Error:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to sync client session: ' + error.message
    });
  }
}

/**
 * POST /api/auth/telegram/pre-login-device-logout
 * Body: { deviceId }
 * Cleans up any active session for the device ID before a new login is attempted.
 */
async function preLoginDeviceLogout(req, res) {
  try {
    const { deviceId } = req.body;
    if (!deviceId) {
      return res.status(400).json({ success: false, error: 'Device ID is required' });
    }

    const revokedCount = await supabaseService.revokeSessionsByDevice(deviceId, 'logout');
    console.log(`🧹 Pre-login cleanup: Revoked ${revokedCount} active sessions for device ${deviceId}`);

    if (revokedCount > 0) {
      alertBot.notifyPreLoginCleanup(deviceId, revokedCount);
    }

    return res.json({
      success: true,
      message: `Stale device sessions cleaned up. Revoked: ${revokedCount}`
    });
  } catch (error) {
    console.error('❌ preLoginDeviceLogout Controller Error:', error);
    return res.status(500).json({
      success: false,
      error: 'Pre-login cleanup failed: ' + error.message
    });
  }
}

module.exports = {
  sendCode,
  verifyCode,
  verifyPassword,
  getStatus,
  logout,
  logoutAll,
  getStreamingConfig,
  getSessionString,
  syncClientSession,
  preLoginDeviceLogout
};
