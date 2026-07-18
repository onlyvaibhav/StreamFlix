const activityTracker = require('../services/activityTracker');

function trackStream(req, res, next) {
    try {
        const fileId = req.params.fileId || req.params.id || 'unknown';
        const clientIp = req.ip || req.connection.remoteAddress || 'unknown';
        const userAgent = req.headers['user-agent'] || 'unknown';
        let userId = (req.cookies && req.cookies.auth_token) ? req.cookies.auth_token : null;
        if (!userId && req.headers.authorization && req.headers.authorization.startsWith('Bearer ')) {
            userId = req.headers.authorization.substring(7);
        }

        // Simply register activity - session logic handles the rest
        activityTracker.registerActivity(fileId, { ip: clientIp, userAgent, userId });

        next();
    } catch (error) {
        console.error('[StreamTracker] Middleware error:', error);
        next(); // Ensure stream doesn't fail if tracker fails
    }
}

module.exports = { trackStream };
