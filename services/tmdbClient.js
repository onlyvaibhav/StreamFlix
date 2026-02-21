const axios = require('axios');

const TMDB_BASE = 'https://api.themoviedb.org/3';
// API documentation: https://developer.themoviedb.org/reference
// Rate limit: ~50 requests per second. We stay well under.

class TMDBClient {
    constructor(apiKey) {
        this.apiKey = apiKey;
        this.requestCount = 0;
        this.windowStart = Date.now();
        this.MAX_REQUESTS = 40; // Conservative limit
        this.WINDOW_MS = 1000;
    }

    async request(endpoint, params = {}) {
        // Rate limiting
        const now = Date.now();
        if (now - this.windowStart > this.WINDOW_MS) {
            this.requestCount = 0;
            this.windowStart = now;
        }
        if (this.requestCount >= this.MAX_REQUESTS) {
            const wait = this.WINDOW_MS - (now - this.windowStart) + 100;
            await new Promise(r => setTimeout(r, wait));
            this.requestCount = 0;
            this.windowStart = Date.now();
        }
        this.requestCount++;

        const response = await axios.get(`${TMDB_BASE}${endpoint}`, {
            params: { ...params, api_key: this.apiKey },
            timeout: 10000
        });
        return response.data;
    }

    // ==========================================================
    // MOVIE: Two-step fetch → Build master schema
    // ==========================================================
    async fetchMovieComplete(fileId, fileName, title, year = null) {
        // STEP 1: Search
        const searchParams = { query: title };
        if (year) searchParams.year = year;

        const search = await this.request('/search/movie', searchParams);

        if (!search.results || search.results.length === 0) {
            if (year) return this.fetchMovieComplete(fileId, fileName, title, null);
            return null;
        }

        const tmdbId = search.results[0].id;

        // STEP 2: Full details
        const d = await this.request(`/movie/${tmdbId}`);

        return {
            fileId,
            fileName,
            type: 'movie',
            title: d.title || title,
            originalTitle: d.original_title || '',
            overview: d.overview || '',
            releaseDate: d.release_date || null,
            year: d.release_date ? parseInt(d.release_date.split('-')[0]) : year,
            runtime: d.runtime || 0,
            genres: (d.genres || []).map(g => g.name),
            rating: d.vote_average || 0,
            popularity: d.popularity || 0,
            poster: null,
            backdrop: null,
            tmdbId: d.id,
            fetchedAt: new Date().toISOString(),
            needsRetry: false,
            tv: null,
            // Internal — used by worker for image download, stripped before final save
            _posterPath: d.poster_path,
            _backdropPath: d.backdrop_path
        };
    }

    // ==========================================================
    // TV SHOW: Single show-level fetch (called ONCE per show)
    // Returns raw show metadata — NOT the master schema
    // ==========================================================
    async fetchTVShowDetails(title, year = null) {
        const searchParams = { query: title };
        if (year) searchParams.first_air_date_year = year;

        const search = await this.request('/search/tv', searchParams);

        if (!search.results || search.results.length === 0) {
            if (year) return this.fetchTVShowDetails(title, null);
            return null;
        }

        const tmdbId = search.results[0].id;
        const d = await this.request(`/tv/${tmdbId}`);

        return {
            showTmdbId: d.id,
            showTitle: d.name || title,
            originalShowTitle: d.original_name || '',
            overview: d.overview || '',
            firstAirDate: d.first_air_date || null,
            genres: (d.genres || []).map(g => g.name),
            rating: d.vote_average || 0,
            popularity: d.popularity || 0,
            posterPath: d.poster_path,
            backdropPath: d.backdrop_path,
            // episode_run_time is deprecated for newer shows — check both
            defaultEpisodeRuntime: (d.episode_run_time && d.episode_run_time.length > 0)
                ? d.episode_run_time[0]
                : 0,
            totalSeasons: d.number_of_seasons || 0,
            totalEpisodes: d.number_of_episodes || 0
        };
    }

    // ==========================================================
    // TV EPISODE: Fetch individual episode details
    // Only needed for episodeTitle and episodeOverview
    // ==========================================================
    async fetchEpisodeDetails(showTmdbId, season, episode) {
        try {
            const d = await this.request(
                `/tv/${showTmdbId}/season/${season}/episode/${episode}`
            );
            return {
                episodeTitle: d.name || '',
                episodeOverview: d.overview || '',
                episodeRuntime: d.runtime || 0
            };
        } catch (err) {
            // Episode might not exist on TMDB — not fatal
            return {
                episodeTitle: '',
                episodeOverview: '',
                episodeRuntime: 0
            };
        }
    }

    // ==========================================================
    // BUILD MASTER SCHEMA FOR TV EPISODE
    // Combines show metadata + episode details into one object
    // ==========================================================
    buildEpisodeSchema(fileId, fileName, showMeta, episodeDetails, season, episode) {
        return {
            fileId,
            fileName,
            type: 'tv',
            title: showMeta.showTitle,
            originalTitle: showMeta.originalShowTitle,
            overview: showMeta.overview,
            releaseDate: showMeta.firstAirDate || null,
            year: showMeta.firstAirDate
                ? parseInt(showMeta.firstAirDate.split('-')[0])
                : null,
            runtime: episodeDetails.episodeRuntime || showMeta.defaultEpisodeRuntime || 0,
            genres: showMeta.genres,
            rating: showMeta.rating,
            popularity: showMeta.popularity,
            poster: null,
            backdrop: null,
            tmdbId: showMeta.showTmdbId,
            fetchedAt: new Date().toISOString(),
            needsRetry: false,
            tv: {
                showTitle: showMeta.showTitle,
                originalShowTitle: showMeta.originalShowTitle,
                seasonNumber: season,
                episodeNumber: episode,
                episodeTitle: episodeDetails.episodeTitle,
                episodeOverview: episodeDetails.episodeOverview,
                showTmdbId: showMeta.showTmdbId,
                episodeRuntime: episodeDetails.episodeRuntime || showMeta.defaultEpisodeRuntime || 0,
                totalSeasons: showMeta.totalSeasons,
                totalEpisodes: showMeta.totalEpisodes
            },
            _posterPath: showMeta.posterPath,
            _backdropPath: showMeta.backdropPath
        };
    }
}

module.exports = TMDBClient;
