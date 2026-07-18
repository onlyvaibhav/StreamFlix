const supabaseService = require('../services/supabaseService');



/**
 * GET /api/progress
 * Retrieves watch progress for the authenticated user
 */
async function getWatchProgress(req, res) {
  try {
    const telegramId = req.deviceAuth.telegramId;

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
    const telegramId = req.deviceAuth.telegramId;

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
