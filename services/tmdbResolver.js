const fs = require('fs').promises;
const path = require('path');

const DATA_DIR = path.join(__dirname, '../data/metadata');
const INDEX_TTL = 60000; // Cache index for 60 seconds

let tmdbIndex = null;
let lastIndexTime = 0;

/**
 * Builds an index of tmdbId -> library entry.
 * Movies: 1 tmdbId -> 1 file.
 * TV: collapses multiple episodes into 1 entry per show using showTmdbId.
 */
async function buildIndex() {
    const index = new Map();
    try {
        const files = await fs.readdir(DATA_DIR);
        for (const file of files) {
            if (!file.endsWith('.json')) continue;
            
            try {
                const raw = await fs.readFile(path.join(DATA_DIR, file), 'utf-8');
                const parsed = JSON.parse(raw);

                if (!parsed.fileId || parsed.needsRetry || !parsed.fetchedAt || !parsed.title || !parsed.tmdbId) {
                    continue; // Skip invalid or incomplete metadata
                }

                const tmdbId = parsed.tmdbId; // for TV, this is showTmdbId

                // Check if it's TV
                const isTV = parsed.type === 'tv' || (parsed.tv && parsed.tv.showTmdbId);

                const entry = {
                    fileId: isTV ? `show_${tmdbId}` : parsed.fileId,
                    originalFileId: parsed.fileId, // Keep this to read recommendations later
                    tmdbId: tmdbId,
                    title: isTV && parsed.tv && parsed.tv.showTitle ? parsed.tv.showTitle : parsed.title,
                    poster: parsed.poster,
                    year: parsed.year,
                    rating: parsed.rating,
                    type: isTV ? 'tv' : 'movie',
                    genres: Array.isArray(parsed.genres) ? parsed.genres.map(g => g.toLowerCase()) : [],
                    keywords: Array.isArray(parsed.keywords) ? parsed.keywords.map(k => k.toLowerCase()) : [],
                    // Optional: keep episode details to decide which one is "representative"
                    _season: isTV && parsed.tv ? parsed.tv.seasonNumber : 0,
                    _episode: isTV && parsed.tv ? parsed.tv.episodeNumber : 0,
                    collectionId: parsed.collection ? parsed.collection.id : null
                };

                if (!index.has(tmdbId)) {
                    index.set(tmdbId, entry);
                } else if (isTV) {
                    // We already have an entry for this show.
                    // Prefer S01E01 or the lowest season/episode as the representative
                    const existing = index.get(tmdbId);
                    if (entry._season < existing._season || 
                       (entry._season === existing._season && entry._episode < existing._episode)) {
                        index.set(tmdbId, entry);
                    }
                }

            } catch (err) {
                // Skip unparseable files
            }
        }
        
        tmdbIndex = index;
        lastIndexTime = Date.now();
    } catch (error) {
        console.error('[tmdbResolver] Error building index:', error);
    }
}

async function getIndex() {
    if (!tmdbIndex || (Date.now() - lastIndexTime > INDEX_TTL)) {
        await buildIndex();
    }
    return tmdbIndex;
}

/**
 * Resolves a list of TMDB IDs into playable library entries.
 * 
 * @param {Array<number>} tmdbIds - Array of TMDB IDs (e.g. from recommendations/similar)
 * @param {number} excludeTmdbId - The TMDB ID of the current title to exclude
 * @returns {Array<Object>} - Array of resolved library cards
 */
async function resolveTmdbIds(tmdbIds, excludeTmdbId = null) {
    if (!Array.isArray(tmdbIds)) return [];

    const index = await getIndex();
    const results = [];
    const seen = new Set();

    for (const id of tmdbIds) {
        // Skip if it's the current title
        if (excludeTmdbId && id === excludeTmdbId) continue;
        
        // Skip duplicates
        if (seen.has(id)) continue;
        seen.add(id);

        const entry = index.get(id);
        if (entry) {
            // Remove internal fields before returning
            const cleanEntry = { ...entry };
            delete cleanEntry._season;
            delete cleanEntry._episode;
            delete cleanEntry.genres;
            delete cleanEntry.keywords;
            delete cleanEntry.originalFileId;
            delete cleanEntry.collectionId;
            results.push(cleanEntry);
        }
    }

    return results;
}

/**
 * Fallback to matching by shared genres/keywords within the local library.
 * @param {Object} sourceMetadata - The metadata JSON object of the source title
 * @param {number} limit - Maximum number of results to return
 * @returns {Array<Object>} - Array of resolved library cards
 */
async function getFallbackRecommendations(sourceMetadata, limit = 15) {
    const index = await getIndex();
    
    const sourceTmdbId = sourceMetadata.tmdbId; // Could be movie or tv showTmdbId
    const sourceGenres = new Set((sourceMetadata.genres || []).map(g => g.toLowerCase()));
    const sourceKeywords = new Set((sourceMetadata.keywords || []).map(k => k.toLowerCase()));
    
    if (sourceGenres.size === 0 && sourceKeywords.size === 0) return [];
    
    const matches = [];
    
    for (const [tmdbId, entry] of index.entries()) {
        if (tmdbId === sourceTmdbId) continue;
        
        let score = 0;
        
        for (const g of entry.genres) {
            if (sourceGenres.has(g)) score += 2; // Weight genres slightly higher
        }
        for (const k of entry.keywords) {
            if (sourceKeywords.has(k)) score += 1;
        }
        
        if (score > 0) {
            matches.push({ entry, score });
        }
    }
    
    matches.sort((a, b) => b.score - a.score);
    
    const results = [];
    for (let i = 0; i < Math.min(matches.length, limit); i++) {
        const cleanEntry = { ...matches[i].entry };
        delete cleanEntry._season;
        delete cleanEntry._episode;
        delete cleanEntry.genres;
        delete cleanEntry.keywords;
        delete cleanEntry.originalFileId;
        delete cleanEntry.collectionId;
        results.push(cleanEntry);
    }
    
    return results;
}

/**
 * Returns movies in the same collection.
 */
async function getCollectionRecommendations(sourceMetadata) {
    if (!sourceMetadata.collection || !sourceMetadata.collection.id) return [];
    
    const index = await getIndex();
    const sourceTmdbId = sourceMetadata.tmdbId;
    const collectionId = sourceMetadata.collection.id;
    
    const results = [];
    
    for (const [tmdbId, entry] of index.entries()) {
        if (tmdbId === sourceTmdbId) continue;
        
        if (entry.collectionId === collectionId) {
            const cleanEntry = { ...entry };
            delete cleanEntry._season;
            delete cleanEntry._episode;
            delete cleanEntry.genres;
            delete cleanEntry.keywords;
            delete cleanEntry.originalFileId;
            delete cleanEntry.collectionId;
            results.push(cleanEntry);
        }
    }
    
    // Sort by year
    results.sort((a, b) => (a.year || 0) - (b.year || 0));
    
    return results;
}

// Function to force cache invalidation (e.g., when a new file is added)
function invalidateIndex() {
    tmdbIndex = null;
    lastIndexTime = 0;
}

module.exports = {
    resolveTmdbIds,
    getFallbackRecommendations,
    getCollectionRecommendations,
    invalidateIndex,
    getIndex
};
