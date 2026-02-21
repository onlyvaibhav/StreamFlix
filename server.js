require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const os = require('os');

const streamRoutes = require('./routes/streamRoutes');
const internalRoutes = require('./routes/internal');
const movieRoutes = require('./routes/movieRoutes');
const authRoutes = require('./routes/authRoutes');
const subtitleRoutes = require('./routes/subtitleRoutes');
const debugRoutes = require('./routes/debugRoutes');
const homeRoutes = require('./routes/homeRoutes');
const tvRoutes = require('./routes/tvRoutes');
const adminRoutes = require('./routes/adminRoutes');
const activityTracker = require('./services/activityTracker');
const { initTelegram, telegramService } = require('./services/telegramService');
const {
  worker,
  startFileWatcher,
  startIdleLoop,
  getIdleLoopStatus,
  rebuildTVCaches,
  findIncompleteMetadata
} = require('./services/metadataWorker');

const telegramServiceModule = require('./services/telegramService');
worker.setTelegramService(telegramServiceModule);

// ============================================================
// PROCESS ERROR HANDLING — Prevent crashes from Telegram errors
// ============================================================
process.on('unhandledRejection', (reason, promise) => {
  const message = reason?.message || String(reason);

  const telegramErrors = [
    'TIMEOUT',
    'Not connected',
    'Connection closed',
    'connection closed',
    'CONNECTION_NOT_INITED',
    'FLOOD_WAIT',
    'AUTH_KEY_UNREGISTERED',
    'SESSION_REVOKED',
    'Disconnect',
  ];

  const isTelegramError = telegramErrors.some(e => message.includes(e));

  if (isTelegramError) {
    console.warn(`[Telegram] Recoverable error: ${message}`);
    return;
  }

  console.error('⚠️ Unhandled Rejection:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('[UncaughtException]', error.message);

  if (
    error.message.includes('TIMEOUT') ||
    error.message.includes('Not connected') ||
    error.message.includes('Connection closed')
  ) {
    console.warn('[Telegram] Auto-recovering from crash...');
    return;
  }

  console.error('[UncaughtException] Stack:', error.stack);
});

// ============================================================
// EXPRESS APP SETUP
// ============================================================
const app = express();
const PORT = process.env.PORT || 5000;
app.set('internalPort', PORT);

// Fix rate limiter X-Forwarded-For warning
app.set('trust proxy', 1);

// ============================================================
// MIDDLEWARE
// ============================================================
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" },
  contentSecurityPolicy: false
}));

// CORS — Allow localhost + any LAN IP (for network access)
app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (mobile apps, curl, same-origin)
    if (!origin) return callback(null, true);

    // Allow localhost, 127.0.0.1, and any private/LAN IP
    const allowed =
      origin.includes('localhost') ||
      origin.includes('127.0.0.1') ||
      origin.match(/^http:\/\/192\.168\.\d+\.\d+/) ||
      origin.match(/^http:\/\/10\.\d+\.\d+\.\d+/) ||
      origin.match(/^http:\/\/172\.(1[6-9]|2\d|3[01])\.\d+\.\d+/);

    callback(null, allowed ? true : false);
  },
  credentials: true
}));

app.use(morgan('dev'));
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true, limit: '5mb' }));

// ============================================================
// STATIC DATA FILES
// ============================================================
console.log('Static Data Path:', path.join(__dirname, 'data'));

app.use('/data', (req, res, next) => {
  console.log('Serving Static:', req.path);
  next();
}, express.static(path.join(__dirname, 'data')));

app.use('/api/proxy', express.static(path.join(__dirname, 'data')));

// Serve local images ONLY — no proxy to TMDB or anywhere else
app.use('/data/posters', express.static(path.join(__dirname, 'data/posters'), {
  fallthrough: false,
  maxAge: '7d'
}));

app.use('/data/backdrops', express.static(path.join(__dirname, 'data/backdrops'), {
  fallthrough: false,
  maxAge: '7d'
}));

// ============================================================
// API ROUTES
// ============================================================
app.use('/api/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/movies', movieRoutes);
app.use('/api/stream', streamRoutes);
app.use('/api/subtitles', subtitleRoutes);
app.use('/api/debug', debugRoutes);
app.use('/api/home', homeRoutes);
app.use('/api/tv', tvRoutes);
app.use('/internal', internalRoutes);

// ============================================================
// ADMIN WORKER ROUTES
// ============================================================

app.get('/api/admin/worker-status', (req, res) => {
  const status = activityTracker.getStatus();
  const loopStatus = getIdleLoopStatus();
  res.json({ ...status, ...loopStatus });
});

app.post('/api/admin/worker/pause', (req, res) => {
  const success = activityTracker.forcePause();
  res.json({ success, status: activityTracker.getStatus() });
});

app.post('/api/admin/worker/resume', (req, res) => {
  const success = activityTracker.forceResume();
  res.json({ success, status: activityTracker.getStatus() });
});

// ============================================================
// METADATA HELPERS
// ============================================================
const fs = require('fs').promises;
const DATA_DIR = path.join(__dirname, 'data/metadata');

// TV detection helpers — use tv.showTmdbId as primary indicator
function isTVContent(item) {
  if (item.tv && item.tv.showTmdbId) return true;
  if (item.type && item.type.toLowerCase() === 'tv') return true;
  return false;
}

function isMovieContent(item) {
  if (isTVContent(item)) return false;
  if (!item.fileId || !item.title) return false;
  return true;
}

// ==================== CACHE MANAGEMENT ====================
let _metadataCache = null;
let _metadataCacheTime = 0;
const METADATA_CACHE_TTL = 1000 * 60 * 60; // 1 hour


// Debounce invalidation logs
let _cacheInvalidateTimer = null;
let _cacheInvalidateCount = 0;

function invalidateCache() {
  _metadataCache = null;
  _metadataCacheTime = 0;
  _cacheInvalidateCount++;

  if (_cacheInvalidateTimer) clearTimeout(_cacheInvalidateTimer);

  _cacheInvalidateTimer = setTimeout(() => {
    console.log(`🗑️ [Server] Metadata cache invalidated (${_cacheInvalidateCount} changes)`);

    // Invalidate Telegram service cache too (Debounced)
    if (worker.worker && worker.worker.telegramService && worker.worker.telegramService.invalidateCache) {
      worker.worker.telegramService.invalidateCache();
    }

    _cacheInvalidateCount = 0;
    _cacheInvalidateTimer = null;
  }, 1000);
}

async function loadAllValidMetadata() {
  // Check cache
  if (_metadataCache && (Date.now() - _metadataCacheTime < METADATA_CACHE_TTL)) {
    return _metadataCache;
  }

  const results = [];
  try {
    await fs.mkdir(DATA_DIR, { recursive: true });
    const files = await fs.readdir(DATA_DIR);

    for (const file of files) {
      if (!file.endsWith('.json')) continue;
      try {
        const raw = await fs.readFile(path.join(DATA_DIR, file), 'utf-8');
        const parsed = JSON.parse(raw);

        // CRITICAL FILTER: Only include items that have real metadata
        if (!parsed.fileId) continue;
        if (parsed.needsRetry === true) continue;
        if (!parsed.fetchedAt) continue;
        if (!parsed.title || parsed.title.trim() === '') continue;
        if (!parsed.tmdbId || parsed.tmdbId === 0) continue;

        // Verify image paths exist on disk
        if (parsed.poster) {
          try {
            await fs.access(path.join(__dirname, parsed.poster.startsWith('/') ? parsed.poster.slice(1) : parsed.poster));
          } catch {
            parsed.poster = null;
          }
        }
        if (parsed.backdrop) {
          try {
            await fs.access(path.join(__dirname, parsed.backdrop.startsWith('/') ? parsed.backdrop.slice(1) : parsed.backdrop));
          } catch {
            parsed.backdrop = null;
          }
        }

        // Auto-fix: has tv.showTmdbId but type is not 'tv'
        if (parsed.tv && parsed.tv.showTmdbId && parsed.type !== 'tv') {
          console.log(`[Metadata] Auto-fixing type for ${parsed.fileId}: "${parsed.type}" → "tv" (has tv.showTmdbId: ${parsed.tv.showTmdbId})`);
          parsed.type = 'tv';
          try {
            await fs.writeFile(path.join(DATA_DIR, file), JSON.stringify(parsed, null, 2), 'utf-8');
          } catch (writeErr) {
            console.warn(`[Metadata] Could not save type fix for ${file}`);
          }
        }

        // Auto-fix: type is 'tv' but no tv object
        if (parsed.type === 'tv' && (!parsed.tv || !parsed.tv.showTmdbId)) {
          console.log(`[Metadata] Auto-fixing type for ${parsed.fileId}: "tv" → "movie" (no tv data)`);
          parsed.type = 'movie';
        }

        // Strip internal fields
        delete parsed._retry;
        delete parsed._posterPath;
        delete parsed._backdropPath;

        results.push(parsed);
      } catch { continue; }
    }
  } catch (err) {
    console.error('Failed to read metadata directory:', err);
  }

  // Update cache
  _metadataCache = results;
  _metadataCacheTime = Date.now();
  console.log(`[Server] 💾 Metadata loaded & cached (${results.length} items)`);

  return results;
}

// ============================================================
// MULTI-PART MOVIE DETECTION & GROUPING
// ============================================================

/**
 * Detect if a filename indicates a multi-part upload
 * Returns { baseName, partNumber } or null
 */
function detectSplitFile(fileName) {
  if (!fileName) return null;

  // Remove extension
  const name = fileName.replace(/\.[^/.]+$/, '');

  // Patterns to match (case insensitive):
  // "Movie Name Part 1" / "Movie Name Part 2"
  // "Movie.Name.Part.1" / "Movie.Name.Part.2"
  // "Movie Name part1" / "Movie Name part2"
  // "Movie Name - Part 1 of 3"
  // "Movie_Name_pt1" / "Movie_Name_pt2"
  // "Movie Name CD1" / "Movie Name CD2"
  // "Movie Name Disc 1" / "Movie Name Disc 2"
  // "Movie Name 1of2" / "Movie Name 2of2"
  // "Movie Name-001" / "Movie Name-002"
  const patterns = [
    /^(.+?)[\s._-]*(?:part|pt)[\s._-]*(\d+)(?:\s*(?:of|\/)\s*\d+)?$/i,
    /^(.+?)[\s._-]*(?:cd|disc|disk)[\s._-]*(\d+)$/i,
    /^(.+?)[\s._-]+(\d+)\s*of\s*\d+$/i,
    /^(.+?)[\s._-]+(\d{3})$/i, // Matches -001, -002
  ];

  for (const pattern of patterns) {
    const match = name.match(pattern);
    if (match) {
      return {
        baseName: match[1].trim().replace(/[\s._-]+$/, ''),
        partNumber: parseInt(match[2])
      };
    }
  }

  return null;
}

/**
 * Group multi-part movies into single entries.
 * Uses TWO strategies:
 *   1. Same tmdbId → definitely the same movie (most reliable)
 *   2. Filename pattern detection → "Part 1", "Part 2" etc.
 * 
 * Input: flat array of movie metadata objects
 * Output: array where split movies are merged into one entry with a `parts` array
 */
function groupSplitMovies(movies) {
  // Strategy 1: Group by tmdbId (most reliable — same TMDB ID = same movie)
  const tmdbGroups = new Map();   // tmdbId → array of movies
  const noTmdbId = [];            // Movies without tmdbId

  for (const movie of movies) {
    if (movie.tmdbId && movie.tmdbId !== 0) {
      if (!tmdbGroups.has(movie.tmdbId)) tmdbGroups.set(movie.tmdbId, []);
      tmdbGroups.get(movie.tmdbId).push(movie);
    } else {
      noTmdbId.push(movie);
    }
  }

  const result = [];

  // Process tmdbId groups
  for (const [tmdbId, group] of tmdbGroups) {
    if (group.length === 1) {
      // Single file — not split
      result.push(group[0]);
    } else {
      // Multiple files with same tmdbId — these are parts of the same movie
      // Sort by filename to determine part order
      const sorted = group.sort((a, b) => {
        // Try to extract part numbers from filename
        const partA = detectSplitFile(a.fileName);
        const partB = detectSplitFile(b.fileName);

        if (partA && partB) return partA.partNumber - partB.partNumber;

        // Fallback: sort by fileName alphabetically
        return (a.fileName || '').localeCompare(b.fileName || '');
      });

      // Use the first part's metadata as the base
      const primary = { ...sorted[0] };
      primary.isSplit = true;
      primary.totalParts = sorted.length;
      primary.parts = sorted.map((m, i) => ({
        fileId: m.fileId,
        fileName: m.fileName,
        partNumber: i + 1
      }));

      // Use Part 1's fileId as the primary fileId
      primary.fileId = sorted[0].fileId;

      result.push(primary);
    }
  }

  // Strategy 2: For movies without tmdbId, try filename pattern matching
  const filenameGroups = new Map();
  const singles = [];

  for (const movie of noTmdbId) {
    const partInfo = detectSplitFile(movie.fileName);
    if (partInfo) {
      const key = partInfo.baseName.toLowerCase().replace(/[^a-z0-9]/g, '');
      if (!filenameGroups.has(key)) filenameGroups.set(key, []);
      filenameGroups.get(key).push({ movie, partNumber: partInfo.partNumber });
    } else {
      singles.push(movie);
    }
  }

  for (const [, group] of filenameGroups) {
    if (group.length === 1) {
      // Only one part found — treat as single
      result.push(group[0].movie);
    } else {
      const sorted = group.sort((a, b) => a.partNumber - b.partNumber);
      const primary = { ...sorted[0].movie };
      primary.isSplit = true;
      primary.totalParts = sorted.length;
      primary.parts = sorted.map(g => ({
        fileId: g.movie.fileId,
        fileName: g.movie.fileName,
        partNumber: g.partNumber
      }));
      primary.fileId = sorted[0].movie.fileId;
      result.push(primary);
    }
  }

  // Add remaining singles
  result.push(...singles);

  return result;
}

// GET /api/debug/split-movies - Debug split movie grouping
app.get('/api/debug/split-movies', async (req, res) => {
  try {
    const allMetadata = await loadAllValidMetadata();
    const rawMovies = allMetadata.filter(isMovieContent);
    const groupedMovies = groupSplitMovies(rawMovies);

    // Find duplicates in raw data
    const tmdbCounts = new Map();
    for (const m of rawMovies) {
      if (m.tmdbId) tmdbCounts.set(m.tmdbId, (tmdbCounts.get(m.tmdbId) || 0) + 1);
    }
    const rawDuplicates = Array.from(tmdbCounts.entries())
      .filter(([k, v]) => v > 1)
      .map(([tmdbId, count]) => ({
        tmdbId,
        count,
        titles: rawMovies.filter(m => m.tmdbId === tmdbId).map(m => m.title)
      }));

    res.json({
      rawCount: rawMovies.length,
      groupedCount: groupedMovies.length,
      mergedCount: rawMovies.length - groupedMovies.length,
      rawDuplicates,
      sampleGrouped: groupedMovies.filter(m => m.isSplit).slice(0, 5)
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/metadata — Everything the frontend needs
app.get('/api/metadata', async (req, res) => {
  try {
    const allMetadata = await loadAllValidMetadata();
    const rawMovies = allMetadata.filter(isMovieContent);
    const movies = groupSplitMovies(rawMovies);

    // Group TV episodes by show
    const tvShowsMap = new Map();
    for (const item of allMetadata.filter(isTVContent)) {
      if (!item.tv || !item.tv.showTmdbId) continue;
      const showId = item.tv.showTmdbId;

      if (!tvShowsMap.has(showId)) {
        tvShowsMap.set(showId, {
          showTmdbId: showId,
          showTitle: item.tv.showTitle || item.title,
          originalShowTitle: item.tv.originalShowTitle || item.originalTitle,
          overview: item.overview || '',
          genres: item.genres || [],
          rating: item.rating || 0,
          popularity: item.popularity || 0,
          poster: item.poster,
          backdrop: item.backdrop,
          totalSeasons: item.tv.totalSeasons || 0,
          totalEpisodes: item.tv.totalEpisodes || 0,
          year: item.year,
          releaseDate: item.releaseDate,
          episodes: []
        });
      }
      tvShowsMap.get(showId).episodes.push({
        fileId: item.fileId,
        fileName: item.fileName,
        seasonNumber: item.tv.seasonNumber,
        episodeNumber: item.tv.episodeNumber,
        episodeTitle: item.tv.episodeTitle || '',
        episodeOverview: item.tv.episodeOverview || '',
        runtime: item.runtime || item.tv.episodeRuntime || 0
      });
    }

    // Sort episodes within each show
    const tvShows = Array.from(tvShowsMap.values()).map(show => {
      show.episodes.sort((a, b) => {
        if (a.seasonNumber !== b.seasonNumber) return a.seasonNumber - b.seasonNumber;
        return a.episodeNumber - b.episodeNumber;
      });
      show.availableSeasons = [...new Set(show.episodes.map(e => e.seasonNumber))].sort((a, b) => a - b);
      show.availableEpisodeCount = show.episodes.length;
      return show;
    });

    // Build genre rows based on GROUPED movies
    const genreMap = new Map();
    for (const movie of movies) {
      for (const genre of (movie.genres || [])) {
        if (!genreMap.has(genre)) genreMap.set(genre, []);
        genreMap.get(genre).push({
          id: movie.fileId, type: 'movie', title: movie.title,
          poster: movie.poster, backdrop: movie.backdrop,
          rating: movie.rating || 0, year: movie.year, runtime: movie.runtime,
          overview: movie.overview,
          isSplit: movie.isSplit || false,
          totalParts: movie.totalParts || 1
        });
      }
    }
    for (const show of tvShows) {
      for (const genre of (show.genres || [])) {
        if (!genreMap.has(genre)) genreMap.set(genre, []);
        genreMap.get(genre).push({
          id: `show_${show.showTmdbId}`, type: 'tv', title: show.showTitle,
          poster: show.poster, backdrop: show.backdrop,
          rating: show.rating || 0, year: show.year, overview: show.overview
        });
      }
    }

    const genreRows = Array.from(genreMap.entries())
      .map(([genre, items]) => {
        const seen = new Set();
        const unique = items.filter(item => {
          if (seen.has(item.id)) return false;
          seen.add(item.id);
          return true;
        });
        return { genre, items: unique };
      })
      .filter(row => row.items.length >= 2)
      .sort((a, b) => b.items.length - a.items.length);

    // Hero items — prioritize items with backdrops and good ratings
    const heroPool = [];
    for (const movie of movies) {
      if (movie.backdrop && movie.rating >= 5) {
        heroPool.push({
          id: movie.fileId, type: 'movie', title: movie.title, overview: movie.overview || '',
          backdrop: movie.backdrop, poster: movie.poster, rating: movie.rating || 0,
          year: movie.year, runtime: movie.runtime, genres: movie.genres || [],
          isSplit: movie.isSplit || false,
          totalParts: movie.totalParts || 1
        });
      }
    }
    for (const show of tvShows) {
      if (show.backdrop && show.rating >= 5) {
        heroPool.push({
          id: `show_${show.showTmdbId}`, type: 'tv', title: show.showTitle, overview: show.overview || '',
          backdrop: show.backdrop, poster: show.poster, rating: show.rating || 0,
          year: show.year, genres: show.genres || [],
          firstEpisodeFileId: show.episodes.length > 0 ? show.episodes[0].fileId : null
        });
      }
    }

    const heroItems = heroPool.sort((a, b) => b.rating - a.rating).slice(0, 8);

    // Fallback if no hero items have backdrops
    if (heroItems.length === 0) {
      const fallback = [
        ...movies.map(m => ({
          id: m.fileId, type: 'movie', title: m.title, overview: m.overview || '',
          backdrop: null, poster: m.poster, rating: m.rating || 0, year: m.year, runtime: m.runtime,
          isSplit: m.isSplit || false,
          totalParts: m.totalParts || 1
        })),
        ...tvShows.map(s => ({
          id: `show_${s.showTmdbId}`, type: 'tv', title: s.showTitle, overview: s.overview || '',
          backdrop: null, poster: s.poster, rating: s.rating || 0, year: s.year
        }))
      ];
      heroItems.push(...fallback.sort((a, b) => b.rating - a.rating).slice(0, 5));
    }

    res.json({
      movies: movies.map(m => ({
        fileId: m.fileId,
        title: m.title,
        poster: m.poster,
        backdrop: m.backdrop,
        rating: m.rating,
        year: m.year,
        runtime: m.runtime,
        genres: m.genres,
        overview: m.overview,
        tmdbId: m.tmdbId,
        isSplit: m.isSplit || false,
        totalParts: m.totalParts || 1,
        parts: m.parts || null
      })),
      tvShows, genreRows, heroItems,
      counts: {
        movies: movies.length,
        tvShows: tvShows.length,
        totalEpisodes: allMetadata.filter(isTVContent).length
      }
    });
  } catch (error) {
    console.error('API /api/metadata error:', error);
    res.status(500).json({ error: 'Failed to load library' });
  }
});

// GET /api/metadata/:fileId — Single item metadata
app.get('/api/metadata/:fileId', async (req, res) => {
  try {
    const filePath = path.join(DATA_DIR, `${req.params.fileId}.json`);
    try {
      await fs.access(filePath);
    } catch {
      return res.status(404).json({ error: 'Not found' });
    }

    const raw = await fs.readFile(filePath, 'utf-8');
    const parsed = JSON.parse(raw);

    if (parsed.needsRetry || !parsed.fetchedAt) {
      return res.status(404).json({ error: 'Metadata not ready' });
    }

    if (parsed.poster) {
      try {
        await fs.access(path.join(__dirname, parsed.poster.startsWith('/') ? parsed.poster.slice(1) : parsed.poster));
      } catch {
        parsed.poster = null;
      }
    }
    if (parsed.backdrop) {
      try {
        await fs.access(path.join(__dirname, parsed.backdrop.startsWith('/') ? parsed.backdrop.slice(1) : parsed.backdrop));
      } catch {
        parsed.backdrop = null;
      }
    }

    delete parsed._retry;
    delete parsed._posterPath;
    delete parsed._backdropPath;

    // Check for split parts (same tmdbId)
    if (parsed.type === 'movie' && parsed.tmdbId) {
      const allMetadata = await loadAllValidMetadata();
      const sameMovie = allMetadata.filter(m =>
        m.tmdbId === parsed.tmdbId &&
        isMovieContent(m)
      );

      if (sameMovie.length > 1) {
        // It is split
        const sorted = sameMovie.sort((a, b) => {
          const partA = detectSplitFile(a.fileName);
          const partB = detectSplitFile(b.fileName);
          if (partA && partB) return partA.partNumber - partB.partNumber;
          return (a.fileName || '').localeCompare(b.fileName || '');
        });

        parsed.isSplit = true;
        parsed.totalParts = sorted.length;
        parsed.parts = sorted.map((m, i) => ({
          fileId: m.fileId,
          fileName: m.fileName,
          partNumber: i + 1
        }));
      }
    }

    res.json(parsed);
  } catch (error) {
    res.status(500).json({ error: 'Failed to load metadata' });
  }
});

// GET /api/tv/:showTmdbId — Full show with all seasons/episodes
app.get('/api/tv/:showTmdbId', async (req, res) => {
  try {
    const showId = parseInt(req.params.showTmdbId);
    if (isNaN(showId)) return res.status(400).json({ error: 'Invalid show ID' });

    const allMetadata = await loadAllValidMetadata();
    const showEpisodes = allMetadata.filter(m => isTVContent(m) && m.tv && m.tv.showTmdbId === showId);

    if (showEpisodes.length === 0) return res.status(404).json({ error: 'Show not found' });

    showEpisodes.sort((a, b) => {
      if (a.tv.seasonNumber !== b.tv.seasonNumber) return a.tv.seasonNumber - b.tv.seasonNumber;
      return a.tv.episodeNumber - b.tv.episodeNumber;
    });

    const seasons = {};
    for (const ep of showEpisodes) {
      const sNum = ep.tv.seasonNumber;
      if (!seasons[sNum]) seasons[sNum] = [];
      seasons[sNum].push(ep);
    }

    const first = showEpisodes[0];
    res.json({
      showTmdbId: showId,
      showTitle: first.tv.showTitle,
      originalShowTitle: first.tv.originalShowTitle,
      overview: first.overview,
      genres: first.genres,
      rating: first.rating,
      popularity: first.popularity,
      poster: first.poster,
      backdrop: first.backdrop,
      year: first.year,
      totalSeasons: first.tv.totalSeasons,
      totalEpisodes: first.tv.totalEpisodes,
      availableSeasons: Object.keys(seasons).map(Number).sort((a, b) => a - b),
      availableEpisodeCount: showEpisodes.length,
      seasons
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to load show' });
  }
});

// GET /api/search — Search movies and shows
app.get('/api/search', async (req, res) => {
  const query = (req.query.q || '').toLowerCase().trim();
  if (!query || query.length < 2) return res.json({ results: [], query: '' });

  try {
    const allMetadata = await loadAllValidMetadata();
    const movieMatches = [];
    const tvMatches = [];
    const seenShowIds = new Set();

    for (const item of allMetadata) {
      const title = (item.title || '').toLowerCase();
      const overview = (item.overview || '').toLowerCase();
      const genres = (item.genres || []).map(g => g.toLowerCase());

      let isTV = isTVContent(item);
      let showTitle = '';
      if (isTV && item.tv) {
        showTitle = (item.tv.showTitle || item.title || '').toLowerCase();
      }

      // Calculate Relevance Score
      let score = 0;

      // 1. Exact Title Match (Highest Priority)
      if (title === query || (isTV && showTitle === query)) {
        score += 100;
      }
      // 2. Starts With Title (High Priority)
      else if (title.startsWith(query) || (isTV && showTitle.startsWith(query))) {
        score += 80;
      }
      // 3. Title Contains Query (Medium Priority)
      else if (title.includes(query) || (isTV && showTitle.includes(query))) {
        score += 60;
      }

      // 4. Genre Match
      if (genres.some(g => g.includes(query))) {
        score += 40;
      }

      // 5. Overview Match (Low Priority)
      if (overview.includes(query)) {
        score += 20;
      }

      if (score === 0) continue;

      if (isTV && item.tv) {
        const showId = item.tv.showTmdbId;
        if (!showId || seenShowIds.has(showId)) continue;

        seenShowIds.add(showId);
        tvMatches.push({
          id: `show_${showId}`, type: 'tv', title: item.tv.showTitle || item.title, poster: item.poster,
          backdrop: item.backdrop, rating: item.rating, year: item.year, overview: item.overview,
          genres: item.genres, showTmdbId: showId,
          relevanceScore: score,
          availableEpisodeCount: item.availableEpisodeCount || 0
        });
      } else if (isMovieContent(item)) {
        // Clone item to avoid mutating cache, and attach score
        movieMatches.push({ ...item, relevanceScore: score });
      }
    }

    // Group split movies
    const groupedMovies = groupSplitMovies(movieMatches).map(m => ({
      id: m.fileId, type: 'movie', title: m.title, poster: m.poster,
      backdrop: m.backdrop, rating: m.rating, year: m.year, overview: m.overview,
      runtime: m.runtime, genres: m.genres,
      isSplit: m.isSplit || false,
      totalParts: m.totalParts || 1,
      parts: m.parts || null,
      relevanceScore: m.relevanceScore || 0
    }));

    const results = [...groupedMovies, ...tvMatches];

    // Sort by Relevance (Desc), then Rating (Desc), then Title (Asc)
    results.sort((a, b) => {
      const scoreDiff = (b.relevanceScore || 0) - (a.relevanceScore || 0);
      if (scoreDiff !== 0) return scoreDiff;

      const ratingDiff = (b.rating || 0) - (a.rating || 0);
      if (ratingDiff !== 0) return ratingDiff;

      return (a.title || '').localeCompare(b.title || '');
    });

    res.json({ results, query });
  } catch (error) {
    res.status(500).json({ error: 'Search failed' });
  }
});

// GET /api/health — Server health check
app.get('/api/health', async (req, res) => {
  try {
    const allMetadata = await loadAllValidMetadata();
    const movies = allMetadata.filter(isMovieContent);
    const tvEpisodes = allMetadata.filter(isTVContent);
    let failedCount = 0;

    try {
      const files = await fs.readdir(DATA_DIR);
      for (const file of files) {
        if (!file.endsWith('.json')) continue;
        try {
          const raw = await fs.readFile(path.join(DATA_DIR, file), 'utf-8');
          const parsed = JSON.parse(raw);
          if (parsed.needsRetry || !parsed.fetchedAt) failedCount++;
        } catch { continue; }
      }
    } catch { }

    res.json({
      status: 'ok',
      library: {
        validEntries: allMetadata.length,
        movies: movies.length,
        tvEpisodes: tvEpisodes.length,
        failedEntries: failedCount
      }
    });
  } catch (error) {
    res.status(500).json({ status: 'error', error: error.message });
  }
});

// GET /api/admin/debug/tv-detection — Debug TV show detection
app.get('/api/admin/debug/tv-detection', async (req, res) => {
  try {
    const allMetadata = await loadAllValidMetadata();
    const analysis = {
      total: allMetadata.length,
      withTvField: 0, withTvShowTmdbId: 0, withTypeTv: 0,
      withTypeTvAndTvField: 0, withTvFieldButWrongType: 0,
      uniqueShows: [], issues: []
    };
    const showIds = new Set();

    for (const item of allMetadata) {
      const hasTvField = item.tv && typeof item.tv === 'object';
      const hasShowTmdbId = hasTvField && item.tv.showTmdbId;
      const typeIsTv = item.type === 'tv';

      if (hasTvField) analysis.withTvField++;
      if (hasShowTmdbId) { analysis.withTvShowTmdbId++; showIds.add(item.tv.showTmdbId); }
      if (typeIsTv) analysis.withTypeTv++;
      if (typeIsTv && hasTvField) analysis.withTypeTvAndTvField++;

      if (hasShowTmdbId && !typeIsTv) {
        analysis.withTvFieldButWrongType++;
        analysis.issues.push({
          fileId: item.fileId, fileName: item.fileName, type: item.type,
          showTitle: item.tv.showTitle, showTmdbId: item.tv.showTmdbId,
          issue: `Has tv.showTmdbId but type="${item.type}"`
        });
      }
      if (typeIsTv && !hasShowTmdbId) {
        analysis.issues.push({
          fileId: item.fileId, fileName: item.fileName, type: item.type,
          issue: 'Type is "tv" but no tv.showTmdbId field'
        });
      }
    }

    analysis.uniqueShowCount = showIds.size;
    analysis.uniqueShows = [...showIds];
    analysis.detectedByHelper = {
      tvContent: allMetadata.filter(isTVContent).length,
      movieContent: allMetadata.filter(isMovieContent).length
    };
    res.json(analysis);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }

});

// POST /api/admin/sync-telegram — Manual Trigger
app.post('/api/admin/sync-telegram', async (req, res) => {
  try {
    const { syncWithTelegram } = require('./services/metadataWorker'); // Lazy load
    console.log('[Admin] 🔄 Triggering Telegram sync...');
    const result = await syncWithTelegram();
    res.json({ success: true, result });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

// POST /api/admin/invalidate-cache — Manual Trigger
app.post('/api/admin/invalidate-cache', (req, res) => {
  invalidateCache();
  res.json({ success: true, message: 'Caches invalidated' });
});

// GET /api/admin/sync-status
app.get('/api/admin/sync-status', (req, res) => {
  const { getIdleLoopStatus } = require('./services/metadataWorker');
  res.json(getIdleLoopStatus());
});

// POST /api/admin/rebuild-tv-caches
app.post('/api/admin/rebuild-tv-caches', async (req, res) => {
  try {
    const stats = await rebuildTVCaches();
    res.json({ success: true, stats });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// GET /api/admin/incomplete-metadata
app.get('/api/admin/incomplete-metadata', async (req, res) => {
  try {
    const incomplete = await findIncompleteMetadata();
    res.json({ count: incomplete.length, items: incomplete });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// GET /api/routes — List all registered routes (debugging)
app.get('/api/routes', (req, res) => {
  const routes = [];
  app._router.stack.forEach((middleware) => {
    if (middleware.route) {
      routes.push({
        method: Object.keys(middleware.route.methods).join(', '),
        path: middleware.route.path,
      });
    } else if (middleware.name === 'router') {
      middleware.handle.stack.forEach((handler) => {
        if (handler.route) {
          const prefix = middleware.regexp.source
            .replace('\\/?(?=\\/|$)', '')
            .replace(/\\\//g, '/')
            .replace(/\^/g, '')
            .replace(/\?\(\?=.*\)/g, '');
          routes.push({
            method: Object.keys(handler.route.methods).join(', ').toUpperCase(),
            path: prefix + handler.route.path,
          });
        }
      });
    }
  });
  res.json({ routes });
});

// ============================================================
// SERVE FRONTEND — Static files from /public
// ============================================================
app.use(express.static(path.join(__dirname, 'public')));

// Catch-all for SPA — serve index.html for any unmatched non-API route
app.get('*', (req, res, next) => {
  if (req.path.startsWith('/api/') || req.path.startsWith('/data/')) {
    return next();
  }
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ============================================================
// NETWORK IP HELPER
// ============================================================
function getNetworkIP() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  return null;
}

// ============================================================
// START SERVER
// ============================================================
const { checkFFmpeg, checkFFprobe } = require('./services/ffmpegService');

async function startServer() {
  try {
    // Check ffmpeg availability
    const hasFFmpeg = await checkFFmpeg();
    const hasFFprobe = await checkFFprobe();
    console.log(`🎬 ffmpeg: ${hasFFmpeg ? '✅ installed' : '❌ NOT FOUND'}`);
    console.log(`🔍 ffprobe: ${hasFFprobe ? '✅ installed' : '❌ NOT FOUND'}`);

    if (!hasFFmpeg || !hasFFprobe) {
      console.log('⚠️  Install ffmpeg for subtitle extraction & audio transcoding');
      console.log('   Windows: choco install ffmpeg');
      console.log('   Ubuntu: sudo apt install ffmpeg');
    }

    // Initialize Telegram client
    console.log('🔄 Initializing Telegram client...');
    await initTelegram();
    console.log('✅ Telegram client initialized');

    // Register Activity Hooks
    activityTracker.onPause(() => {
      console.log('📊 [Server] Metadata worker paused due to active streaming');
    });
    activityTracker.onResume(() => {
      console.log('📊 [Server] Metadata worker resumed — server idle');
    });

    // Start listening on all interfaces
    app.listen(PORT, '0.0.0.0', () => {
      const networkIP = getNetworkIP();

      console.log('\n==========================================');
      console.log('   🎬 StreamFlix is running!');
      console.log('==========================================\n');
      console.log(`   ➜  Local:    http://localhost:${PORT}`);
      if (networkIP) {
        console.log(`   ➜  Network:  http://${networkIP}:${PORT}`);
      }
      console.log(`   ➜  API:      http://localhost:${PORT}/api`);
      console.log(`   ➜  Health:   http://localhost:${PORT}/api/health`);
      console.log(`   ➜  Worker:   http://localhost:${PORT}/api/admin/worker-status`);
      console.log('');

      // Start File Watcher + Idle Loop (replaces old setInterval approach)
      console.log('📅 Starting file watcher and idle loop...');
      startFileWatcher();

      // Start idle loop after 30s to let server stabilize
      setTimeout(() => {
        startIdleLoop();
      }, 30000);

      // Trigger initial Telegram sync
      setTimeout(async () => {
        try {
          // Lazy load and set sync time
          const { syncWithTelegram, setLastSyncTime } = require('./services/metadataWorker');

          await syncWithTelegram();

          // Mark sync as done so idle loop doesn't run it again immediately
          if (setLastSyncTime) setLastSyncTime(Date.now());

          // Rebuild TV caches on startup to ensure consistency
          console.log('📺 Rebuilding TV caches on startup...');
          await rebuildTVCaches();

        } catch (e) {
          console.error('Initial sync failed:', e);
        }
      }, 5000); // 5s after startup
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

// Debug endpoint for streaming 404s
app.get('/api/debug/stream-check/:fileId', async (req, res) => {
  const { fileId } = req.params;
  const results = {};
  const fs = require('fs');
  const path = require('path');

  // Check 1: list_caches.json
  try {
    const raw = await fs.promises.readFile(path.join(__dirname, 'data', 'list_caches.json'), 'utf-8');
    const list = JSON.parse(raw);
    const found = list.find(f =>
      String(f.id) === String(fileId) ||
      String(f.messageId) === String(fileId) ||
      String(f.fileId) === String(fileId)
    );
    results.listCache = found ? { found: true, entry: found } : { found: false };
  } catch (e) {
    results.listCache = { error: e.message };
  }

  // Check 2: metadata JSON
  try {
    const raw = await fs.promises.readFile(path.join(__dirname, 'data', 'metadata', `${fileId}.json`), 'utf-8');
    const meta = JSON.parse(raw);
    results.metadata = { found: true, title: meta.title, tmdbId: meta.tmdbId };
  } catch (e) {
    results.metadata = { found: false, error: e.message };
  }

  // Check 3: telegramService cache
  try {
    const tg = require('./services/telegramService');
    // Check if there's a movieCache
    if (tg.getCacheStats) {
      const stats = tg.getCacheStats();
      results.telegramCacheStats = stats;
    }

    // Try to get file info directly (force lookup)
    try {
      const fileInfo = await tg.getFileInfo(fileId);
      results.telegramLookup = fileInfo ? { success: true, fileInfo } : { success: false, error: 'Returned null' };
    } catch (e) {
      results.telegramLookup = { success: false, error: e.message };
    }

  } catch (e) {
    results.telegramService = { error: e.message };
  }

  res.json({ fileId, checks: results });
});

// Export for circular access
module.exports = {
  invalidateCache,
  app
};

// Only start if main module
if (require.main === module) {
  startServer();
}
