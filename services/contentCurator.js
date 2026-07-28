/**
 * ContentCurator — Server-side curation engine for StreamFlix
 * 
 * Processes raw metadata into smart, deduplicated content sections
 * for the homepage, genre page, and special sections.
 * 
 * Key features:
 * - Show deduplication (one entry per TV show, not per episode)
 * - Multi-audio, language, quality detection from metadata
 * - Max 3 appearances per item across all sections
 * - StreamFlix intelligence: _tracksDetected, needsTranscoding awareness
 */

// ============================================================
// CONFIGURATIONS
// ============================================================
const collectionNames = require('../config/collectionNames');
const topStreamingServices = require('../config/topStreamingServices');
const originalStudios = require('../config/originalStudios');

// ============================================================
// HELPERS
// ============================================================

const HANGUL_REGEX = /[\uAC00-\uD7AF]/;
const JAPANESE_REGEX = /[\u3040-\u30FF\u4E00-\u9FFF]/;
const DEVANAGARI_REGEX = /[\u0900-\u097F]/;

function isTVContent(item) {
  return (item.tv && item.tv.showTmdbId) || (item.type && item.type.toLowerCase() === 'tv');
}

function isMovieContent(item) {
  if (isTVContent(item)) return false;
  if (!item.fileId || !item.title) return false;
  return true;
}

function getAudioLanguages(item) {
  if (!item.audioTracks || !Array.isArray(item.audioTracks)) return [];
  return item.audioTracks.map(t => (t.language || '').trim()).filter(Boolean);
}

function hasLanguage(item, lang) {
  return getAudioLanguages(item).some(l => l.toLowerCase() === lang.toLowerCase());
}

function isMultiAudio(item) {
  return item.audioTracks && Array.isArray(item.audioTracks) && item.audioTracks.length > 1;
}

function parseQuality(fileName) {
  if (!fileName) return null;
  const match = fileName.match(/(2160p|1080p|720p|480p|4K)/i);
  if (!match) return null;
  return match[1].toLowerCase() === '4k' ? '4K' : match[1];
}

function runtimeMinutes(item) {
  // duration is in seconds from ffprobe, runtime is in minutes from TMDB
  if (item.runtime && item.runtime > 0) return item.runtime;
  if (item.duration && item.duration > 0) return Math.round(item.duration / 60);
  if (item.tv && item.tv.episodeRuntime) return item.tv.episodeRuntime;
  return 0;
}

// ============================================================
// SHOW DEDUPLICATION — Collapse TV episodes into show entries
// ============================================================

function buildShowMap(allItems) {
  const tvShowsMap = new Map();

  for (const item of allItems) {
    if (!isTVContent(item)) continue;
    if (!item.tv || !item.tv.showTmdbId) continue;
    const showId = item.tv.showTmdbId;

    if (!tvShowsMap.has(showId)) {
      tvShowsMap.set(showId, {
        _curationType: 'tv',
        showTmdbId: showId,
        id: `show_${showId}`,
        fileId: item.fileId || '',
        maxFileId: Number(item.fileId) || 0,
        type: 'tv',
        title: item.tv.showTitle || item.title,
        originalTitle: item.tv.originalShowTitle || item.originalTitle || '',
        overview: item.overview || '',
        genres: item.genres || [],
        rating: item.rating || 0,
        popularity: item.popularity || 0,
        poster: item.poster,
        backdrop: item.backdrop,
        logo: item.logo || null,
        year: item.year,
        runtime: item.runtime || item.tv.episodeRuntime || 0,
        fetchedAt: item.fetchedAt,
        certification: item.certification || '',
        audioTracks: item.audioTracks || [],
        subtitleTracks: item.subtitleTracks || [],
        _tracksDetected: item._tracksDetected || false,
        needsTranscoding: item.needsTranscoding || false,
        browserPlayable: item.browserPlayable !== false,
        fileName: item.fileName,
        episodeCount: 1,
        _hasMultiAudio: false,
        _allAudioLanguages: new Set(),
        collection: item.collection || null,
        releaseDate: item.tv.firstAirDate || item.releaseDate,
        watchProviders: item.watchProviders || null,
        productionCompanies: item.productionCompanies || [],
        keywords: item.keywords || [],
      });
    }

    const show = tvShowsMap.get(showId);
    show.episodeCount++;

    // Accumulate audio languages across all episodes
    for (const lang of getAudioLanguages(item)) {
      show._allAudioLanguages.add(lang);
    }

    // If ANY episode has multi-audio, flag the show
    if (isMultiAudio(item)) show._hasMultiAudio = true;

    // Upgrade metadata from later episodes if better
    if (!show.backdrop && item.backdrop) show.backdrop = item.backdrop;
    if (!show.poster && item.poster) show.poster = item.poster;
    if (!show.logo && item.logo && item.logo !== 'N/A') show.logo = item.logo;
    if (item.rating > show.rating) show.rating = item.rating;
    if (item.popularity > show.popularity) show.popularity = item.popularity;
    if (item._tracksDetected) show._tracksDetected = true;
    if (item.needsTranscoding) show.needsTranscoding = true;

    const epFileId = Number(item.fileId) || 0;
    if (epFileId > (show.maxFileId || 0)) {
      show.maxFileId = epFileId;
      show.fileId = item.fileId;
    }

    // Use the most recent fetchedAt
    if (item.fetchedAt && (!show.fetchedAt || new Date(item.fetchedAt) > new Date(show.fetchedAt))) {
      show.fetchedAt = item.fetchedAt;
    }
  }

  // Finalize shows — convert language sets to arrays for matching
  for (const show of tvShowsMap.values()) {
    show._audioLanguagesList = [...show._allAudioLanguages];
    delete show._allAudioLanguages;
  }

  return Array.from(tvShowsMap.values());
}

// ============================================================
// MOVIE GROUPING — Handle split/multi-part movies
// ============================================================

function groupMoviesByTmdb(allItems) {
  const tmdbGroups = new Map();
  const noTmdbId = [];

  for (const item of allItems) {
    if (!isMovieContent(item)) continue;

    const movieItem = {
      _curationType: 'movie',
      id: item.fileId,
      type: 'movie',
      title: item.title,
      originalTitle: item.originalTitle || '',
      overview: item.overview || '',
      genres: item.genres || [],
      rating: item.rating || 0,
      popularity: item.popularity || 0,
      poster: item.poster,
      backdrop: item.backdrop,
      logo: item.logo || null,
      year: item.year,
      runtime: runtimeMinutes(item),
      fetchedAt: item.fetchedAt,
      certification: item.certification || '',
      audioTracks: item.audioTracks || [],
      subtitleTracks: item.subtitleTracks || [],
      _tracksDetected: item._tracksDetected || false,
      needsTranscoding: item.needsTranscoding || false,
      browserPlayable: item.browserPlayable !== false,
      fileName: item.fileName,
      tmdbId: item.tmdbId,
      isSplit: item.isSplit || false,
      totalParts: item.totalParts || 1,
      collection: item.collection || null,
      releaseDate: item.releaseDate || item.year,
      watchProviders: item.watchProviders || null,
      productionCompanies: item.productionCompanies || [],
      keywords: item.keywords || [],
    };

    if (item.tmdbId && item.tmdbId !== 0) {
      if (!tmdbGroups.has(item.tmdbId)) tmdbGroups.set(item.tmdbId, []);
      tmdbGroups.get(item.tmdbId).push(movieItem);
    } else {
      noTmdbId.push(movieItem);
    }
  }

  const result = [];

  for (const [, group] of tmdbGroups) {
    if (group.length === 1) {
      result.push(group[0]);
    } else {
      // Multiple files with same tmdbId = split movie. Use first as representative.
      const primary = { ...group[0] };
      primary.maxFileId = Math.max(...group.map(g => Number(g.fileId) || 0));
      primary.isSplit = true;
      primary.totalParts = group.length;
      result.push(primary);
    }
  }

  result.push(...noTmdbId);
  return result;
}

// ============================================================
// SECTION BUILDER — Core curation logic
// ============================================================

class SectionBuilder {
  constructor() {
    this.appearanceCount = new Map(); // id -> count
    this.MAX_APPEARANCES = 3;
  }

  /**
   * Take items from a sorted/filtered list, respecting the appearance limit.
   * @param {Array} items - Pre-sorted items
   * @param {number} count - Max items to take
   * @param {boolean} trackAppearances - Whether to count towards the limit
   * @returns {Array} - Selected items
   */
  take(items, count, trackAppearances = true) {
    const result = [];
    for (const item of items) {
      if (result.length >= count) break;
      const id = item.id;
      const current = this.appearanceCount.get(id) || 0;
      if (current >= this.MAX_APPEARANCES) continue;

      // Skip items without any visual representation
      if (!item.poster && !item.backdrop) continue;

      result.push(this._formatItem(item));
      if (trackAppearances) {
        this.appearanceCount.set(id, current + 1);
      }
    }
    return result;
  }

  _formatItem(item) {
    const itemId = item.id || item.fileId || (item.tmdbId ? String(item.tmdbId) : (item.showTmdbId ? 'show_' + item.showTmdbId : null));
    const itemTitle = item.title || item.showTitle || item.name || (item.tv && item.tv.episodeTitle) || 'Untitled';
    return {
      id: itemId || ('item_' + Math.random().toString(36).substring(2, 9)),
      fileId: item.fileId || item.id || '',
      maxFileId: item.maxFileId || Number(item.fileId) || 0,
      title: itemTitle,
      thumbnail: item.poster || item.thumbnail || '',
      backdrop: item.backdrop || null,
      rating: item.rating || 0,
      year: item.year || 0,
      duration: item.runtime || 0,
      genres: item.genres || [],
      description: item.overview ? item.overview.substring(0, 200) : '',
      type: item.type || (item.showTmdbId ? 'tv' : 'movie'),
      logo: item.logo || null,
      certification: item.certification || '',
      episodeCount: item.episodeCount || 0,
      isSplit: item.isSplit || false,
      totalParts: item.totalParts || 1,
    };
  }
}

// ============================================================
// MAIN CURATION FUNCTION
// ============================================================

async function curate(allRawItems) {
  // 1. Build unified content pool (deduplicated shows + grouped movies)
  const shows = buildShowMap(allRawItems);
  const movies = groupMoviesByTmdb(allRawItems);
  const allContent = [...movies, ...shows];

  // Prefer items with complete metadata
  const preferComplete = (a, b) => {
    if (a._tracksDetected && !b._tracksDetected) return -1;
    if (!a._tracksDetected && b._tracksDetected) return 1;
    return 0;
  };

  // Sort helpers
  const byPopularity = (a, b) => (b.popularity - a.popularity) || preferComplete(a, b);
  const byRating = (a, b) => (b.rating - a.rating) || preferComplete(a, b);
  const byRecent = (a, b) => {
    const getId = (item) => {
      if (item.maxFileId) return Number(item.maxFileId);
      if (item.fileId) return Number(item.fileId);
      if (typeof item.id === 'number') return item.id;
      if (typeof item.id === 'string') return Number(item.id.replace(/\D/g, '')) || 0;
      return 0;
    };
    const aId = getId(a);
    const bId = getId(b);
    if (aId !== bId) {
      return bId - aId;
    }
    const aTime = a.fetchedAt ? new Date(a.fetchedAt).getTime() : 0;
    const bTime = b.fetchedAt ? new Date(b.fetchedAt).getTime() : 0;
    return (bTime - aTime) || preferComplete(a, b);
  };
  const byYear = (a, b) => (b.year - a.year) || byPopularity(a, b);

  const builder = new SectionBuilder();

  // ========== HOMEPAGE SECTIONS ==========

  // Hero Section (5-8 items): High rating OR high popularity, require backdrop
  const heroPool = [...allContent]
    .filter(i => i.backdrop && (i.rating >= 5 || i.popularity >= 20))
    .sort((a, b) => {
      const aScore = (a.rating || 0) * 0.6 + Math.min(a.popularity || 0, 500) * 0.004;
      const bScore = (b.rating || 0) * 0.6 + Math.min(b.popularity || 0, 500) * 0.004;
      return bScore - aScore;
    });

  // Take top 25 candidates, shuffle, pick 8 with movie/TV mix
  const heroCandidates = heroPool.slice(0, 25);
  shuffleArray(heroCandidates);
  const heroTV = heroCandidates.filter(i => i.type === 'tv').slice(0, 3);
  const heroMovies = heroCandidates.filter(i => i.type === 'movie').slice(0, 8 - heroTV.length);
  let heroItems = [...heroMovies, ...heroTV];
  shuffleArray(heroItems);
  
  const heroMovie = { ...heroCandidates[0] };
  
  // Attach provider logo for the hero banner
  if (heroMovie.productionCompanies && heroMovie.productionCompanies.length > 0) {
    for (const [normName, studios] of Object.entries(originalStudios)) {
      const isOriginal = heroMovie.productionCompanies.some(company => studios.includes(company.name.toLowerCase()));
      if (isOriginal) {
        if (heroMovie.watchProviders && heroMovie.watchProviders.flatrate) {
          const prov = heroMovie.watchProviders.flatrate.find(p => topStreamingServices.normalized[p.name.toLowerCase()] === normName);
          if (prov) heroMovie.providerLogo = prov.logo_path;
        }
        break;
      }
    }
  }
  if (!heroMovie.providerLogo && heroMovie.watchProviders && heroMovie.watchProviders.flatrate) {
    const priority = ['Netflix', 'Prime Video', 'Apple TV+', 'SonyLIV', 'JioHotstar', 'ZEE5', 'Aha'];
    let chosenLogo = null;
    for (const p of priority) {
      const prov = heroMovie.watchProviders.flatrate.find(prov => topStreamingServices.normalized[prov.name.toLowerCase()] === p);
      if (prov) {
        chosenLogo = prov.logo_path;
        break;
      }
    }
    if (!chosenLogo && heroMovie.watchProviders.flatrate.length > 0) {
      chosenLogo = heroMovie.watchProviders.flatrate[0].logo_path;
    }
    heroMovie.providerLogo = chosenLogo;
  }
  
  const hero = [builder._formatItem(heroMovie), ...builder.take(heroItems.filter(h => h.id !== heroMovie.id), 7, false)];

  // Trending Now
  const trending = builder.take([...allContent].sort(byPopularity), 15);

  // Recently Added
  const recentlyAdded = builder.take([...allContent].sort(byRecent), 15);

  // Top Rated
  const topRated = builder.take(
    [...allContent].filter(i => i.rating >= 7).sort(byRating),
    15
  );

  // ========== STREAMFLIX-SPECIFIC SECTIONS ==========

  // Multi Audio Picks
  const multiAudioItems = allContent.filter(i => {
    if (i._curationType === 'tv') return i._hasMultiAudio;
    return isMultiAudio(i);
  });
  const multiAudio = builder.take([...multiAudioItems].sort(byPopularity), 15);

  // Language Collections
  const hindiItems = allContent.filter(i => {
    if (i._curationType === 'tv') return i._audioLanguagesList && i._audioLanguagesList.some(l => l.toLowerCase() === 'hindi');
    return hasLanguage(i, 'Hindi');
  });
  const hindi = builder.take([...hindiItems].sort(byPopularity), 15);

  const englishItems = allContent.filter(i => {
    if (i._curationType === 'tv') return i._audioLanguagesList && i._audioLanguagesList.some(l => l.toLowerCase() === 'english');
    return hasLanguage(i, 'English');
  });
  const english = builder.take([...englishItems].sort(byPopularity), 15);

  const koreanItems = allContent.filter(i => {
    if (i._curationType === 'tv') {
      const hasKoreanAudio = i._audioLanguagesList && i._audioLanguagesList.some(l => l.toLowerCase() === 'korean');
      const hasKoreanTitle = HANGUL_REGEX.test(i.originalTitle || '');
      return hasKoreanAudio || hasKoreanTitle;
    }
    return hasLanguage(i, 'Korean') || HANGUL_REGEX.test(i.originalTitle || '');
  });
  const kdrama = builder.take([...koreanItems].sort(byPopularity), 15);

  const animeItems = allContent.filter(i => {
    const hasJapanese = i._curationType === 'tv'
      ? (i._audioLanguagesList && i._audioLanguagesList.some(l => l.toLowerCase() === 'japanese'))
      : hasLanguage(i, 'Japanese');
    const hasJapaneseTitle = JAPANESE_REGEX.test(i.originalTitle || '');
    const hasAnimationGenre = (i.genres || []).some(g => g.toLowerCase().includes('animation'));
    return (hasJapanese || hasJapaneseTitle) && hasAnimationGenre;
  });
  const anime = builder.take([...animeItems].sort(byPopularity), 15);

  // Quick Watch (< 90 min, movies only)
  const quickWatchItems = movies.filter(i => {
    const mins = runtimeMinutes(i);
    return mins > 0 && mins < 90;
  });
  const quickWatch = builder.take([...quickWatchItems].sort(byPopularity), 15);

  // ============================================================
  // SPECIAL COLLECTIONS
  // ============================================================

  // Recently Fixed (_tracksDetected recently added)
  const recentlyFixed = builder.take(
    [...allContent].filter(i => i._tracksDetected === true).sort(byRecent),
    10
  );

  // ========== GENRE ROWS ==========
  const GENRES = [
    'Action', 'Comedy', 'Drama', 'Romance', 'Crime',
    'Sci-Fi & Fantasy', 'Thriller', 'Animation', 'Family',
    'Horror', 'Mystery', 'Documentary', 'War', 'Music',
    'Action & Adventure', 'Science Fiction'
  ];

  // Also normalize genre matching for combined genres
  const genreAliases = {
    'sci-fi': ['Sci-Fi & Fantasy', 'Science Fiction', 'Sci-Fi'],
    'action': ['Action', 'Action & Adventure'],
    'family': ['Family', 'Kids'],
  };

  function matchesGenre(item, genre) {
    const itemGenres = (item.genres || []).map(g => g.toLowerCase());
    const gLower = genre.toLowerCase();

    // Direct match
    if (itemGenres.includes(gLower)) return true;

    // Alias match
    const aliases = genreAliases[gLower];
    if (aliases) return aliases.some(a => itemGenres.includes(a.toLowerCase()));

    // Partial match (e.g., "Action" matches "Action & Adventure")
    return itemGenres.some(ig => ig.includes(gLower) || gLower.includes(ig));
  }

  const genreRows = {};
  const discoveredGenres = new Set();

  // Discover all genres from content
  for (const item of allContent) {
    for (const g of (item.genres || [])) {
      discoveredGenres.add(g);
    }
  }

  // Build rows for discovered genres that have enough content
  for (const genre of discoveredGenres) {
    const genreItems = allContent.filter(i => matchesGenre(i, genre));
    if (genreItems.length >= 4) {
      const slug = 'genre_' + genre.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/_+$/, '');
      genreRows[slug] = {
        title: genre,
        items: builder.take([...genreItems].sort(byPopularity), 20)
      };
    }
  }

  // ========== COLLECTION ROWS ==========
  let collectionNames = {};
  try {
    collectionNames = require('../config/collectionNames');
  } catch (err) {
    console.warn('[Curator] config/collectionNames.js not found or invalid.');
  }

  const collectionsMap = new Map();
  for (const item of allContent) {
    if (item.collection && item.collection.id) {
      if (!collectionsMap.has(item.collection.id)) {
        collectionsMap.set(item.collection.id, {
          id: item.collection.id,
          name: item.collection.name,
          items: []
        });
      }
      collectionsMap.get(item.collection.id).items.push(item);
    }
  }

  const collectionRows = {};
  for (const [colId, colData] of collectionsMap.entries()) {
    if (colData.items.length >= 2) {
      let displayName = collectionNames[colData.name] || collectionNames[colId] || colData.name;
      if (!displayName.toLowerCase().includes('collection')) {
        displayName += ' Collection';
      }
      const slug = 'collection_' + colId;
      // Sort by release order (oldest first)
      const sortedItems = [...colData.items].sort((a, b) => {
        const dateA = a.releaseDate ? new Date(a.releaseDate).getTime() : (a.year ? new Date(a.year, 0, 1).getTime() : 0);
        const dateB = b.releaseDate ? new Date(b.releaseDate).getTime() : (b.year ? new Date(b.year, 0, 1).getTime() : 0);
        return dateA - dateB;
      });
      collectionRows[slug] = {
        title: displayName,
        items: sortedItems.map(item => builder._formatItem(item)) // Bypass deduplication for collections
      };
    }
  }

  // ========== STREAMING PROVIDER & ORIGINALS ROWS ==========
  const providerGroups = new Map();
  const originalsGroups = new Map();

  for (const item of allContent) {
    let isOriginalContent = false;
    let primaryProvider = null;

    if (item.productionCompanies && item.productionCompanies.length > 0) {
      for (const [normName, studios] of Object.entries(originalStudios)) {
        const isOriginal = item.productionCompanies.some(company => {
          return studios.includes(company.name.toLowerCase());
        });
        if (isOriginal) {
          primaryProvider = normName;
          isOriginalContent = true;
          break;
        }
      }
    }

    if (isOriginalContent) {
      if (!originalsGroups.has(primaryProvider)) {
        let logo = null;
        if (item.watchProviders && item.watchProviders.flatrate) {
          const prov = item.watchProviders.flatrate.find(p => topStreamingServices.normalized[p.name.toLowerCase()] === primaryProvider);
          if (prov) logo = prov.logo_path;
        }
        originalsGroups.set(primaryProvider, { items: [], logoPath: logo });
      }
      originalsGroups.get(primaryProvider).items.push(item);
    }

    if (item.watchProviders && item.watchProviders.flatrate) {
      const validProviders = new Set();
      for (const prov of item.watchProviders.flatrate) {
        const rawName = prov.name.toLowerCase();
        const normName = topStreamingServices.normalized[rawName];
        if (normName) {
          validProviders.add(normName);
        }
      }

      if (validProviders.size > 0 && !isOriginalContent) {
        let chosenProvider = null;
        const priority = ['Netflix', 'Prime Video', 'Apple TV+', 'SonyLIV', 'JioHotstar', 'ZEE5', 'Aha'];
        for (const p of priority) {
          if (validProviders.has(p)) {
            chosenProvider = p;
            break;
          }
        }
        if (!chosenProvider) {
          chosenProvider = validProviders.values().next().value;
        }

        if (!providerGroups.has(chosenProvider)) {
          let chosenLogo = null;
          const prov = item.watchProviders.flatrate.find(p => topStreamingServices.normalized[p.name.toLowerCase()] === chosenProvider);
          if (prov) chosenLogo = prov.logo_path;
          providerGroups.set(chosenProvider, { items: [], logoPath: chosenLogo });
        }
        providerGroups.get(chosenProvider).items.push(item);
      }
    }
  }

  const providerRows = {};
  for (const [provider, data] of providerGroups.entries()) {
    if (data.items.length >= topStreamingServices.threshold) {
      const slug = 'provider_' + provider.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/_+$/, '');
      providerRows[slug] = {
        title: `Now Streaming on ${provider}`,
        logo: data.logoPath,
        items: builder.take([...data.items].sort(byPopularity), data.items.length, true)
      };
    }
  }

  const originalsRows = {};
  for (const [provider, data] of originalsGroups.entries()) {
    if (data.items.length >= topStreamingServices.threshold) {
      const slug = 'original_' + provider.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/_+$/, '');
      const sortedItems = [...data.items].sort(byRecent);
      originalsRows[slug] = {
        title: `${provider} Originals`,
        logo: data.logoPath,
        items: sortedItems.map(item => builder._formatItem(item))
      };
    }
  }

  // ========== KEYWORD ROWS ==========
  const keywordFreq = new Map();
  for (const item of allContent) {
    if (item.keywords && Array.isArray(item.keywords)) {
      for (const kw of item.keywords) {
        if (!kw || typeof kw !== 'string') continue;
        const lowerKw = kw.toLowerCase().trim();
        keywordFreq.set(lowerKw, (keywordFreq.get(lowerKw) || 0) + 1);
      }
    }
  }

  const GENERIC_KEYWORDS = new Set([
    'based on novel or book', 'based on true story', 'sequel', 'prequel', 'superhero',
    'duringcreditsstinger', 'aftercreditsstinger', 'marvel cinematic universe (mcu)', 'remake',
    'based on comic', 'murder', 'police', 'revenge', 'romance', 'anime', 'based on manga',
    'school', 'school life', 'shounen', 'shoujo', 'high school', 'japanese high school',
    'friendship', 'violence', 'tragedy'
  ]);

  const MIN_KEYWORD_COUNT = 5;
  const validKeywords = [];
  for (const [kw, count] of keywordFreq.entries()) {
    if (count >= MIN_KEYWORD_COUNT && !GENERIC_KEYWORDS.has(kw)) {
      validKeywords.push({ keyword: kw, count });
    }
  }

  // Sort by count descending, pick top 8
  validKeywords.sort((a, b) => b.count - a.count);
  const topKeywords = validKeywords.slice(0, 8);

  const keywordRows = {};
  for (const tk of topKeywords) {
    const kwItems = allContent.filter(i => 
      (i.keywords || []).some(k => k.toLowerCase().trim() === tk.keyword)
    );
    if (kwItems.length >= MIN_KEYWORD_COUNT) {
      const slug = 'keyword_' + tk.keyword.replace(/[^a-z0-9]+/g, '_').replace(/_+$/, '');
      const titleCase = tk.keyword.split(' ').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
      keywordRows[slug] = {
        title: `Because you like ${titleCase}`,
        items: builder.take([...kwItems].sort(byPopularity), 20)
      };
    }
  }
  console.log('[Curator] keywordRows generated:', Object.keys(keywordRows).length);

  // ========== GENRES PAGE ==========
  const genresPage = buildGenresPage(allContent, discoveredGenres);

  // ========== SPECIAL SECTIONS ==========
  const specialSections = buildSpecialSections(allContent, movies, shows, builder);

  // ========== DISCOVER ROWS (Phase 7) ==========
  const discoverRowsData = {};
  try {
    const fs = require('fs');
    const path = require('path');
    const tmdbResolver = require('./tmdbResolver');
    const discoverConfig = require('../config/discoverRows');
    const discoverJsonPath = path.join(__dirname, '../data/metadata/discoverRows.json');
    if (fs.existsSync(discoverJsonPath)) {
      const parsed = JSON.parse(fs.readFileSync(discoverJsonPath, 'utf8'));
      for (const row of discoverConfig) {
        if (parsed[row.id] && Array.isArray(parsed[row.id])) {
          const resolved = await tmdbResolver.resolveTmdbIds(parsed[row.id]);
          if (resolved.length >= 5) {
            discoverRowsData[row.id] = {
              title: row.title,
              items: builder.take(resolved, 20)
            };
          }
        }
      }
    }
  } catch (err) {
    console.error('[Curator] Error resolving discover rows:', err);
  }

  return {
    homepage: {
      hero,
      trending,
      recently_added: recentlyAdded,
      top_rated: topRated,
      discover: discoverRowsData,
      rows: {
        multi_audio: { title: 'Multi-Audio Hits', items: multiAudio },
        hindi: { title: 'Hindi Movies', items: hindi },
        english: { title: 'English Movies', items: english },
        kdrama: { title: 'K-Drama Collection', items: kdrama },
        anime: { title: 'Anime Collection', items: anime },
        quick_watch: { title: 'Quick Watches', items: quickWatch },
        recently_fixed: { title: 'Recently Restored', items: recentlyFixed },
        special_top_rated: { title: 'Top Rated', items: topRated },
        special_movies: { title: 'Movies', items: builder.take([...movies].sort(byPopularity), 20) },
        special_tv_shows: { title: 'TV Shows', items: builder.take([...shows].sort(byPopularity), 20) },
        ...originalsRows,
        ...providerRows,
        ...collectionRows,
        ...keywordRows,
        ...genreRows,
        ...discoverRowsData
      }
    },
    genres_page: genresPage,
    special_sections: specialSections,
  };
}

// ============================================================
// GENRES PAGE BUILDER
// ============================================================

function buildGenresPage(allContent, discoveredGenres) {
  const genreCards = [];
  const genreSections = {};

  // Core genres to prioritize in display order
  const coreGenres = [
    'Action', 'Comedy', 'Drama', 'Romance', 'Crime', 'Thriller',
    'Sci-Fi & Fantasy', 'Animation', 'Family', 'Horror', 'Mystery',
    'Documentary', 'Action & Adventure', 'Science Fiction', 'War',
    'Music', 'Western', 'History', 'Adventure',
  ];

  // Process each genre
  const processedSlugs = new Set();

  for (const genre of [...coreGenres, ...discoveredGenres]) {
    const slug = genre.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/_+$/, '');
    if (processedSlugs.has(slug)) continue;

    const genreItems = allContent.filter(i =>
      (i.genres || []).some(g => g.toLowerCase() === genre.toLowerCase())
    );

    if (genreItems.length < 2) continue;
    processedSlugs.add(slug);

    // Genre card — use backdrop from highest rated item
    const bestItem = [...genreItems].sort((a, b) => (b.rating - a.rating))[0];
    genreCards.push({
      name: genre,
      slug,
      image: bestItem.backdrop || bestItem.poster || null,
      count: genreItems.length,
    });

    // Genre sub-sections
    const sectionBuilder = new SectionBuilder();

    const popular = sectionBuilder.take([...genreItems].sort((a, b) => b.popularity - a.popularity), 15);
    const topRated = sectionBuilder.take([...genreItems].filter(i => i.rating >= 6).sort((a, b) => b.rating - a.rating), 15);
    const newItems = sectionBuilder.take([...genreItems].sort((a, b) => (b.year || 0) - (a.year || 0)), 15);
    const hiddenGems = sectionBuilder.take(
      [...genreItems].filter(i => (i.popularity || 0) < 50 && (i.rating || 0) >= 7).sort((a, b) => b.rating - a.rating),
      10
    );
    const multiAudioInGenre = sectionBuilder.take(
      [...genreItems].filter(i => {
        if (i._curationType === 'tv') return i._hasMultiAudio;
        return isMultiAudio(i);
      }).sort((a, b) => b.popularity - a.popularity),
      10
    );
    const recentlyAdded = sectionBuilder.take(
      [...genreItems].sort((a, b) => {
        const aTime = a.fetchedAt ? new Date(a.fetchedAt).getTime() : 0;
        const bTime = b.fetchedAt ? new Date(b.fetchedAt).getTime() : 0;
        return bTime - aTime;
      }),
      15
    );

    genreSections[slug] = {
      popular,
      top_rated: topRated,
      new: newItems,
      hidden_gems: hiddenGems,
      multi_audio: multiAudioInGenre,
      recently_added: recentlyAdded,
    };
  }

  return { genres: genreCards, sections: genreSections };
}

// ============================================================
// SPECIAL SECTIONS BUILDER
// ============================================================

function buildSpecialSections(allContent, movies, shows, builder) {
  // Mood-Based
  const feelGood = builder.take(
    [...allContent].filter(i => {
      const genres = (i.genres || []).map(g => g.toLowerCase());
      return genres.some(g => g.includes('comedy') || g.includes('family') || g.includes('music'));
    }).sort((a, b) => b.popularity - a.popularity),
    15
  );

  const darkThriller = builder.take(
    [...allContent].filter(i => {
      const genres = (i.genres || []).map(g => g.toLowerCase());
      return genres.some(g => g.includes('thriller') || g.includes('crime') || g.includes('horror'));
    }).sort((a, b) => b.rating - a.rating),
    15
  );

  const comedyNights = builder.take(
    [...allContent].filter(i => {
      const genres = (i.genres || []).map(g => g.toLowerCase());
      return genres.some(g => g.includes('comedy'));
    }).sort((a, b) => b.popularity - a.popularity),
    15
  );

  const emotional = builder.take(
    [...allContent].filter(i => {
      const genres = (i.genres || []).map(g => g.toLowerCase());
      return genres.some(g => g.includes('drama') || g.includes('romance'));
    }).sort((a, b) => b.rating - a.rating),
    15
  );

  // Duration-Based
  const quickWatch = builder.take(
    [...movies].filter(i => {
      const mins = runtimeMinutes(i);
      return mins > 0 && mins < 90;
    }).sort((a, b) => b.popularity - a.popularity),
    15
  );

  const longMovies = builder.take(
    [...movies].filter(i => {
      const mins = runtimeMinutes(i);
      return mins > 150;
    }).sort((a, b) => b.rating - a.rating),
    15
  );

  const series = builder.take(
    [...shows].sort((a, b) => b.popularity - a.popularity),
    15
  );

  return {
    mood: {
      feel_good: feelGood,
      dark_thriller: darkThriller,
      comedy_nights: comedyNights,
      emotional,
    },
    duration: {
      quick_watch: quickWatch,
      long_movies: longMovies,
      series,
    }
  };
}

// ============================================================
// UTILITY
// ============================================================

function shuffleArray(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
  return array;
}

module.exports = { curate };
