const { worker, loadMetadata, getAllMetadata } = require('./metadataWorker');
const { cleanMediaFilename, detectTVEpisode } = require('../utils/filenameUtils');

// ==================== CORE METADATA LOGIC ====================

// Get Metadata for a specific file (Movie or TV Episode)
exports.getMetadata = async (fileId, filename) => {
    // 1. Try to load existing metadata
    const meta = await loadMetadata(fileId);

    // 2. If it exists and is valid, return it
    if (meta && !meta.needsRetry && meta.fetchedAt) {
        return meta;
    }

    // 3. If it doesn't exist or needs retry, we can't block to fetch it 
    // because the new system is background-worker based. 
    // We return what we have (even if null or partial) 
    // and ensure the worker knows about it.

    // Trigger background processing for this single file
    worker.processMediaLibrary([{
        fileId,
        filename,
        path: '', // Path unknown here, but filename is enough for search
        parentFolder: ''
    }]);

    return meta || null;
};

exports.hasMetadata = async (fileId) => {
    const meta = await loadMetadata(fileId);
    return !!meta;
};

// ==================== ENRICH LIST ====================
exports.enrichMovieList = async (files) => {
    // 1. Trigger background processing for the whole batch
    // This is "fire and forget" so the UI doesn't hang
    worker.processMediaLibrary(files.map(f => ({
        fileId: f.id,
        filename: f.fileName || f.message, // handle various input formats
        path: '',
        parentFolder: ''
    })));

    // 2. Return whatever metadata we currently have on disk
    // The first time this runs, it might return empty/null metadata
    // The polling mechanism in the frontend (or next refresh) will pick up updates
    const enriched = await Promise.all(files.map(async (file) => {
        const meta = await loadMetadata(file.id);
        if (meta) {
            return {
                ...file,
                ...meta,
                // Ensure specific fields expected by frontend
                title: meta.title || file.title,
                year: meta.year || file.year,
                poster: meta.poster,
                backdrop: meta.backdrop,
                rating: meta.rating,
                overview: meta.overview,
                // TV specific
                showTitle: meta.tv ? meta.tv.showTitle : undefined,
                seasonNumber: meta.tv ? meta.tv.seasonNumber : undefined,
                episodeNumber: meta.tv ? meta.tv.episodeNumber : undefined
            };
        }
        return file;
    }));

    return groupMoviesAndTV(enriched);
};

// Reuse grouping logic from original service, adapted for new schema
function groupMoviesAndTV(items) {
    const movies = [];
    const tvShows = {}; // Key: "Show Name"

    items.forEach(item => {
        if (item.type === 'tv' || item.tv) {
            // It's a TV episode
            const showName = item.tv?.showTitle || item.showTitle || item.title || "Unknown Show";

            if (!tvShows[showName]) {
                tvShows[showName] = {
                    type: 'tv_show',
                    title: showName,
                    poster: item.poster, // Use episode poster as show poster if available
                    backdrop: item.backdrop,
                    rating: item.rating,
                    tmdbId: item.tv?.showTmdbId || item.tmdbId, // Show ID
                    overview: item.tv?.overview || item.overview,
                    seasons: {}
                };
            }

            // Should probably use show-level metadata if available?
            // But we don't have easy access to show-level cache here without loading it. 
            // For now, this aggregation is fine.

            const seasonNum = item.tv?.seasonNumber || item.seasonNumber || 1;
            if (!tvShows[showName].seasons[seasonNum]) {
                tvShows[showName].seasons[seasonNum] = {
                    seasonNumber: seasonNum,
                    episodes: []
                };
            }

            // Add episode to season
            tvShows[showName].seasons[seasonNum].episodes.push(item);

        } else {
            movies.push(item);
        }
    });

    const tvList = Object.values(tvShows).map(show => {
        show.seasons = Object.values(show.seasons).sort((a, b) => a.seasonNumber - b.seasonNumber);
        show.seasons.forEach(season => {
            season.episodes.sort((a, b) => a.episodeNumber - b.episodeNumber);
        });
        return show;
    });

    return [...tvList, ...movies];
}

exports.getShowByTmdbId = async (tmdbId) => {
    // Scan all metadata
    const all = await getAllMetadata();
    const episodes = all.filter(meta =>
        (meta.type === 'tv' || meta.tv) &&
        String(meta.tv?.showTmdbId || meta.tmdbId) === String(tmdbId)
    );

    if (episodes.length === 0) return null;

    // Use the first episode to build the show object
    const showBase = episodes[0];
    const show = {
        type: 'tv_show',
        title: showBase.tv?.showTitle || showBase.title,
        poster: showBase.poster,
        backdrop: showBase.backdrop,
        rating: showBase.rating,
        tmdbId: tmdbId,
        overview: showBase.tv?.overview || showBase.overview,
        seasons: {}
    };

    episodes.forEach(item => {
        const seasonNum = item.tv?.seasonNumber || 1;
        if (!show.seasons[seasonNum]) {
            show.seasons[seasonNum] = {
                seasonNumber: seasonNum,
                episodes: []
            };
        }
        show.seasons[seasonNum].episodes.push(item);
    });

    show.seasons = Object.values(show.seasons).sort((a, b) => a.seasonNumber - b.seasonNumber);
    show.seasons.forEach(season => {
        season.episodes.sort((a, b) => a.episodeNumber - b.episodeNumber);
    });

    return show;
};

// Legacy alias
exports.cleanFilename = (filename) => {
    const { title, year } = cleanMediaFilename(filename);
    const tv = detectTVEpisode(filename);
    return {
        title,
        year,
        isTV: tv.type === 'tv',
        season: tv.season,
        episode: tv.episode
    };
};

// Worker needs this exposed if older code calls it
exports.downloadImage = async (url, filepath) => {
    // Delegate to worker's internal logic or axios directly?
    // Worker logic is private. But we can just use axios here as legacy support.
    try {
        const fs = require('fs');
        const { promisify } = require('util');
        const stream = require('stream');
        const finished = promisify(stream.finished);
        const axios = require('axios');

        const writer = fs.createWriteStream(filepath);
        const response = await axios({
            url,
            method: 'GET',
            responseType: 'stream'
        });
        response.data.pipe(writer);
        await finished(writer);
        return true;
    } catch (e) {
        return false;
    }
};
