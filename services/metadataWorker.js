const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');
const axios = require('axios');
const TMDBClient = require('./tmdbClient');
const { cleanMediaFilename, detectTVEpisode, extractTVShowTitle } = require('../utils/filenameUtils');
const activityTracker = require('./activityTracker');

const DATA_DIR = path.join(__dirname, '../data/metadata');
const TV_CACHE_DIR = path.join(__dirname, '../data/tv_cache');
const MOVIES_DIR = path.join(__dirname, '../data/movies');
const POSTERS_DIR = path.join(__dirname, '../data/posters');
const BACKDROPS_DIR = path.join(__dirname, '../data/backdrops');

const TMDB_IMAGE_BASE = 'https://image.tmdb.org/t/p';

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Helper: Ensure directories exist
async function ensureDirs() {
    const dirs = [DATA_DIR, TV_CACHE_DIR, POSTERS_DIR, BACKDROPS_DIR];
    for (const dir of dirs) {
        try {
            await fs.mkdir(dir, { recursive: true });
        } catch (e) { }
    }
}
ensureDirs();

// ==================== PHASE 5: Image Downloads (Optimized) ====================

async function downloadImage(tmdbPath, localDir, localFilename, size = 'w500') {
    if (!tmdbPath) return null;

    const url = `${TMDB_IMAGE_BASE}/${size}${tmdbPath}`;
    const localPath = path.join(localDir, localFilename);

    try {
        // Check if valid image already exists
        try {
            const stat = await fs.stat(localPath);
            if (stat.size > 1000) return localPath; // Already downloaded — skip
        } catch { /* doesn't exist yet */ }

        await activityTracker.waitIfBusy();

        const response = await axios.get(url, {
            responseType: 'arraybuffer',
            timeout: 30000
        });

        if (response.data.byteLength < 1000) return null;

        // Ensure directory exists (redundant safe check)
        await fs.mkdir(localDir, { recursive: true });
        await fs.writeFile(localPath, response.data);
        return localPath;
    } catch (error) {
        console.error(`Image download failed: ${url}`, error.message);
        return null;
    }
}

// MOVIE images — unique per file, uses fileId
async function downloadMovieImages(fileId, posterTmdbPath, backdropTmdbPath) {
    const poster = await downloadImage(
        posterTmdbPath,
        POSTERS_DIR,
        `${fileId}.jpg`,
        'w500'
    );

    const backdrop = await downloadImage(
        backdropTmdbPath,
        BACKDROPS_DIR,
        `${fileId}_bd.jpg`,
        'w1280'
    );

    return {
        poster: poster ? `/data/posters/${fileId}.jpg` : null,
        backdrop: backdrop ? `/data/backdrops/${fileId}_bd.jpg` : null
    };
}

// FORCE DOWNLOAD — deletes existing file first (for refetch/corrections)
async function forceDownloadImage(tmdbPath, localDir, localFilename, size = 'w500') {
    if (!tmdbPath) return null;

    const localPath = path.join(localDir, localFilename);
    const url = `${TMDB_IMAGE_BASE}/${size}${tmdbPath}`;

    try {
        // Delete existing file first
        try { await fs.unlink(localPath); } catch { /* doesn't exist */ }

        await activityTracker.waitIfBusy();

        const response = await axios.get(url, {
            responseType: 'arraybuffer',
            timeout: 30000
        });

        if (response.data.byteLength < 1000) return null;

        await fs.mkdir(localDir, { recursive: true });
        await fs.writeFile(localPath, response.data);
        return localPath;
    } catch (error) {
        console.error(`Image force-download failed: ${url}`, error.message);
        return null;
    }
}

// FORCE MOVIE images — delete old, download new
async function forceDownloadMovieImages(fileId, posterTmdbPath, backdropTmdbPath) {
    const poster = await forceDownloadImage(
        posterTmdbPath, POSTERS_DIR, `${fileId}.jpg`, 'w500'
    );
    const backdrop = await forceDownloadImage(
        backdropTmdbPath, BACKDROPS_DIR, `${fileId}_bd.jpg`, 'w1280'
    );
    return {
        poster: poster ? `/data/posters/${fileId}.jpg` : null,
        backdrop: backdrop ? `/data/backdrops/${fileId}_bd.jpg` : null
    };
}

// FORCE SHOW images — delete old, download new
async function forceDownloadShowImages(showTmdbId, posterTmdbPath, backdropTmdbPath) {
    const posterFilename = `show_${showTmdbId}.jpg`;
    const backdropFilename = `show_${showTmdbId}_bd.jpg`;
    const poster = await forceDownloadImage(
        posterTmdbPath, POSTERS_DIR, posterFilename, 'w500'
    );
    const backdrop = await forceDownloadImage(
        backdropTmdbPath, BACKDROPS_DIR, backdropFilename, 'w1280'
    );
    return {
        poster: poster ? `/data/posters/${posterFilename}` : null,
        backdrop: backdrop ? `/data/backdrops/${backdropFilename}` : null
    };
}

// TV SHOW images — shared across all episodes, uses showTmdbId
// Downloaded ONCE when show metadata is fetched
async function downloadShowImages(showTmdbId, posterTmdbPath, backdropTmdbPath) {
    const posterFilename = `show_${showTmdbId}.jpg`;
    const backdropFilename = `show_${showTmdbId}_bd.jpg`;

    const poster = await downloadImage(
        posterTmdbPath,
        POSTERS_DIR,
        posterFilename,
        'w500'
    );

    const backdrop = await downloadImage(
        backdropTmdbPath,
        BACKDROPS_DIR,
        backdropFilename,
        'w1280'
    );

    return {
        poster: poster ? `/data/posters/${posterFilename}` : null,
        backdrop: backdrop ? `/data/backdrops/${backdropFilename}` : null
    };
}


// ==================== PHASE 3: TV Show Registry (Rebuilt with Shared Images) ====================
class TVShowRegistry {
    constructor() {
        // Key: normalized show title
        this.shows = new Map();
        // Key: normalized show title, Value: Promise
        this.activeFetches = new Map();
    }

    // Register an episode — no API calls happen here
    registerEpisode(fileId, filename, filePath, parentFolder) {
        const tvInfo = detectTVEpisode(filename);
        if (tvInfo.type !== 'tv') return null;

        const showTitleInfo = extractTVShowTitle(filename, parentFolder);
        const showKey = this.makeKey(showTitleInfo.title);

        if (!this.shows.has(showKey)) {
            this.shows.set(showKey, {
                title: showTitleInfo.title,
                year: showTitleInfo.year,
                tmdbId: null,
                showMetadata: null,
                fetchState: 'pending', // pending | fetching | complete | failed
                // Image paths — set ONCE when show is fetched
                sharedPoster: null,
                sharedBackdrop: null,
                episodes: []
            });
        }

        const show = this.shows.get(showKey);
        // Avoid duplicates
        if (!show.episodes.find(e => e.fileId === fileId)) {
            show.episodes.push({
                fileId,
                filename,
                filePath,
                season: tvInfo.season,
                episode: tvInfo.episode
            });
        }

        return showKey;
    }

    makeKey(title) {
        return title.toLowerCase().replace(/[^a-z0-9]/g, '');
    }

    // Get all shows that need their SHOW-LEVEL metadata fetched
    getShowsNeedingFetch() {
        const result = [];
        for (const [key, show] of this.shows) {
            if (show.fetchState === 'pending' || show.fetchState === 'failed') {
                result.push({
                    key,
                    title: show.title,
                    year: show.year,
                    episodeCount: show.episodes.length
                });
            }
        }
        return result;
    }

    getEpisodesForShow(showKey) {
        const show = this.shows.get(showKey);
        return show ? show.episodes : [];
    }

    setShowMetadata(showKey, tmdbId, showMetadata) {
        const show = this.shows.get(showKey);
        if (!show) return;
        show.tmdbId = tmdbId;
        show.showMetadata = showMetadata;
        show.fetchState = 'complete';
    }

    // Set shared image paths — called ONCE after downloading show images
    setShowImages(showKey, posterPath, backdropPath) {
        const show = this.shows.get(showKey);
        if (!show) return;
        show.sharedPoster = posterPath;
        show.sharedBackdrop = backdropPath;
    }

    // Get shared image paths for any episode of this show
    getShowImages(showKey) {
        const show = this.shows.get(showKey);
        if (!show) return { poster: null, backdrop: null };
        return {
            poster: show.sharedPoster,
            backdrop: show.sharedBackdrop
        };
    }

    setShowFailed(showKey) {
        const show = this.shows.get(showKey);
        if (show) show.fetchState = 'failed';
    }

    setShowFetching(showKey) {
        const show = this.shows.get(showKey);
        if (show) show.fetchState = 'fetching';
    }

    // Ensure only ONE fetch per show, even if called concurrently
    async fetchShowOnce(showKey, fetchFunction) {
        if (this.activeFetches.has(showKey)) {
            return this.activeFetches.get(showKey);
        }

        const fetchPromise = (async () => {
            try {
                this.setShowFetching(showKey);
                return await fetchFunction();
            } finally {
                this.activeFetches.delete(showKey);
            }
        })();

        this.activeFetches.set(showKey, fetchPromise);
        return fetchPromise;
    }
}

// ==================== Helpers: Retry Logic & Data Persistence ====================
function buildFailedEntry(fileId, fileName, type, title, year, failureType, season = null, episode = null) {
    return {
        fileId,
        fileName,
        type,
        title,
        originalTitle: '',
        overview: '',
        releaseDate: null,
        year,
        runtime: 0,
        genres: [],
        rating: 0,
        popularity: 0,
        poster: null,
        backdrop: null,
        tmdbId: 0,
        fetchedAt: null,
        needsRetry: true,
        tv: type === 'tv' ? {
            showTitle: title,
            originalShowTitle: '',
            seasonNumber: season || 0,
            episodeNumber: episode || 0,
            episodeTitle: '',
            episodeOverview: '',
            showTmdbId: 0,
            episodeRuntime: 0,
            totalSeasons: 0,
            totalEpisodes: 0
        } : null,
        _retry: {
            failureType,
            lastAttempt: Date.now(),
            attemptCount: 1,
            searchedTitle: title,
            searchedYear: year
        }
    };
}

function shouldRetry(entry) {
    if (!entry.needsRetry) return false;
    if (!entry._retry) return true;
    if (entry._retry.attemptCount >= 10) return false;

    const elapsed = Date.now() - entry._retry.lastAttempt;
    const delays = [
        1 * 3600000,   // 1 hour
        6 * 3600000,   // 6 hours
        24 * 3600000,  // 24 hours
        168 * 3600000  // 7 days
    ];
    const delay = delays[Math.min(entry._retry.attemptCount - 1, delays.length - 1)];
    return elapsed >= delay;
}

function incrementRetry(entry, failureType) {
    if (!entry._retry) {
        entry._retry = { failureType, lastAttempt: Date.now(), attemptCount: 1 };
    } else {
        entry._retry.failureType = failureType;
        entry._retry.lastAttempt = Date.now();
        entry._retry.attemptCount += 1;
    }
}

async function saveMetadata(metadata) {
    if (!metadata.fileId) throw new Error('Missing fileId');
    const toSave = { ...metadata };
    delete toSave._posterPath;
    delete toSave._backdropPath;

    await fs.writeFile(
        path.join(DATA_DIR, `${metadata.fileId}.json`),
        JSON.stringify(toSave, null, 2)
    );
}

async function loadMetadata(fileId) {
    try {
        const data = await fs.readFile(path.join(DATA_DIR, `${fileId}.json`), 'utf-8');
        return JSON.parse(data);
    } catch { return null; }
}

async function getAllMetadata() {
    try {
        const files = await fs.readdir(DATA_DIR);
        const results = [];
        for (const file of files) {
            if (!file.endsWith('.json')) continue;
            try {
                const data = await fs.readFile(path.join(DATA_DIR, file), 'utf-8');
                results.push(JSON.parse(data));
            } catch { continue; }
        }
        return results;
    } catch { return []; }
}

async function saveTVShowCache(showTmdbId, showMetadata) {
    await fs.writeFile(
        path.join(TV_CACHE_DIR, `${showTmdbId}.json`),
        JSON.stringify(showMetadata, null, 2)
    );
}

async function loadTVShowCache(showTmdbId) {
    try {
        const data = await fs.readFile(path.join(TV_CACHE_DIR, `${showTmdbId}.json`), 'utf-8');
        return JSON.parse(data);
    } catch { return null; }
}

// ==================== PHASE 8: Metadata Worker (Optimized) ====================
class MetadataWorker {
    constructor() {
        this.tmdb = new TMDBClient(process.env.TMDB_API_KEY);
        this.tvRegistry = new TVShowRegistry();
        this.isRunning = false;
        this.telegramService = null; // Will be set externally
    }

    setTelegramService(service) {
        this.telegramService = service;
    }

    // ==================== PROCESS BATCH ====================

    async processMediaLibrary(files) {
        if (this.isRunning) {
            console.log('[Worker] Already running, queuing batch...');
            // In a real queue system, we'd add to a queue. 
            // For now, we just rely on the retry mechanism to pick these up later 
            // or hope the current run picks them up if they are in the list.
            // But actually, we should probably just process them sequentially.
            // Let's just process them now, concurrency handled by loop.
        }
        this.isRunning = true;
        console.log(`[Worker] Processing ${files.length} items...`);

        try {
            const movies = [];

            // 1. Classify
            for (const file of files) {
                const existing = await loadMetadata(file.fileId);
                if (existing && !existing.needsRetry && existing.fetchedAt) continue;
                if (existing && existing.needsRetry && !shouldRetry(existing)) continue;

                const tvInfo = detectTVEpisode(file.filename);
                if (tvInfo.type === 'tv') {
                    this.tvRegistry.registerEpisode(
                        file.fileId, file.filename, file.path, file.parentFolder
                    );
                } else {
                    const cleaned = cleanMediaFilename(file.filename);
                    movies.push({
                        fileId: file.fileId,
                        filename: file.filename,
                        title: cleaned.title,
                        year: cleaned.year
                    });
                }
            }

            console.log(`[Worker] Classified: ${movies.length} movies, ${this.tvRegistry.getShowsNeedingFetch().length} TV shows`);


            // 2. Process Movies
            for (const movie of movies) {
                if (activityTracker.isPaused()) {
                    await activityTracker.waitIfBusy();
                }

                try {
                    // CHECK FOR SPLIT PARTS
                    // if partNumber > 1, try to find Part 1 metadata first
                    let partToCopy = null;
                    const cleaned = cleanMediaFilename(movie.filename);

                    if (cleaned.partNumber && cleaned.partNumber > 1) {
                        // Try to find Part 1
                        const allMeta = await getAllMetadata();
                        partToCopy = allMeta.find(m =>
                            m.type === 'movie' &&
                            m.title === cleaned.title &&
                            m.year === cleaned.year &&
                            (!m.partNumber || m.partNumber === 1)
                        );
                    }

                    if (partToCopy) {
                        console.log(`[Worker] Detected Part ${cleaned.partNumber} for "${cleaned.title}". Copying metadata from Part 1...`);
                        const copy = { ...partToCopy };
                        copy.fileId = movie.fileId;
                        copy.filename = movie.filename;
                        copy.isSplit = true;
                        copy.partNumber = cleaned.partNumber;
                        // Keep unique file props
                        delete copy._id;

                        await saveMetadata(copy);
                        console.log(`✓ Movie Part ${cleaned.partNumber}: ${copy.title}`);
                        continue; // Skip TMDB fetch
                    }

                    // =========================================================
                    // 1. GENERATE & SAVE BASE ENTRY IMMEDIATELY
                    // =========================================================
                    let baseMetadata = buildFailedEntry(
                        movie.fileId, movie.filename, 'movie',
                        movie.title, movie.year, 'pending_tmdb'
                    );

                    // Pre-fetch track information right away for the base object
                    try {
                        const telegramService = require('./telegramService');
                        const doc = await telegramService.getDocument(movie.fileId);
                        if (doc) {
                            const tracks = await telegramService.detectAllTracks(doc, movie.fileId);
                            baseMetadata.audioTracks = tracks.audioTracks;
                            baseMetadata.subtitleTracks = tracks.subtitleTracks;

                            const defaultAudio = tracks.audioTracks.find(t => t.isDefault) || tracks.audioTracks[0];
                            baseMetadata.audioCodec = defaultAudio ? defaultAudio.codec : 'unknown';
                            baseMetadata.browserPlayable = defaultAudio ? defaultAudio.browserPlayable : true;
                        }
                    } catch (e) {
                        console.warn(`[Worker] Track detection failed for ${movie.fileId}:`, e.message);
                    }

                    await saveMetadata(baseMetadata);
                    console.log(`[Worker] Initialized base metadata for: ${movie.title}. Fetching TMDB...`);

                    // =========================================================
                    // 2. FETCH TMDB DATA AND UPDATE
                    // =========================================================
                    await activityTracker.waitIfBusy();
                    let metadata = null;
                    try {
                        metadata = await this.tmdb.fetchMovieComplete(
                            movie.fileId, movie.filename, movie.title, movie.year
                        );
                    } catch (error) {
                        const failureType = error.response?.status === 429 ? 'rate_limited' : 'network_error';
                        console.error(`✗ Movie TMDB failed: ${movie.title}`, error.message);
                        baseMetadata._failureType = failureType;
                        await saveMetadata(baseMetadata);
                        if (failureType === 'rate_limited') {
                            await new Promise(r => setTimeout(r, 5000));
                        }
                        continue;
                    }

                    if (!metadata) {
                        baseMetadata._failureType = 'not_found';
                        await saveMetadata(baseMetadata);
                        console.log(`~ Movie TMDB not found. Leaving base metadata: ${movie.title}`);
                        continue;
                    }

                    // Check if this is Part 1 of a split (explicit)
                    if (cleaned.partNumber === 1) {
                        metadata.isSplit = true;
                        metadata.partNumber = 1;
                    }

                    // Transfer track info to the new metadata object
                    metadata.audioTracks = baseMetadata.audioTracks;
                    metadata.subtitleTracks = baseMetadata.subtitleTracks;
                    metadata.audioCodec = baseMetadata.audioCodec;
                    metadata.browserPlayable = baseMetadata.browserPlayable;

                    // Optimized: Use downloadMovieImages
                    const images = await downloadMovieImages(
                        metadata.fileId, metadata._posterPath, metadata._backdropPath
                    );
                    metadata.poster = images.poster;
                    metadata.backdrop = images.backdrop;

                    // Save the fully resolved object
                    await saveMetadata(metadata);
                    console.log(`✓ Movie: ${metadata.title} (${metadata.year})`);

                } catch (error) {
                    console.error(`✗ Fatal error processing movie ${movie.title}:`, error.message);
                }

                if (activityTracker.isStreaming()) {
                    await sleep(2000);
                } else {
                    await sleep(250);
                }
            }

            // 3. Process TV Shows (Optimized Shared Images)
            const showsToFetch = this.tvRegistry.getShowsNeedingFetch();

            for (const show of showsToFetch) {
                if (activityTracker.isPaused()) {
                    await activityTracker.waitIfBusy();
                }

                console.log(`Processing TV show: "${show.title}" (${show.episodeCount} episodes)`);

                // =========================================================
                // 1. GENERATE & SAVE BASE ENTRY FOR ALL EPISODES IMMEDIATELY
                // =========================================================
                const episodes = this.tvRegistry.getEpisodesForShow(show.key);
                for (const ep of episodes) {
                    let baseMetadata = buildFailedEntry(
                        ep.fileId, ep.filename, 'tv',
                        show.title, show.year, 'pending_tmdb',
                        ep.season, ep.episode
                    );

                    // Pre-fetch track information right away for the base object
                    try {
                        if (this.telegramService) {
                            const doc = await this.telegramService.getDocument(ep.fileId);
                            if (doc) {
                                // Use detectAudioCodec which is the new standard for TV tracks
                                const codecInfo = await this.telegramService.detectAudioCodec(ep.fileId);
                                baseMetadata.audioCodec = codecInfo.codec;
                                baseMetadata.browserPlayable = codecInfo.browserPlayable;
                            }
                        }
                    } catch (e) {
                        console.warn(`[Worker] Track detection failed for ${ep.fileId}:`, e.message);
                    }

                    await saveMetadata(baseMetadata);
                    // Attach base metadata to episode reference for later
                    ep.baseMetadata = baseMetadata;
                }

                console.log(`[Worker] Initialized base metadata for ${episodes.length} episodes of: ${show.title}. Fetching TMDB...`);

                // =========================================================
                // 2. FETCH TMDB DATA AND UPDATE
                // =========================================================
                const showMetadata = await this.tvRegistry.fetchShowOnce(show.key, async () => {
                    try {
                        await activityTracker.waitIfBusy();
                        const meta = await this.tmdb.fetchTVShowDetails(show.title, show.year);

                        if (!meta) {
                            this.tvRegistry.setShowFailed(show.key);
                            for (const ep of episodes) {
                                ep.baseMetadata._failureType = 'not_found';
                                await saveMetadata(ep.baseMetadata);
                            }
                            return null;
                        }

                        // Store show metadata
                        this.tvRegistry.setShowMetadata(show.key, meta.showTmdbId, meta);
                        await saveTVShowCache(meta.showTmdbId, meta);

                        // DOWNLOAD IMAGES ONCE
                        const images = await downloadShowImages(
                            meta.showTmdbId,
                            meta.posterPath,
                            meta.backdropPath
                        );

                        // Store shared paths in registry
                        this.tvRegistry.setShowImages(show.key, images.poster, images.backdrop);

                        console.log(`  ✓ Show: ${meta.showTitle} (TMDB: ${meta.showTmdbId})`);
                        if (images.poster) console.log(`  ✓ Poster: ${images.poster} (shared)`);

                        return meta;

                    } catch (error) {
                        this.tvRegistry.setShowFailed(show.key);
                        const failureType = error.response?.status === 429 ? 'rate_limited' : 'network_error';
                        for (const ep of episodes) {
                            ep.baseMetadata._failureType = failureType;
                            await saveMetadata(ep.baseMetadata);
                        }
                        console.error(`  ✗ Show failed: ${show.title}`, error.message);
                        return null;
                    }
                });

                if (!showMetadata) continue;

                // Get the shared image paths
                const sharedImages = this.tvRegistry.getShowImages(show.key);

                for (const ep of episodes) {
                    if (activityTracker.isPaused()) {
                        await activityTracker.waitIfBusy();
                    }

                    try {
                        await activityTracker.waitIfBusy();
                        const episodeDetails = await this.tmdb.fetchEpisodeDetails(
                            showMetadata.showTmdbId, ep.season, ep.episode
                        );

                        const metadata = this.tmdb.buildEpisodeSchema(
                            ep.fileId, ep.filename,
                            showMetadata,
                            episodeDetails,
                            ep.season, ep.episode
                        );

                        // USE SHARED IMAGE PATHS
                        metadata.poster = sharedImages.poster;
                        metadata.backdrop = sharedImages.backdrop;

                        // Transfer base metadata track info to the new metadata object
                        if (ep.baseMetadata) {
                            metadata.audioCodec = ep.baseMetadata.audioCodec;
                            metadata.browserPlayable = ep.baseMetadata.browserPlayable;
                        }

                        await saveMetadata(metadata);
                        console.log(`    ✓ S${String(ep.season).padStart(2, '0')}E${String(ep.episode).padStart(2, '0')}: ${episodeDetails.episodeTitle || '(untitled)'}`);

                    } catch (error) {
                        const fallbackMetadata = this.tmdb.buildEpisodeSchema(
                            ep.fileId, ep.filename,
                            showMetadata,
                            { episodeTitle: '', episodeOverview: '', episodeRuntime: 0 },
                            ep.season, ep.episode
                        );

                        // Still use shared images
                        fallbackMetadata.poster = sharedImages.poster;
                        fallbackMetadata.backdrop = sharedImages.backdrop;

                        // Transfer track info
                        if (ep.baseMetadata) {
                            fallbackMetadata.audioCodec = ep.baseMetadata.audioCodec;
                            fallbackMetadata.browserPlayable = ep.baseMetadata.browserPlayable;
                        }

                        await saveMetadata(fallbackMetadata);
                        console.warn(`    ~ S${String(ep.season).padStart(2, '0')}E${String(ep.episode).padStart(2, '0')}: show-level data only`);
                    }

                    if (activityTracker.isStreaming()) {
                        await sleep(2000);
                    } else {
                        await sleep(150);
                    }
                }

                if (activityTracker.isStreaming()) {
                    await sleep(2000);
                } else {
                    await sleep(300);
                }
            }

        } finally {
            this.isRunning = false;
        }
    }

    // ==================== RETRY WORKERS (Optimized) ====================

    // NOTE: Kept method name 'retryFailedLookups' to match server.js integration
    async retryFailedLookups() {
        if (activityTracker.isPaused()) {
            console.log('[Worker] Skipping retryFailedLookups — streams active, will retry next cycle');
            return;
        }

        const all = await getAllMetadata();
        const retriable = all.filter(e => e.needsRetry && shouldRetry(e));
        console.log(`[RetryWorker] ${retriable.length} entries to retry`);

        // Group TV retries by show
        const tvRetryShows = new Map();
        const movieRetries = [];

        for (const entry of retriable) {
            // FIXED: Route based on type, handle missing _retry
            const isTv = entry.type === 'tv' || (entry.tv && entry.tv.seasonNumber);

            if (isTv) {
                // Determine show key from existing metadata or filename
                let showKey = null;
                let showTitle = null;
                let showYear = null;

                if (entry._retry?.searchedTitle) {
                    showTitle = entry._retry.searchedTitle;
                    showYear = entry._retry.searchedYear;
                } else if (entry.tv?.showTitle) {
                    showTitle = entry.tv.showTitle;
                } else {
                    // Parse from filename if desperate
                    const cleaned = cleanMediaFilename(entry.fileName);
                    showTitle = cleaned.title;
                    showYear = cleaned.year;
                }

                if (showTitle) {
                    showKey = showTitle.toLowerCase().replace(/[^a-z0-9]/g, '');
                    if (!tvRetryShows.has(showKey)) {
                        tvRetryShows.set(showKey, {
                            title: showTitle,
                            year: showYear,
                            episodes: []
                        });
                    }
                    tvRetryShows.get(showKey).episodes.push(entry);
                } else {
                    // Fallback to individual retry if we can't group
                    movieRetries.push(entry);
                }
            } else {
                movieRetries.push(entry);
            }
        }

        // Retry movies
        for (const entry of movieRetries) {
            if (activityTracker.isPaused()) {
                await activityTracker.waitIfBusy();
            }

            try {
                // Use current values in the entry (allows for manual fixes in JSON)
                // Fallback to filename cleaning only if title is missing
                let title = entry.title;
                let year = entry.year;

                if (!title) {
                    const cleaned = cleanMediaFilename(entry.fileName);
                    title = cleaned.title;
                    year = cleaned.year;
                }

                await activityTracker.waitIfBusy();
                const metadata = await this.tmdb.fetchMovieComplete(
                    entry.fileId, entry.fileName, title, year
                );
                if (metadata) {
                    const images = await downloadMovieImages(
                        metadata.fileId, metadata._posterPath, metadata._backdropPath
                    );
                    metadata.poster = images.poster;
                    metadata.backdrop = images.backdrop;
                    await saveMetadata(metadata);
                } else {
                    incrementRetry(entry, 'not_found');
                    await saveMetadata(entry);
                }
            } catch (error) {
                incrementRetry(entry, error.response?.status === 429 ? 'rate_limited' : 'network_error');
                await saveMetadata(entry);
            }

            if (activityTracker.isStreaming()) {
                await sleep(2000);
            } else {
                await sleep(500);
            }
        }

        // Retry TV shows — shared images per show
        for (const [showKey, showGroup] of tvRetryShows) {
            if (activityTracker.isPaused()) {
                await activityTracker.waitIfBusy();
            }

            try {
                let showMeta = null;
                // Check cache first
                const firstEp = showGroup.episodes[0];
                if (firstEp.tv?.showTmdbId && firstEp.tv.showTmdbId > 0) {
                    showMeta = await loadTVShowCache(firstEp.tv.showTmdbId);
                }

                // Fetch ONCE if not cached
                if (!showMeta) {
                    await activityTracker.waitIfBusy();
                    showMeta = await this.tmdb.fetchTVShowDetails(showGroup.title, showGroup.year);
                    if (showMeta) {
                        await saveTVShowCache(showMeta.showTmdbId, showMeta);
                    }
                }

                if (!showMeta) {
                    for (const ep of showGroup.episodes) {
                        incrementRetry(ep, 'not_found');
                        await saveMetadata(ep);
                    }
                    continue;
                }

                // Download show images ONCE for all episodes in this retry batch
                const sharedImages = await downloadShowImages(
                    showMeta.showTmdbId,
                    showMeta.posterPath,
                    showMeta.backdropPath
                );

                // Build metadata for each episode using shared images
                for (const ep of showGroup.episodes) {
                    if (activityTracker.isPaused()) {
                        await activityTracker.waitIfBusy();
                    }

                    await activityTracker.waitIfBusy();
                    const episodeDetails = await this.tmdb.fetchEpisodeDetails(
                        showMeta.showTmdbId,
                        ep.tv?.seasonNumber || 1,
                        ep.tv?.episodeNumber || 1
                    );

                    const metadata = this.tmdb.buildEpisodeSchema(
                        ep.fileId, ep.fileName, showMeta, episodeDetails,
                        ep.tv?.seasonNumber || 1, ep.tv?.episodeNumber || 1
                    );

                    // Shared images
                    metadata.poster = sharedImages.poster;
                    metadata.backdrop = sharedImages.backdrop;

                    await saveMetadata(metadata);

                    if (activityTracker.isStreaming()) {
                        await sleep(2000);
                    } else {
                        await sleep(200);
                    }
                }

            } catch (error) {
                for (const ep of showGroup.episodes) {
                    incrementRetry(ep, 'network_error');
                    await saveMetadata(ep);
                }
            }

            if (activityTracker.isStreaming()) {
                await sleep(2000);
            } else {
                await sleep(500);
            }
        }
    }

    // NOTE: Kept method name 'retryFailedImageDownloads' to match server.js integration
    async retryFailedImageDownloads() {
        if (activityTracker.isPaused()) {
            console.log('[Worker] Skipping retryFailedImageDownloads — streams active, will retry next cycle');
            return;
        }

        const all = await getAllMetadata();
        const needsImages = all.filter(e =>
            !e.needsRetry && e.fetchedAt && e.tmdbId > 0 &&
            (!e.poster || !e.backdrop)
        );
        console.log(`[ImageWorker] ${needsImages.length} need images`);

        // Group TV episodes by show
        const tvImageGroups = new Map();
        const movieImageNeeds = [];

        for (const entry of needsImages) {
            if (entry.type === 'tv' && entry.tv?.showTmdbId) {
                const showId = entry.tv.showTmdbId;
                if (!tvImageGroups.has(showId)) {
                    tvImageGroups.set(showId, { showTmdbId: showId, episodes: [] });
                }
                tvImageGroups.get(showId).episodes.push(entry);
            } else {
                movieImageNeeds.push(entry);
            }
        }

        // Movies — individual downloads
        for (const entry of movieImageNeeds) {
            if (activityTracker.isPaused()) {
                await activityTracker.waitIfBusy();
            }

            try {
                await activityTracker.waitIfBusy();
                const d = await this.tmdb.request(`/movie/${entry.tmdbId}`);
                const images = await downloadMovieImages(entry.fileId, d.poster_path, d.backdrop_path);

                let updated = false;
                if (images.poster && !entry.poster) { entry.poster = images.poster; updated = true; }
                if (images.backdrop && !entry.backdrop) { entry.backdrop = images.backdrop; updated = true; }
                if (updated) await saveMetadata(entry);
            } catch { continue; }

            if (activityTracker.isStreaming()) {
                await sleep(2000);
            } else {
                await sleep(300);
            }
        }

        // TV shows — ONE download per show, apply to all episodes
        for (const [showId, group] of tvImageGroups) {
            if (activityTracker.isPaused()) {
                await activityTracker.waitIfBusy();
            }

            try {
                let posterPath = null;
                let backdropPath = null;

                // Try cache first
                const cached = await loadTVShowCache(showId);
                if (cached) {
                    posterPath = cached.posterPath;
                    backdropPath = cached.backdropPath;
                } else {
                    await activityTracker.waitIfBusy();
                    const d = await this.tmdb.request(`/tv/${showId}`);
                    posterPath = d.poster_path;
                    backdropPath = d.backdrop_path;
                }

                // Download ONCE
                const sharedImages = await downloadShowImages(showId, posterPath, backdropPath);

                // Apply to ALL episodes of this show
                for (const entry of group.episodes) {
                    let updated = false;
                    if (sharedImages.poster && !entry.poster) {
                        entry.poster = sharedImages.poster;
                        updated = true;
                    }
                    if (sharedImages.backdrop && !entry.backdrop) {
                        entry.backdrop = sharedImages.backdrop;
                        updated = true;
                    }
                    if (updated) await saveMetadata(entry);
                }

                console.log(`  ✓ Show ${showId}: images applied to ${group.episodes.length} episodes`);

            } catch { continue; }

            if (activityTracker.isStreaming()) {
                await sleep(2000);
            } else {
                await sleep(300);
            }
        }
    }

    async getMetadata(fileId) {
        return await loadMetadata(fileId);
    }

    // ==================== REFETCH METADATA ====================
    // Re-fetches ALL metadata for a fileId using a specific (or existing) TMDB ID
    // Used by: file watcher (needsRefetch flag), admin API (/fix, /refetch)
    async refetchMetadata(fileId, options = {}) {
        const { tmdbId: overrideTmdbId, type: overrideType } = options;

        // 1. Load existing metadata
        const existing = await loadMetadata(fileId);
        if (!existing) {
            throw new Error(`No metadata file found for fileId: ${fileId}`);
        }

        const tmdbId = overrideTmdbId || existing.tmdbId;
        if (!tmdbId || tmdbId === 0) {
            throw new Error(`No TMDB ID available for fileId: ${fileId}`);
        }

        const type = overrideType || existing.type || 'movie';
        console.log(`[Worker] 🔄 Refetching ${type} metadata: fileId=${fileId}, tmdbId=${tmdbId}`);

        await activityTracker.waitIfBusy();

        if (type === 'movie') {
            // Fetch full movie details by TMDB ID
            const d = await this.tmdb.request(`/movie/${tmdbId}`);

            const metadata = {
                fileId: existing.fileId,
                fileName: existing.fileName,
                type: 'movie',
                title: d.title || existing.title,
                originalTitle: d.original_title || '',
                overview: d.overview || '',
                releaseDate: d.release_date || null,
                year: d.release_date ? parseInt(d.release_date.split('-')[0]) : existing.year,
                runtime: d.runtime || 0,
                genres: (d.genres || []).map(g => g.name),
                rating: d.vote_average || 0,
                popularity: d.popularity || 0,
                poster: null,
                backdrop: null,
                tmdbId: d.id,
                fetchedAt: new Date().toISOString(),
                needsRetry: false,
                tv: null
            };

            // Preserve split info
            if (existing.isSplit) {
                metadata.isSplit = existing.isSplit;
                metadata.partNumber = existing.partNumber;
            }

            // Force re-download images (delete old, download new)
            const images = await forceDownloadMovieImages(
                fileId, d.poster_path, d.backdrop_path
            );
            metadata.poster = images.poster;
            metadata.backdrop = images.backdrop;

            await saveMetadata(metadata);
            console.log(`[Worker] ✅ Refetched movie: ${metadata.title} (${metadata.year})`);
            return metadata;

        } else if (type === 'tv') {
            // Fetch show details
            const d = await this.tmdb.request(`/tv/${tmdbId}`);

            const showMeta = {
                showTmdbId: d.id,
                showTitle: d.name || existing.title,
                originalShowTitle: d.original_name || '',
                overview: d.overview || '',
                firstAirDate: d.first_air_date || null,
                genres: (d.genres || []).map(g => g.name),
                rating: d.vote_average || 0,
                popularity: d.popularity || 0,
                posterPath: d.poster_path,
                backdropPath: d.backdrop_path,
                defaultEpisodeRuntime: (d.episode_run_time && d.episode_run_time.length > 0)
                    ? d.episode_run_time[0] : 0,
                totalSeasons: d.number_of_seasons || 0,
                totalEpisodes: d.number_of_episodes || 0
            };

            // Preserve season/episode from existing
            const season = existing.tv?.seasonNumber || 1;
            const episode = existing.tv?.episodeNumber || 1;

            // Fetch episode details
            const episodeDetails = await this.tmdb.fetchEpisodeDetails(
                showMeta.showTmdbId, season, episode
            );

            const metadata = this.tmdb.buildEpisodeSchema(
                existing.fileId, existing.fileName,
                showMeta, episodeDetails, season, episode
            );

            // Force re-download show images
            const images = await forceDownloadShowImages(
                showMeta.showTmdbId, showMeta.posterPath, showMeta.backdropPath
            );
            metadata.poster = images.poster;
            metadata.backdrop = images.backdrop;

            await saveMetadata(metadata);
            console.log(`[Worker] ✅ Refetched TV: ${metadata.title} S${season}E${episode}`);
            return metadata;
        }

        throw new Error(`Unknown type: ${type}`);
    }
}



// ==================== TELEGRAM SYNC ====================

const LIST_CACHE_PATH = path.join(__dirname, '../data/list_caches.json');

/**
 * Sync local file list with Telegram channel
 * Called on server startup and periodically
 */
async function syncWithTelegram() {
    console.log('[Worker] 🔄 Starting Telegram sync...');

    // Batch invalidations
    let requiresInvalidation = false;

    // Step 1: Read local cache
    let localCache = [];
    try {
        const raw = await fs.readFile(LIST_CACHE_PATH, 'utf-8');
        localCache = JSON.parse(raw);
        if (!Array.isArray(localCache)) localCache = [];
        console.log(`[Worker] 📋 Local cache: ${localCache.length} files`);
    } catch (err) {
        console.log('[Worker] 📋 No local cache found, starting fresh');
        localCache = [];
    }

    // Step 2: Fetch current files from Telegram
    let telegramFiles = [];
    try {
        if (!worker.telegramService) {
            throw new Error('Telegram service not linked');
        }
        telegramFiles = await worker.telegramService.scanChannelFiles();
        console.log(`[Worker] 📡 Telegram: ${telegramFiles.length} files`);
    } catch (err) {
        console.error('[Worker] ❌ Failed to fetch Telegram files:', err.message);
        return { added: 0, removed: 0, updated: 0, error: err.message };
    }

    // Step 3: Build lookup maps
    const localMap = new Map();     // fileId → local cache entry
    const telegramMap = new Map();  // fileId → telegram entry

    for (const item of localCache) {
        const id = String(item.id || item.fileId || item.messageId);
        localMap.set(id, item);
    }

    for (const item of telegramFiles) {
        const id = String(item.id || item.fileId || item.messageId);
        telegramMap.set(id, item);
    }

    // Step 4: Find differences
    const newFiles = [];
    const removedFiles = [];
    const changedFiles = [];

    // Find NEW files
    for (const [id, tgFile] of telegramMap) {
        if (!localMap.has(id)) {
            newFiles.push(tgFile);
        } else {
            // Check if file was renamed or modified
            const localFile = localMap.get(id);
            if (localFile.fileName !== tgFile.fileName) {
                changedFiles.push({ old: localFile, new: tgFile });
            }
        }
    }

    // Find REMOVED files
    for (const [id, localFile] of localMap) {
        if (!telegramMap.has(id)) {
            removedFiles.push(localFile);
        }
    }

    console.log(`[Worker] 📊 Sync result: ${newFiles.length} new, ${removedFiles.length} removed, ${changedFiles.length} changed`);

    // Step 5: Process new files - ACTIVE FETCH
    if (newFiles.length > 0) {
        console.log(`[Worker] 🎬 Actively fetching metadata for ${newFiles.length} new files...`);

        // Use the worker instance to process files (borrow logic from processMediaLibrary)
        // We'll process them sequentially to respect rate limits
        for (const file of newFiles) {
            const fileId = String(file.id || file.fileId);
            const fileName = file.fileName || file.name || '';

            // 1. Create stub first (safekeeping)
            const exists = await queueMetadataFetch(file);
            if (exists) continue;

            // 2. Active Fetch
            try {
                await activityTracker.waitIfBusy();

                // Determine type
                const cleanFn = fileName.replace(/\.[^/.]+$/, '').replace(/[._]/g, ' ');
                const tvMatch = cleanFn.match(/S(\d{1,2})[\s._-]*E(\d{1,2})/i);
                const isTv = !!tvMatch;

                let metadata = null;

                if (isTv) {
                    const title = cleanFn.split(/S\d/i)[0].trim().replace(/[\s._-]+$/, '');
                    const season = parseInt(tvMatch[1]);
                    const episode = parseInt(tvMatch[2]);

                    // We need to fetch show details first or check cache
                    // Simplified: just call fetchTVShowDetails then episode
                    const showMeta = await worker.tmdb.fetchTVShowDetails(title);
                    if (showMeta) {
                        const epDetails = await worker.tmdb.fetchEpisodeDetails(showMeta.showTmdbId, season, episode);
                        metadata = worker.tmdb.buildEpisodeSchema(fileId, fileName, showMeta, epDetails, season, episode);

                        // Download shared images
                        const images = await downloadShowImages(showMeta.showTmdbId, showMeta.posterPath, showMeta.backdropPath);
                        metadata.poster = images.poster;
                        metadata.backdrop = images.backdrop;
                    }
                } else {
                    const yearMatch = cleanFn.match(/(\d{4})/);
                    const year = yearMatch ? parseInt(yearMatch[1]) : null;
                    const title = yearMatch ? cleanFn.split(yearMatch[0])[0].trim() : cleanFn;

                    metadata = await worker.tmdb.fetchMovieComplete(fileId, fileName, title, year);

                    if (metadata) {
                        const images = await downloadMovieImages(fileId, metadata._posterPath, metadata._backdropPath);
                        metadata.poster = images.poster;
                        metadata.backdrop = images.backdrop;
                    }
                }

                if (metadata) {
                    // Detect tracks
                    try {
                        if (worker.telegramService) {
                            const doc = await worker.telegramService.getDocument(fileId);
                            if (doc) {
                                const codecInfo = await worker.telegramService.detectAudioCodec(fileId);
                                metadata.audioCodec = codecInfo.codec;
                                metadata.browserPlayable = codecInfo.browserPlayable;
                            }
                        }
                    } catch (e) { }

                    await saveMetadata(metadata);
                    console.log(`[Worker] ✅ Active fetch success: ${fileName}`);

                    if (metadata.type === 'tv' && metadata.tv?.showTmdbId) {
                        await updateTVCacheForShow(metadata.tv.showTmdbId);
                    }
                } else {
                    console.warn(`[Worker] ⚠️ Active fetch returned no results for ${fileName}`);
                }

            } catch (err) {
                console.error(`[Worker] ❌ Active fetch failed for ${fileName}:`, err.message);
                // Stub already exists, so retry worker will pick it up later
            }

            await sleep(1500); // Rate limit
        }

        // Rebuild TV caches if new files contained TV shows
        console.log('[Worker] 📺 Sweeping TV caches after sync...');
        await rebuildTVCaches();
    }

    // Step 6: Handle removed files
    for (const file of removedFiles) {
        console.log(`[Worker] 🗑️ Removed from Telegram: ${file.fileName || file.id}`);
    }

    // Remove deleted files from local cache
    if (removedFiles.length > 0) {
        const removedIds = new Set(removedFiles.map(f => String(f.id || f.fileId || f.messageId)));
        localCache = localCache.filter(f => !removedIds.has(String(f.id || f.fileId || f.messageId)));
    }

    // Step 7: Handle changed files (renamed)
    for (const change of changedFiles) {
        console.log(`[Worker] ✏️ Renamed: "${change.old.fileName}" → "${change.new.fileName}"`);

        // Update in local cache
        const idx = localCache.findIndex(f =>
            String(f.id || f.fileId) === String(change.old.id || change.old.fileId)
        );
        if (idx !== -1) {
            localCache[idx].fileName = change.new.fileName;
            localCache[idx].updatedAt = new Date().toISOString();
        }

        // Update metadata JSON if exists
        const fileId = String(change.old.id || change.old.fileId);
        const metaPath = path.join(DATA_DIR, `${fileId}.json`);
        try {
            const raw = await fs.readFile(metaPath, 'utf-8');
            const meta = JSON.parse(raw);
            meta.fileName = change.new.fileName;
            meta.needsRefetch = true; // Trigger refetch to update title/year
            await fs.writeFile(metaPath, JSON.stringify(meta, null, 2), 'utf-8');
        } catch { }
    }

    // Add new files to local cache
    if (newFiles.length > 0) {
        localCache.push(...newFiles);
    }

    // Step 8: Save updated local cache (always atomic write)
    try {
        await fs.writeFile(LIST_CACHE_PATH, JSON.stringify(localCache, null, 2), 'utf-8');
        console.log(`[Worker] 💾 Updated list_caches.json (${localCache.length} files)`);
    } catch (err) {
        console.error('[Worker] Failed to save list_caches.json:', err.message);
    }

    // Step 9: Invalidate cache (Batched)
    if (newFiles.length > 0 || removedFiles.length > 0 || changedFiles.length > 0) {
        requiresInvalidation = true;
    }

    if (requiresInvalidation) {
        try { require('../server').invalidateCache?.(); } catch { }
    }

    return {
        added: newFiles.length,
        removed: removedFiles.length,
        changed: changedFiles.length,
        totalLocal: localCache.length,
        totalTelegram: telegramFiles.length
    };
}

/**
 * Queue a new file for metadata fetching
 */
/**
 * Queue a new file for metadata fetching
 */
async function queueMetadataFetch(file) {
    const fileId = String(file.id || file.fileId);
    const fileName = file.fileName || file.name || '';

    // Check if metadata already exists
    const metaPath = path.join(DATA_DIR, `${fileId}.json`);
    try {
        const existingRaw = await fs.readFile(metaPath, 'utf-8');
        const existing = JSON.parse(existingRaw);
        // Only skip if it's a complete valid entry
        if (existing.fetchedAt && !existing.needsRetry) {
            console.log(`[Worker] ⏭️ Metadata already exists for ${fileId}`);
            return true;
        }
    } catch { }

    // Parse filename to determine type and basic info
    // This ensures the retry worker knows how to categorize it
    const cleanFn = fileName.replace(/\.[^/.]+$/, '').replace(/[._]/g, ' ');
    const tvMatch = cleanFn.match(/S(\d{1,2})[\s._-]*E(\d{1,2})/i);

    const isTv = !!tvMatch;
    const type = isTv ? 'tv' : 'movie';
    let title = cleanFn;
    let year = null;

    // Simple naive parser for stub creation (retry worker has better logic, but this helps routing)
    if (isTv) {
        title = cleanFn.split(/S\d/i)[0].trim().replace(/[\s._-]+$/, '');
    } else {
        const yearMatch = cleanFn.match(/(\d{4})/);
        if (yearMatch) {
            year = parseInt(yearMatch[1]);
            title = cleanFn.split(yearMatch[0])[0].trim().replace(/[\s._-]+$/, '');
        }
    }

    // Create metadata stub with TYPE info
    const stub = {
        fileId: fileId,
        fileName: fileName,
        type: type,
        title: title, // improved stub title
        year: year,
        tmdbId: 0,
        needsRetry: true,
        createdAt: new Date().toISOString(),
        // Initialize _retry state so shouldRetry() accepts it immediately
        _retry: {
            attemptCount: 0,
            lastAttempt: 0,
            searchedTitle: title,
            searchedYear: year
        }
    };

    if (isTv) {
        stub.tv = {
            seasonNumber: parseInt(tvMatch[1]),
            episodeNumber: parseInt(tvMatch[2]),
            showTitle: title
        };
    }

    await fs.writeFile(metaPath, JSON.stringify(stub, null, 2), 'utf-8');
    console.log(`[Worker] 📝 Created metadata stub for: ${fileName} (Type: ${type})`);
    return false;
}

const worker = new MetadataWorker();
worker.syncWithTelegram = syncWithTelegram; // Bind to worker instance

// ==================== FILE WATCHER ====================
// Watches data/metadata/ for changes — detects manual edits (needsRefetch flag)

const refetchQueue = new Set();
let fileWatcher = null;
const fileChangeTimers = new Map();

function startFileWatcher() {
    if (fileWatcher) return;

    try {
        fsSync.mkdirSync(DATA_DIR, { recursive: true });

        fileWatcher = fsSync.watch(DATA_DIR, (eventType, filename) => {
            if (!filename || !filename.endsWith('.json')) return;
            if (eventType !== 'change') return;

            // Debounce — editors trigger multiple saves
            if (fileChangeTimers.has(filename)) {
                clearTimeout(fileChangeTimers.get(filename));
            }

            fileChangeTimers.set(filename, setTimeout(async () => {
                fileChangeTimers.delete(filename);
                await handleFileChange(filename);
            }, 2000));
        });

        fileWatcher.on('error', (err) => {
            console.error('[Worker] File watcher error:', err.message);
        });

        console.log('[Worker] 👀 Watching metadata directory for changes');
    } catch (err) {
        console.error('[Worker] Failed to start file watcher:', err.message);
    }
}

function stopFileWatcher() {
    if (fileWatcher) {
        fileWatcher.close();
        fileWatcher = null;
        // Clear pending timers
        for (const timer of fileChangeTimers.values()) {
            clearTimeout(timer);
        }
        fileChangeTimers.clear();
        console.log('[Worker] 👀 File watcher stopped');
    }
}

async function handleFileChange(filename) {
    try {
        const filePath = path.join(DATA_DIR, filename);
        const raw = await fs.readFile(filePath, 'utf-8');
        const data = JSON.parse(raw);

        if (!data.fileId) return;

        // Check: Explicit refetch flag
        if (data.needsRefetch === true) {
            console.log(`[Worker] 📝 Manual refetch requested: ${data.fileId} (${data.title || filename})`);
            refetchQueue.add(data.fileId);
            return;
        }

        // Check: tmdbId exists and _manualTmdbId flag set
        if (data.tmdbId && data._manualTmdbId) {
            console.log(`[Worker] 📝 TMDB ID manually set: ${data.fileId} → tmdbId: ${data.tmdbId}`);
            refetchQueue.add(data.fileId);
            return;
        }

        // Just a normal update — validate cache
        try { require('../server').invalidateCache?.(); } catch { }

    } catch (err) {
        // File might be mid-write, ignore parse errors
        if (err.code !== 'ENOENT' && err.name !== 'SyntaxError') {
            console.warn(`[Worker] Could not read changed file ${filename}:`, err.message);
        }
    }
}

// ==================== REFETCH QUEUE PROCESSOR ====================

async function processRefetchQueue() {
    if (refetchQueue.size === 0) return 0;

    const items = [...refetchQueue];
    console.log(`[Worker] 📦 Processing ${items.length} refetch items...`);
    let processed = 0;

    for (const fileId of items) {
        try {
            await activityTracker.waitIfBusy();

            console.log(`[Worker] 🔄 Re-fetching metadata for: ${fileId}`);
            await worker.refetchMetadata(fileId);
            refetchQueue.delete(fileId);
            processed++;

            console.log(`[Worker] ✅ Successfully re-fetched: ${fileId}`);
            await sleep(1000); // Rate limit TMDB API
        } catch (err) {
            console.error(`[Worker] ❌ Refetch failed for ${fileId}:`, err.message);
            refetchQueue.delete(fileId); // Remove to prevent infinite retry
        }
    }

    return processed;
}

// ==================== IDLE LOOP ====================
// Continuous background loop — replaces setInterval approach

let idleLoopRunning = false;
let lastIdleCheck = null;

let lastTelegramSync = 0;
// FIXED: Increased interval to 7 mins Telegram Sync 
const TELEGRAM_SYNC_INTERVAL = 7 * 60 * 1000;

function setLastSyncTime(time) {
    lastTelegramSync = time;
}



// Rewriting startIdleLoop to include sync
async function startIdleLoop() {
    if (idleLoopRunning) return;
    idleLoopRunning = true;
    console.log('[Worker] 🔄 Idle loop started');

    while (idleLoopRunning) {
        let didWork = false;
        lastIdleCheck = new Date().toISOString();

        try {
            await activityTracker.waitIfBusy();
            if (!idleLoopRunning) break;

            // 0. Periodic Telegram Sync
            const now = Date.now();
            if (now - lastTelegramSync > TELEGRAM_SYNC_INTERVAL) {
                lastTelegramSync = now;
                console.log('[Worker] 📡 Periodic Telegram sync...');
                try {
                    const result = await syncWithTelegram();
                    if (result.added > 0) didWork = true;
                } catch (err) {
                    console.warn('[Worker] Telegram sync failed:', err.message);
                }
            }

            // 0.5 Check for incomplete metadata (tmdbId: 0)
            if (!activityTracker.isPaused()) {
                const incomplete = await findIncompleteMetadata();
                if (incomplete.length > 0) {
                    console.log(`[Worker] 🔍 Found ${incomplete.length} files with incomplete metadata`);
                    let repaired = 0;

                    for (const item of incomplete) {
                        if (activityTracker.isPaused()) break;

                        try {
                            console.log(`[Worker] 🔄 Attempting repair for: ${item.fileName}`);
                            await queueMetadataFetch({ id: item.fileId, fileName: item.fileName });

                            // We can reuse the active fetch logic or just trigger refetchMetadata if we had more info
                            // But queueMetadataFetch creates a stub that retryFailedLookups will pick up
                            // Actually, let's try to fix it right now similar to active fetch

                            const cleanFn = item.fileName.replace(/\.[^/.]+$/, '').replace(/[._]/g, ' ');
                            const tvMatch = cleanFn.match(/S(\d{1,2})[\s._-]*E(\d{1,2})/i);
                            const isTv = !!tvMatch;
                            let metadata = null;

                            if (isTv) {
                                let title = cleanFn.split(/S\d/i)[0].trim().replace(/[\s._-]+$/, '');
                                const showMeta = await worker.tmdb.fetchTVShowDetails(title);
                                if (showMeta) {
                                    const season = parseInt(tvMatch[1]);
                                    const episode = parseInt(tvMatch[2]);
                                    const epDetails = await worker.tmdb.fetchEpisodeDetails(showMeta.showTmdbId, season, episode);
                                    metadata = worker.tmdb.buildEpisodeSchema(item.fileId, item.fileName, showMeta, epDetails, season, episode);

                                    const images = await downloadShowImages(showMeta.showTmdbId, showMeta.posterPath, showMeta.backdropPath);
                                    metadata.poster = images.poster;
                                    metadata.backdrop = images.backdrop;
                                }
                            } else {
                                const yearMatch = cleanFn.match(/(\d{4})/);
                                const year = yearMatch ? parseInt(yearMatch[1]) : null;
                                const title = yearMatch ? cleanFn.split(yearMatch[0])[0].trim() : cleanFn;
                                metadata = await worker.tmdb.fetchMovieComplete(item.fileId, item.fileName, title, year);
                                if (metadata) {
                                    const images = await downloadMovieImages(item.fileId, metadata._posterPath, metadata._backdropPath);
                                    metadata.poster = images.poster;
                                    metadata.backdrop = images.backdrop;
                                }
                            }

                            if (metadata) {
                                await saveMetadata(metadata);
                                console.log(`[Worker] ✅ Repaired: ${item.fileName}`);
                                repaired++;
                                if (metadata.type === 'tv' && metadata.tv?.showTmdbId) {
                                    await updateTVCacheForShow(metadata.tv.showTmdbId);
                                }
                            }
                        } catch (e) {
                            console.warn(`[Worker] Repair failed for ${item.fileName}: ${e.message}`);
                        }
                        await sleep(2000);
                    }
                    if (repaired > 0) didWork = true;
                }
            }

            // 1. Process refetch queue (manual fixes first — highest priority)
            if (refetchQueue.size > 0) {
                const count = await processRefetchQueue();
                if (count > 0) didWork = true;
            }

            // 2. Retry failed metadata lookups
            if (!activityTracker.isPaused()) {
                const all = await getAllMetadata();
                const retriable = all.filter(e => e.needsRetry && shouldRetry(e));
                if (retriable.length > 0) {
                    console.log(`[Worker] 🔁 Idle loop: ${retriable.length} failed lookups to retry`);
                    await worker.retryFailedLookups();
                    didWork = true;
                }
            }

            // 3. Periodic TV Cache Sweep (every ~10 runs or if active work done)
            // Just running it occasionally to be safe
            if (didWork) {
                await rebuildTVCaches();
            }

            // 4. Retry failed image downloads
            if (!activityTracker.isPaused()) {
                const all = await getAllMetadata();
                const needsImages = all.filter(e =>
                    !e.needsRetry && e.fetchedAt && e.tmdbId > 0 &&
                    (!e.poster || !e.backdrop)
                );
                if (needsImages.length > 0) {
                    console.log(`[Worker] 🖼️ Idle loop: ${needsImages.length} missing images to retry`);
                    await worker.retryFailedImageDownloads();
                    didWork = true;
                }
            }

        } catch (err) {
            console.error('[Worker] Idle loop error:', err.message);
        }

        if (!idleLoopRunning) break;

        // Adaptive sleep
        const delay = didWork ? 15000 : 60000;
        await sleep(delay);
    }

    console.log('[Worker] ⏹️ Idle loop stopped');
}

function stopIdleLoop() {
    idleLoopRunning = false;
}

function getIdleLoopStatus() {
    return {
        idleLoopRunning,
        lastIdleCheck,
        refetchQueueSize: refetchQueue.size,
        fileWatcherActive: !!fileWatcher,
        lastTelegramSync: new Date(lastTelegramSync).toISOString()
    };
}

// ==================== TV CACHE MANAGEMENT ====================

/**
 * Scan ALL metadata JSONs and rebuild/update TV cache files
 * A TV cache file is created per show (named by showTmdbId)
 */
async function rebuildTVCaches() {
    console.log('[Worker] 📺 Rebuilding TV caches...');

    // Ensure directory exists
    await fs.mkdir(TV_CACHE_DIR, { recursive: true });

    // Step 1: Read ALL metadata JSONs
    let files = [];
    try {
        files = await fs.readdir(DATA_DIR);
    } catch {
        // Directory might not exist yet
        return { totalShows: 0, created: 0, updated: 0 };
    }

    const tvShowsMap = new Map(); // showTmdbId → show data

    for (const file of files) {
        if (!file.endsWith('.json')) continue;

        try {
            const raw = await fs.readFile(path.join(DATA_DIR, file), 'utf-8');
            const data = JSON.parse(raw);

            // Skip incomplete entries
            if (!data.fileId) continue;
            if (!data.fetchedAt) continue;
            if (!data.tmdbId || data.tmdbId === 0) continue;

            // ✅ Detect TV by checking tv.showTmdbId
            if (!data.tv || !data.tv.showTmdbId) continue;

            const showId = data.tv.showTmdbId;

            if (!tvShowsMap.has(showId)) {
                tvShowsMap.set(showId, {
                    showTmdbId: showId,
                    showTitle: data.tv.showTitle || data.title || 'Unknown Show',
                    originalShowTitle: data.tv.originalShowTitle || data.originalTitle || '',
                    overview: data.overview || '',
                    genres: data.genres || [],
                    rating: data.rating || 0,
                    popularity: data.popularity || 0,
                    poster: data.poster || null,
                    backdrop: data.backdrop || null,
                    totalSeasons: data.tv.totalSeasons || 0,
                    totalEpisodes: data.tv.totalEpisodes || 0,
                    year: data.year || null,
                    releaseDate: data.releaseDate || null,
                    seasons: {},
                    episodes: []
                });
            }

            const show = tvShowsMap.get(showId);

            // Update show-level data with best available (some eps might have better data)
            if (!show.poster && data.poster) show.poster = data.poster;
            if (!show.backdrop && data.backdrop) show.backdrop = data.backdrop;
            if (data.rating > show.rating) show.rating = data.rating;
            if (!show.overview && data.overview) show.overview = data.overview;
            if (!show.year && data.year) show.year = data.year;
            if (data.genres?.length > (show.genres?.length || 0)) show.genres = data.genres;

            // Add episode
            const seasonNum = data.tv.seasonNumber || 1;
            const episodeNum = data.tv.episodeNumber || 1;

            if (!show.seasons[seasonNum]) show.seasons[seasonNum] = [];

            // Check if episode already exists in this season
            const existingEpIdx = show.seasons[seasonNum].findIndex(
                ep => ep.episodeNumber === episodeNum
            );

            const episodeData = {
                fileId: data.fileId,
                fileName: data.fileName,
                seasonNumber: seasonNum,
                episodeNumber: episodeNum,
                episodeTitle: data.tv.episodeTitle || `Episode ${episodeNum}`,
                episodeOverview: data.tv.episodeOverview || '',
                runtime: data.runtime || data.tv.episodeRuntime || 0,
                tracks: data.tracks || null
            };

            if (existingEpIdx >= 0) {
                show.seasons[seasonNum][existingEpIdx] = episodeData;
            } else {
                show.seasons[seasonNum].push(episodeData);
            }

        } catch { continue; }
    }

    // Step 2: Sort episodes and calculate stats
    for (const [showId, show] of tvShowsMap) {
        // Sort episodes within each season
        for (const seasonNum of Object.keys(show.seasons)) {
            show.seasons[seasonNum].sort((a, b) => a.episodeNumber - b.episodeNumber);
        }

        // Calculate stats
        show.availableSeasons = Object.keys(show.seasons).map(Number).sort((a, b) => a - b);
        show.availableEpisodeCount = Object.values(show.seasons)
            .reduce((total, episodes) => total + episodes.length, 0);
    }

    // Step 3: Get existing TV cache files to compare
    let existingCacheFiles = [];
    try {
        existingCacheFiles = await fs.readdir(TV_CACHE_DIR);
    } catch { }

    const existingShowIds = new Set(
        existingCacheFiles
            .filter(f => f.endsWith('.json'))
            .map(f => f.replace('.json', ''))
    );

    // Step 4: Write/update TV cache files
    let created = 0;
    let updated = 0;

    for (const [showId, show] of tvShowsMap) {
        const cacheFile = path.join(TV_CACHE_DIR, `${showId}.json`);

        try {
            // Check if cache needs updating to avoid redundant writes
            let needsWrite = true;

            if (existingShowIds.has(String(showId))) {
                try {
                    const raw = await fs.readFile(cacheFile, 'utf-8');
                    const existing = JSON.parse(raw);

                    // Simple check: Compare episode counts
                    // (Deep comparison is too expensive, reliable enough for now)
                    if (existing.availableEpisodeCount === show.availableEpisodeCount &&
                        existing.poster === show.poster) {
                        needsWrite = false;
                    }
                } catch { }
            }

            if (needsWrite) {
                await fs.writeFile(cacheFile, JSON.stringify(show, null, 2), 'utf-8');

                if (existingShowIds.has(String(showId))) {
                    updated++;
                    // console.log(`[TVCache] 📝 Updated: ${show.showTitle}`);
                } else {
                    created++;
                    console.log(`[TVCache] ✨ Created: ${show.showTitle} (${show.availableEpisodeCount} eps)`);
                }
            }
        } catch (err) {
            console.error(`[TVCache] Failed to write ${showId}: ${err.message}`);
        }
    }

    // Step 5: Remove orphaned TV cache files (shows no longer in metadata)
    const currentShowIds = new Set([...tvShowsMap.keys()].map(String));
    for (const existingId of existingShowIds) {
        if (!currentShowIds.has(existingId)) {
            try {
                await fs.unlink(path.join(TV_CACHE_DIR, `${existingId}.json`));
                console.log(`[TVCache] 🗑️ Removed orphaned cache: ${existingId}`);
            } catch { }
        }
    }

    console.log(`[TVCache] ✅ Done: ${created} created, ${updated} updated, ${tvShowsMap.size} total shows`);

    return {
        totalShows: tvShowsMap.size,
        created,
        updated
    };
}

/**
 * Update TV cache for a SINGLE show (faster than full rebuild)
 * Called after a single episode's metadata is fetched/updated
 */
async function updateTVCacheForShow(showTmdbId) {
    if (!showTmdbId) return;

    // console.log(`[TVCache] Updating cache for show ${showTmdbId}...`);

    await fs.mkdir(TV_CACHE_DIR, { recursive: true });

    // Find all episodes for this show
    const files = await fs.readdir(DATA_DIR);
    const episodes = [];
    let showInfo = null;

    for (const file of files) {
        if (!file.endsWith('.json')) continue;
        try {
            const raw = await fs.readFile(path.join(DATA_DIR, file), 'utf-8');
            const data = JSON.parse(raw);

            if (!data.tv || data.tv.showTmdbId !== showTmdbId) continue;
            if (!data.fetchedAt || !data.tmdbId || data.tmdbId === 0) continue;

            episodes.push(data);

            // Capture show info from the first valid episode we find
            // (We assume all episodes have consistent show-level data)
            if (!showInfo) {
                showInfo = {
                    showTmdbId: showTmdbId,
                    showTitle: data.tv.showTitle || data.title,
                    overview: data.overview, // Usually episode overview, but better than nothing
                    genres: data.genres,
                    rating: data.rating,
                    poster: data.poster,
                    backdrop: data.backdrop,
                    year: data.year,
                    totalSeasons: data.tv.totalSeasons,
                    totalEpisodes: data.tv.totalEpisodes
                };
            } else {
                // Try to improve show info if missing
                if (!showInfo.poster && data.poster) showInfo.poster = data.poster;
                if (!showInfo.backdrop && data.backdrop) showInfo.backdrop = data.backdrop;
            }
        } catch { continue; }
    }

    if (episodes.length === 0 || !showInfo) {
        // console.log(`[TVCache] No valid episodes found for show ${showTmdbId}`);
        return;
    }

    // Build seasons object
    const seasons = {};
    for (const ep of episodes) {
        const sNum = ep.tv.seasonNumber || 1;
        if (!seasons[sNum]) seasons[sNum] = [];
        seasons[sNum].push({
            fileId: ep.fileId,
            fileName: ep.fileName,
            seasonNumber: sNum,
            episodeNumber: ep.tv.episodeNumber || 1,
            episodeTitle: ep.tv.episodeTitle || '',
            episodeOverview: ep.tv.episodeOverview || '',
            runtime: ep.runtime || ep.tv.episodeRuntime || 0
        });
    }

    // Sort
    for (const sNum of Object.keys(seasons)) {
        seasons[sNum].sort((a, b) => a.episodeNumber - b.episodeNumber);
    }

    const cacheData = {
        ...showInfo,
        seasons,
        availableSeasons: Object.keys(seasons).map(Number).sort((a, b) => a - b),
        availableEpisodeCount: episodes.length
    };

    const cacheFile = path.join(TV_CACHE_DIR, `${showTmdbId}.json`);
    await fs.writeFile(cacheFile, JSON.stringify(cacheData, null, 2), 'utf-8');

    // console.log(`[TVCache] ✅ Updated: ${showInfo.showTitle} (${episodes.length} eps)`);
}

// Check for files with tmdbId: 0 or missing tmdbId
async function findIncompleteMetadata() {
    let files = [];
    try {
        files = await fs.readdir(DATA_DIR);
    } catch { return []; }

    const incomplete = [];

    for (const file of files) {
        if (!file.endsWith('.json')) continue;
        try {
            const raw = await fs.readFile(path.join(DATA_DIR, file), 'utf-8');
            const data = JSON.parse(raw);

            if (!data.fileId) continue;

            // Check for incomplete metadata
            const isIncomplete =
                (!data.tmdbId || data.tmdbId === 0) ||
                (!data.fetchedAt) ||
                (!data.title || data.title === '') ||
                (data.needsRetry === true);

            // Skip if too many retries (unless we want to force check)
            if ((data._retryCount || 0) >= 10 && !data.needsRefetch) continue;

            if (isIncomplete) {
                incomplete.push({
                    fileId: data.fileId,
                    fileName: data.fileName || file.replace('.json', ''),
                    tmdbId: data.tmdbId || 0,
                    retryCount: data._retryCount || 0,
                    lastError: data._lastError || null
                });
            }
        } catch { continue; }
    }

    return incomplete;
}

module.exports = {
    worker,
    saveMetadata,
    loadMetadata,
    getAllMetadata,
    startFileWatcher,
    stopFileWatcher,
    startIdleLoop,
    stopIdleLoop,
    getIdleLoopStatus,
    refetchQueue,
    syncWithTelegram,
    setLastSyncTime,
    rebuildTVCaches,
    updateTVCacheForShow,
    findIncompleteMetadata
};
