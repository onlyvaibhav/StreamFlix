const fs = require('fs');
const path = require('path');
const axios = require('axios');
const AdmZip = require('adm-zip');

// ==================== CONFIG ====================

const SUBDL_API_KEY = process.env.SUBDL_API_KEY || '';
const OPENSUBTITLES_API_KEY = process.env.OPENSUBTITLES_API_KEY || '';
const SUBDL_BASE = 'https://api.subdl.com/api/v1/subtitles';
const SUBDL_DOWNLOAD_BASE = 'https://dl.subdl.com';
const OS_BASE = 'https://api.opensubtitles.com/api/v1';
const TEMP_DIR = path.join(__dirname, '..', 'temp');

console.log('--- External Subtitle Service Config ---');
console.log('SubDL Key:', SUBDL_API_KEY ? 'Present' : 'Missing');
console.log('OpenSubtitles Key:', OPENSUBTITLES_API_KEY ? 'Present' : 'Missing');
console.log('-------------------------------------------');

// In-memory cache
const searchCache = new Map();
const downloadCache = new Map();
const CACHE_TTL = 60 * 60 * 1000; // 1 hour

if (!fs.existsSync(TEMP_DIR)) {
    fs.mkdirSync(TEMP_DIR, { recursive: true });
}

// Axios instance with default headers
const httpClient = axios.create({
    timeout: 15000,
    headers: {
        'User-Agent': 'TelegramStreaming v1.0',
    },
});

// ==================== UTILITIES ====================

function extractZip(zipBuffer) {
    return new Promise((resolve, reject) => {
        try {
            const zip = new AdmZip(zipBuffer);
            const zipEntries = zip.getEntries();
            const results = [];
            const subtitleExts = ['.srt', '.vtt', '.ass', '.ssa', '.sub'];

            zipEntries.forEach(entry => {
                if (entry.isDirectory) return;

                const ext = path.extname(entry.entryName).toLowerCase();
                if (subtitleExts.includes(ext)) {
                    const content = zip.readAsText(entry);
                    results.push({
                        fileName: entry.entryName,
                        content: content,
                        ext: ext
                    });
                }
            });

            resolve(results);
        } catch (e) {
            reject(new Error(`ZIP extraction failed: ${e.message}`));
        }
    });
}

/**
 * Convert SRT content to VTT format
 */
function srtToVtt(srt) {
    let vtt = 'WEBVTT\n\n';

    // Normalize line endings
    const normalized = srt.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

    // Replace comma with dot in timestamps
    vtt += normalized.replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, '$1.$2');

    // Remove SRT cue numbers (lines that are just numbers before timestamps)
    vtt = vtt.replace(/^\d+\s*\n(?=\d{2}:\d{2}:\d{2})/gm, '');

    return vtt;
}

/**
 * Convert ASS/SSA to VTT (basic conversion)
 */
function assToVtt(ass) {
    let vtt = 'WEBVTT\n\n';

    const lines = ass.split(/\r?\n/);
    for (const line of lines) {
        if (line.startsWith('Dialogue:')) {
            // Format: Dialogue: 0,0:00:01.00,0:00:04.00,Default,,0,0,0,,Text
            const parts = line.substring(9).split(',');
            if (parts.length >= 10) {
                const startTime = parts[1].trim();
                const endTime = parts[2].trim();
                const text = parts.slice(9).join(',')
                    .replace(/\\N/g, '\n')
                    .replace(/\\n/g, '\n')
                    .replace(/\{[^}]*\}/g, ''); // Remove ASS styling tags

                // Convert H:MM:SS.CC to HH:MM:SS.MMM
                const convertTime = (t) => {
                    const match = t.match(/(\d+):(\d{2}):(\d{2})\.(\d{2,3})/);
                    if (!match) return t;
                    const [, h, m, s, cs] = match;
                    const ms = cs.length === 2 ? cs + '0' : cs;
                    return `${h.padStart(2, '0')}:${m}:${s}.${ms}`;
                };

                if (text.trim()) {
                    vtt += `${convertTime(startTime)} --> ${convertTime(endTime)}\n${text.trim()}\n\n`;
                }
            }
        }
    }

    return vtt;
}

/**
 * Convert any subtitle format to VTT
 */
function toVtt(content, ext) {
    if (ext === '.vtt') return content;
    if (ext === '.srt') return srtToVtt(content);
    if (ext === '.ass' || ext === '.ssa') return assToVtt(content);
    // For unknown formats, try SRT conversion as most common
    return srtToVtt(content);
}

/**
 * Parse a release-style filename into components.
 * Example: "The Lunchbox 2013 BluRay 720p Hindi AAC 5 1 x264 ESub Vegamovies"
 * -> { title: 'The Lunchbox', year: '2013', quality: 'BluRay', resolution: '720p', fileName: original }
 */
function parseMovieString(name) {
    if (!name) return {};
    const original = name;
    // Remove extension if present
    let s = name.replace(/\.(mp4|mkv|avi|mov|webm|flv|wmv|m4v|ts)$/i, '');

    // Collect year
    const yearMatch = s.match(/\b(19|20)\d{2}\b/);
    const year = yearMatch ? yearMatch[0] : null;

    // Collect resolution (e.g., 720p, 1080p)
    const resMatch = s.match(/\b(\d{3,4}p)\b/i);
    const resolution = resMatch ? resMatch[1].toLowerCase() : null;

    // Quality tags like BluRay, WEBRip, DVDRip, HDTV
    const qualityMatch = s.match(/\b(bluray|brrip|webrip|web-dl|hdtv|dvdrip|hdrip|uhd|blu-ray)\b/i);
    const quality = qualityMatch ? qualityMatch[1] : null;

    // Title: everything before year or quality or resolution or known tags
    let title = s;
    // cut at year if present
    if (year) title = title.split(year)[0];
    // cut at quality/resolution if present
    title = title.split(/\b(bluray|brrip|webrip|web-dl|hdtv|dvdrip|hdrip|uhd|blu-ray|\d{3,4}p)\b/i)[0];

    // Remove common release tags and separators
    title = title.replace(/[_\.\-\[\]\(\)]/g, ' ')
        .replace(/\b(x264|x265|h264|h265|hevc|aac|ac3|dts|esub|hardcoded|hc|repack|proper|rarbg|yify)\b/ig, '')
        .replace(/\s+/g, ' ').trim();

    // Capitalize title words
    title = title.split(' ').map(w => w.length > 0 ? (w[0].toUpperCase() + w.slice(1)) : '').join(' ').trim();

    return { title: title || null, year: year || null, quality: quality || null, resolution: resolution || null, fileName: original };
}

// ==================== SUBDL API (TMDB ID-based) ====================

/**
 * Search SubDL for subtitles using TMDB ID (direct, accurate lookup).
 * For movies: uses tmdb_id + type=movie
 * For TV:     uses tmdb_id + type=tv + season_number + episode_number
 *
 * @param {number} tmdbId - TMDB ID of the movie/show
 * @param {string} mediaType - 'movie' or 'tv'
 * @param {number|null} seasonNumber - Season number (TV only)
 * @param {number|null} episodeNumber - Episode number (TV only)
 * @param {string[]} languages - Language codes to search for
 * @returns {Array} Mapped subtitle results
 */
async function searchSubDL(tmdbId, mediaType = 'movie', seasonNumber = null, episodeNumber = null, languages = ['en']) {
    if (!SUBDL_API_KEY) {
        console.log('   ⚠️ SubDL: No API key configured');
        return [];
    }

    if (!tmdbId) {
        console.log('   ⚠️ SubDL: No TMDB ID provided, skipping');
        return [];
    }

    const langParam = (languages || []).map(l => l.toUpperCase()).join(',');
    const tvInfo = (mediaType === 'tv' && seasonNumber && episodeNumber)
        ? ` S${seasonNumber}E${episodeNumber}` : '';
    console.log(`   🔍 SubDL: Searching tmdb=${tmdbId} type=${mediaType}${tvInfo} [${langParam}]...`);

    try {
        // Single API call using tmdb_id — no two-step name matching needed
        let url = `${SUBDL_BASE}?api_key=${SUBDL_API_KEY}&tmdb_id=${tmdbId}&type=${mediaType}&languages=${encodeURIComponent(langParam)}&subs_per_page=30`;

        // Add season/episode for TV shows
        if (mediaType === 'tv' && seasonNumber && episodeNumber) {
            url += `&season_number=${seasonNumber}&episode_number=${episodeNumber}`;
        }

        const searchRes = await httpClient.get(url);

        const subtitleList = searchRes.data.subtitles || searchRes.data.results || [];

        if (subtitleList.length === 0) {
            console.log('   ⚠️ SubDL: No subtitles found');
            return [];
        }

        console.log(`   ✅ SubDL: Found ${subtitleList.length} subtitle(s)`);

        const mappedSubs = subtitleList.map((sub, index) => ({
            id: `subdl_${index}_${Date.now()}`,
            provider: 'subdl',
            label: sub.release_name || sub.name || `Subtitle ${index + 1}`,
            language: sub.lang || sub.language || 'en',
            languageLabel: getLanguageLabel(sub.lang || sub.language),
            format: (sub.name || '').split('.').pop() || 'srt',
            downloadUrl: sub.url ? `${SUBDL_DOWNLOAD_BASE}${sub.url}` : null,
            author: sub.author || 'Unknown',
            isZip: true,  // SubDL returns zip files
            rating: sub.hi ? '🔇 HI' : '',
            source: 'SubDL',
            // Store episode info for correct ZIP extraction
            seasonNumber: seasonNumber || null,
            episodeNumber: episodeNumber || null,
        })).filter(sub => sub.downloadUrl);

        // Pre-sort SubDL results to prioritize 'HI' (Hearing Impaired) at the top of the list 
        // using the embedded boolean flag or text matching
        mappedSubs.sort((a, b) => {
            const aHI = a.rating === '🔇 HI' || a.label?.toUpperCase().includes('HI') || a.label?.toUpperCase().includes('HEARING IMPAIRED');
            const bHI = b.rating === '🔇 HI' || b.label?.toUpperCase().includes('HI') || b.label?.toUpperCase().includes('HEARING IMPAIRED');
            if (aHI && !bHI) return -1;
            if (!aHI && bHI) return 1;
            return 0;
        });

        console.log(`   ✅ SubDL: ${mappedSubs.length} downloadable subtitle(s)`);
        return mappedSubs;

    } catch (error) {
        console.error(`   ❌ SubDL error: ${error.message}`);
        if (error.response) {
            console.error('   SubDL Response:', JSON.stringify(error.response.data).substring(0, 200));
        }
        return [];
    }
}

async function downloadSubDL(subtitle) {
    if (!subtitle.downloadUrl) throw new Error('No download URL');

    console.log(`   ⬇️ SubDL: Downloading ${subtitle.label}...`);

    const response = await httpClient.get(subtitle.downloadUrl, {
        responseType: 'arraybuffer'
    });

    // SubDL returns ZIP files
    const files = await extractZip(response.data);

    if (files.length === 0) {
        throw new Error('No subtitle file found in ZIP');
    }

    // For TV episodes: match the correct episode file from multi-episode ZIPs
    let candidates = files;
    if (subtitle.episodeNumber) {
        const epNum = subtitle.episodeNumber;
        const seasonNum = subtitle.seasonNumber || 1;

        // Build patterns like S01E02, s01e02, E02, e02
        const padEp = String(epNum).padStart(2, '0');
        const padSeason = String(seasonNum).padStart(2, '0');
        const patterns = [
            `S${padSeason}E${padEp}`,
            `s${padSeason}e${padEp}`,
            `E${padEp}`,
            `e${padEp}`,
            `.${padEp}.`,
            `Episode ${epNum}`,
            `Episode.${padEp}`,
        ];

        const episodeFiles = files.filter(f => {
            const name = f.fileName;
            return patterns.some(p => name.includes(p));
        });

        if (episodeFiles.length > 0) {
            candidates = episodeFiles;
            console.log(`   🎯 Matched ${episodeFiles.length} file(s) for S${padSeason}E${padEp} from ${files.length} total`);
        } else {
            console.log(`   ⚠️ No episode-specific match in ZIP (${files.length} files), using first`);
        }
    }

    // Prefer .srt, then .vtt, then others
    const sorted = candidates.sort((a, b) => {
        const order = ['.srt', '.vtt', '.ass', '.ssa', '.sub'];
        return order.indexOf(a.ext) - order.indexOf(b.ext);
    });

    const file = sorted[0];
    console.log(`   📄 Extracted: ${file.fileName} (${file.content.length} chars)`);

    return toVtt(file.content, file.ext);
}

// ==================== OPENSUBTITLES API ====================

/**
 * Search OpenSubtitles using TMDB ID (direct lookup).
 * For movies: uses tmdb_id
 * For TV:     uses tmdb_id + season_number + episode_number
 *
 * @param {number} tmdbId - TMDB ID of the movie/show
 * @param {string} mediaType - 'movie' or 'tv'
 * @param {number|null} seasonNumber - Season number (TV only)
 * @param {number|null} episodeNumber - Episode number (TV only)
 * @param {string[]} languages - Language codes to search for
 * @returns {Array} Mapped subtitle results
 */
async function searchOpenSubtitles(tmdbId, mediaType = 'movie', seasonNumber = null, episodeNumber = null, languages = ['en']) {
    if (!OPENSUBTITLES_API_KEY) {
        console.log('   ⚠️ OpenSubtitles: No API key configured');
        return [];
    }

    if (!tmdbId) {
        console.log('   ⚠️ OpenSubtitles: No TMDB ID provided, skipping');
        return [];
    }

    const params = new URLSearchParams({
        tmdb_id: tmdbId.toString(),
        languages: languages.join(','),
        order_by: 'download_count',
        order_direction: 'desc',
    });

    // For TV, add season/episode
    if (mediaType === 'tv' && seasonNumber && episodeNumber) {
        params.append('season_number', seasonNumber.toString());
        params.append('episode_number', episodeNumber.toString());
    }

    const tvInfo = (mediaType === 'tv' && seasonNumber && episodeNumber)
        ? ` S${seasonNumber}E${episodeNumber}` : '';
    const url = `${OS_BASE}/subtitles?${params}`;
    console.log(`   🔍 OpenSubtitles: Searching tmdb=${tmdbId} type=${mediaType}${tvInfo} [${languages}]...`);

    try {
        const response = await httpClient.get(url, {
            headers: {
                'Api-Key': OPENSUBTITLES_API_KEY,
                'Content-Type': 'application/json',
            }
        });

        const data = response.data;

        if (!data.data || data.data.length === 0) {
            console.log('   ⚠️ OpenSubtitles: No results found');
            return [];
        }

        console.log(`   ✅ OpenSubtitles: Found ${data.data.length} subtitle(s)`);

        const mappedSubs = data.data.map((item) => {
            const attrs = item.attributes || {};
            const files = attrs.files || [];
            const file = files[0] || {};

            return {
                id: `os_${item.id}`,
                provider: 'opensubtitles',
                label: attrs.release || file.file_name || `OS Subtitle`,
                language: attrs.language || 'en',
                languageLabel: getLanguageLabel(attrs.language),
                format: 'srt',
                fileId: file.file_id,
                downloadCount: attrs.download_count || 0,
                rating: attrs.ratings ? `⭐ ${attrs.ratings}` : '',
                hearingImpaired: attrs.hearing_impaired,
                source: 'OpenSubtitles',
            };
        }).filter(sub => sub.fileId);

        console.log(`   ✅ OpenSubtitles: ${mappedSubs.length} downloadable subtitle(s)`);
        return mappedSubs;
    } catch (error) {
        console.error(`   ❌ OpenSubtitles error: ${error.message}`);
        if (error.response) {
            console.error('   OpenSubtitles Response:', JSON.stringify(error.response.data).substring(0, 200));
        }
        return [];
    }
}

async function downloadOpenSubtitles(subtitle) {
    if (!subtitle.fileId) throw new Error('No file ID');

    console.log(`   ⬇️ OpenSubtitles: Downloading ${subtitle.label}...`);

    // Step 1: Request download link
    const postData = { file_id: subtitle.fileId };

    const tokenRes = await httpClient.post(`${OS_BASE}/download`, postData, {
        headers: {
            'Api-Key': OPENSUBTITLES_API_KEY,
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    });

    const downloadInfo = tokenRes.data;

    if (!downloadInfo.link) {
        throw new Error('No download link returned');
    }

    // Step 2: Download the actual file
    const fileRes = await httpClient.get(downloadInfo.link, {
        responseType: 'text' // Auto-decode text
    });

    const content = fileRes.data;

    console.log(`   📄 Downloaded: ${content.length} chars`);

    // Convert to VTT
    return srtToVtt(content);
}

// ==================== UNIFIED API ====================

/**
 * Search for subtitles using TMDB ID via SubDL first, then OpenSubtitles as fallback.
 *
 * @param {object} mediaInfo - Media identification info
 * @param {number} mediaInfo.tmdbId - TMDB ID of the movie/show
 * @param {string} mediaInfo.type - 'movie' or 'tv'
 * @param {number|null} mediaInfo.seasonNumber - Season number (TV only)
 * @param {number|null} mediaInfo.episodeNumber - Episode number (TV only)
 * @param {string} mediaInfo.title - Display title (for logging only)
 * @param {string[]} languages - Language codes to search for
 * @param {string[]} providers - Which providers to use
 * @returns {Array} Combined subtitle results from all providers
 */
async function searchSubtitles(mediaInfo, languages = ['en'], providers = ['subdl', 'opensubtitles']) {
    const { tmdbId, type, seasonNumber, episodeNumber, title } = mediaInfo || {};

    if (!tmdbId) {
        console.log(`\n🔤 No TMDB ID available for subtitle search (title: "${title || 'unknown'}")`);
        return [];
    }

    const mediaType = type === 'tv' ? 'tv' : 'movie';
    const cacheKey = `search_tmdb_${tmdbId}_${mediaType}_s${seasonNumber || 0}_e${episodeNumber || 0}_${languages.join(',')}_${providers.join(',')}`;
    const cached = searchCache.get(cacheKey);
    if (cached && Date.now() - cached.time < CACHE_TTL) {
        console.log(`   📦 Cache hit for subtitle search: tmdb=${tmdbId}`);
        return cached.data;
    }

    const tvInfo = (mediaType === 'tv' && seasonNumber && episodeNumber)
        ? ` S${seasonNumber}E${episodeNumber}` : '';
    console.log(`\n🔤 Searching subtitles: "${title || 'unknown'}" (tmdb=${tmdbId}, ${mediaType}${tvInfo}) [Providers: ${providers.join(',')}]`);

    let results = [];

    // Try SubDL (if requested)
    if (providers.includes('subdl')) {
        try {
            const subdlResults = await searchSubDL(tmdbId, mediaType, seasonNumber, episodeNumber, languages);
            results.push(...subdlResults);
        } catch (e) {
            console.error(`   SubDL failed: ${e.message}`);
        }
    }

    // Try OpenSubtitles (if requested, or as fallback when SubDL returns nothing)
    if (providers.includes('opensubtitles') || (results.length === 0 && OPENSUBTITLES_API_KEY)) {
        try {
            const osResults = await searchOpenSubtitles(tmdbId, mediaType, seasonNumber, episodeNumber, languages);
            results.push(...osResults);
        } catch (e) {
            console.error(`   OpenSubtitles failed: ${e.message}`);
        }
    }

    console.log(`   📊 Total results: ${results.length} subtitle(s) from all sources`);

    searchCache.set(cacheKey, { data: results, time: Date.now() });
    return results;
}

/**
 * Download a subtitle by its ID
 */
async function downloadSubtitle(subtitleId, allResults = []) {
    // Check download cache
    const cached = downloadCache.get(subtitleId);
    if (cached && Date.now() - cached.time < CACHE_TTL) {
        console.log(`   📦 Cache hit for subtitle download: ${subtitleId}`);
        return cached.data;
    }

    // Find the subtitle in results
    const subtitle = allResults.find(s => s.id === subtitleId);
    if (!subtitle) throw new Error(`Subtitle ${subtitleId} not found`);

    let vttContent;

    if (subtitle.provider === 'subdl') {
        vttContent = await downloadSubDL(subtitle);
    } else if (subtitle.provider === 'opensubtitles') {
        vttContent = await downloadOpenSubtitles(subtitle);
    } else {
        throw new Error(`Unknown provider: ${subtitle.provider}`);
    }

    // Ensure it starts with WEBVTT
    if (!vttContent.trim().startsWith('WEBVTT')) {
        vttContent = 'WEBVTT\n\n' + vttContent;
    }

    const result = {
        content: vttContent,
        fileName: `${subtitle.label}.vtt`,
        format: 'vtt',
        mimeType: 'text/vtt',
        language: subtitle.language,
        source: subtitle.source,
    };

    downloadCache.set(subtitleId, { data: result, time: Date.now() });
    return result;
}

// ==================== HELPERS ====================

function cleanMovieName(name) {
    if (!name) return '';

    return name
        // Remove file extension
        .replace(/\.(mp4|mkv|avi|mov|webm|flv|wmv|m4v|ts)$/i, '')
        // Replace dots, underscores, hyphens with spaces
        .replace(/[._-]/g, ' ')
        // Remove bracket content [720p], [BluRay], (2020), etc.
        .replace(/\[.*?\]/g, '')
        .replace(/\(.*?\)/g, '')
        // Remove common tags
        .replace(/(720p|1080p|2160p|4k|bluray|brrip|dvdrip|webrip|web-dl|hdtv|hdrip|x264|x265|hevc|aac|ac3|dts|10bit|6ch|multi|dual|hindi|eng|sub|subs|subtitle|extended|directors cut|unrated|remastered)/gi, '')
        // Remove year at the end (but keep it for search)
        .replace(/\s+/g, ' ')
        .trim();
}

function getLanguageLabel(code) {
    const langs = {
        en: 'English', hi: 'Hindi', es: 'Spanish', fr: 'French',
        de: 'German', ja: 'Japanese', ko: 'Korean', zh: 'Chinese',
        ar: 'Arabic', pt: 'Portuguese', it: 'Italian', ru: 'Russian',
        nl: 'Dutch', sv: 'Swedish', da: 'Danish', no: 'Norwegian',
        pl: 'Polish', tr: 'Turkish', th: 'Thai', vi: 'Vietnamese',
        id: 'Indonesian', ms: 'Malay', ro: 'Romanian', el: 'Greek',
        cs: 'Czech', hu: 'Hungarian', fi: 'Finnish', bg: 'Bulgarian',
        hr: 'Croatian', sk: 'Slovak', sl: 'Slovenian', uk: 'Ukrainian',
        he: 'Hebrew', fa: 'Persian', bn: 'Bengali', ta: 'Tamil',
        te: 'Telugu', ml: 'Malayalam', kn: 'Kannada', mr: 'Marathi',
        eng: 'English', hin: 'Hindi', spa: 'Spanish', fre: 'French',
        ger: 'German', jpn: 'Japanese', kor: 'Korean', chi: 'Chinese',
        ara: 'Arabic', por: 'Portuguese', ita: 'Italian', rus: 'Russian',
    };
    return langs[code] || code || 'Unknown';
}

function isConfigured() {
    return !!(SUBDL_API_KEY || OPENSUBTITLES_API_KEY);
}

module.exports = {
    searchSubtitles,
    downloadSubtitle,
    cleanMovieName,
    isConfigured,
};
