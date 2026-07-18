const crypto = require('crypto');
const supabaseService = require('../services/supabaseService');

/**
 * Middleware to enforce strict device + session authentication.
 * Requires:
 * 1. Bearer token (Flutter) or httpOnly cookie (Web)
 * 2. X-Device-Id header
 */
async function requireDeviceAuth(req, res, next) {
  try {
    const deviceId = req.headers['x-device-id'];
    if (!deviceId) {
      return res.status(401).json({ success: false, error: 'X-Device-Id header required' });
    }

    let token = null;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7);
    } else if (req.cookies && req.cookies.auth_token) {
      token = req.cookies.auth_token;
    }

    if (!token) {
      return res.status(401).json({ success: false, error: 'Authentication token required' });
    }

    // Hash the token
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

    if (!supabaseService.isEnabled()) {
      return res.status(500).json({ success: false, error: 'Database authentication unavailable' });
    }

    // Look up session by token_hash
    const { data: sessions, error } = await supabaseService.supabase
      .from('sessions')
      .select('*, users(*)')
      .eq('token_hash', tokenHash)
      .limit(1);

    if (error || !sessions || sessions.length === 0) {
      return res.status(401).json({ success: false, error: 'Invalid or expired session' });
    }

    const session = sessions[0];

    if (session.status !== 'active') {
      return res.status(401).json({ success: false, error: 'Session has been revoked' });
    }

    if (session.expires_at && new Date(session.expires_at) < new Date()) {
      return res.status(401).json({ success: false, error: 'Session has expired' });
    }

    if (session.device_id !== deviceId) {
      return res.status(401).json({ success: false, error: 'Device ID mismatch' });
    }

    // Attach to request context
    req.user = session.users;
    req.deviceAuth = {
      telegramId: session.telegram_id,
      deviceId: session.device_id,
      sessionId: session.session_id,
      telegramSession: session.telegram_session
    };

    // Async update last_used, expires_at and last_active (fire-and-forget)
    const now = new Date();
    // Sliding window: extend expiration by 30 days on active use
    const newExpiresAt = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000).toISOString();
    
    supabaseService.supabase
      .from('sessions')
      .update({ 
        last_used: now.toISOString(),
        expires_at: newExpiresAt
      })
      .eq('session_id', session.session_id)
      .then();

    supabaseService.supabase
      .from('devices')
      .update({ last_active: now.toISOString() })
      .eq('device_id', session.device_id)
      .then();

    next();
  } catch (err) {
    console.error('❌ Device Auth Middleware Error:', err);
    return res.status(500).json({ success: false, error: 'Internal server error during authentication' });
  }
}

module.exports = { requireDeviceAuth };
