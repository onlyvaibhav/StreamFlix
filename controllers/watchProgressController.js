const supabaseService = require('../services/supabaseService');

/**
 * Helper to extract session token from the request
 */
function getSessionToken(req) {
  const authHeader = req.headers['authorization'];
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7);
  }
  return req.body?.sessionToken || req.query?.sessionToken;
}

/**
 * Helper to authenticate and get user's Telegram ID
 */
async function authenticateRequest(req, res) {
  const sessionToken = getSessionToken(req);
  if (!sessionToken) {
    res.status(401).json({ success: false, error: 'Authorization required' });
    return null;
  }

  const dbSession = await supabaseService.getSession(sessionToken);
  if (!dbSession) {
    res.status(401).json({ success: false, error: 'Invalid or expired session' });
    return null;
  }

  return dbSession.telegram_id;
}

/**
 * GET /api/progress
 * Retrieves watch progress for the authenticated user
 */
async function getWatchProgress(req, res) {
  try {
    const telegramId = await authenticateRequest(req, res);
    if (!telegramId) return; // Response already sent

    const progress = await supabaseService.getWatchProgress(telegramId);
    return res.json({ success: true, progress });
  } catch (error) {
    console.error('❌ Error getting watch progress:', error);
    return res.status(500).json({ success: false, error: 'Failed to retrieve watch progress' });
  }
}

/**
 * POST /api/progress
 * Upserts watch progress for the authenticated user
 */
async function saveWatchProgress(req, res) {
  try {
    const telegramId = await authenticateRequest(req, res);
    if (!telegramId) return;

    const { fileId, positionSeconds, durationSeconds, title, posterPath, mediaType, season, episode, showId } = req.body;
    
    if (!fileId || typeof positionSeconds !== 'number' || typeof durationSeconds !== 'number') {
      return res.status(400).json({ success: false, error: 'Missing or invalid required fields' });
    }

    await supabaseService.syncWatchProgress(telegramId, {
      file_id: fileId,
      position_seconds: positionSeconds,
      duration_seconds: durationSeconds,
      title: title || null,
      poster_path: posterPath || null,
      media_type: mediaType || 'movie',
      season: season || null,
      episode: episode || null,
      show_id: showId || null
    });

    return res.json({ success: true });
  } catch (error) {
    console.error('❌ Error saving watch progress:', error);
    return res.status(500).json({ success: false, error: 'Failed to save watch progress' });
  }
}

module.exports = {
  getWatchProgress,
  saveWatchProgress
};
