// ============================================================
// CONSTANTS
// ============================================================

const RELEASE_GROUPS = new Set([
    'yts', 'yify', 'rarbg', 'psa', 'pahe', 'tigole', 'mkvcage', 'iorg',
    'sparks', 'geckos', 'fleet', 'cmrg', 'ntg', 'evo', 'fgt', 'stuttershit',
    'afm72', 'ion10', 'ntb', 'playnow', 'usury', 'mkvking', 'galaxyrg',
    'ganool', 'jetix', 'bone', 'reward', 'hone', 'ift', 'syncopy', 'caffeine',
    'cakes', 'mzabi', 'ethel', 'sekrit', 'nikt0n', 'hdetg', 'etrg', 'hon3y',
    'shaanig', 'joy', 'amiable', 'vxt', 'ghosts', 'acool', 'ebi', 'mkvhub',
    'cinefile', 'ctl', 'mega', 'nhanc3', 'sujaidr', 'blade', 'demand',
    'd3g', 'cody', 'rovers', 'watcher', 'monkee', 'pimprg', 'bordure',
    'nogrp', 'mtb', 'shortbrehd', 'strife', 'epsilon', 'yol0w'
]);

const SITE_NAMES = [
    'Vegamovies?', 'Vegamovie', 'YTS', 'YIFY', 'RARBG', 'PSA', 'Pahe', 'Tigole',
    'mkvcage', 'Tamilrockers', 'Movierulz', '1337x', 'TGx', 'Torrent',
    'FilmyZilla', 'SkymoviesHD', 'HDHub4u', 'Bolly4u', 'ExtraMovies',
    'SSR', 'KatMovieHD', 'KatmovieHD', 'MoviesFlix', 'DownloadHub', 'MkvCinemas',
    'WorldFree4u', 'Mkv?King', 'HDMoviesHub', 'MovieVerse', 'CoolMoviez',
    'UWatchFree', 'KLwap', 'FullyMaza', 'Hubflix', 'GalaxyRG', 'EZTV',
    'MkvHub', 'Mkvking', 'TamilBlasters', 'iSAimini', 'Kuttymovies',
    'DVDPlay', 'Cinemavilla', 'HDPrime', 'MkvMoviesPoint', 'MoviesVerse',
    'extramovies', 'themoviesflix', 'moviesverse', 'torrentgalaxy',
    'ettv', 'cpasbien', 'ygg', 'torrent9', 'torrentz2',
    'MoviesMod', 'HDHubu4u', 'HDHub4u', 'Veagamovies',
    'Tsundere Raws', 'Tsundere'
];

const WATERMARK_TLDS = [
    'is', 'nl', 'mx', 'com', 'org', 'net', 'in',
    'me', 'to', 'cc', 'co', 'pm', 'fun', 'top', 'xyz', 'club', 'site',
    'live', 'pro', 'io', 'se', 'ch', 'li', 'gg', 'ws', 'lol', 'lat',
    'tv', 'ru', 'de', 'fr', 'it', 'es', 'uk', 'us', 'ca', 'au',
    'vg', 'hot', 'Link'
];

const LOWERCASE_WORDS = new Set([
    'a', 'an', 'the', 'and', 'but', 'or', 'nor', 'for', 'yet', 'so',
    'in', 'on', 'at', 'to', 'of', 'by', 'up', 'as', 'is', 'it',
    'vs', 'with', 'from', 'into', 'than', 'not', 'no', 'via'
]);

const YEAR_TITLES = new Set([
    '1917', '2001', '2010', '2012', '1984', '1776', '1492', '1941',
    '1408', '2036', '2046', '2067', '1922', '1992', '2003', '2898'
]);

const JUNK_KEYWORDS = [
    // Resolution
    '480p', '576p', '720p', '720P', '1080p', '1080P', '2160p', '4k', 'UHD', 'FHD', 'QHD',
    // Source
    'BluRay', 'Blu Ray', 'BRRip', 'BDRip', 'BDRemux',
    'WEB DL', 'WEBDL', 'WEBRip', 'WEB Rip', 'Web Dl', 'WeBDL', 'WebRip',
    'HDRip', 'HDRip', 'DVDRip', 'DVDScr', 'HDTV', 'PDTV', 'SDTV',
    'CAMRip', 'HDCAM', 'HDTS', 'TeleSync', 'TeleCine', 'HDTC', 'HQDub',
    // Streaming services
    'AMZN', 'NF', 'DSNP', 'HMAX', 'ATVP', 'PCOK', 'STAN',
    'BCORE', 'CRAV', 'PMTP', 'ROKU', 'SONYLIV', 'SONY', 'DPHS',
    'JC', 'Zee5', 'HS', 'Amazon miniTV', 'Netflix Original',
    // Video codec
    'x264', 'x265', 'HEVC', 'AVC', 'VP9', 'AV1',
    '10bit', '10Bit', '8bit', '12bit',
    'HDR', 'HDR10', 'HDR10Plus', 'DV', 'DoVi', 'Dolby Vision',
    // Audio codec
    'AAC', 'AC3', 'DTS', 'DDP', 'DDP5 1', 'DD5 1', 'DD',
    'FLAC', 'Atmos', 'TrueHD', 'MP3', 'EAC3', 'LPCM', 'Opus',
    'DTS HD', 'DTS X', 'DTS HD MA',
    // Language tags
    'Dual', 'Audio', 'Multi', 'Dual Audio', 'MULTi',
    'Hindi', 'English', 'Tamil', 'Telugu', 'Korean', 'Japanese',
    'Spanish', 'French', 'German', 'Italian', 'Russian', 'Chinese',
    'Portuguese', 'Arabic', 'Indonesian', 'Turkish', 'Thai', 'Vietnamese',
    'Malayalam', 'Kannada',
    'Hin', 'Eng', 'Tam', 'Tel', 'Kor', 'Jap', 'Spa', 'Fra', 'Ger',
    'Ita', 'Rus', 'Chi', 'Por', 'Ara',
    'HIN', 'ENG', 'KOR', 'JAP',
    'Engish', 'Englis', // common typos
    // Subtitle tags
    'Sub', 'Subs', 'Subbed', 'Dubbed', 'ESub', 'ESubs', 'Esub', 'Esubs',
    'HC', 'HardSub', 'SoftSub', 'HardCoded', 'MSubs', 'Msubs',
    'HardCoded', 'SoftCoded',
    // Release tags
    'PROPER', 'REPACK', 'RERIP', 'INTERNAL',
    'EXTENDED', 'Extended Cut', 'UNCUT', 'UnCut', 'UNRATED',
    'THEATRICAL', 'DC',
    'DIRECTORS CUT', "DIRECTOR'S CUT", 'IMAX', 'OPEN MATTE',
    'REMUX', 'COMPLETE', 'REMASTERED', 'RESTORED',
    'CRITERION', 'SPECIAL EDITION', 'ANNIVERSARY EDITION',
    // 3D tags
    '3D', 'HSBS', 'HOU', 'Half SBS', 'SBS',
    // Misc
    'READNFO', 'NFO', 'SAMPLE', 'TRAILER',
    'V2', 'V3', 'FIXED', 'REGRADED',
    'MULTI',
    // Industry tags
    'ORG', 'Org',
    'Bollywood', 'Hollywood', 'South',
    'Full Movie', 'Movie', 'Series', 'Film',
    'HD', 'TRUE',
    'DS4K',
    // Size indicators
    '800MB', '400MB', '600MB', '1GB', '2GB',
    // Bitrate
    '640Kbps', '320Kbps', '192Kbps', '192kbps', '128Kbps', '96Kbps',
    // Channel layout words
    '2CH',
    // Org Vers
    'Org Vers',
];

// Build a single regex from junk keywords for performance
const JUNK_REGEX = new RegExp(
    '\\b(' + JUNK_KEYWORDS.map(k => k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|') + ')\\b',
    'gi'
);

// Build site name regex
const SITE_REGEX = new RegExp(
    '(?:^|[._\\s\\-])(' + SITE_NAMES.map(s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|') + ')(?:[._\\s\\-]|$)',
    'gi'
);

// ============================================================
// TV EPISODE DETECTION PATTERNS (precompiled)
// ============================================================

// S01E01, S01 E01, S01E01E02, S01E01-E02, S01_E01, S01 EP01, S01EP01
const TV_PATTERN_STANDARD = /S(\d{1,2})\s?[._\- ]?E(?:P)?(\d{1,3})(?:\s?[-]?\s?E?(\d{1,3}))?/i;

// "Season 1 Episode 12"
const TV_PATTERN_VERBOSE = /Season\s*(\d{1,2})\s*[-–—]?\s*Episode\s*(\d{1,3})/i;

// "01x12"
const TV_PATTERN_CROSS = /\b(\d{1,2})x(\d{2,3})\b/i;

// "Episode 12", "EP12", "Chapter 5"
const TV_PATTERN_EPISODE_ONLY = /\b(?:Episode|EP|Chapter|Ch)\s*(\d{1,3})\b/i;

// Bare "E01" — only zero-padded
const TV_PATTERN_BARE_E = /(?<!\w)E(\d{2,3})(?!\w)/i;

// Anime-style " - 01"
const TV_PATTERN_ANIME = /\s-\s(\d{2,3})(?:\s|$)/;

// S01 without episode (Complete season) e.g. "Campus_Beats_S01_2023"
const TV_PATTERN_SEASON_ONLY = /\bS(\d{1,2})\b(?!\s?[._\- ]?E(?:P)?\d)/i;

// All episode marker patterns for title extraction — ordered by specificity
const EPISODE_MARKER_PATTERNS = [
    /S\d{1,2}\s?[._\- ]?E(?:P)?\d{1,3}/i,
    /Season\s*\d{1,2}\s*[-–—]?\s*Episode/i,
    /\b\d{1,2}x\d{2,3}\b/i,
    /\b(?:Episode|EP|Chapter|Ch)\s*\d{1,3}\b/i,
    /(?<!\w)E\d{2,3}(?!\w)/i,
    /\s-\s\d{2,3}(?:\s|$)/,
    /\bS\d{1,2}\b/i, // Season-only marker
];

// ============================================================
// PHASE 1 — Filename Cleaner
// ============================================================

/**
 * Cleans a media filename into a human-readable title + year.
 *
 * @param {string} filename
 * @returns {{title: string, year: number|null, partNumber: number|null}}
 */
function cleanMediaFilename(filename) {
    if (!filename || typeof filename !== 'string') {
        return { title: '', year: null, partNumber: null };
    }

    let name = filename.trim();

    // ── STEP 1: Remove file extension ──
    name = name.replace(/(?:\.[a-z]{2,3})?\.[a-zA-Z0-9]{2,5}$/, '');

    // ── STEP 2: Remove leading numbering ──
    // "01. Movie Name" or "01 - Movie Name" or "#5 Movie Name"
    // Also "2_" prefix like "2_Fifty.Shade.Darker" or "2_WallE"
    name = name.replace(/^#?\d{1,3}[\s._\-]+(?=[A-Za-z])/, '');

    // ── STEP 3: Remove CRC32 hashes and bracket tags ──
    name = name.replace(/\[[A-Fa-f0-9]{6,8}\]/g, '');  // CRC32 hashes
    name = name.replace(/\[.*?\]/g, ' ');
    name = name.replace(/\(.*?\)/g, ' ');
    name = name.replace(/\{.*?\}/g, ' ');

    // ── STEP 4: Remove trailing release group ──
    const trailingGroupMatch = name.match(/-([a-zA-Z][a-zA-Z0-9]{1,12})$/);
    if (trailingGroupMatch) {
        const group = trailingGroupMatch[1];
        if (RELEASE_GROUPS.has(group.toLowerCase()) || /^[A-Z0-9]{2,8}$/.test(group)) {
            name = name.slice(0, -trailingGroupMatch[0].length);
        }
    }

    // ── STEP 5: Remove trailing split-file numbers ──
    // "-001", "-002", "_001", "_002" at end of name
    name = name.replace(/[-_]\d{3}$/, '');

    // ── STEP 6: Remove trailing random hashes ──
    // "_prCMbz", "_kWjonY" — 5-7 char mixed case at end
    name = name.replace(/[_\-][a-zA-Z][a-zA-Z0-9]{4,6}$/, function (match) {
        // Only strip if it looks random (mixed case or has digits mixed in)
        const inner = match.slice(1);
        if (/[a-z]/.test(inner) && /[A-Z]/.test(inner)) return '';
        if (/[a-zA-Z]/.test(inner) && /\d/.test(inner) && inner.length >= 5) return '';
        return match; // keep it
    });

    // ── STEP 7: Remove compound technical patterns BEFORE separator replacement ──

    // Audio channels: DD_5_1, DDP5.1, AAC.5.1, EAC3.5.1, 7.1, 2.0
    name = name.replace(/[._\- ]?(?:DDP?|AAC|AC3|TrueHD|Atmos|FLAC|LPCM|MP3|EAC3|Opus|DD\+?)[._\- ]?\d[._]\d/gi, '');

    // Standalone channel layouts: 5.1, 7.1, 2.0 (bounded by separators)
    name = name.replace(/(?<=[._\- ])[257]\.[01](?=[._\- ]|$)/g, '');

    // DTS variants
    name = name.replace(/[._\- ]?DTS[._\- ]?(?:HD)?[._\- ]?(?:MA)?[._\- ]?(?:\d[._]\d)?/gi, '');

    // Codec with dots: H.264, H.265, x.264
    name = name.replace(/[._\- ]?[HXx][._]?26[45]/gi, '');

    // Site names
    name = name.replace(SITE_REGEX, ' ');

    // ── STEP 8: Remove site watermarks with TLDs ──
    const tldPattern = new RegExp(
        '([._\\-])(' + WATERMARK_TLDS.join('|') + ')(?=[._\\-]|$)',
        'gi'
    );
    name = name.replace(tldPattern, '$1');

    // Remove www prefix
    name = name.replace(/\bwww\b[._\-]?/gi, '');

    // ── STEP 9: Remove "Netflix Original", "– Netflix Original" etc. ──
    name = name.replace(/[–—\-]?\s*Netflix\s*Original/gi, '');

    // ── STEP 10: Replace separators with spaces ──
    name = name.replace(/[._]/g, ' ');
    // Hyphens: preserve in-word ("Spider-Man"), remove as separators (" - ")
    name = name.replace(/\s+-\s+/g, ' ');
    name = name.replace(/\s+-(?=\S)/g, ' ');
    name = name.replace(/(?<=\S)-\s+/g, ' ');
    name = name.replace(/^-+|-+$/g, '');

    // ── STEP 11: Remove "transl." parenthetical leftovers ──
    // After bracket removal, might leave "transl Hi Dad" etc.
    name = name.replace(/\btransl\.?\s+\w[\w\s]*/gi, '');

    // ── STEP 12: Extract year ──
    let year = null;
    let partNumber = null;
    const yearMatches = [...name.matchAll(/\b((?:19|20)\d{2})\b/g)];

    if (yearMatches.length > 0) {
        const nameWords = name.trim().split(/\s+/);

        // Check for year-in-title patterns like "Scam 1992", "Article 370", "Kalki 2898 AD"
        // Also protect pure year titles like "2012", "1917"
        const isYearTitle = yearMatches.length === 1 &&
            (nameWords.length === 1 || YEAR_TITLES.has(yearMatches[0][1]));

        // Check if year is part of compound title like "Scam 1992", "Kalki 2898 AD"
        let yearIsPartOfTitle = false;
        if (!isYearTitle) {
            for (const ym of yearMatches) {
                const yVal = parseInt(ym[1], 10);
                const yIdx = ym.index;
                const beforeYear = name.substring(0, yIdx).trim();
                const afterYear = name.substring(yIdx + 4).trim();

                // If year is followed by words that look like title continuation (not junk)
                // e.g. "Scam 1992 S01" — "1992" is title, "S01" is episode marker
                // e.g. "Kalki 2898 AD" — "2898" is title
                if (YEAR_TITLES.has(ym[1])) {
                    yearIsPartOfTitle = true;
                    break;
                }
            }
        }

        if (isYearTitle || yearIsPartOfTitle) {
            // Don't extract year from title
            // But still try to find a release year AFTER the title-year
            // Find the last year that is NOT in YEAR_TITLES
            for (let i = yearMatches.length - 1; i >= 0; i--) {
                if (!YEAR_TITLES.has(yearMatches[i][1])) {
                    const possibleYear = parseInt(yearMatches[i][1], 10);
                    const currentYear = new Date().getFullYear();
                    if (possibleYear >= 1920 && possibleYear <= currentYear + 2) {
                        year = possibleYear;
                        const yearIndex = yearMatches[i].index;
                        const afterYear = name.substring(yearIndex + 4).trim();
                        const partAfterYear = afterYear.match(/^\s*(?:Part|Pt)\s*(\d+)/i);
                        if (partAfterYear) {
                            partNumber = parseInt(partAfterYear[1], 10);
                        }
                        name = name.substring(0, yearIndex).trim();
                        break;
                    }
                }
            }
        } else {
            // Use the LAST year
            const lastYearMatch = yearMatches[yearMatches.length - 1];
            const possibleYear = parseInt(lastYearMatch[1], 10);
            const currentYear = new Date().getFullYear();

            if (possibleYear >= 1920 && possibleYear <= currentYear + 2) {
                year = possibleYear;
                const yearIndex = lastYearMatch.index;
                const afterYear = name.substring(yearIndex + 4).trim();

                const partAfterYear = afterYear.match(/^\s*(?:Part|Pt)\s*(\d+)/i);
                if (partAfterYear) {
                    partNumber = parseInt(partAfterYear[1], 10);
                }

                name = name.substring(0, yearIndex).trim();
            }
        }
    }

    // ── STEP 13: Remove junk keywords ──
    name = name.replace(JUNK_REGEX, ' ');
    name = name.replace(/English/g, ' ');
    name = name.replace(/Tamil/g, ' ');
    name = name.replace(/Telugu/g, ' ');
    name = name.replace(/Korean/g, ' ');
    name = name.replace(/Japanese/g, ' ');
    name = name.replace(/Chinese/g, ' ');
    name = name.replace(/French/g, ' ');
    name = name.replace(/Spanish/g, ' ');
    name = name.replace(/German/g, ' ');
    name = name.replace(/Italian/g, ' ');
    name = name.replace(/Russian/g, ' ');
    name = name.replace(/Portuguese/g, ' ');
    name = name.replace(/Arabic/g, ' ');
    name = name.replace("Hindi", ' ');

    // ── STEP 14: Remove "+" used as separator for languages ──
    // "Hindi + Telugu" already removed, but leftover "+" signs
    name = name.replace(/\s*\+\s*/g, ' ');

    // ── STEP 15: Handle "AKA" — keep primary title only ──
    const akaIndex = name.search(/\bAKA\b/i);
    if (akaIndex > 2) {
        name = name.substring(0, akaIndex).trim();
    }

    // ── STEP 16: Extract part number if not already found ──
    if (partNumber === null) {
        const partMatch = name.match(/\b(?:Part|Pt)\s*(\d+)\b/i);
        if (partMatch) {
            partNumber = parseInt(partMatch[1], 10);
            name = name.replace(partMatch[0], ' ');
        }
    }

    // ── STEP 17: Remove episode title after episode marker ──
    // For TV shows like "Loki_S02E01_Ouroboros" — the episode title "Ouroboros" is after the marker
    // This is handled in extractTVShowTitle, but clean any residual episode-title-looking words

    // ── STEP 18: Remove orphan trailing numbers ──
    const cleanWords = name.trim().split(/\s+/).filter(w => w.length > 0);
    if (cleanWords.length > 2) {
        const last = cleanWords[cleanWords.length - 1];
        if (/^(1080|720|480|576|2160|264|265)$/.test(last)) {
            cleanWords.pop();
            name = cleanWords.join(' ');
        }
    }

    // ── STEP 19: Remove trailing "HEp" or similar short junk ──
    name = name.replace(/\s+HEp$/i, '');

    // ── STEP 20: Final cleanup ──
    name = name.replace(/\s+/g, ' ').trim();
    name = name.replace(/^[\s\-–—:,.']+|[\s\-–—:,.]+$/g, '').trim();
    name = name.replace(/\s{2,}/g, ' ');
    name = name.replace(/\s*&\s*/g, ' & ');

    // Remove trailing lone "A" or similar articles that got orphaned
    name = name.replace(/\s+[A-Z]$/, '').trim();

    // ── STEP 21: Smart title case ──
    if (name.length > 0) {
        name = smartTitleCase(name);
    }

    return { title: name, year, partNumber };
}

/**
 * Smart title case — preserves acronyms, Roman numerals, intentional casing.
 */
function smartTitleCase(str) {
    return str.split(' ').map((word, index, arr) => {
        if (!word) return '';

        // Preserve Roman numerals
        if (/^[IVXLCDM]+$/i.test(word) && /^(I{1,3}|IV|V|VI{0,3}|IX|X{1,3}|XI{1,3}|XIV|XV|XVI{0,3}|L|C|D|M)+$/i.test(word.toUpperCase())) {
            return word.toUpperCase();
        }

        // Preserve short ALL-CAPS (acronyms: FBI, CIA, DC, LA, NYC, FROM, HIT)
        if (word.length >= 2 && word.length <= 5 && /^[A-Z0-9]+$/.test(word)) {
            return word;
        }

        // Preserve Se7en style
        if (/\d/.test(word) && /[a-zA-Z]/.test(word)) {
            return word;
        }

        // Preserve mixed-case patterns: McQueen, iPhone, O'Brien, DeNiro
        if (/^(?:Mc|Mac|O'|De|Le|La|Di|Al)[A-Z]/.test(word)) return word;
        if (/^[a-z][A-Z]/.test(word)) return word;

        // Handle apostrophes: Don't, It's, Wife's
        if (word.includes("'")) {
            const parts = word.split("'");
            return parts.map((p, i) => {
                if (i === 0) return p.charAt(0).toUpperCase() + p.slice(1).toLowerCase();
                if (p.length <= 1) return p.toLowerCase();
                // "s" after apostrophe stays lowercase (Wife's)
                if (p.toLowerCase() === 's') return 's';
                if (p.toLowerCase() === 't') return 't';
                return p.toLowerCase();
            }).join("'");
        }

        const lower = word.toLowerCase();

        // Articles/prepositions — lowercase unless first or last word
        if (index > 0 && index < arr.length - 1 && LOWERCASE_WORDS.has(lower)) {
            return lower;
        }

        // Numbers with ordinals
        if (/^\d+(st|nd|rd|th)$/i.test(word)) {
            return word.toLowerCase();
        }

        return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    }).join(' ');
}

// ============================================================
// PHASE 2 — TV Episode Detection
// ============================================================

/**
 * Detects if a file is a TV episode and extracts season/episode numbers.
 */
function detectTVEpisode(filename) {
    if (!filename) return { type: 'movie', season: null, episode: null, episodeEnd: null };

    const normalized = filename.replace(/[._]/g, ' ');

    // Pattern 1: Standard — S01E01, S01_E01, S01EP01, S01 EP01, S01E01E02, S01E01-E02
    const standardMatch = normalized.match(TV_PATTERN_STANDARD);
    if (standardMatch) {
        return {
            type: 'tv',
            season: parseInt(standardMatch[1], 10),
            episode: parseInt(standardMatch[2], 10),
            episodeEnd: standardMatch[3] ? parseInt(standardMatch[3], 10) : null
        };
    }

    // Pattern 2: Verbose — "Season 1 Episode 12"
    const verboseMatch = normalized.match(TV_PATTERN_VERBOSE);
    if (verboseMatch) {
        return {
            type: 'tv',
            season: parseInt(verboseMatch[1], 10),
            episode: parseInt(verboseMatch[2], 10),
            episodeEnd: null
        };
    }

    // Pattern 3: Cross — "01x12"
    const crossMatch = normalized.match(TV_PATTERN_CROSS);
    if (crossMatch) {
        return {
            type: 'tv',
            season: parseInt(crossMatch[1], 10),
            episode: parseInt(crossMatch[2], 10),
            episodeEnd: null
        };
    }

    // Pattern 4: "Episode 12", "EP12"
    const episodeOnlyMatch = normalized.match(TV_PATTERN_EPISODE_ONLY);
    if (episodeOnlyMatch) {
        return {
            type: 'tv',
            season: 1,
            episode: parseInt(episodeOnlyMatch[1], 10),
            episodeEnd: null
        };
    }

    // Pattern 5: Bare "E01"
    const bareEMatch = normalized.match(TV_PATTERN_BARE_E);
    if (bareEMatch) {
        const eNum = parseInt(bareEMatch[1], 10);
        if (eNum >= 1 && eNum <= 999) {
            return {
                type: 'tv',
                season: 1,
                episode: eNum,
                episodeEnd: null
            };
        }
    }

    // Pattern 6: Anime-style " - 01"
    const animeMatch = normalized.match(TV_PATTERN_ANIME);
    if (animeMatch) {
        const epNum = parseInt(animeMatch[1], 10);
        if (epNum >= 1 && epNum <= 999) {
            return {
                type: 'tv',
                season: 1,
                episode: epNum,
                episodeEnd: null
            };
        }
    }

    // Pattern 7: Season-only "S01" without episode (Complete season)
    const seasonOnlyMatch = normalized.match(TV_PATTERN_SEASON_ONLY);
    if (seasonOnlyMatch) {
        return {
            type: 'tv',
            season: parseInt(seasonOnlyMatch[1], 10),
            episode: 1,
            episodeEnd: null
        };
    }

    return { type: 'movie', season: null, episode: null, episodeEnd: null };
}

// ============================================================
// PHASE 3 — TV Show Title Extraction
// ============================================================

/**
 * Extracts the TV show title from the filename.
 */
function extractTVShowTitle(filename, parentFolderName = null) {
    if (!filename) {
        if (parentFolderName) return cleanMediaFilename(parentFolderName + '.mkv');
        return { title: '', year: null, partNumber: null };
    }

    const normalized = filename.replace(/[._]/g, ' ');

    for (const pattern of EPISODE_MARKER_PATTERNS) {
        const matchIndex = normalized.search(pattern);
        if (matchIndex > 0) {
            const rawTitle = normalized.substring(0, matchIndex).trim();
            if (rawTitle.length > 0) {
                return cleanMediaFilename(rawTitle + '.mkv');
            }
        }
    }

    // Fallback 1: Parent folder name
    if (parentFolderName) {
        return cleanMediaFilename(parentFolderName + '.mkv');
    }

    // Fallback 2: Clean the whole filename
    return cleanMediaFilename(filename);
}

// ============================================================
// EXPORTS
// ============================================================
module.exports = {
    cleanMediaFilename,
    detectTVEpisode,
    extractTVShowTitle,
    smartTitleCase
};