const express = require('express');
const router = express.Router();
const fs = require('fs').promises;
const path = require('path');
const { worker, loadMetadata, saveMetadata, getAllMetadata, refetchQueue, getIdleLoopStatus } = require('../services/metadataWorker');

const DATA_DIR = path.join(__dirname, '../data/metadata');
const POSTERS_DIR = path.join(__dirname, '../data/posters');
const BACKDROPS_DIR = path.join(__dirname, '../data/backdrops');

// Helper
function checkIfBroken(metadata) {
    if (!metadata) return { broken: true, reason: 'null metadata' };
    if (!metadata.fileId) return { broken: true, reason: 'missing fileId' };

    const fieldCount = Object.keys(metadata).length;
    // Overwritten by track detection (missing title/genres/poster)
    if (fieldCount <= 5 && !metadata.title) {
        return { broken: true, reason: 'overwritten by track detection' };
    }

    // Has fileId but missing all TMDB data
    if (!metadata.title && !metadata.needsRetry) {
        return { broken: true, reason: 'missing title' };
    }

    if (metadata.fetchedAt && !metadata.tmdbId && !metadata.needsRetry) {
        return { broken: true, reason: 'missing tmdbId despite fetchedAt' };
    }

    // Title exists but no genres/overview (partial TMDB fetch)
    if (metadata.title && metadata.fetchedAt && (!metadata.genres || metadata.genres.length === 0) && !metadata.needsRetry) {
        return { broken: true, reason: 'missing genres' };
    }

    return { broken: false, reason: null };
}

// GET /api/admin/health
router.get('/health', async (req, res) => {
    try {
        const files = await fs.readdir(DATA_DIR);
        const jsonFiles = files.filter(f => f.endsWith('.json'));

        let valid = 0;
        let broken = 0;
        let needsRetry = 0;
        let withPoster = 0;
        let withBackdrop = 0;
        let withAudioDetected = 0;
        const brokenList = [];

        for (const file of jsonFiles) {
            try {
                const raw = await fs.readFile(path.join(DATA_DIR, file), 'utf-8');
                const parsed = JSON.parse(raw);
                const fileId = file.replace('.json', '');

                const check = checkIfBroken(parsed);

                if (check.broken) {
                    broken++;
                    brokenList.push({ fileId, reason: check.reason });
                } else if (parsed.needsRetry) {
                    needsRetry++;
                } else {
                    valid++;
                }

                if (parsed.poster) withPoster++;
                if (parsed.backdrop) withBackdrop++;
                if (parsed._tracksDetected) withAudioDetected++;

            } catch {
                broken++;
                brokenList.push({ fileId: file.replace('.json', ''), reason: 'Corrupt JSON' });
            }
        }

        res.json({
            status: 'ok',
            total: jsonFiles.length,
            valid,
            broken,
            needsRetry,
            withPoster,
            withBackdrop,
            withAudioDetected,
            brokenList: brokenList.slice(0, 50),
        });

    } catch (error) {
        res.status(500).json({ status: 'error', error: error.message });
    }
});

// POST /api/admin/fix-broken
router.post('/fix-broken', async (req, res) => {
    try {
        const files = await fs.readdir(DATA_DIR);
        const fixed = [];
        const deleted = [];

        for (const file of files) {
            if (!file.endsWith('.json')) continue;
            const filePath = path.join(DATA_DIR, file);
            const fileId = file.replace('.json', '');

            try {
                const raw = await fs.readFile(filePath, 'utf-8');
                const parsed = JSON.parse(raw);

                const check = checkIfBroken(parsed);
                if (check.broken) {
                    // Mark for retry
                    parsed.needsRetry = true;
                    parsed.fetchedAt = null;
                    if (!parsed._retry) {
                        parsed._retry = { failureType: 'corrupted', lastAttempt: 0, attemptCount: 0 };
                    }
                    parsed._retry.attemptCount = 0;
                    parsed._retry.lastAttempt = 0;

                    // Ensure minimal fields
                    if (!parsed.fileId) parsed.fileId = fileId;

                    // Preserve detected usage if possible
                    if (!parsed.type) parsed.type = 'movie';

                    await fs.writeFile(filePath, JSON.stringify(parsed, null, 2));
                    fixed.push({ fileId, reason: check.reason });
                }

            } catch {
                // Completely corrupt
                try {
                    await fs.unlink(filePath);
                    deleted.push(fileId);
                } catch { }
            }
        }

        res.json({
            success: true,
            fixed: fixed.length,
            deleted: deleted.length,
            fixedList: fixed,
            deletedList: deleted,
        });

    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// POST /api/admin/retry-failed
router.post('/retry-failed', async (req, res) => {
    try {
        if (worker && worker.isRunning) {
            return res.json({ success: false, message: 'Worker already running' });
        }

        // Trigger in bg
        if (worker) {
            worker.retryFailedLookups().catch(e => console.error(e));
            res.json({ success: true, message: 'Retry triggered' });
        } else {
            res.status(500).json({ error: 'Worker not available' });
        }

    } catch (error) {
        if (!res.headersSent) {
            res.status(500).json({ error: error.message });
        }
    }
});

// ==================== NEW ENDPOINTS ====================

// POST /api/admin/metadata/:fileId/fix — Fix wrong TMDB match
router.post('/metadata/:fileId/fix', async (req, res) => {
    try {
        const { fileId } = req.params;
        const { tmdbId, type } = req.body;

        if (!tmdbId || typeof tmdbId !== 'number') {
            return res.status(400).json({ error: 'tmdbId (number) is required in body' });
        }

        const existing = await loadMetadata(fileId);
        if (!existing) {
            return res.status(404).json({ error: `No metadata found for fileId: ${fileId}` });
        }

        console.log(`[Admin] Manual fix: fileId=${fileId}, tmdbId=${tmdbId}, type=${type || existing.type}`);

        const updated = await worker.refetchMetadata(fileId, { tmdbId, type });
        res.json({ success: true, metadata: updated });

    } catch (error) {
        console.error(`[Admin] Fix failed for ${req.params.fileId}:`, error.message);
        res.status(500).json({ error: error.message });
    }
});

// POST /api/admin/metadata/:fileId/refetch — Re-fetch using existing TMDB ID
router.post('/metadata/:fileId/refetch', async (req, res) => {
    try {
        const { fileId } = req.params;

        const existing = await loadMetadata(fileId);
        if (!existing) {
            return res.status(404).json({ error: `No metadata found for fileId: ${fileId}` });
        }

        if (!existing.tmdbId || existing.tmdbId === 0) {
            return res.status(400).json({ error: 'No TMDB ID in existing metadata — use /fix to set one' });
        }

        console.log(`[Admin] Refetch: fileId=${fileId}, tmdbId=${existing.tmdbId}`);

        const updated = await worker.refetchMetadata(fileId);
        res.json({ success: true, metadata: updated });

    } catch (error) {
        console.error(`[Admin] Refetch failed for ${req.params.fileId}:`, error.message);
        res.status(500).json({ error: error.message });
    }
});

// GET /api/admin/metadata/issues — List all problematic metadata entries
router.get('/metadata/issues', async (req, res) => {
    try {
        const all = await getAllMetadata();
        const issues = [];

        for (const entry of all) {
            const problems = [];

            if (entry.needsRetry) problems.push('needs_retry');
            if (entry.needsRefetch) problems.push('needs_refetch');
            if (!entry.tmdbId || entry.tmdbId === 0) problems.push('no_tmdb_id');
            if (!entry.title) problems.push('no_title');
            if (!entry.fetchedAt) problems.push('never_fetched');
            if (entry.rating !== undefined && entry.rating > 0 && entry.rating < 2) problems.push('very_low_rating');

            // Check poster/backdrop files on disk
            if (!entry.poster) {
                problems.push('no_poster');
            } else {
                try {
                    const posterPath = path.join(__dirname, '..', entry.poster);
                    await fs.access(posterPath);
                } catch {
                    problems.push('poster_file_missing');
                }
            }

            if (!entry.backdrop) {
                problems.push('no_backdrop');
            } else {
                try {
                    const backdropPath = path.join(__dirname, '..', entry.backdrop);
                    await fs.access(backdropPath);
                } catch {
                    problems.push('backdrop_file_missing');
                }
            }

            if (problems.length > 0) {
                issues.push({
                    fileId: entry.fileId,
                    fileName: entry.fileName,
                    title: entry.title || null,
                    tmdbId: entry.tmdbId || 0,
                    type: entry.type || 'unknown',
                    issues: problems,
                    detail: problems.join(', ')
                });
            }
        }

        res.json({
            total: issues.length,
            issues: issues.slice(0, 100)
        });

    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// POST /api/admin/metadata/refetch-all-failed — Queue all failed items for retry
router.post('/metadata/refetch-all-failed', async (req, res) => {
    try {
        const all = await getAllMetadata();
        let queued = 0;

        for (const entry of all) {
            if (entry.needsRetry && entry.fileId) {
                refetchQueue.add(entry.fileId);
                queued++;
            }
        }

        res.json({
            success: true,
            queued,
            message: `${queued} items queued for re-fetch`
        });

    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;

