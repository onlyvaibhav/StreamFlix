const fs = require('fs').promises;
const path = require('path');
const telegramService = require('../services/telegramService');
const externalSubService = require('../services/externalSubtitleService');
const { detectAndConvert } = require('../services/subtitleService');

const METADATA_DIR = path.join(__dirname, '..', 'data', 'metadata');

// In-memory store for search results (needed to map IDs to download URLs)
const searchResultsStore = new Map();

exports.getSubtitles = async (req, res) => {
    try {
        const { movieId } = req.params;
        console.log(`🔤 Subtitle list request for movie: ${movieId}`);

        const allSubtitles = [];

        // 1. Load metadata to get TMDB ID (much more reliable than filename parsing)
        let metadata = null;
        try {
            const metadataPath = path.join(METADATA_DIR, `${movieId}.json`);
            const raw = await fs.readFile(metadataPath, 'utf-8');
            metadata = JSON.parse(raw);
        } catch (e) {
            console.log(`   Could not read metadata for ${movieId}: ${e.message}`);
        }

        // 2. Search external subtitle services using TMDB ID
        if (externalSubService.isConfigured() && metadata?.tmdbId) {
            try {
                const providers = req.query.providers ? req.query.providers.split(',') : ['subdl'];
                const languages = req.query.lang ? req.query.lang.split(',') : ['en'];

                // Build mediaInfo from metadata — use tmdbId for direct API lookup
                // For TV: use the SHOW's tmdbId (not the episode's), + season + episode
                const isTv = metadata.type === 'tv' && metadata.tv;
                const mediaInfo = {
                    tmdbId: isTv ? (metadata.tv.showTmdbId || metadata.tmdbId) : metadata.tmdbId,
                    type: metadata.type || 'movie',
                    seasonNumber: metadata.tv?.seasonNumber || null,
                    episodeNumber: metadata.tv?.episodeNumber || null,
                    title: metadata.title || metadata.fileName || 'Unknown',
                };

                console.log(`   📋 Using ${isTv ? 'Show' : ''} TMDB ID ${mediaInfo.tmdbId} (${mediaInfo.type}${mediaInfo.seasonNumber ? ` S${mediaInfo.seasonNumber}E${mediaInfo.episodeNumber}` : ''})`);

                const externalSubs = await externalSubService.searchSubtitles(mediaInfo, languages, providers);

                for (const sub of externalSubs) {
                    allSubtitles.push({
                        id: sub.id,
                        label: `🌐 ${sub.label}`,
                        language: sub.language,
                        languageLabel: sub.languageLabel,
                        type: 'external',
                        source: sub.source,
                        provider: sub.provider,
                        rating: sub.rating,
                        author: sub.author,
                    });
                }

                // Store search results for later download
                searchResultsStore.set(movieId, {
                    results: externalSubs,
                    time: Date.now(),
                });

                // Clean old entries
                if (searchResultsStore.size > 100) {
                    const oldest = [...searchResultsStore.entries()]
                        .sort((a, b) => a[1].time - b[1].time);
                    for (let i = 0; i < 50; i++) {
                        searchResultsStore.delete(oldest[i][0]);
                    }
                }
            } catch (e) {
                console.error('   External subtitle search failed:', e.message);
            }
        } else if (!metadata?.tmdbId) {
            console.log(`   ⚠️ No TMDB ID in metadata for ${movieId}, cannot search external subtitles`);
        }

        res.json({
            success: true,
            count: allSubtitles.length,
            subtitles: allSubtitles,
        });
    } catch (error) {
        console.error('Get subtitles error:', error);
        res.status(500).json({
            error: 'Failed to fetch subtitles',
            message: error.message,
        });
    }
};

exports.getSubtitleFile = async (req, res) => {
    try {
        const { subtitleId } = req.params;
        console.log(`🔤 Subtitle file request: ${subtitleId}`);

        let result;

        // Only external subtitles via SubDL/OpenSubtitles are supported.
        if (subtitleId.startsWith('subdl_') || subtitleId.startsWith('os_')) {
            // Aggregate cached search results to find the subtitle entry
            let allResults = [];
            for (const entry of searchResultsStore.values()) {
                allResults.push(...entry.results);
            }

            result = await externalSubService.downloadSubtitle(subtitleId, allResults);
        } else {
            throw new Error('Embedded or Telegram-hosted subtitle extraction is disabled. Use SubDL/OpenSubtitles from the UI.');
        }

        // Frontend fetches subtitle text via XHR/fetch — no Content-Disposition needed.
        res.set({
            'Content-Type': 'text/vtt; charset=utf-8',
            'Cache-Control': 'public, max-age=86400',
            'Access-Control-Allow-Origin': '*',
        });

        res.send(result.content);
    } catch (error) {
        console.error('Get subtitle file error:', error);
        res.status(500).json({
            error: 'Failed to fetch subtitle',
            message: error.message,
        });
    }
};

// Search subtitles by TMDB ID or custom query
exports.searchSubtitles = async (req, res) => {
    try {
        const { query } = req.params;
        const languages = req.query.lang ? req.query.lang.split(',') : ['en'];
        const providers = req.query.providers ? req.query.providers.split(',') : ['subdl', 'opensubtitles'];
        const type = req.query.type || 'movie';
        const season = req.query.season ? parseInt(req.query.season) : null;
        const episode = req.query.episode ? parseInt(req.query.episode) : null;

        // Try to parse query as a TMDB ID (number)
        const tmdbId = /^\d+$/.test(query) ? parseInt(query) : null;

        console.log(`🔤 Subtitle search: ${tmdbId ? `tmdb=${tmdbId}` : `"${query}"`} [${languages}] [${providers}]`);

        const mediaInfo = {
            tmdbId: tmdbId,
            type: type,
            seasonNumber: season,
            episodeNumber: episode,
            title: query,
        };

        const results = await externalSubService.searchSubtitles(mediaInfo, languages, providers);

        // Store for download
        searchResultsStore.set(`search_${query}`, {
            results,
            time: Date.now(),
        });

        res.json({
            success: true,
            count: results.length,
            subtitles: results.map(sub => ({
                id: sub.id,
                label: sub.label,
                language: sub.language,
                languageLabel: sub.languageLabel,
                source: sub.source,
                provider: sub.provider,
                rating: sub.rating,
                author: sub.author,
            })),
        });
    } catch (error) {
        console.error('Subtitle search error:', error);
        res.status(500).json({
            error: 'Search failed',
            message: error.message,
        });
    }
};

exports.convertSubtitle = async (req, res) => {
    try {
        const { content, format } = req.body;

        if (!content) {
            console.error('convertSubtitle: empty content, headers:', req.headers['content-type'], 'length:', req.headers['content-length']);
            return res.status(400).json({ error: 'Subtitle content required' });
        }

        const vttContent = detectAndConvert(content, `subtitle.${format || 'srt'}`);

        res.set({
            'Content-Type': 'text/vtt; charset=utf-8',
            'Access-Control-Allow-Origin': '*',
        });

        res.send(vttContent);
    } catch (error) {
        res.status(500).json({
            error: 'Conversion failed',
            message: error.message,
        });
    }
};