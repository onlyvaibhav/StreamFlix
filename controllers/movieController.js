const telegramService = require('../services/telegramService');
const tmdbService = require('../services/tmdbService');
const cacheService = require('../services/cacheService');
const metadataService = require('../services/metadataService');

// Helper for caching controller responses
const getCachedOrFetch = async (res, key, fetchFn, ttl = 3600 * 1000) => {
  const cached = cacheService.get(key);
  if (cached) {
    console.log(`⚡ Cache HIT: ${key}`);
    res.set('X-Cache', 'HIT');
    return cached;
  }
  console.log(`🔌 Cache MISS: ${key}`);
  res.set('X-Cache', 'MISS');
  try {
    const data = await fetchFn();
    if (data) cacheService.set(key, data, ttl);
    return data;
  } catch (e) {
    console.error(`Fetch failed for ${key}:`, e.message);
    return null;
  }
};

function isMovieNotFoundError(error) {
  const message = error?.message || '';
  return message === 'Movie not found' || message === 'Not a video file';
}

function sendFallbackThumbnail(res, id) {
  const safeId = String(id || '').replace(/[^0-9a-zA-Z_-]/g, '');
  const subtitle = safeId ? `ID: ${safeId}` : 'ID: unknown';
  const svg = [
    '<svg xmlns="http://www.w3.org/2000/svg" width="720" height="1080" viewBox="0 0 720 1080">',
    '<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">',
    '<stop offset="0%" stop-color="#1f2937"/>',
    '<stop offset="100%" stop-color="#111827"/>',
    '</linearGradient></defs>',
    '<rect width="720" height="1080" fill="url(#g)"/>',
    '<rect x="80" y="180" width="560" height="720" rx="24" fill="#0f172a" stroke="#374151" stroke-width="4"/>',
    '<circle cx="360" cy="460" r="70" fill="#334155"/>',
    '<polygon points="338,420 338,500 406,460" fill="#e5e7eb"/>',
    '<text x="360" y="610" text-anchor="middle" fill="#e5e7eb" font-family="Arial, sans-serif" font-size="44" font-weight="700">No Thumbnail</text>',
    `<text x="360" y="662" text-anchor="middle" fill="#9ca3af" font-family="Arial, sans-serif" font-size="26">${subtitle}</text>`,
    '</svg>',
  ].join('');

  res.set({
    'Content-Type': 'image/svg+xml; charset=utf-8',
    'Content-Length': Buffer.byteLength(svg),
    'Cache-Control': 'public, max-age=86400',
  });
  res.status(200).send(svg);
}

// ==================== LIBRARY (LOCAL) ====================

// ==================== LIBRARY (LOCAL) ====================

exports.getLibrary = async (req, res) => {
  try {
    // 1. Fetch EVERYTHING (limit 1000 for now, or implement infinite scroll later)
    // We need 'enrich=true' to get metadata for sorting/filtering
    const { movies: allFiles } = await telegramService.getMoviesList(1000, 0, '', true);

    // 2. Separate Movies & TV
    const movies = [];
    const tvShows = [];

    // Helper to group TV
    const tvMap = new Map(); // showTitle -> { ...show, episodes: [] }

    for (const file of allFiles) {
      // Primary TV indicator: has tv.showTmdbId
      // Secondary: type is 'tv' or 'tv_show' (from groupMoviesAndTV), or has .seasons
      const isTV = (file.tv && file.tv.showTmdbId)
        || (file.type && file.type.toLowerCase() === 'tv')
        || file.type === 'tv_show'
        || file.seasons;

      if (isTV) {
        // Handle both raw episodes and pre-grouped show objects
        const showTitle = file.showTitle || file.tv?.showTitle || file.title;
        const showTmdbId = file.tv?.showTmdbId || file.tmdbId || file.showTmdbId;
        const key = showTitle.toLowerCase();

        if (!tvMap.has(key)) {
          tvMap.set(key, {
            showTitle,
            showTmdbId,
            poster: file.poster,
            backdrop: file.backdrop,
            rating: file.rating,
            year: file.year,
            genres: file.genres || [],
            overview: file.tv?.overview || file.overview,
            availableEpisodeCount: 0
          });
        }
        const show = tvMap.get(key);

        // Count episodes: pre-grouped shows have seasons with episodes arrays
        if (file.seasons && Array.isArray(file.seasons)) {
          let episodeCount = 0;
          for (const season of file.seasons) {
            episodeCount += (season.episodes || []).length;
          }
          show.availableEpisodeCount += episodeCount;
        } else {
          show.availableEpisodeCount++;
        }

        // Allow show metadata to improve if later episodes have better data
        if (!show.backdrop && file.backdrop) show.backdrop = file.backdrop;
        if (!show.poster && file.poster) show.poster = file.poster;
        if (!show.showTmdbId && showTmdbId) show.showTmdbId = showTmdbId;
      } else {
        movies.push(file);
      }
    }

    tvShows.push(...tvMap.values());

    // 3. Build Hero Items (Top 5 Recent/Rated with Backdrops)
    const combined = [...movies, ...tvShows];
    const withBackdrop = combined.filter(m => m.backdrop);
    // Sort by rating desc? Or recent?
    // Let's mix: Recent additions + High rating
    withBackdrop.sort((a, b) => {
      // Simple shuffle-ish or just rating?
      // Let's use rating for now
      return (b.rating || 0) - (a.rating || 0);
    });
    const heroItems = withBackdrop.slice(0, 5);

    // 4. Build Genre Rows
    const genres = new Set();
    combined.forEach(m => {
      if (m.genres) m.genres.forEach(g => genres.add(g));
    });

    const genreRows = [];
    for (const genre of genres) {
      const items = combined.filter(m => m.genres && m.genres.includes(genre));
      if (items.length >= 4) { // Only show populated genres
        genreRows.push({ genre, items: items.slice(0, 20) });
      }
    }
    // Sort genres alphabetically
    genreRows.sort((a, b) => a.genre.localeCompare(b.genre));

    res.json({
      success: true,
      counts: { movies: movies.length, tvShows: tvShows.length },
      movies,
      tvShows,
      heroItems,
      genreRows
    });

  } catch (error) {
    console.error('Get library error:', error);
    res.status(500).json({ error: 'Failed to fetch library' });
  }
};

exports.getMovies = async (req, res) => {
  try {
    const { limit = 50, offset = 0, search = '' } = req.query;
    // Use local enrichment (fast, non-blocking)
    const { movies, nextOffset } = await telegramService.getMoviesList(
      parseInt(limit), parseInt(offset), search, true
    );
    res.json({ success: true, count: movies.length, nextOffset, movies });
  } catch (error) {
    console.error('Get movies error:', error);
    res.status(500).json({ error: 'Failed to fetch movies', message: error.message });
  }
};

exports.getMovie = async (req, res) => {
  try {
    const { id } = req.params;
    const movie = await telegramService.getMovieById(id);
    if (!movie) return res.status(404).json({ error: 'Movie not found' });
    res.json({ success: true, movie });
  } catch (error) {
    if (isMovieNotFoundError(error)) {
      return res.status(404).json({ error: 'Movie not found', message: error.message });
    }
    res.status(500).json({ error: 'Failed to fetch movie', message: error.message });
  }
};

exports.getMovieMetadata = async (req, res) => {
  try {
    const { id } = req.params;
    const meta = await telegramService.getMovieMetadata(id);
    if (!meta) return res.status(404).json({ error: 'Metadata not found' });
    res.json({ success: true, metadata: meta });
  } catch (error) {
    console.error('Get metadata error:', error);
    res.status(500).json({ error: 'Failed to fetch metadata', message: error.message });
  }
};

// ==================== TMDB DISCOVER / HOME ====================

exports.getTrending = async (req, res) => {
  const data = await getCachedOrFetch(res, 'home_trending', () => tmdbService.getTrending());
  res.json(data || { results: [] });
};

exports.getTopRated = async (req, res) => {
  const data = await getCachedOrFetch(res, 'home_top_rated', () => tmdbService.getTopRated());
  res.json(data || { results: [] });
};

exports.getPopular = async (req, res) => {
  const data = await getCachedOrFetch(res, 'home_popular', () => tmdbService.getPopular());
  res.json(data || { results: [] });
};

exports.getGenres = async (req, res) => {
  const data = await getCachedOrFetch(res, 'genres_list', () => tmdbService.getGenres());
  res.json(data || { genres: [] });
};

exports.getByGenre = async (req, res) => {
  const { id } = req.params;
  const { page } = req.query;
  const key = `genre_${id}_p${page || 1}`;
  const data = await getCachedOrFetch(res, key, () => tmdbService.getByGenre('movie', id, page));
  res.json(data || { results: [] });
};

exports.getTmdbMovieDetails = async (req, res) => {
  const { id } = req.params;
  const key = `tmdb_movie_${id}`;
  const data = await getCachedOrFetch(res, key, () => tmdbService.getMovieDetails(id));
  res.json(data || {});
};

exports.getTmdbTVDetails = async (req, res) => {
  const { id } = req.params;
  const key = `tmdb_tv_${id}`;
  const data = await getCachedOrFetch(res, key, () => tmdbService.getTVDetails(id));
  res.json(data || {});
};

exports.getTmdbSeasonDetails = async (req, res) => {
  const { id, season } = req.params;
  const key = `tmdb_tv_${id}_s${season}`;
  const data = await getCachedOrFetch(res, key, () => tmdbService.getSeasonDetails(id, season));
  res.json(data || {});
};

exports.getLocalTVDetails = async (req, res) => {
  const { id } = req.params; // This is TMDB ID
  const show = await metadataService.getShowByTmdbId(id);
  // If not found, try to fetch from TMDB to at least show details?
  // But for "watching", we need local files. 
  // Let's just return what we have.
  if (!show) return res.status(404).json({ error: 'TV Show not found locally' });
  res.json(show);
};


// ==================== ASSETS & INFO ====================

exports.getThumbnail = async (req, res) => {
  try {
    const { id } = req.params;
    const thumb = await telegramService.getThumbnail(id);
    if (!thumb) return sendFallbackThumbnail(res, id);

    res.set({
      'Content-Type': 'image/jpeg',
      'Content-Length': thumb.length,
      'Cache-Control': 'public, max-age=86400',
    });
    res.send(thumb);
  } catch (error) {
    sendFallbackThumbnail(res, req.params.id);
  }
};

exports.getMediaInfo = async (req, res) => {
  try {
    const { id } = req.params;
    const info = await telegramService.getMediaInfo(id);

    // Embedded subtitle extraction is disabled. Clients should request external
    // subtitles (SubDL/OpenSubtitles) via the `/api/subtitles/movie/:id` endpoint.
    const subtitleList = [];

    if (!info) {
      return res.json({
        success: true,
        info: null,
        subtitles: subtitleList,
        message: 'ffprobe not available. Install ffmpeg for media analysis.',
      });
    }

    res.json({ success: true, info, subtitles: subtitleList });
  } catch (error) {
    res.status(500).json({ error: 'Failed to get media info', message: error.message });
  }
};

exports.getCacheStats = async (req, res) => {
  try {
    const stats = telegramService.getCacheStats();
    res.json({ success: true, stats });
  } catch (error) {
    res.status(500).json({ error: 'Failed to get cache stats' });
  }
};

const tmdbResolver = require('../services/tmdbResolver');
const fs = require('fs').promises;
const path = require('path');

exports.getMoreLikeThisMovie = async (req, res) => {
    try {
        const { id: fileId } = req.params;
        const metaPath = path.join(__dirname, '../data/metadata', `${fileId}.json`);
        
        let meta;
        try {
            const raw = await fs.readFile(metaPath, 'utf-8');
            meta = JSON.parse(raw);
        } catch (e) {
            return res.status(404).json({ error: 'Metadata not found' });
        }
        
        let results = [];
        
        let collectionData = null;
        
        // 1. Collection Matches (Prioritized)
        if (meta.collection && meta.collection.id) {
            const collectionItems = await tmdbResolver.getCollectionRecommendations(meta);
            
            // For the general "Because you watched" row, we can still include them
            results = [...collectionItems];
            
            // But we also pass the separate collection row data so frontend can build a dedicated row
            if (collectionItems.length > 0) {
                const collectionNames = require('../config/collectionNames');
                const displayName = collectionNames[meta.collection.name] || collectionNames[meta.collection.id] || meta.collection.name;
                
                // Add the current movie back into the collection row to make it complete
                const index = await tmdbResolver.getIndex();
                const currentEntry = index.get(meta.tmdbId);
                const fullCollection = currentEntry ? [currentEntry, ...collectionItems] : collectionItems;
                fullCollection.sort((a, b) => (a.year || 0) - (b.year || 0));

                collectionData = {
                    title: displayName,
                    items: fullCollection 
                };
            }
        }
        
        // 2. TMDB Recommendations & Similar
        if (results.length < 50) {
            const recs = meta.recommendations || [];
            const sim = meta.similar || [];
            const combined = [...new Set([...recs, ...sim])];
            
            const tmdbMatches = await tmdbResolver.resolveTmdbIds(combined, meta.tmdbId);
            
            for (const match of tmdbMatches) {
                if (!results.find(r => r.fileId === match.fileId)) {
                    results.push(match);
                }
                if (results.length >= 50) break;
            }
        }
        
        // 3. Fallback Genres and Keywords
        if (results.length < 50) {
            const fallbacks = await tmdbResolver.getFallbackRecommendations(meta, 50 - results.length);
            for (const match of fallbacks) {
                if (!results.find(r => r.fileId === match.fileId)) {
                    results.push(match);
                }
            }
        }
        
        res.json({ success: true, results });
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch recommendations', message: error.message });
    }
};

exports.getMoreLikeThisTV = async (req, res) => {
    try {
        const { id: showTmdbId } = req.params;
        const index = await tmdbResolver.getIndex();
        const entry = index.get(Number(showTmdbId));
        
        if (!entry || !entry.originalFileId) {
             return res.status(404).json({ error: 'TV Show not found in library' });
        }
        
        const metaPath = path.join(__dirname, '../data/metadata', `${entry.originalFileId}.json`);
        let meta;
        try {
            const raw = await fs.readFile(metaPath, 'utf-8');
            meta = JSON.parse(raw);
        } catch (e) {
            return res.status(404).json({ error: 'Metadata not found' });
        }
        
        const recs = meta.recommendations || [];
        const sim = meta.similar || [];
        const combined = [...new Set([...recs, ...sim])];
        
        let results = await tmdbResolver.resolveTmdbIds(combined, meta.tmdbId);
        
        if (results.length < 50) {
            const fallbacks = await tmdbResolver.getFallbackRecommendations(meta, 50 - results.length);
            for (const match of fallbacks) {
                if (!results.find(r => r.fileId === match.fileId)) {
                    results.push(match);
                }
            }
        }
        
        results = results.slice(0, 50);
        
        res.json({ success: true, results });
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch TV recommendations', message: error.message });
    }
};
