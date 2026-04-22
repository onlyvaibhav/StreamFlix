const express = require('express');
const router = express.Router();
const fs = require('fs').promises;
const path = require('path');
const {
    worker,
    loadMetadata,
    saveMetadata,
    getAllMetadata,
    refetchQueue,
    getIdleLoopStatus,
    fetchMissingAudioInfo,
    getAudioSweepStatus
} = require('../services/metadataWorker');
const logger = require('../services/logger');

const DATA_DIR = path.join(__dirname, '../data/metadata');
const POSTERS_DIR = path.join(__dirname, '../data/posters');
const BACKDROPS_DIR = path.join(__dirname, '../data/backdrops');

// Cache for health stats
let cachedHealthStats = null;
let lastHealthFetch = 0;
const HEALTH_CACHE_TTL = 60000; // 60 seconds

// Helper to invalidate health cache
function invalidateHealthCache() {
    cachedHealthStats = null;
    lastHealthFetch = 0;
}

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

    // Title exists but no genres (partial TMDB fetch) for movies
    if (metadata.type === 'movie' && metadata.title && metadata.fetchedAt && (!metadata.genres || metadata.genres.length === 0) && !metadata.needsRetry) {
        return { broken: true, reason: 'missing genres' };
    }

    return { broken: false, reason: null };
}

function isTrackUnsupported(track) {
    if (!track) return false;
    if (track.browserPlayable === false) return true;
    const codec = String(track.codec || track.codecName || '').toLowerCase();
    if (!codec) return false;
    return !['aac', 'mp3', 'opus', 'vorbis', 'flac', 'mp4a', 'mp4a.40.2', 'mp4a.40.5'].includes(codec);
}

function buildAudioSummary(entry) {
    const rawAudioTracks = Array.isArray(entry.audioTracks) ? entry.audioTracks : [];
    const audioTracks = rawAudioTracks.length > 0
        ? rawAudioTracks
        : (entry.audioCodec ? [{
            index: 0,
            streamIndex: 0,
            codec: entry.audioCodec,
            language: 'Default',
            languageCode: 'und',
            title: '',
            channels: 0,
            browserPlayable: entry.browserPlayable !== false,
            isDefault: true
        }] : []);
    const subtitleTracks = Array.isArray(entry.subtitleTracks) ? entry.subtitleTracks : [];
    const unsupportedTracks = audioTracks.filter(isTrackUnsupported);
    const hasAudioDetected = entry._tracksDetected === true || audioTracks.length > 0 || !!entry.audioCodec;

    const type = entry.type || (entry.tv?.showTmdbId ? 'tv' : 'movie');
    const title = entry.title || entry.tv?.showTitle || entry.fileName || String(entry.fileId || '');

    return {
        fileId: entry.fileId,
        fileName: entry.fileName || '',
        title,
        type,
        tmdbId: entry.tmdbId || entry.tv?.showTmdbId || 0,
        year: entry.year || null,
        season: entry.tv?.seasonNumber ?? null,
        episode: entry.tv?.episodeNumber ?? null,
        episodeTitle: entry.tv?.episodeTitle || '',
        poster: entry.poster || null,
        backdrop: entry.backdrop || null,
        container: entry.container || '',
        duration: Number(entry.duration) || 0,
        runtime: entry.runtime || 0,
        audioCodec: entry.audioCodec || audioTracks[0]?.codec || '',
        browserPlayable: unsupportedTracks.length === 0 && entry.browserPlayable !== false,
        tracksDetected: hasAudioDetected,
        manualProbeNeeded: !!entry.manualProbeNeeded,
        audioTracks,
        subtitleTrackCount: subtitleTracks.length,
        unsupportedTracks,
        unsupportedReason: unsupportedTracks.length > 0
            ? unsupportedTracks.map(t => `${t.language || t.languageCode || 'Unknown'} ${String(t.codec || t.codecName || 'unknown').toUpperCase()}`).join(', ')
            : ''
    };
}

function countByCodec(items, unsupportedOnly = false) {
    const counts = {};
    for (const item of items) {
        const tracks = unsupportedOnly ? item.unsupportedTracks : item.audioTracks;
        for (const track of tracks || []) {
            const codec = String(track.codec || track.codecName || 'unknown').toLowerCase() || 'unknown';
            counts[codec] = (counts[codec] || 0) + 1;
        }
    }
    return Object.entries(counts)
        .sort((a, b) => b[1] - a[1])
        .map(([codec, count]) => ({ codec, count }));
}

// GET /api/admin/health
router.get('/health', async (req, res) => {
    try {
        const now = Date.now();
        if (cachedHealthStats && (now - lastHealthFetch) < HEALTH_CACHE_TTL) {
            return res.json(cachedHealthStats);
        }

        const files = await fs.readdir(DATA_DIR);
        const jsonFiles = files.filter(f => f.endsWith('.json'));

        let valid = 0;
        let broken = 0;
        let needsRetry = 0;
        let withPoster = 0;
        let withBackdrop = 0;
        let withAudioDetected = 0;
        let unsupportedAudio = 0;
        let manualProbeNeeded = 0;
        const brokenList = [];
        const unsupportedAudioList = [];

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
                if (parsed.manualProbeNeeded) manualProbeNeeded++;
                if (parsed.browserPlayable === false) {
                    unsupportedAudio++;
                    unsupportedAudioList.push({
                        fileId,
                        title: parsed.title || parsed.tv?.showTitle || parsed.fileName || fileId,
                        codec: parsed.audioCodec
                    });
                }

            } catch {
                broken++;
                brokenList.push({ fileId: file.replace('.json', ''), reason: 'Corrupt JSON' });
            }
        }

        const result = {
            status: 'ok',
            total: jsonFiles.length,
            valid,
            broken,
            needsRetry,
            withPoster,
            withBackdrop,
            withAudioDetected,
            unsupportedAudio,
            manualProbeNeeded,
            unsupportedAudioList: unsupportedAudioList.slice(0, 50),
            brokenList: brokenList.slice(0, 50),
            cached: false,
            cachedAt: new Date(now).toISOString()
        };

        cachedHealthStats = result;
        lastHealthFetch = now;

        res.json(result);

    } catch (error) {
        res.status(500).json({ status: 'error', error: error.message });
    }
});

// GET /api/admin/audio/audit
router.get('/audio/audit', async (req, res) => {
    try {
        const all = await getAllMetadata();
        const usable = all.filter(entry => entry && entry.fileId && entry.fetchedAt && !entry.needsRetry);
        const summaries = usable.map(buildAudioSummary);
        const detected = summaries.filter(item => item.tracksDetected);
        const unsupported = summaries.filter(item => item.unsupportedTracks.length > 0 || item.browserPlayable === false);
        const incomplete = summaries.filter(item =>
            !item.container ||
            !item.duration
        );
        const manualProbeNeeded = summaries.filter(item => item.manualProbeNeeded);

        unsupported.sort((a, b) => {
            const titleDiff = String(a.title || '').localeCompare(String(b.title || ''));
            if (titleDiff !== 0) return titleDiff;
            return parseInt(a.fileId, 10) - parseInt(b.fileId, 10);
        });

        detected.sort((a, b) => parseInt(b.fileId, 10) - parseInt(a.fileId, 10));
        incomplete.sort((a, b) => parseInt(a.fileId, 10) - parseInt(b.fileId, 10));

        const totalAudioTracks = detected.reduce((sum, item) => sum + item.audioTracks.length, 0);
        const unsupportedTrackCount = unsupported.reduce((sum, item) => sum + item.unsupportedTracks.length, 0);

        res.json({
            summary: {
                totalMetadata: all.length,
                usableMetadata: usable.length,
                detectedFiles: detected.length,
                incompleteFiles: incomplete.length,
                unsupportedFiles: unsupported.length,
                supportedFiles: detected.length - unsupported.length,
                totalAudioTracks,
                unsupportedTrackCount,
                manualProbeCount: manualProbeNeeded.length,
                coveragePct: usable.length ? Math.round((detected.length / usable.length) * 100) : 0
            },
            codecCounts: countByCodec(detected),
            unsupportedCodecCounts: countByCodec(unsupported, true),
            unsupported,
            detected,
            manualProbeNeeded,
            incomplete: incomplete.slice(0, 200),
            sweep: getAudioSweepStatus()
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// POST /api/admin/audio/sweep
router.post('/audio/sweep', async (req, res) => {
    try {
        const limit = Number.isFinite(Number(req.body?.limit)) ? parseInt(req.body.limit, 10) : 0;
        const concurrency = Number.isFinite(Number(req.body?.concurrency)) ? parseInt(req.body.concurrency, 10) : 3;
        const minDelayMs = Number.isFinite(Number(req.body?.minDelayMs)) ? parseInt(req.body.minDelayMs, 10) : 900;

        fetchMissingAudioInfo(limit, concurrency, { minDelayMs }).catch(error => {
            console.error('[Admin] Audio sweep failed:', error.message);
        });

        res.json({
            success: true,
            message: getAudioSweepStatus().running ? 'Audio sweep started' : 'Audio sweep queued',
            sweep: getAudioSweepStatus()
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
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

// POST /api/admin/refetch-logos
router.post('/refetch-logos', (req, res) => {
    try {
        require('../services/metadataWorker').fetchMissingLogos();
        res.json({ success: true, message: 'Missing logos fetch queued in background' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// POST /api/admin/refetch-audio
router.post('/refetch-audio', (req, res) => {
    try {
        invalidateHealthCache();
        fetchMissingAudioInfo(0, 3, { minDelayMs: 900 }).catch(error => {
            console.error('[Admin] Audio info sweep failed:', error.message);
        });
        res.json({ success: true, message: 'Full audio info sweep started', sweep: getAudioSweepStatus() });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
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

// POST /api/admin/metadata/:fileId/manual-override — Manually edit metadata fields
router.post('/metadata/:fileId/manual-override', async (req, res) => {
    try {
        const { fileId } = req.params;
        const updates = req.body; // title, year, type, season, episode, tmdbId, overview

        const existing = await loadMetadata(fileId);
        if (!existing) {
            return res.status(404).json({ error: `No metadata found for fileId: ${fileId}` });
        }

        console.log(`[Admin] Manual override: fileId=${fileId}`);

        // Update fields
        existing.title = updates.title || existing.title;
        existing.overview = updates.overview || existing.overview;
        existing.year = parseInt(updates.year) || existing.year;
        existing.type = updates.type || existing.type;
        existing.tmdbId = updates.tmdbId ? parseInt(updates.tmdbId) : existing.tmdbId;
        
        // Remove retry flags since it's manually fixed
        existing.needsRetry = false;
        existing.fetchedAt = new Date().toISOString(); 

        if (existing.type === 'tv') {
            if (!existing.tv) existing.tv = {};
            existing.tv.showTitle = updates.title || existing.tv.showTitle || existing.title;
            existing.tv.seasonNumber = updates.season !== undefined ? parseInt(updates.season) : existing.tv.seasonNumber;
            existing.tv.episodeNumber = updates.episode !== undefined ? parseInt(updates.episode) : existing.tv.episodeNumber;
            
            // Re-sync basic fields just in case
            if (!existing.title && existing.tv.showTitle) {
                existing.title = existing.tv.showTitle;
            }
        } else {
            // Convert to movie
            if (existing.tv) delete existing.tv;
        }

        await saveMetadata(existing);
        res.json({ success: true, metadata: existing });

    } catch (error) {
        console.error(`[Admin] Manual override failed for ${req.params.fileId}:`, error.message);
        res.status(500).json({ error: error.message });
    }
});

// POST /api/admin/metadata/:fileId/set-probe-result — Manually provide ffprobe JSON output
router.post('/metadata/:fileId/set-probe-result', async (req, res) => {
    try {
        const { fileId } = req.params;
        const probeResult = req.body; // Expect full ffprobe JSON output

        if (!probeResult || !probeResult.streams) {
            return res.status(400).json({ error: 'Valid ffprobe JSON with streams is required' });
        }

        const existing = await loadMetadata(fileId);
        if (!existing) {
            return res.status(404).json({ error: `No metadata found for fileId: ${fileId}` });
        }

        console.log(`[Admin] Applying manual probe result: fileId=${fileId}`);

        // Extract tracks (reuse logic from telegramService but simplified)
        const audioTracks = probeResult.streams
            .filter(s => s.codec_type === 'audio')
            .map((s, idx) => ({
                index: idx,
                streamIndex: s.index,
                codec: s.codec_name,
                language: s.tags?.language || 'Unknown',
                languageCode: s.tags?.language || 'und',
                title: s.tags?.title || '',
                channels: s.channels || 0,
                browserPlayable: ['aac', 'mp3', 'opus', 'vorbis', 'flac'].includes(s.codec_name),
                isDefault: s.disposition?.default === 1
            }));

        const subtitleTracks = probeResult.streams
            .filter(s => s.codec_type === 'subtitle')
            .map((s, idx) => ({
                index: idx,
                streamIndex: s.index,
                codec: s.codec_name,
                language: s.tags?.language || 'Unknown',
                languageCode: s.tags?.language || 'und',
                title: s.tags?.title || '',
                isExternal: false
            }));

        if (audioTracks.length > 0) {
            existing.audioTracks = audioTracks;
            const defaultAudio = audioTracks.find(t => t.isDefault) || audioTracks[0];
            existing.audioCodec = defaultAudio.codec;
            existing.browserPlayable = defaultAudio.browserPlayable;
        }

        existing.subtitleTracks = subtitleTracks;

        if (probeResult.format) {
            if (probeResult.format.format_name) {
                existing.container = probeResult.format.format_name.split(',')[0];
            }
            if (probeResult.format.duration) {
                existing.duration = Number(probeResult.format.duration);
            }
        }

        // Success!
        existing._tracksDetected = true;
        existing.manualProbeNeeded = false;
        existing._probeFailCount = 0;

        await saveMetadata(existing);
        res.json({ success: true, metadata: existing });

    } catch (error) {
        console.error(`[Admin] Set probe failed for ${req.params.fileId}:`, error.message);
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
            if (entry.manualProbeNeeded) problems.push('manual_probe_needed');
            if (!entry.tmdbId || entry.tmdbId === 0) problems.push('no_tmdb_id');
            if (!entry.title) problems.push('no_title');
            if (!entry.fetchedAt) problems.push('never_fetched');
            if (entry.rating !== undefined && entry.rating > 0 && entry.rating < 2) problems.push('very_low_rating');
            
            const audio = buildAudioSummary(entry);
            if (audio.unsupportedTracks.length > 0 || audio.browserPlayable === false) problems.push('unsupported_audio');

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

// GET /api/admin/metadata/search — Search metadata entries
router.get('/metadata/search', async (req, res) => {
    try {
        const query = (req.query.q || '').toLowerCase();
        const type = req.query.type || 'all';
        
        const all = await getAllMetadata();
        let filtered = all;

        if (type !== 'all') {
            filtered = filtered.filter(m => {
                if (type === 'movie') return m.type === 'movie' && (!m.tv || !m.tv.seasonNumber);
                if (type === 'tv') return m.type === 'tv' || (m.tv && m.tv.seasonNumber);
                if (type === 'unsupported_audio') {
                    const audio = buildAudioSummary(m);
                    return audio.unsupportedTracks.length > 0 || audio.browserPlayable === false;
                }
                return true;
            });
        }

        if (query) {
            filtered = filtered.filter(m => 
                (m.title && m.title.toLowerCase().includes(query)) ||
                (m.fileName && m.fileName.toLowerCase().includes(query)) ||
                (m.fileId && m.fileId.toString() === query) ||
                (m.tv && m.tv.showTitle && m.tv.showTitle.toLowerCase().includes(query))
            );
        }

        // Sort by most recently added/fetched if possible, else fallback to fileId
        filtered.sort((a, b) => {
            if (a.fetchedAt && b.fetchedAt) return new Date(b.fetchedAt) - new Date(a.fetchedAt);
            return parseInt(b.fileId) - parseInt(a.fileId);
        });

        const results = filtered.map(entry => {
            const audioSummary = buildAudioSummary(entry);
            return {
                fileId: entry.fileId,
                fileName: entry.fileName,
                title: entry.title || (entry.tv ? entry.tv.showTitle : null) || 'Unknown',
                tmdbId: entry.tmdbId || 0,
                type: entry.type || (entry.tv && entry.tv.seasonNumber ? 'tv' : 'movie'),
                year: entry.year || '',
                poster: entry.poster,
                season: entry.tv?.seasonNumber,
                episode: entry.tv?.episodeNumber,
                audioCodec: entry.audioCodec || '',
                browserPlayable: audioSummary.browserPlayable,
                audioTracks: audioSummary.audioTracks,
                subtitleTrackCount: audioSummary.subtitleTrackCount,
                container: entry.container || '',
                duration: Number(entry.duration) || 0,
                tracksDetected: audioSummary.tracksDetected,
                manualProbeNeeded: !!entry.manualProbeNeeded
            };
        });

        res.json({
            total: results.length,
            results: results.slice(0, 100) // limit for performance
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

// ==================== SYSTEM & MONITORING ====================

// GET /api/admin/system/storage
router.get('/system/storage', async (req, res) => {
    try {
        const root = path.parse(process.cwd()).root;
        const { exec } = require('child_process');
        const util = require('util');
        const execPromise = util.promisify(exec);

        let storageInfo = {
            total: 0,
            free: 0,
            used: 0,
            percent: 0,
            drive: root
        };

        if (process.platform === 'win32') {
            const driveLetter = root.slice(0, 1);
            const { stdout } = await execPromise(`powershell -Command "Get-CimInstance Win32_LogicalDisk -Filter 'DeviceID=\'${driveLetter}:\'\" | Select-Object Size, FreeSpace"`);
            const lines = stdout.trim().split('\n').map(l => l.trim()).filter(Boolean);
            if (lines.length >= 2) {
                const values = lines[1].split(/\s+/);
                const size = parseInt(values[0]);
                const free = parseInt(values[1]);
                storageInfo.total = size;
                storageInfo.free = free;
                storageInfo.used = size - free;
                storageInfo.percent = Math.round((storageInfo.used / size) * 100);
            }
        } else {
            const { stdout } = await execPromise('df -B1 / --output=size,avail');
            const lines = stdout.trim().split('\n');
            if (lines.length >= 2) {
                const [size, free] = lines[1].trim().split(/\s+/).map(Number);
                storageInfo.total = size;
                storageInfo.free = free;
                storageInfo.used = size - free;
                storageInfo.percent = Math.round((storageInfo.used / size) * 100);
            }
        }

        res.json(storageInfo);
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch storage info' });
    }
});

// GET /api/admin/worker/logs
router.get('/worker/logs', (req, res) => {
    res.json(logger.getLogs());
});

module.exports = router;
