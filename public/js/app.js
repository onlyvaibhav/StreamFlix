// ============================================================
// STATE — No hardcoded data, everything from API
// ============================================================
const state = {
  data: null,           // Raw API response
  currentRoute: 'home',
  heroIndex: 0,
  heroTimer: null,
  searchTimer: null,
  player: {
    active: false,
    fileId: null,
    title: null,
    tmdbId: null, // For next episode tracking
    season: null,
    episode: null,
    volume: 1,
    muted: false,
    speed: 1,
    audioTracks: [],
    subtitleTracks: [],
    currentAudioTrack: 0,
    currentSubtitleTrack: -1,
    hideControlsTimer: null,
    heartbeatTimer: null,
    abortController: null, // AbortController for all player event listeners
    useClientStreaming: false, // Whether to route chunks through SW
    defaultAudioTrack: 0,
    duration: 0,
    parsedCues: null,
    subtitleVTTCache: {},
    subtitleOffset: 0,
    _syncSeenTime: null,
    _syncStep: 0,           // 0=idle, 1=waiting-for-second, 2=done
    _syncFirstLabel: null,  // 'subtitle' or 'audio'
    _syncFirstTime: null,
    // ---- Multipart seamless playback state ----
    multipart: {
      enabled: false,
      parts: [],             // [{fileId, partNumber, duration, estimated}, ...]
      durationMap: [],       // [{part, fileId, start, end}, ...] cumulative
      currentPartIndex: 0,
      totalDuration: 0,
      completedDuration: 0,  // Sum of durations of finished parts
      _switchLog: [],        // Analytics: [{from, to, delay, success, timestamp}]
      timeline: {
        displayCurrentTime: 0,
        displayTotalDuration: 0,
        displayProgressPercent: 0,
      },
    },
  }
};

let telegramWorker = null;
let telegramWorkerReady = null;

// Helper to guarantee a file is registered with the worker before we point the video source to it
async function ensureFileRegistered(fileId) {
  if (!state.player.useClientStreaming || !telegramWorker) return;
  try {
    const res = await api(`/api/stream/${fileId}/file-info`);
    if (res && telegramWorker) {
      telegramWorker.postMessage({
        type: 'REGISTER_FILE',
        ...res
      });
    }
  } catch (err) {
    console.warn(`[Streaming] Failed to ensure file registered ${fileId}:`, err);
  }
}

async function initTelegramWorker() {
  if ('serviceWorker' in navigator) {
    try {
      const reg = await navigator.serviceWorker.register('/sw.js', { scope: '/' });
      if (reg.installing) {
        await new Promise(resolve => {
          reg.installing.addEventListener('statechange', (e) => {
            if (e.target.state === 'activated') resolve();
          });
        });
      }
    } catch (e) {
      console.warn('SW reg failed', e);
    }
  }

  if (telegramWorkerReady) return telegramWorkerReady;
  
  telegramWorkerReady = (async () => {
    try {
      const token = StreamFlixAuth.sessionToken;
      if (!token) throw new Error('No session');

      const configRes = await fetch('/api/auth/telegram/streaming-config', { headers: { 'Authorization': `Bearer ${token}` }});
      const config = await configRes.json();
      
      const sessionRes = await fetch('/api/auth/telegram/session-string', { headers: { 'Authorization': `Bearer ${token}` }});
      const session = await sessionRes.json();
      
      if (!config.success || !session.success) throw new Error('Failed to fetch streaming credentials');
      
      telegramWorker = new Worker('/js/telegram-worker.js');
      
      await new Promise((resolve, reject) => {
        telegramWorker.onmessage = (event) => {
          if (event.data.type === 'INIT_OK') {
            resolve();
          } else if (event.data.type === 'INIT_ERROR') {
            reject(new Error(event.data.error));
          }
        };
        
        telegramWorker.postMessage({
          type: 'INIT',
          sessionString: session.sessionString,
          apiId: config.apiId,
          apiHash: config.apiHash
        });
      });
      
      if (navigator.serviceWorker && navigator.serviceWorker.controller) {
        const channel = new MessageChannel();
        navigator.serviceWorker.controller.postMessage({ type: 'INIT_PORT' }, [channel.port1]);
        telegramWorker.postMessage({ type: 'INIT_PORT' }, [channel.port2]);
      }
    } catch (e) {
      console.warn('Client streaming init failed, will fallback to proxy:', e);
      telegramWorker = null;
    }
  })();
  
  return telegramWorkerReady;
}

let playPauseDebounce = false;
const KEYBOARD_SEEK_DELAY = 180;
const seekState = {
  dragging: false,
  dragPct: 0,
  lastActualSeek: 0,
  pendingSeekTimer: null,
  keyboardSeeking: false,
  keyboardAccum: 0,
  keyboardTimer: null,
  isCrossPartSeeking: false,
  crossPartVirtualTime: 0,
};
const progressRefs = {
  container: null,
  timeDisplay: null,
  video: null,
};

// ============================================================
// API — Only source of data, no fallbacks or defaults
// ============================================================
async function api(endpoint, silent404 = false) {
  try {
    const response = await fetch(endpoint);
    if (!response.ok) {
      if (response.status === 404 && silent404) return null;
      console.error(`API ${response.status}: ${endpoint}`);
      return null;
    }
    return await response.json();
  } catch (err) {
    console.error(`API failed: ${endpoint}`, err);
    return null;
  }
}

// ============================================================
// IMAGE HANDLING — Local only, never external
// ============================================================
function posterSrc(posterPath) {
  if (!posterPath || posterPath === 'N/A') return null;
  if (posterPath.startsWith('http')) return null;
  return posterPath;
}

function backdropSrc(backdropPath) {
  if (!backdropPath || backdropPath === 'N/A') return null;
  if (backdropPath.startsWith('http')) return null;
  return backdropPath;
}

function posterHTML(posterPath, title, extraClass = '') {
  const src = posterSrc(posterPath);
  if (src) {
    return `
      <div class="card-poster-wrapper ${extraClass}">
        <div class="skeleton-poster shimmer card-poster-skeleton"></div>
        <img
          class="card-poster ${extraClass}"
          src="${src}"
          alt="${esc(title)}"
          loading="lazy"
          onload="this.previousElementSibling.style.display='none';this.style.opacity='1';"
          onerror="this.style.display='none';this.parentElement.querySelector('.card-poster-placeholder-inner').style.display='flex';this.previousElementSibling.style.display='none';"
          style="opacity:0;transition:opacity 0.3s;"
        >
        <div class="card-poster-placeholder-inner ${extraClass}" style="display:none">
          <span>${esc(title)}</span>
        </div>
      </div>`;
  }
  return `<div class="card-poster-placeholder ${extraClass}"><span>${esc(title)}</span></div>`;
}

function backdropHTML(backdropPath, title) {
  const src = backdropSrc(backdropPath);
  if (src) {
    return `<img 
      class="hero-backdrop" 
      src="${src}" 
      alt="${esc(title)}"
      onerror="this.style.display='none';this.nextElementSibling.style.display='flex';"
    ><div class="hero-backdrop-placeholder" style="display:none"></div>`;
  }
  return '<div class="hero-backdrop-placeholder"></div>';
}

// ============================================================
// UTILITIES
// ============================================================
function esc(str) {
  if (!str) return '';
  const d = document.createElement('div');
  d.textContent = str;
  return d.innerHTML;
}

function escArg(str) {
  if (!str) return '';
  return str.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

function isValidLogo(url) {
  if (!url) return false;
  if (typeof url !== 'string') return false;
  const trimmed = url.trim();
  return trimmed !== '' && trimmed !== 'N/A' && trimmed !== 'null' && trimmed !== 'undefined';
}

function getItemTitle(item) {
  const title = item.title || item.showTitle || item.name || '';
  if (title.trim()) return title;
  if (item.fileName) {
    return item.fileName.split('.').slice(0, -1).join('.').replace(/_/g, ' ');
  }
  return 'Untitled Content';
}

function fmtRuntime(min) {
  if (!min || min <= 0) return '';
  if (min < 60) return `${min}m`;
  const h = Math.floor(min / 60);
  const m = min % 60;
  return m > 0 ? `${h}h ${m}m` : `${h}h`;
}

function fmtTime(sec) {
  if (!sec || isNaN(sec)) return '0:00';
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = Math.floor(sec % 60);
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
}

function getLanguageName(code) {
  if (!code || code.toLowerCase() === 'unk' || code.toLowerCase() === 'und') return 'Unknown';
  try {
    const displayNames = new Intl.DisplayNames(['en'], { type: 'language' });
    let name = displayNames.of(code);
    if (code.toLowerCase() === 'hin') return 'Hindi';
    if (code.toLowerCase() === 'eng') return 'English';
    if (code.toLowerCase() === 'tam') return 'Tamil';
    if (code.toLowerCase() === 'tel') return 'Telugu';
    if (code.toLowerCase() === 'mal') return 'Malayalam';
    if (code.toLowerCase() === 'kan') return 'Kannada';
    if (code.toLowerCase() === 'ben') return 'Bengali';
    if (code.toLowerCase() === 'mar') return 'Marathi';
    if (code.toLowerCase() === 'guj') return 'Gujarati';
    if (code.toLowerCase() === 'pan') return 'Punjabi';
    if (name.toLowerCase() === code.toLowerCase()) return code.toUpperCase();
    return name;
  } catch (e) {
    return code.toUpperCase();
  }
}

function parseResolution(filename) {
  if (!filename) return null;
  const match = filename.match(/(2160p|1080p|720p|480p|4K)-?/i);
  if (!match) return null;
  let res = match[1].toLowerCase();
  if (res === '4k') return '4K';
  return res;
}

function toggleOverview() {
  const p = document.querySelector('.modal-overview');
  const btn = document.querySelector('.read-more-btn');
  if (p && btn) {
    p.classList.toggle('collapsed');
    btn.textContent = p.classList.contains('collapsed') ? 'Read more' : 'Show less';
  }
}

function getBadges(item) {
  const badges = [];
  
  // 1. Resolution
  const res = parseResolution(item.fileName || (item.parts && item.parts[0]?.fileName));
  if (res) badges.push(res.toUpperCase());
  
  // 2. Multi Audio
  const audioTracks = item.audioTracks || [];
  if (audioTracks.length > 1) badges.push('Multi Audio');
  
  // 3. Needs Transcoding
  if (item.browserPlayable === false || item._needsTranscode === true) {
    badges.push('Needs Transcoding');
  }

  return badges.filter(Boolean).map(text => `<span class="ott-badge">${text}</span>`).join('');
}

function getLanguageSummary(item) {
  const audios = [...new Set((item.audioTracks || item.languages || []).map(l => typeof l === 'string' ? l : l.language).map(getLanguageName))].filter(Boolean);
  const subs = [...new Set((item.subtitleTracks || item.subtitles || []).map(l => typeof l === 'string' ? l : l.language).map(getLanguageName))].filter(Boolean);
  
  let html = '';
  if (audios.length > 0) {
    html += `<div class="spec-line"><span class="icon">🎧</span><span class="value">${audios.join(', ')}</span></div>`;
  }
  if (subs.length > 0) {
    html += `<div class="spec-line"><span class="icon">📝</span><span class="value">${subs.join(', ')}</span></div>`;
  }
  return html;
}

function handleLogoError(img) {
  const h1 = document.createElement('h1');
  h1.className = 'modal-title';
  h1.textContent = img.alt || 'Untitled';
  img.replaceWith(h1);
}

// ============================================================
// ROUTER
// ============================================================
function navigate(route, params = {}, pushState = true) {
  state.currentRoute = route;
  stopHero();

  if (pushState) {
    let url = '/';
    if (route === 'movies') url = '/movies';
    else if (route === 'tvshows') url = '/tvshows';
    else if (route === 'genres') url = '/genres';
    else if (route === 'genre-detail') url = `/genres/${params.slug || ''}`;
    else if (route === 'search') {
      url = params && params.query ? `/search?q=${params.query}` : '/search';
    }

    window.history.pushState({ route, params }, '', url);
  }

  // Update nav active state (both desktop and mobile)
  const activeRoute = route === 'genre-detail' ? 'genres' : route;
  document.querySelectorAll('.nav-link').forEach(link => {
    link.classList.toggle('active', link.dataset.route === activeRoute);
  });
  document.querySelectorAll('.mobile-nav-link').forEach(link => {
    link.classList.toggle('active', link.dataset.route === activeRoute);
  });

  // Close mobile nav if open
  const mobileNav = document.getElementById('mobile-nav');
  if (mobileNav && !mobileNav.classList.contains('hidden')) {
    mobileNav.classList.add('hidden');
    document.body.style.overflow = '';
  }

  const app = document.getElementById('app');

  switch (route) {
    case 'home': renderHome(app); break;
    case 'movies': renderBrowse(app, 'movie'); break;
    case 'tvshows': renderBrowse(app, 'tv'); break;
    case 'genres': renderGenres(app); break;
    case 'genre-detail': renderGenreDetail(app, params.slug, params.name); break;
    case 'search': renderSearch(app, params.query); break;
    default: renderHome(app);
  }

  window.scrollTo(0, 0);
}


// ============================================================
// HOME PAGE
// ============================================================
function renderHome(container) {
  if (!state.data) {
    container.innerHTML = buildHomePageSkeleton();
    return;
  }

  const { heroItems, movies, tvShows, counts, genreRows } = state.data;

  if (counts.movies === 0 && counts.tvShows === 0) {
    container.innerHTML = `
      <div class="empty-library" style="text-align:center; padding:100px;">
        <h1>Your library is empty</h1>
        <p style="color:#aaa; margin-top:10px;">No content with complete metadata found.</p>
        <p style="color:#aaa;">Check <code>/api/health</code> to see the status of your metadata processing.</p>
      </div>`;
    return;
  }

  let html = '';

  // ========== HERO ==========
  if (heroItems && heroItems.length > 0) {
    html += '<section class="hero">';
    heroItems.forEach((item, i) => {
      const title = item.title || '';
      const isTV = item.type === 'tv';
      const playId = isTV ? (item.firstEpisodeFileId || '') : (item.id || '');
      // For TV play button, we need basic info. Ideally we pass full context.
      // We'll trust openDetail or handlePlayClick to resolve logic.

      html += `
        <div class="hero-slide ${i === 0 ? 'active' : ''}" data-index="${i}">
          ${backdropHTML(item.backdrop, title)}
          <div class="hero-gradient-left"></div>
          <div class="hero-gradient-bottom"></div>
          <div class="hero-content">
            ${item.logo && item.logo !== 'N/A' 
              ? `<img src="${item.logo}" alt="${esc(title)}" class="hero-logo" crossorigin="anonymous" onerror="this.outerHTML='<h1 class=\\'hero-title\\'>${esc(title)}</h1>'">` 
              : `<h1 class="hero-title">${esc(title)}</h1>`}
            <div class="hero-meta">
              ${item.rating ? `<span class="hero-rating">★ ${Number(item.rating).toFixed(1)}</span>` : ''}
              ${item.year ? `<span class="hero-year">${item.year}</span>` : ''}
              ${!isTV && item.runtime ? `<span class="hero-runtime">${fmtRuntime(item.runtime)}</span>` : ''}
              ${isTV ? '<span class="hero-badge-tv">TV Series</span>' : ''}
            </div>
            ${item.genres && item.genres.length > 0 ? `
              <div class="hero-genres">
                ${item.genres.slice(0, 4).map(g => `<span class="genre-tag">${esc(g)}</span>`).join('')}
              </div>` : ''}
            ${item.overview ? `<p class="hero-overview">${esc(item.overview)}</p>` : ''}
            <div class="hero-actions">
              ${playId
          ? `<button class="btn btn-play" onclick="handlePlayClick('${escArg(playId)}', '${item.type}', '${escArg(title)}')">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
                      <polygon points="5 3 19 12 5 21 5 3"/>
                    </svg>
                    ${isTV ? 'Play S1E1' : 'Play'}
                  </button>`
          : ''
        }
              <button class="btn btn-info" onclick="openDetail('${escArg(item.id)}', '${item.type}')">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/>
                </svg>
                More Info
              </button>
            </div>
          </div>
        </div>`;
    });

    if (heroItems.length > 1) {
      html += '<div class="hero-indicators">';
      heroItems.forEach((_, i) => {
        html += `<div class="hero-progress ${i === 0 ? 'active' : ''}" onclick="heroGoTo(${i})"><div class="hero-progress-fill"></div></div>`;
      });
      html += '</div>';
    }
    html += '</section>';
  }

  // ========== CONTENT ROWS ==========
  html += '<section class="content-section">';
  html += '<div id="continue-watching-container"></div>';

  const allCards = [
    ...movies.map(m => ({
      id: m.fileId,
      sortId: parseInt(m.fileId || 0),
      type: 'movie',
      title: m.title,
      poster: m.poster,
      rating: m.rating,
      year: m.year
    })),
    ...tvShows.map(s => {
      // Use the latest episode's fileId to determine recency
      const maxFileId = s.episodes && s.episodes.length > 0
        ? s.episodes.reduce((max, e) => Math.max(max, parseInt(e.fileId || 0)), 0)
        : 0;
      return {
        id: `show_${s.showTmdbId}`,
        sortId: maxFileId,
        type: 'tv',
        title: s.showTitle,
        poster: s.poster,
        rating: s.rating,
        year: s.year
      };
    })
  ].sort((a, b) => b.sortId - a.sortId);

  if (allCards.length > 0) {
    html += buildRow('Recently Added', allCards.slice(0, 20));
  }

  const topRated = [...allCards]
    .filter(c => (c.rating || 0) >= 7)
    .sort((a, b) => (b.rating || 0) - (a.rating || 0))
    .slice(0, 20);

  if (topRated.length >= 4) {
    html += buildRow('Top Rated', topRated);
  }

  if (movies.length >= 1) {
    html += buildRow('Movies', movies.map(m => ({
      id: m.fileId, type: 'movie', title: m.title,
      poster: m.poster, rating: m.rating, year: m.year
    })));
  }

  if (tvShows.length >= 1) {
    html += buildRow('TV Shows', tvShows.map(s => ({
      id: `show_${s.showTmdbId}`, type: 'tv', title: s.showTitle,
      poster: s.poster, rating: s.rating, year: s.year
    })));
  }

  if (genreRows) {
    for (const row of genreRows) {
      if (row.items.length < 1) continue;
      html += buildRow(row.genre, row.items.map(normalizeItem));
    }
  }

  // Placeholder for curated rows (loaded async)
  html += '<div id="curated-rows-container"></div>';

  html += '</section>';
  container.innerHTML = html;

  if (heroItems && heroItems.length > 1) {
    startHero(heroItems.length);
    setupHeroSwipe();
  }

  // Load curated content async (non-blocking)
  loadCuratedRows();
}

// ============================================================
// CURATED ROWS — Loaded async and appended to home page
// ============================================================
async function loadCuratedRows() {
  const container = document.getElementById('curated-rows-container');
  if (!container) return;

  const curated = await api('/api/curated');
  if (!curated || !curated.homepage) return;

  // Cache for genre page use
  state.curatedData = curated;

  let html = '';
  
  // 1. Continue Watching
  if (typeof fetchWatchProgress === 'function') {
    const progressItems = await fetchWatchProgress();
    if (progressItems && progressItems.length > 0) {
      window._watchProgress = progressItems; // Store globally for modals to access
      
      const seenShows = new Set();
      const continueItems = [];
      
      for (const p of progressItems) {
        const isTVGuess = p.media_type === 'tv' || (p.title && p.title.includes(' - S') && p.title.includes('E'));
        const playType = isTVGuess ? 'tv' : 'movie';
        const season = p.season || (isTVGuess ? 1 : null);
        const episode = p.episode || null;
        let showId = p.show_id || null;
        
        // Smart Recovery for older watch progress rows that lack show_id
        if (playType === 'tv' && !showId && state.data && state.data.tvShows) {
           for (const show of state.data.tvShows) {
             if (!show.seasons) continue;
             for (const s of Object.keys(show.seasons)) {
               for (const ep of show.seasons[s]) {
                 if (String(ep.fileId) === String(p.file_id)) {
                   showId = String(show.showTmdbId);
                   break;
                 }
               }
               if (showId) break;
             }
             if (showId) break;
           }
        }
        
        if (playType === 'tv' && showId) {
          if (seenShows.has(showId)) continue; // Keep only the most recent episode for this show
          seenShows.add(showId);
        }
        
        let displayTitle = p.title || 'Continue Watching';
        const onClickStr = (playType === 'tv' && showId) ? `openDetail('show_${showId}', 'tv')` : `openDetail('${p.file_id}', 'movie')`;
        
        continueItems.push({
          id: p.file_id,
          type: playType,
          title: displayTitle,
          season: season,
          episode: episode,
          poster: p.poster_path, // Could be null, fallbacks handled by UI
          progressPercent: Math.min(100, Math.max(0, (p.position_seconds / p.duration_seconds) * 100)),
          onClick: onClickStr
        });
      }
      
      const cwContainer = document.getElementById('continue-watching-container');
      if (cwContainer) {
        cwContainer.innerHTML = buildRow('▶ Continue Watching', continueItems);
      } else {
        html += buildRow('▶ Continue Watching', continueItems);
      }
    }
  }

  const rows = curated.homepage.rows || {};

  // Section display config: key => {title, minItems}
  const sectionConfig = [
    { key: 'multi_audio', title: '🎧 Multi Audio Picks', min: 3 },
    { key: 'hindi', title: '🇮🇳 Hindi Collection', min: 3 },
    { key: 'english', title: '🇺🇸 English Collection', min: 3 },
    { key: 'kdrama', title: '🇰🇷 K-Drama', min: 2 },
    { key: 'anime', title: '🇯🇵 Anime', min: 2 },
    { key: 'quick_watch', title: '⚡ Quick Watch', min: 3 },
  ];

  for (const { key, title, min } of sectionConfig) {
    const items = rows[key];
    if (!items || items.length < min) continue;
    html += buildRow(title, items.map(curatedToCard));
  }

  // Mood sections
  if (curated.special_sections && curated.special_sections.mood) {
    const moodConfig = [
      { key: 'feel_good', title: '😊 Feel Good' },
      { key: 'dark_thriller', title: '🔪 Dark & Thriller' },
      { key: 'comedy_nights', title: '😂 Comedy Nights' },
      { key: 'emotional', title: '💔 Emotional Drama' },
    ];
    for (const { key, title } of moodConfig) {
      const items = curated.special_sections.mood[key];
      if (!items || items.length < 3) continue;
      html += buildRow(title, items.map(curatedToCard));
    }
  }

  // Duration sections
  if (curated.special_sections && curated.special_sections.duration) {
    const durConfig = [
      { key: 'long_movies', title: '🎬 Epic Movies (2.5h+)' },
      { key: 'series', title: '📺 Series to Binge' },
    ];
    for (const { key, title } of durConfig) {
      const items = curated.special_sections.duration[key];
      if (!items || items.length < 3) continue;
      html += buildRow(title, items.map(curatedToCard));
    }
  }

  // Genre rows from curated (these may differ from /api/metadata genre rows — more variety)
  const genreRowConfig = [
    { key: 'action', title: 'Action' },
    { key: 'comedy', title: 'Comedy' },
    { key: 'drama', title: 'Drama' },
    { key: 'romance', title: 'Romance' },
    { key: 'crime', title: 'Crime' },
    { key: 'thriller', title: 'Thriller' },
    { key: 'animation', title: 'Animation' },
    { key: 'family', title: 'Family' },
    { key: 'horror', title: 'Horror' },
    { key: 'mystery', title: 'Mystery' },
    { key: 'documentary', title: 'Documentary' },
  ];

  for (const { key, title } of genreRowConfig) {
    const items = rows[key];
    if (!items || items.length < 4) continue;
    // Skip if we already rendered this genre from /api/metadata
    const existingRow = document.getElementById('row_' + title.replace(/[^a-zA-Z0-9]/g, '_'));
    if (existingRow) continue;
    html += buildRow(title, items.map(curatedToCard));
  }

  // Needs Attention row (only if items exist)
  if (rows.needs_attention && rows.needs_attention.length > 0) {
    html += buildRow('⚠️ Needs Attention', rows.needs_attention.map(curatedToCard));
  }

  if (html) {
    container.innerHTML = html;
  }
}

/** Convert curated item format to card() compatible format */
function curatedToCard(item) {
  return {
    id: item.id,
    type: item.type || 'movie',
    title: item.title,
    poster: item.thumbnail,
    rating: item.rating,
    year: item.year,
    episodeCount: item.episodeCount || 0,
    isSplit: item.isSplit || false,
    totalParts: item.totalParts || 1,
  };
}

// ============================================================
// GENRES PAGE
// ============================================================
async function renderGenres(container) {
  // Show skeleton immediately
  container.innerHTML = buildGenresPageSkeleton();

  // Try to use cached curated data first
  let curated = state.curatedData;
  if (!curated) {
    curated = await api('/api/curated');
    if (curated) state.curatedData = curated;
  }

  if (!curated || !curated.genres_page || !curated.genres_page.genres) {
    container.innerHTML = `
      <div class="browse-page">
        <h1 class="browse-title">Genres</h1>
        <div class="empty-state"><p>No genres available.</p></div>
      </div>`;
    return;
  }

  const genres = curated.genres_page.genres.filter(g => g.count >= 2);

  container.innerHTML = `
    <div class="genres-page">
      <div class="genres-header">
        <h1 class="genres-page-title">Explore Genres</h1>
        <p class="genres-subtitle">Discover content by genre</p>
      </div>
      <div class="genre-grid" id="genre-grid">
        ${genres.map(genre => `
          <div class="genre-card" onclick="navigate('genre-detail', {slug:'${genre.slug}', name:'${escArg(genre.name)}'})"
               style="--genre-bg: url('${genre.image || ''}')">
            <div class="genre-card-overlay"></div>
            <div class="genre-card-content">
              <h3 class="genre-card-name">${esc(genre.name)}</h3>
              <span class="genre-card-count">${genre.count} titles</span>
            </div>
          </div>
        `).join('')}
      </div>
    </div>`;
}

async function renderGenreDetail(container, slug, genreName) {
  container.innerHTML = buildBrowsePageSkeleton(genreName || 'Genre');

  let curated = state.curatedData;
  if (!curated) {
    curated = await api('/api/curated');
    if (curated) state.curatedData = curated;
  }

  if (!curated || !curated.genres_page || !curated.genres_page.sections || !curated.genres_page.sections[slug]) {
    container.innerHTML = `
      <div class="browse-page">
        <h1 class="browse-title">${esc(genreName || slug)}</h1>
        <div class="empty-state"><p>No content found for this genre.</p></div>
      </div>`;
    return;
  }

  const sections = curated.genres_page.sections[slug];
  const genre = curated.genres_page.genres.find(g => g.slug === slug);
  const displayName = genreName || (genre ? genre.name : slug);

  let html = `
    <div class="genre-detail-page">
      <div class="genre-detail-header" style="--genre-bg: url('${genre && genre.image ? genre.image : ''}')">
        <div class="genre-detail-header-overlay"></div>
        <div class="genre-detail-header-content">
          <button class="btn-back" onclick="navigate('genres')">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
            All Genres
          </button>
          <h1 class="genre-detail-title">${esc(displayName)}</h1>
          ${genre ? `<p class="genre-detail-count">${genre.count} titles available</p>` : ''}
        </div>
      </div>
      <section class="content-section">`;

  const subSections = [
    { key: 'popular', title: `Popular in ${displayName}` },
    { key: 'top_rated', title: `Top Rated ${displayName}` },
    { key: 'new', title: `New in ${displayName}` },
    { key: 'hidden_gems', title: 'Hidden Gems' },
    { key: 'multi_audio', title: `Multi Audio in ${displayName}` },
    { key: 'recently_added', title: `Recently Added` },
  ];

  for (const { key, title } of subSections) {
    const items = sections[key];
    if (!items || items.length < 2) continue;
    html += buildRow(title, items.map(curatedToCard));
  }

  html += '</section></div>';
  container.innerHTML = html;
}

function buildGenresPageSkeleton() {
  const skeletonCards = Array(12).fill('')
    .map(() => '<div class="genre-card skeleton-genre-card"><div class="shimmer" style="width:100%;height:100%;border-radius:12px;"></div></div>')
    .join('');

  return `
    <div class="genres-page">
      <div class="genres-header">
        <div class="skeleton-line shimmer" style="width:250px;height:36px;margin-bottom:8px;"></div>
        <div class="skeleton-line shimmer" style="width:180px;height:18px;"></div>
      </div>
      <div class="genre-grid">${skeletonCards}</div>
    </div>`;
}

function renderBrowse(container, type) {
  if (!state.data) {
    container.innerHTML = buildBrowsePageSkeleton(type === 'movie' ? 'Movies' : 'TV Shows');
    return;
  }

  const isMovie = type === 'movie';
  const title = isMovie ? 'Movies' : 'TV Shows';
  const rawItems = isMovie ? (state.data.movies || []) : (state.data.tvShows || []);

  console.log(`[Browse] ${title}: ${rawItems.length} items`, rawItems.length > 0 ? Object.keys(rawItems[0]) : 'empty');

  const items = rawItems.map(item => ({
    id: isMovie ? (item.fileId || item.id) : `show_${item.showTmdbId}`,
    type: type,
    title: isMovie ? item.title : (item.showTitle || item.title),
    poster: item.poster,
    rating: item.rating,
    year: item.year,
    isSplit: item.isSplit,
    totalParts: item.totalParts,
    episodeCount: item.availableEpisodeCount || item.episodes?.length || 0
  }));

  if (items.length === 0) {
    container.innerHTML = `
      <div class="browse-page">
        <h1 class="browse-title">${title}</h1>
        <div class="empty-state"><p>No ${title.toLowerCase()} found.</p></div>
      </div>`;
    return;
  }

  items.sort((a, b) => (b.rating || 0) - (a.rating || 0));

  container.innerHTML = `
    <div class="browse-page">
      <div class="browse-header">
        <h1 class="browse-title">${title}</h1>
        <select class="browse-sort" id="browse-sort">
          <option value="rating">Top Rated</option>
          <option value="alpha">A-Z</option>
          <option value="year">Newest</option>
        </select>
      </div>
      <div class="browse-grid" id="browse-grid">
        ${items.map(card).join('')}
      </div>
    </div>`;

  document.getElementById('browse-sort').onchange = function () {
    const val = this.value;
    if (val === 'rating') items.sort((a, b) => (b.rating || 0) - (a.rating || 0));
    if (val === 'alpha') items.sort((a, b) => (a.title || '').localeCompare(b.title || ''));
    if (val === 'year') items.sort((a, b) => (b.year || 0) - (a.year || 0));
    document.getElementById('browse-grid').innerHTML = items.map(card).join('');
  };
}

async function renderSearch(container, query) {
  if (!query || query.length < 2) {
    container.innerHTML = `<div class="search-results"><div class="empty-state"><h2>Type to search...</h2></div></div>`;
    return;
  }

  const skeletonCards = Array(8).fill('')
    .map(() => '<div class="card skeleton-card"><div class="skeleton-poster shimmer"></div></div>')
    .join('');

  container.innerHTML = `
    <div class="search-results">
      <div class="skeleton-line shimmer" style="width:250px;height:20px;margin-bottom:20px;"></div>
      <div class="search-grid">${skeletonCards}</div>
    </div>`;

  const data = await api(`/api/search?q=${encodeURIComponent(query)}`);
  if (!data || !data.results || data.results.length === 0) {
    container.innerHTML = `
      <div class="search-results">
        <div class="empty-state"><h2>No results for "${esc(query)}"</h2></div>
      </div>`;
    return;
  }

  container.innerHTML = `
    <div class="search-results">
      <p class="search-results-title">Results for "${esc(query)}"</p>
      <div class="search-grid">
        ${data.results.map(item => card({
    id: item.id, type: item.type,
    title: item.title, poster: item.poster,
    rating: item.rating, year: item.year,
    isSplit: item.isSplit, totalParts: item.totalParts
  })).join('')}
      </div>
    </div>`;
}

// ============================================================
// CARD & ROW BUILDERS
// ============================================================
function card(item) {
  const id = item.id || '';
  const type = item.type || 'movie';
  const title = item.title || 'Untitled';
  const isTV = type === 'tv' || (id && id.startsWith('show_'));
  const onClickStr = item.onClick ? item.onClick : `openDetail('${escArg(id)}', '${isTV ? 'tv' : type}')`;

  return `
    <div class="card" onclick="${onClickStr}">
      <div style="position:relative; width:100%; height:100%;">
        ${posterHTML(item.poster, title)}
        ${item.progressPercent !== undefined ? `<div style="position:absolute; bottom:0; left:0; right:0; height:4px; background:rgba(255,255,255,0.2); z-index: 10;"><div style="height:100%; background:var(--primary); width:${item.progressPercent}%;"></div></div>` : ''}
      </div>
      <div class="card-info">
        <div class="card-title">${esc(title)}</div>
        <div class="card-meta">
          ${item.rating ? `<span style="color:#46d369">★ ${Number(item.rating).toFixed(1)}</span>` : ''}
          ${item.year ? `<span>${item.year}</span>` : ''}
          ${item.season && item.episode ? `<span>S${item.season} E${item.episode}</span>` : (isTV && item.episodeCount ? `<span>${item.episodeCount} ep</span>` : '')}
        </div>
      </div>
      ${isTV ? '<div class="card-type-badge">Series</div>' : ''}
    </div>`;
}

function buildRow(title, items) {
  if (!items || items.length === 0) return '';
  const id = 'row_' + title.replace(/[^a-zA-Z0-9]/g, '_');

  return `
    <div class="row">
      <h2 class="row-title">${esc(title)}</h2>
      <div class="row-slider-container">
        <div class="slider-arrow slider-arrow-left" onclick="slide('${id}', -1)">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
            <path d="M15 18l-6-6 6-6"/>
          </svg>
        </div>
        <div class="row-slider" id="${id}">
          ${items.map(card).join('')}
        </div>
        <div class="slider-arrow slider-arrow-right" onclick="slide('${id}', 1)">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
            <path d="M9 18l6-6-6-6"/>
          </svg>
        </div>
      </div>
    </div>`;
}

function slide(id, dir) {
  const el = document.getElementById(id);
  if (!el) return;
  const cw = el.clientWidth;
  el.scrollBy({ left: dir * cw * 0.8, behavior: 'smooth' });
}

// ============================================================
// DETAIL MODAL
// ============================================================
function closeModal(pushState = true) {
  const modal = document.getElementById('detail-modal');
  const container = modal.querySelector('.modal-container');

  container.classList.add('closing');
  setTimeout(() => {
    modal.classList.add('hidden');
    container.classList.remove('closing');
    document.body.style.overflow = '';

    // Replace URL back to the main route
    if (pushState) {
      let url = '/';
      if (state.currentRoute === 'movies') url = '/movies';
      else if (state.currentRoute === 'tvshows') url = '/tvshows';
      else if (state.currentRoute === 'search') {
        const queryParams = new URLSearchParams(window.location.search);
        url = queryParams.has('q') ? `/search?q=${queryParams.get('q')}` : '/search';
      }
      window.history.pushState({ route: state.currentRoute }, '', url);
    }
  }, 200);
}

async function openDetail(id, type, pushState = true) {
  const modal = document.getElementById('detail-modal');
  const body = document.getElementById('modal-body');

  if (pushState) {
    const url = type === 'tv' ? `/tv/${id.replace('show_', '')}` : `/movie/${id}`;
    window.history.pushState({ route: state.currentRoute, modal: { id, type } }, '', url);
  }

  modal.classList.remove('hidden');
  document.body.style.overflow = 'hidden';

  // Show modal skeleton instead of spinner
  body.innerHTML = `
    <div class="skeleton-modal-hero shimmer"></div>
    <div class="skeleton-modal-content">
      <div class="skeleton-line skeleton-modal-title shimmer"></div>
      <div class="skeleton-line skeleton-modal-meta shimmer"></div>
      <div class="skeleton-line skeleton-modal-overview shimmer"></div>
      <div class="skeleton-line shimmer" style="width:80%;"></div>
      <div class="skeleton-line shimmer" style="width:60%;margin-top:20px;"></div>
    </div>`;

  let data;
  if (type === 'tv' && id.startsWith('show_')) {
    data = await api(`/api/tv/${id.replace('show_', '')}`);
    if (data) renderShowModal(body, data);
  } else {
    data = await api(`/api/metadata/${id}`);

    // Check if it's actually an episode redirect — use tv.showTmdbId as primary indicator
    if (data && data.tv && data.tv.showTmdbId) {
      const show = await api(`/api/tv/${data.tv.showTmdbId}`);
      if (show) {
        renderShowModal(body, show);
        return;
      }
    }

    if (data) renderMovieModal(body, data);
  }

  if (!data) {
    body.innerHTML = '<div class="empty-state"><h2>Content not found</h2></div>';
  }
}

function renderMovieModal(container, movie) {
  const isSplit = movie.isSplit && movie.parts && movie.parts.length > 1;
  const backdrop = backdropSrc(movie.backdrop) || posterSrc(movie.poster);

  const metaItems = [
    movie.year,
    movie.runtime ? fmtRuntime(movie.runtime) : null,
  ].filter(Boolean);

  if (isSplit) {
    window._pendingMovieParts = movie.parts;
  } else {
    window._pendingMovieParts = null;
  }

  const playFileId = movie.fileId || (isSplit ? movie.parts[0].fileId : '');
  const movieTitle = getItemTitle(movie);
  const logoUrl = movie.logo;
  const logoHtml = isValidLogo(logoUrl)
    ? `<img src="${logoUrl}" alt="${esc(movieTitle)}" class="modal-logo" crossorigin="anonymous" onerror="handleLogoError(this)">`
    : `<h1 class="modal-title">${esc(movieTitle)}</h1>`;

  let dynamicPlayLabel = 'Play';
  if (window._watchProgress) {
    const prog = window._watchProgress.find(p => String(p.file_id) === String(playFileId));
    if (prog && prog.position_seconds > 0) {
      dynamicPlayLabel = 'Resume';
    }
  }

  container.innerHTML = `
    <div class="modal-hero" style="background-image: url('${backdrop}');">
      <div class="modal-hero-gradient"></div>
      <div class="modal-hero-content">
        ${logoHtml}
        <div class="modal-actions">
           <button class="btn-premium-play" onclick="playVideo({fileId: '${playFileId}', title: '${escArg(movieTitle)}', poster: '${escArg(movie.poster || movie.backdrop || '')}', _useStoredParts: ${isSplit}})">
             <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>
             ${dynamicPlayLabel}
           </button>
           <button class="btn-circle" title="Add to List">
             <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
           </button>
        </div>
      </div>
    </div>
    <div class="modal-body-inner">
      <div class="modal-meta-row">
        ${movie.rating ? `<span class="match-score">★ ${Number(movie.rating).toFixed(1)}</span>` : ''}
        ${metaItems.map(m => `<span>${m}</span>`).join('')}
      </div>
      <div class="badge-container">
        ${getBadges(movie)}
      </div>
      <p class="modal-overview collapsed">
        ${esc(movie.overview || 'No description available.')}
      </p>
      ${movie.overview && movie.overview.length > 200 ? `<button class="read-more-btn" onclick="toggleOverview()">Read more</button>` : ''}
      
      <div class="modal-genres">
        ${(movie.genres || []).join(' | ')}
      </div>

      <div class="spec-info" style="margin-top:30px; border-top:1px solid #222; padding-top:30px;">
        ${getLanguageSummary(movie)}
      </div>
    </div>`;
}

function renderShowModal(container, show) {
  const seasons = show.seasons || {};
  const seasonNums = Object.keys(seasons).map(Number).sort((a, b) => a - b);
  const firstS = seasonNums[0] || 1;
  const episodes = seasons[firstS] || [];
  const firstEp = episodes[0]; // Restored for badges/spec info
  let targetEp = episodes[0];
  let targetS = firstS;
  let playLabel = targetEp ? `Play S${targetS}E${targetEp.tv.episodeNumber}` : 'Play';
  const backdrop = backdropSrc(show.backdrop) || posterSrc(show.poster);

  if (window._watchProgress) {
    const allEpIds = new Set();
    for (const s of Object.values(seasons)) {
      for (const ep of s) {
        allEpIds.add(String(ep.fileId));
      }
    }
    let prog = window._watchProgress.find(p => 
      String(p.show_id) === String(show.showTmdbId) || allEpIds.has(String(p.file_id))
    );

    if (prog) {
      let targetEpNum = prog.episode;
      let targetSeasonNum = prog.season;
      
      if (!targetEpNum || !targetSeasonNum) {
         for (const s of Object.keys(seasons)) {
           const found = seasons[s].find(ep => String(ep.fileId) === String(prog.file_id));
           if (found) {
             targetSeasonNum = Number(s);
             targetEpNum = found.tv.episodeNumber;
             break;
           }
         }
      }

      if (targetSeasonNum && targetEpNum) {
        targetS = targetSeasonNum;
        const progEpisodes = seasons[targetS];
        if (progEpisodes) {
          const foundEp = progEpisodes.find(e => e.tv.episodeNumber === targetEpNum);
          if (foundEp) {
            targetEp = foundEp;
            playLabel = `Resume S${targetS}E${targetEpNum}`;
          }
        }
      }
    }
  }

  window._showSeasons = seasons;
  window._showTitle = show.showTitle;
  window._showTmdbId = show.showTmdbId;
  window._showPoster = show.poster || show.backdrop || '';

  const showTitle = getItemTitle(show);
  const logoUrl = show.logo;
  const logoHtml = isValidLogo(logoUrl)
    ? `<img src="${logoUrl}" alt="${esc(showTitle)}" class="modal-logo" crossorigin="anonymous" onerror="handleLogoError(this)">`
    : `<h1 class="modal-title">${esc(showTitle)}</h1>`;

  container.innerHTML = `
    <div class="modal-hero" style="background-image: url('${backdrop}');">
      <div class="modal-hero-gradient"></div>
      <div class="modal-hero-content">
        ${logoHtml}
        <div class="modal-actions">
           ${targetEp ? `
           <button class="btn-premium-play" onclick="playVideo({fileId:'${targetEp.fileId}', title:'${escArg(showTitle)}', poster:'${escArg(show.poster || show.backdrop || '')}', season:${targetS}, episode:${targetEp.tv.episodeNumber}, episodeTitle:'${escArg(targetEp.tv.episodeTitle || `Episode ${targetEp.tv.episodeNumber}`)}', tmdbId:${show.showTmdbId}})">
             <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>
             ${playLabel}
           </button>` : ''}
           <button class="btn-circle" title="Add to List">
             <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
           </button>
        </div>
      </div>
    </div>
    <div class="modal-body-inner">
       <div class="modal-meta-row">
          ${show.rating ? `<span class="match-score">★ ${Number(show.rating).toFixed(1)}</span>` : ''}
          ${show.year ? `<span>${show.year}</span>` : ''}
          <span>${seasonNums.length} Seasons</span>
          <span>${show.availableEpisodeCount} Episodes</span>
       </div>
       <div class="badge-container">
          ${firstEp ? getBadges(firstEp) : ''}
       </div>
       <p class="modal-overview collapsed">${esc(show.overview || '')}</p>
       ${show.overview && show.overview.length > 200 ? `<button class="read-more-btn" onclick="toggleOverview()">Read more</button>` : ''}
       
       <div class="modal-genres">
          ${(show.genres || []).join(' | ')}
       </div>

       <div class="spec-info" style="margin-top:30px; border-top:1px solid #222; padding-top:30px;">
        ${firstEp ? getLanguageSummary(firstEp) : ''}
       </div>
       
       <div class="season-selector" style="justify-content: flex-start; margin-top: 40px;">
          <h3 style="margin-right:auto; font-size:1.4rem;">Episodes</h3>
          <select class="season-select" onchange="renderEpisodeList(this.value)">
             ${seasonNums.map(n => `<option value="${n}">Season ${n}</option>`).join('')}
          </select>
       </div>
       <div id="episode-list-container" class="episode-list">
          ${renderEpisodeRows(episodes, showTitle, show.showTmdbId)}
       </div>
    </div>`;
}

function renderEpisodeRows(episodes, showTitle, tmdbId, poster = '') {
  if (!episodes || episodes.length === 0) return '<div style="padding:20px; color:#666">No episodes</div>';

  return episodes.map(ep => {
    const s = ep.tv.seasonNumber;
    const e = ep.tv.episodeNumber;
    const title = ep.tv.episodeTitle || `Episode ${e}`;
    return `
      <div class="episode-item" onclick="playVideo({fileId: '${ep.fileId}', title: '${escArg(showTitle)}', poster: '${escArg(poster)}', season:${s}, episode:${e}, episodeTitle:'${escArg(title)}', tmdbId:${tmdbId || 'null'}})">
         <div class="episode-number">${e}</div>
         <div class="episode-info">
            <div class="episode-title">${esc(title)}</div>
            <div class="episode-overview-text">${esc(ep.tv.episodeOverview || '')}</div>
         </div>
         <div class="episode-runtime">${fmtRuntime(ep.runtime || ep.tv.episodeRuntime)}</div>
      </div>`;
  }).join('');
}

window.renderEpisodeList = function (seasonNum) {
  const container = document.getElementById('episode-list-container');
  if (window._showSeasons && window._showSeasons[seasonNum]) {
    container.innerHTML = renderEpisodeRows(window._showSeasons[seasonNum], window._showTitle, window._showTmdbId, window._showPoster);

    // --- NEW: Update the main Play button in the hero section ---
    const episodes = window._showSeasons[seasonNum];
    if (episodes && episodes.length > 0) {
      const firstEp = episodes[0];
      const btn = document.querySelector('.modal-hero .btn-premium-play');
      if (btn) {
        // Update text
        btn.innerHTML = `
          <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>
          Play S${seasonNum}E${firstEp.tv.episodeNumber}`;

        const tmdbId = window._showTmdbId;

        btn.setAttribute('onclick', `playVideo({
          fileId: '${firstEp.fileId}', 
          title: '${escArg(window._showTitle)}', 
          poster: '${escArg(window._showPoster || '')}',
          season: ${seasonNum}, 
          episode: ${firstEp.tv.episodeNumber}, 
          episodeTitle: '${escArg(firstEp.tv.episodeTitle || `Episode ${firstEp.tv.episodeNumber}`)}',
          tmdbId: ${tmdbId || 'null'}
        })`);
      }
    }
  }
};

function handlePlayClick(fileId, type, title) {
  // Helper for buttons outside modal
  if (type === 'tv') {
    // Ideally we'd know if it's a show or episode ID. 
    if (fileId.startsWith('show_')) openDetail(fileId, 'tv');
    else playVideo({ fileId, title });
  } else {
    playVideo({ fileId, title });
  }
}

// ============================================================
// CAROUSEL & UTILS
// ============================================================
function heroGoTo(index) {
  state.heroIndex = index;
  document.querySelectorAll('.hero-slide').forEach((s, i) => s.classList.toggle('active', i === index));
  document.querySelectorAll('.hero-progress').forEach((d, i) => {
    d.classList.toggle('active', i === index);
    const fill = d.querySelector('.hero-progress-fill');
    if (fill) {
      fill.style.animation = 'none';
      fill.offsetHeight; /* trigger reflow */
      if (i === index) fill.style.animation = 'fillProgress 8s linear forwards';
    }
  });
}

function startHero(length) {
  stopHero();
  // Ensure the internal state resets animation on current specific element
  heroGoTo(state.heroIndex);
  
  state.heroTimer = setInterval(() => {
    let next = state.heroIndex + 1;
    if (next >= length) next = 0;
    heroGoTo(next);
  }, 8000); // 8-second rotation
}

function stopHero() { if (state.heroTimer) clearInterval(state.heroTimer); }

function setupHeroSwipe() {
  const hero = document.querySelector('.hero');
  if (!hero) return;

  let touchStartX = 0;
  let touchStartY = 0;

  hero.addEventListener('touchstart', (e) => {
    touchStartX = e.changedTouches[0].screenX;
    touchStartY = e.changedTouches[0].screenY;
    stopHero(); // Pause auto-rotation on touch
  }, { passive: true });

  hero.addEventListener('touchend', (e) => {
    const touchEndX = e.changedTouches[0].screenX;
    const touchEndY = e.changedTouches[0].screenY;
    handleHeroSwipe(touchStartX, touchStartY, touchEndX, touchEndY);
    // Restart auto-rotation
    startHero(document.querySelectorAll('.hero-slide').length);
  }, { passive: true });
}

function handleHeroSwipe(startX, startY, endX, endY) {
  const diffX = endX - startX;
  const diffY = endY - startY;

  // Check if horizontal swipe and substantial enough (> 50px)
  // Also ensure it's not a vertical scroll (diffX > diffY)
  if (Math.abs(diffX) > 50 && Math.abs(diffX) > Math.abs(diffY)) {
    const count = document.querySelectorAll('.hero-slide').length;
    if (diffX > 0) {
      // Swiped Right -> Previous
      let next = state.heroIndex - 1;
      if (next < 0) next = count - 1;
      heroGoTo(next);
    } else {
      // Swiped Left -> Next
      let next = state.heroIndex + 1;
      if (next >= count) next = 0;
      heroGoTo(next);
    }
  }
}

// ============================================================
// VIDEO PLAYER LOGIC (THE BIG ONE)
// ============================================================

// ============================================================
// PLAYER STATE RESET — Clean slate for each new video
// ============================================================
function resetPlayerState() {
  const video = document.getElementById('video-player');
  const subtitleDisplay = document.getElementById('subtitle-display');

  // Abort all previous player event listeners
  if (state.player.abortController) {
    state.player.abortController.abort();
    state.player.abortController = null;
  }

  // Stop heartbeat from any previous video
  stopHeartbeat();

  // Clear custom subtitle display
  if (subtitleDisplay) subtitleDisplay.innerHTML = '';

  // Remove any leftover <track> elements
  video.querySelectorAll('track').forEach((track) => {
    if (track.src && track.src.startsWith('blob:')) {
      URL.revokeObjectURL(track.src);
    }
    track.remove();
  });
  for (let i = 0; i < video.textTracks.length; i++) {
    video.textTracks[i].mode = 'disabled';
  }

  // Reset video element
  video.pause();
  video.removeAttribute('src');
  video.load();
  video.playbackRate = 1.0;
  video.currentTime = 0;

  // Reset UI
  document.getElementById('progress-bar').style.width = '0%';
  document.getElementById('progress-buffer').style.width = '0%';
  document.getElementById('time-display').textContent = '0:00 / 0:00';
  document.getElementById('btn-speed').textContent = '1x';

  // Reset state
  state.player.currentAudioTrack = 0;
  state.player.currentSubtitleTrack = -1;
  state.player.subtitleTracks = [];
  state.player.speed = 1;
  state.player.defaultAudioTrack = 0;
  state.player.duration = 0;
  state.player.parsedCues = null;
  state.player.subtitleVTTCache = {};
  state.player.subtitleOffset = 0;
  state.player._syncSeenTime = null;

  seekState.dragging = false;
  seekState.keyboardSeeking = false;
  seekState.keyboardAccum = 0;
  seekState.dragPct = 0;
  seekState.lastActualSeek = 0;
  clearTimeout(seekState.pendingSeekTimer);
  clearTimeout(seekState.keyboardTimer);
  seekState.pendingSeekTimer = null;
  seekState.keyboardTimer = null;
  progressRefs.container = document.getElementById('progress-container');
  progressRefs.timeDisplay = document.getElementById('time-display');
  progressRefs.video = video;

  const progressContainer = document.getElementById('progress-container');
  if (progressContainer) {
    progressContainer.style.setProperty('--progress', 0);
    progressContainer.style.setProperty('--buffer', 0);
  }

  // Hide panels/menus
  document.getElementById('track-panel')?.classList.add('hidden');
  document.getElementById('speed-menu')?.classList.add('hidden');
  document.getElementById('next-episode-btn')?.classList.add('hidden');
  document.getElementById('btn-next-ep-control')?.classList.add('hidden');
  
  document.getElementById('btn-episodes')?.classList.add('hidden');
  
  const epSheet = document.getElementById('episodes-sheet');
  if (epSheet) epSheet.classList.add('hidden');
  
  const epOverlay = document.getElementById('episodes-sheet-overlay');
  if (epOverlay) epOverlay.classList.add('hidden');

  // Reset speed option highlights
  document.querySelectorAll('.speed-option').forEach(opt => {
    opt.classList.toggle('active', parseFloat(opt.dataset.speed) === 1);
  });

  // Reset multipart state
  state.player.multipart = {
    enabled: false,
    parts: [],
    durationMap: [],
    currentPartIndex: 0,
    totalDuration: 0,
    completedDuration: 0,
    _switchLog: [],
    timeline: {
      displayCurrentTime: 0,
      displayTotalDuration: 0,
      displayProgressPercent: 0,
    },
  };
}

function hasEpisodeContext(ctx) {
  const season = Number(ctx?.season);
  const episode = Number(ctx?.episode);
  return Number.isInteger(season) && season > 0 && Number.isInteger(episode) && episode > 0;
}

function setNextEpisodeFloatingVisible(isVisible) {
  const floatingBtn = document.getElementById('next-episode-btn');
  if (isVisible) floatingBtn?.classList.remove('hidden');
  else floatingBtn?.classList.add('hidden');
}

function setNextEpisodeControlVisible(isVisible) {
  const controlBtn = document.getElementById('btn-next-ep-control');
  if (isVisible) controlBtn?.classList.remove('hidden');
  else controlBtn?.classList.add('hidden');
}

function getEffectiveDuration(video) {
  return getDisplayTimelineState(video).displayTotalDuration;
}

function getEffectiveCurrentTime(video) {
  return getDisplayTimelineState(video).displayCurrentTime;
}

/**
 * SINGLE SOURCE OF TRUTH for multipart global time.
 * Always derives from durationMap + video.currentTime — never from cached completedDuration.
 * @param {HTMLVideoElement} video
 * @returns {number} global time in seconds
 */
function multipartCalculateGlobalTime(video) {
  const mp = state.player.multipart;
  if (!mp.enabled || !mp.durationMap || mp.durationMap.length === 0) return 0;

  const idx = Math.max(0, Math.min(Number(mp.currentPartIndex || 0), mp.durationMap.length - 1));
  const mapEntry = mp.durationMap[idx];
  const partStart = mapEntry ? mapEntry.start : 0;
  const elapsed = (video && isFinite(video.currentTime)) ? Math.max(0, video.currentTime) : 0;
  return partStart + elapsed;
}

/**
 * Sync completedDuration from durationMap. Always use this instead of manual accumulation.
 * completedDuration = durationMap[currentPartIndex].start
 */
function multipartSyncCompletedDuration() {
  const mp = state.player.multipart;
  if (!mp.enabled || !mp.durationMap || mp.durationMap.length === 0) return;
  const idx = Math.max(0, Math.min(Number(mp.currentPartIndex || 0), mp.durationMap.length - 1));
  mp.completedDuration = mp.durationMap[idx].start;
}

function recalculateMultipartTimelineState(video, options = {}) {
  const mp = state.player.multipart;
  const totalDuration = Number(mp.totalDuration || 0);

  if (!mp.enabled || totalDuration <= 0) {
    return {
      displayCurrentTime: 0,
      displayTotalDuration: 0,
      displayProgressPercent: 0,
      activePartIndex: 0,
      accumulatedBeforePart: 0,
      offsetInPart: 0,
    };
  }

  const elapsed = (video && isFinite(video.currentTime)) ? Math.max(0, video.currentTime) : 0;
  const hasVirtualOverride = Number.isFinite(options.virtualTimeOverride);
  const clampedIndex = Math.max(0, Math.min(Number(mp.currentPartIndex || 0), mp.durationMap.length - 1));
  const mapEntry = mp.durationMap[clampedIndex];

  let activePartIndex = clampedIndex;
  // ALWAYS derive from durationMap — never fall back to completedDuration cache
  let accumulatedBeforePart = mapEntry ? mapEntry.start : 0;
  let offsetInPart = elapsed;

  if (hasVirtualOverride) {
    // Virtual override: resolve the requested time to a part via durationMap
    const requestedVirtual = Number(options.virtualTimeOverride);
    const clampedVirtual = Math.max(0, Math.min(requestedVirtual, totalDuration));
    const resolved = multipartFindPart(clampedVirtual);
    if (resolved) {
      activePartIndex = resolved.index;
      accumulatedBeforePart = resolved.part.start;
      offsetInPart = Math.max(0, clampedVirtual - accumulatedBeforePart);
    }
  } else {
    // Normal playback: clamp offset to part duration from durationMap
    const partDuration = mapEntry ? Math.max(0, mapEntry.end - mapEntry.start) : 0;
    if (partDuration > 0) {
      offsetInPart = Math.max(0, Math.min(elapsed, partDuration));
    }
  }

  const displayCurrentTime = Math.max(0, Math.min(accumulatedBeforePart + offsetInPart, totalDuration));
  const displayTotalDuration = totalDuration;
  const displayProgressPercent = displayTotalDuration > 0
    ? (displayCurrentTime / displayTotalDuration) * 100
    : 0;

  mp.timeline = {
    displayCurrentTime,
    displayTotalDuration,
    displayProgressPercent,
  };

  return {
    displayCurrentTime,
    displayTotalDuration,
    displayProgressPercent,
    activePartIndex,
    accumulatedBeforePart,
    offsetInPart,
  };
}

function getDisplayTimelineState(video, options = {}) {
  // If we are mid-seek across parts, freeze the UI at the target
  if (seekState.isCrossPartSeeking && !Number.isFinite(options.virtualTimeOverride)) {
    options.virtualTimeOverride = seekState.crossPartVirtualTime;
  }

  if (state.player.multipart.enabled) {
    return recalculateMultipartTimelineState(video, options);
  }

  const elapsed = (video && isFinite(video.currentTime)) ? Math.max(0, video.currentTime) : 0;
  const totalDuration = Number(video?.duration || 0);
  const safeTotal = totalDuration > 0 ? totalDuration : 0;
  
  const requestedCurrent = Number.isFinite(options.virtualTimeOverride)
    ? Number(options.virtualTimeOverride)
    : elapsed;
  const displayCurrentTime = safeTotal > 0
    ? Math.max(0, Math.min(requestedCurrent, safeTotal))
    : Math.max(0, requestedCurrent);
  const displayProgressPercent = safeTotal > 0
    ? (displayCurrentTime / safeTotal) * 100
    : 0;

  return {
    displayCurrentTime,
    displayTotalDuration: safeTotal,
    displayProgressPercent,
    activePartIndex: 0,
    accumulatedBeforePart: 0,
    offsetInPart: elapsed,
  };
}

function renderTimelineState(video, options = {}) {
  const timeline = getDisplayTimelineState(video, options);
  setVisualProgress(timeline.displayCurrentTime, timeline.displayTotalDuration);
  return timeline;
}

// ============================================================
// MULTIPART SEAMLESS PLAYBACK ENGINE
// ============================================================

/**
 * Find which part contains the given virtual time position.
 * Uses the precomputed durationMap for O(1)/binary-search efficiency.
 * @param {number} virtualTime - Time in seconds within the combined movie
 * @returns {{ index, part, offsetInPart }} or null
 */
function multipartFindPart(virtualTime) {
  const map = state.player.multipart.durationMap;
  if (!map || map.length === 0) return null;

  const t = Math.max(0, virtualTime);
  for (let i = 0; i < map.length; i++) {
    if (t >= map[i].start && t < map[i].end) {
      return { index: i, part: map[i], offsetInPart: t - map[i].start };
    }
  }
  // If beyond all parts, return last part and let offset overflow naturally
  // The player's native failsafe will clamp it to the true video duration later
  const last = map[map.length - 1];
  return { index: map.length - 1, part: last, offsetInPart: t - last.start };
}

/**
 * Get the current part's duration (actual from video element if available, else from map).
 */
function multipartCurrentPartDuration(video) {
  const mp = state.player.multipart;
  if (!mp.enabled) return 0;
  const mapEntry = mp.durationMap[mp.currentPartIndex];
  // Prefer actual video duration if loaded
  if (video && isFinite(video.duration) && video.duration > 0) {
    return video.duration;
  }
  return mapEntry ? (mapEntry.end - mapEntry.start) : 0;
}

/**
 * Correct the duration map when a part's actual duration is discovered via loadedmetadata.
 * This fixes estimated durations with real values.
 */
function multipartCorrectDuration(partIndex, actualDuration) {
  const mp = state.player.multipart;
  if (!mp.enabled || partIndex >= mp.durationMap.length) return;

  const entry = mp.durationMap[partIndex];
  const oldDuration = entry.end - entry.start;
  if (Math.abs(oldDuration - actualDuration) < 0.5) return; // Close enough

  console.log(`[Multipart] Correcting part ${partIndex + 1} duration: ${oldDuration.toFixed(1)}s → ${actualDuration.toFixed(1)}s`);

  // Update this entry and shift all subsequent entries
  entry.end = entry.start + actualDuration;
  mp.parts[partIndex].duration = actualDuration;

  for (let i = partIndex + 1; i < mp.durationMap.length; i++) {
    const prev = mp.durationMap[i - 1];
    const partDur = mp.parts[i].duration;
    mp.durationMap[i].start = prev.end;
    mp.durationMap[i].end = prev.end + partDur;
  }

  mp.totalDuration = mp.durationMap[mp.durationMap.length - 1].end;

  // Derive completedDuration from durationMap — single source of truth, no accumulation
  multipartSyncCompletedDuration();

  renderTimelineState(document.getElementById('video-player'));
}

/**
 * Switch to the next part automatically when current part ends.
 * Preserves playback state: speed, volume, fullscreen, subtitles.
 */
async function multipartAdvanceToNext() {
  const mp = state.player.multipart;
  if (!mp.enabled) return false;

  const nextIndex = mp.currentPartIndex + 1;
  if (nextIndex >= mp.parts.length) {
    console.log('[Multipart] All parts finished');
    return false; // No more parts
  }

  const video = document.getElementById('video-player');
  const buffering = document.getElementById('buffering-spinner');
  const switchStart = performance.now();

  // Save current playback state
  const preservedState = {
    playbackRate: video.playbackRate,
    volume: video._logicalVolume !== undefined ? video._logicalVolume : video.volume,
    muted: video.muted,
    subtitleTrackIndex: state.player.currentSubtitleTrack,
    audioTrackIndex: state.player.currentAudioTrack,
    isFullscreen: !!document.fullscreenElement,
  };

  // Correct duration map with actual duration (may adjust durationMap entries)
  const actualPartDuration = isFinite(video.duration) && video.duration > 0
    ? video.duration : multipartCurrentPartDuration(video);
  multipartCorrectDuration(mp.currentPartIndex, actualPartDuration);

  // Advance to next part — derive completedDuration from durationMap (single source of truth)
  mp.currentPartIndex = nextIndex;
  multipartSyncCompletedDuration();

  const nextPart = mp.parts[nextIndex];
  renderTimelineState(video, { virtualTimeOverride: mp.completedDuration });


  console.log(`[Multipart] Switching to part ${nextPart.partNumber}/${mp.parts.length} (fileId: ${nextPart.fileId})`);
  buffering?.classList.remove('hidden');

  try {
    await ensureFileRegistered(nextPart.fileId);

    const streamBaseUrl = state.player.useClientStreaming ? '/vstream' : '/api/stream';
    video.src = `${streamBaseUrl}/${nextPart.fileId}`;
    state.player.fileId = nextPart.fileId;

    video.load();

    // Restore playback state
    video.playbackRate = preservedState.playbackRate;
    if (preservedState.volume !== undefined) {
      setVolume(preservedState.volume);
    }

    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Part load timeout')), 15000);
      video.addEventListener('loadedmetadata', () => {
        clearTimeout(timeout);
        applyNativeAudioTrack(video);
        // Correct duration with actual value
        if (isFinite(video.duration) && video.duration > 0) {
          multipartCorrectDuration(nextIndex, video.duration);
        }
        resolve();
      }, { once: true });
      video.addEventListener('error', () => {
        clearTimeout(timeout);
        reject(new Error(`Failed to load part ${nextPart.partNumber}`));
      }, { once: true });
    });

    await video.play();
    buffering?.classList.add('hidden');
    renderTimelineState(video);

    // Update heartbeat to new fileId
    startHeartbeat(nextPart.fileId);

    // Restore subtitle track
    if (preservedState.subtitleTrackIndex >= 0) {
      const sub = state.player.subtitleTracks[preservedState.subtitleTrackIndex];
      if (sub && sub.source !== 'embedded') {
        // External subs are per-movie, keep them
      } else if (sub && sub.source === 'embedded') {
        state.player.subtitleTracks[preservedState.subtitleTrackIndex].endpoint =
          `/api/stream/${nextPart.fileId}/subtitle/${sub.streamIndex}`;
        switchSubs(preservedState.subtitleTrackIndex, null, 0).catch(() => {});
      }
    }

    const switchDelay = performance.now() - switchStart;
    console.log(`[Multipart] Part switch completed in ${switchDelay.toFixed(0)}ms`);

    mp._switchLog.push({
      from: nextIndex - 1,
      to: nextIndex,
      delay: Math.round(switchDelay),
      success: true,
      timestamp: Date.now(),
    });

    return true;
  } catch (error) {
    console.error(`[Multipart] Part switch failed:`, error.message);
    buffering?.classList.add('hidden');

    mp._switchLog.push({
      from: nextIndex - 1,
      to: nextIndex,
      delay: Math.round(performance.now() - switchStart),
      success: false,
      error: error.message,
      timestamp: Date.now(),
    });

    return false;
  }
}

/**
 * Seek to a virtual time position across parts.
 * Handles cross-part seeking with boundary snapping.
 */
let multipartSeekSequence = 0;

async function multipartSeek(virtualTime) {
  const mp = state.player.multipart;
  if (!mp.enabled) return;

  const video = document.getElementById('video-player');
  const buffering = document.getElementById('buffering-spinner');
  const totalDuration = mp.totalDuration;

  // Only clamp to 0, let upper bound overflow for uncorrected duration maps
  const clamped = Math.max(0, virtualTime);

  // Smart boundary snapping: if within 2s of a part boundary, snap to next part start
  const target = multipartFindPart(clamped);
  if (!target) return;

  let finalIndex = target.index;
  let finalOffset = target.offsetInPart;

  const partDuration = target.part.end - target.part.start;
  if (partDuration > 0 && (partDuration - finalOffset) < 2 && finalIndex < mp.parts.length - 1) {
    // Snap to next part start
    finalIndex = target.index + 1;
    finalOffset = 0;
    console.log(`[Multipart] Boundary snap: jumping to part ${finalIndex + 1}`);
  }

  // Use the correct part's start time (accounts for boundary snap)
  const finalPartStart = finalIndex < mp.durationMap.length
    ? Number(mp.durationMap[finalIndex].start || 0)
    : Number(target.part.start || 0);
  const targetVirtualTime = finalPartStart + finalOffset;
  renderTimelineState(video, { virtualTimeOverride: targetVirtualTime });

  if (finalIndex === mp.currentPartIndex) {
    // Same part - just seek within it
    video.currentTime = finalOffset;
    renderTimelineState(video, { virtualTimeOverride: targetVirtualTime });
    return;
  }

  // Different part - switch source
  mp.currentPartIndex = finalIndex;
  multipartSyncCompletedDuration();
  const targetPart = mp.parts[finalIndex];
  state.player.fileId = targetPart.fileId;

  console.log(`[Multipart] Cross-part seek to part ${targetPart.partNumber} at ${finalOffset.toFixed(1)}s`);
  buffering?.classList.remove('hidden');

  // Increment seek sequence to invalidate stale loadedmetadata handlers
  const thisSeekSeq = ++multipartSeekSequence;

  // Preserve playback state
  const preservedRate = video.playbackRate;
  const preservedSubIndex = state.player.currentSubtitleTrack;

  // Pause gracefully to avoid 'play request interrupted' error
  const wasPlaying = !video.paused;
  if (wasPlaying) video.pause();

  await ensureFileRegistered(targetPart.fileId);

  seekState.isCrossPartSeeking = true;
  seekState.crossPartVirtualTime = targetVirtualTime;

  const streamBaseUrl = state.player.useClientStreaming ? '/vstream' : '/api/stream';
  video.src = `${streamBaseUrl}/${targetPart.fileId}`;
  video.load();
  renderTimelineState(video, { virtualTimeOverride: targetVirtualTime });

  const seekTimeout = setTimeout(() => {
    if (thisSeekSeq !== multipartSeekSequence) return;
    console.warn(`[Multipart] Cross-part seek timed out for part ${targetPart.partNumber}`);
    buffering?.classList.add('hidden');
    seekState.isCrossPartSeeking = false;
    if (wasPlaying) video.play().catch(() => {});
  }, 15000);

  video.addEventListener('loadedmetadata', function onMeta() {
    if (thisSeekSeq !== multipartSeekSequence) return; // Stale seek, ignore
    clearTimeout(seekTimeout);
    seekState.isCrossPartSeeking = false;
    applyNativeAudioTrack(video);

    if (isFinite(video.duration) && video.duration > 0) {
      multipartCorrectDuration(finalIndex, video.duration);
    }

    // Seek to the target offset within this part
    if (finalOffset >= 0 && finalOffset < video.duration) {
      video.currentTime = finalOffset;
    }

    // Restore playback rate
    video.playbackRate = preservedRate;

    renderTimelineState(video, { virtualTimeOverride: targetVirtualTime });
    if (wasPlaying) video.play().catch(() => {});
    buffering?.classList.add('hidden');

    // Restore subtitle track for the new part
    if (preservedSubIndex >= 0 && preservedSubIndex < state.player.subtitleTracks.length) {
      const sub = state.player.subtitleTracks[preservedSubIndex];
      if (sub && sub.source === 'embedded') {
        sub.endpoint = `/api/stream/${targetPart.fileId}/subtitle/${sub.streamIndex}`;
        switchSubs(preservedSubIndex, null, 0).catch(() => {});
      }
      // External subs are per-movie, no endpoint change needed
    }
  }, { once: true });

  video.addEventListener('error', function onErr() {
    if (thisSeekSeq !== multipartSeekSequence) return;
    clearTimeout(seekTimeout);
    console.error(`[Multipart] Failed to load part ${targetPart.partNumber} during seek`);
    buffering?.classList.add('hidden');
  }, { once: true });

  startHeartbeat(targetPart.fileId);
}

/**
 * Initialize multipart playback from part-info API response.
 */
async function multipartInit(fileId, parts) {
  const mp = state.player.multipart;

  try {
    const partInfo = await api(`/api/stream/${fileId}/part-info`);
    if (!partInfo || !partInfo.isSplit || !partInfo.parts || partInfo.parts.length <= 1) {
      mp.enabled = false;
      return false;
    }

    mp.enabled = true;
    mp.parts = partInfo.parts;
    mp.durationMap = partInfo.durationMap;
    mp.totalDuration = partInfo.totalDuration;
    mp.currentPartIndex = 0;
    mp.completedDuration = 0;
    mp._switchLog = [];
    mp.timeline = {
      displayCurrentTime: 0,
      displayTotalDuration: Number(partInfo.totalDuration || 0),
      displayProgressPercent: 0,
    };

    console.log(`[Multipart] Initialized: ${mp.parts.length} parts, total ${mp.totalDuration.toFixed(0)}s`);
    console.log('[Multipart] Duration map:', mp.durationMap.map(d =>
      `Part ${d.part}: ${d.start.toFixed(0)}s-${d.end.toFixed(0)}s${d.estimated ? ' (est)' : ''}`
    ).join(', '));

    return true;
  } catch (error) {
    console.warn('[Multipart] Init failed:', error.message);
    mp.enabled = false;
    return false;
  }
}

function setVisualProgress(currentTime, totalDuration) {
  const safeTotal = Number(totalDuration || 0);
  const safeCurrent = Math.max(0, Number(currentTime || 0));
  const pct = safeTotal > 0 ? Math.min(100, (safeCurrent / safeTotal) * 100) : 0;

  document.getElementById('progress-bar').style.width = `${pct}%`;
  document.getElementById('time-display').textContent =
    `${fmtTime(safeCurrent)} / ${fmtTime(safeTotal)}`;
  if (progressRefs.container) {
    progressRefs.container.style.setProperty('--progress', pct / 100);
  }
  if (progressRefs.timeDisplay) {
    progressRefs.timeDisplay.textContent = `${fmtTime(safeCurrent)} / ${fmtTime(safeTotal)}`;
  }
}

function setVisualBuffer(bufferedTime, totalDuration) {
  const safeTotal = Number(totalDuration || 0);
  const safeBuffered = Math.max(0, Number(bufferedTime || 0));
  const ratio = safeTotal > 0 ? Math.min(1, safeBuffered / safeTotal) : 0;
  document.getElementById('progress-buffer').style.width = `${ratio * 100}%`;
  if (progressRefs.container) {
    progressRefs.container.style.setProperty('--buffer', ratio);
  }
}

function parseVTT(vttText) {
  const cues = [];
  if (!vttText) return cues;

  const blocks = vttText.split(/\n\s*\n/);

  for (const block of blocks) {
    const lines = block.trim().split('\n');
    let timestampLineIdx = -1;

    for (let i = 0; i < lines.length; i++) {
      if (lines[i].includes('-->')) {
        timestampLineIdx = i;
        break;
      }
    }

    if (timestampLineIdx === -1) continue;

    const tsLine = lines[timestampLineIdx];
    // Support optional hours (1+ digits), 1-2 digit minutes/seconds, dots/commas, and 1-3 digit milliseconds
    const match = tsLine.trim().match(
      /^(?:(\d+):)?(\d{1,2}):(\d{1,2})[.,](\d{1,3})\s*-->\s*(?:(\d+):)?(\d{1,2}):(\d{1,2})[.,](\d{1,3})/
    );
    if (!match) continue;

    const startH = parseInt(match[1] || '0', 10);
    const startM = parseInt(match[2], 10);
    const startS = parseInt(match[3], 10);
    
    // Pad milliseconds to 3 digits (e.g. .5 -> 500ms, .50 -> 500ms)
    const startMsStr = match[4].padEnd(3, '0');
    const startMs = parseInt(startMsStr, 10);

    const endH = parseInt(match[5] || '0', 10);
    const endM = parseInt(match[6], 10);
    const endS = parseInt(match[7], 10);
    
    const endMsStr = match[8].padEnd(3, '0');
    const endMs = parseInt(endMsStr, 10);

    const start = startH * 3600 + startM * 60 + startS + startMs / 1000;
    const end = endH * 3600 + endM * 60 + endS + endMs / 1000;
    const text = lines.slice(timestampLineIdx + 1).join('\n').trim();

    if (text && end > start) {
      cues.push({ start, end, text });
    }
  }

  cues.sort((a, b) => a.start - b.start);
  return cues;
}

function renderSubtitles(actualTimeSeconds) {
  const display = document.getElementById('subtitle-display');
  const cues = state.player.parsedCues;

  if (!cues || cues.length === 0 || state.player.currentSubtitleTrack === -1) {
    if (display.innerHTML !== '') display.innerHTML = '';
    return;
  }

  // ── SUBTITLE OFFSET ──────────────────────────────────────
  // Shift the lookup time by the user-configured offset.
  // Positive offset = subtitle delayed (shows later).
  // Negative offset = subtitle earlier (shows sooner).
  const lookupTime = actualTimeSeconds - (state.player.subtitleOffset || 0);
  // ─────────────────────────────────────────────────────────

  let text = '';
  for (let i = 0; i < cues.length; i++) {
    const cue = cues[i];
    if (lookupTime >= cue.start && lookupTime <= cue.end) {
      if (text) text += '\n';
      text += cue.text;
    }
    if (cue.start > lookupTime + 5) break;
  }

  if (text) {
    display.innerHTML = '<span>' + escapeSubHTML(text).replace(/\n/g, '<br>') + '</span>';
  } else if (display.innerHTML !== '') {
    display.innerHTML = '';
  }
}

function startProgressRAF(video, signal) {
  let rafId = 0;
  let lastDriftCheck = 0;

  const tick = () => {
    if (signal.aborted) return;

    const timeline = getDisplayTimelineState(video);
    const duration = timeline.displayTotalDuration;

    // --- Multipart drift detection (every 30s) ---
    if (state.player.multipart.enabled && duration > 0) {
      const now = performance.now();
      if (now - lastDriftCheck > 30000) {
        lastDriftCheck = now;
        const mp = state.player.multipart;
        const authoritativeGlobal = multipartCalculateGlobalTime(video);
        const displayedGlobal = timeline.displayCurrentTime;
        const drift = Math.abs(authoritativeGlobal - displayedGlobal);
        const mapStart = mp.durationMap[mp.currentPartIndex]?.start ?? -1;
        const cachedCompleted = mp.completedDuration;
        const cacheDrift = Math.abs(mapStart - cachedCompleted);

        if (drift > 0.5 || cacheDrift > 0.1) {
          console.warn('[Multipart Drift]', {
            currentPartIndex: mp.currentPartIndex,
            videoCurrentTime: video.currentTime,
            durationMapStart: mapStart,
            completedDuration: cachedCompleted,
            cacheDrift: cacheDrift.toFixed(3),
            authoritativeGlobal: authoritativeGlobal.toFixed(3),
            displayedGlobal: displayedGlobal.toFixed(3),
            drift: drift.toFixed(3),
          });
          // Auto-correct: sync completedDuration from durationMap
          if (cacheDrift > 0.1) {
            multipartSyncCompletedDuration();
          }
        } else {
          console.log(`[Multipart Sync] OK — drift=${drift.toFixed(3)}s, part=${mp.currentPartIndex + 1}/${mp.parts.length}, global=${authoritativeGlobal.toFixed(1)}s/${mp.totalDuration.toFixed(1)}s`);
        }
      }
    }

    if (duration && isFinite(duration) && !seekState.dragging && !seekState.keyboardSeeking) {
      setVisualProgress(timeline.displayCurrentTime, timeline.displayTotalDuration);
    }

    if (duration && isFinite(duration) && video.buffered.length > 0) {
      // Calculate buffer offset relative to current part
      const timeOffset = state.player.multipart.enabled ? timeline.accumulatedBeforePart : 0;
      const seekOffset = timeOffset;

      let bufPct = 0;
      for (let i = 0; i < video.buffered.length; i++) {
        if (video.buffered.start(i) <= video.currentTime &&
          video.currentTime <= video.buffered.end(i)) {
          bufPct = (video.buffered.end(i) + seekOffset) / duration;
          break;
        }
      }
      if (bufPct === 0 && video.buffered.length > 0) {
        bufPct = (video.buffered.end(video.buffered.length - 1) + seekOffset) / duration;
      }
      if (progressRefs.container) {
        progressRefs.container.style.setProperty('--buffer', Math.min(1, bufPct));
      }
      setVisualBuffer((bufPct || 0) * duration, duration);
    }

    if (duration && isFinite(duration)) {
      renderSubtitles(timeline.displayCurrentTime);
    }

    rafId = requestAnimationFrame(tick);
  };

  rafId = requestAnimationFrame(tick);
  signal.addEventListener('abort', () => cancelAnimationFrame(rafId), { once: true });
}



// ============================================================
// PLAY VIDEO — Main entry point
// ============================================================
async function playVideo(params, pushState = true) {
  // params: { fileId, title, season, episode, episodeTitle, tmdbId }

  // Sanitize params (handle string "null"/"undefined" from onclick attributes)
  if (params.season === 'null' || params.season === 'undefined') params.season = null;
  if (params.episode === 'null' || params.episode === 'undefined') params.episode = null;
  if (params.episodeTitle === 'null' || params.episodeTitle === 'undefined') params.episodeTitle = null;
  if (params.tmdbId === 'null' || params.tmdbId === 'undefined') params.tmdbId = null;

  // Smart Recovery: If played from a corrupted Continue Watching entry, we might lack tmdbId, season, and episode.
  if (!params.tmdbId || !params.season) {
    if (state.data && state.data.tvShows) {
      for (const show of state.data.tvShows) {
        if (!show.seasons) continue;
        for (const s of Object.keys(show.seasons)) {
           for (const ep of show.seasons[s]) {
              if (String(ep.fileId) === String(params.fileId)) {
                 params.tmdbId = show.showTmdbId;
                 params.season = Number(s);
                 params.episode = ep.tv?.episodeNumber || Number(ep.episodeNumber) || 1;
                 if (params.title === 'Movie' || params.title === 'Loading...') params.title = show.showTitle;
                 params.poster = show.poster || show.backdrop;
                 break;
              }
           }
        }
        if (params.tmdbId) break;
      }
    }
    // Also check movies to recover poster if missing
    if (!params.tmdbId && state.data && state.data.movies) {
       const m = state.data.movies.find(mv => String(mv.fileId) === String(params.fileId));
       if (m && !params.poster) {
          params.poster = m.poster || m.backdrop;
          if (params.title === 'Movie' || params.title === 'Loading...') params.title = m.title;
       }
    }
  }

  params.isTV = params.season !== null && params.season !== undefined;

  // Retrieve parts from window variable if flagged by modal
  if (params._useStoredParts && window._pendingMovieParts) {
    params.parts = window._pendingMovieParts;
    window._pendingMovieParts = null;
    console.log('[Multipart] playVideo: retrieved stored parts:', params.parts.length);
  }
  delete params._useStoredParts;

  console.log('[DEBUG] playVideo called:', JSON.stringify({
    fileId: params.fileId,
    title: params.title,
    hasParts: !!(params.parts && params.parts.length > 1),
    partsCount: params.parts ? params.parts.length : 0,
    season: params.season,
  }));

  // We don't pushState in closeModal since we will immediately pushState for playVideo
  closeModal(false);

  // RESET EVERYTHING FIRST
  resetPlayerState();

  // Set new state
  state.player.active = true;
  state.player.fileId = params.fileId;
  state.player.title = params.title;
  state.player.season = params.season || null;
  state.player.episode = params.episode || null;
  state.player.episodeTitle = params.episodeTitle || null;

  // Dynamically resolve missing titles for unindexed items
  if (params.title === 'Loading...' || params.title === 'Playing Movie') {
    api(`/api/metadata/${params.fileId}`).then(meta => {
      if (meta) {
        if (meta.tv?.showTitle) state.player.title = meta.tv.showTitle;
        else if (meta.title) state.player.title = meta.title;
        
        const titleEl = document.getElementById('player-title-main');
        if (titleEl) titleEl.textContent = state.player.title;

        const sheetTitleEl = document.getElementById('episodes-sheet-title');
        if (sheetTitleEl && sheetTitleEl.textContent === 'Loading...') {
          sheetTitleEl.textContent = state.player.title;
        }
      }
    });
  }
  state.player.tmdbId = params.tmdbId || null;

  if (pushState) {
    let url = `/play/movie/${params.fileId}`;
    if (params.season) {
      // If we have TMDB ID, use it for cleaner URL, else fallback to fileId
      const targetId = params.tmdbId || params.fileId;
      url = `/play/tv/${targetId}?s=${params.season}&e=${params.episode || ''}&f=${params.fileId}${params.episodeTitle ? `&et=${encodeURIComponent(params.episodeTitle)}` : ''}`;
    }
    window.history.pushState({ route: 'play', params }, '', url);
  }

  const screen = document.getElementById('player-screen');
  const video = document.getElementById('video-player');

  // UI setup
  screen.classList.remove('hidden');
  document.body.style.overflow = 'hidden';

  // Control button is visible for episode playback. Floating button appears near ending only.
  setNextEpisodeControlVisible(hasEpisodeContext(params));
  setNextEpisodeFloatingVisible(false);

  const btnEpisodes = document.getElementById('btn-episodes');
  if (params.season) {
    if (btnEpisodes) btnEpisodes.classList.remove('hidden');
    // Prepare the panel data ahead of time but do NOT show the sheet until button clicked
    renderEpisodesPanel(params);
  } else {
    if (btnEpisodes) btnEpisodes.classList.add('hidden');
    document.getElementById('episodes-sheet')?.classList.add('hidden');
    document.getElementById('episodes-sheet-overlay')?.classList.add('hidden');
  }

  document.getElementById('player-title-main').textContent = params.title;

  let subTitleText = '';
  if (params.season) {
    subTitleText = `Season ${params.season} Episode ${params.episode}`;
    if (params.episodeTitle && !params.episodeTitle.toLowerCase().startsWith('episode ')) {
      subTitleText += ` - ${params.episodeTitle}`;
    }
  }
  document.getElementById('player-title-sub').textContent = subTitleText;

  // Show buffering spinner immediately
  document.getElementById('buffering-spinner').classList.remove('hidden');

  // Init client-side streaming worker lazily
  await initTelegramWorker();

  // Fetch tracks, external subtitles, AND multipart info concurrently
  let tracks = null;
  let externalSubs = [];
  let fileInfo = null;

  try {
    const fetchJobs = [
      api(`/api/stream/${params.fileId}/tracks`),
      api(`/api/subtitles/movie/${params.fileId}`),
      api(`/api/stream/${params.fileId}/file-info`)
    ];

    // If parts were passed from the modal, also fetch part-info for durations
    const hasPartsHint = params.parts && Array.isArray(params.parts) && params.parts.length > 1;
    if (hasPartsHint) {
      fetchJobs.push(multipartInit(params.fileId, params.parts));
    }

    const results = await Promise.allSettled(fetchJobs);

    if (results[0].status === 'fulfilled') {
      tracks = results[0].value;
    }

    if (results[1].status === 'fulfilled' && results[1].value?.subtitles) {
      externalSubs = results[1].value.subtitles.map(s => ({
        ...s,
        source: s.source || 'SubDL',
        endpoint: `/api/subtitles/file/${s.id}`,
      }));

      // Prioritize "HI" / "Hearing Impaired" subtitles
      externalSubs.sort((a, b) => {
        const aHI = a.rating === '🔇 HI' || a.label?.toUpperCase().includes('HI') || a.label?.toUpperCase().includes('HEARING IMPAIRED');
        const bHI = b.rating === '🔇 HI' || b.label?.toUpperCase().includes('HI') || b.label?.toUpperCase().includes('HEARING IMPAIRED');
        if (aHI && !bHI) return -1;
        if (!aHI && bHI) return 1;
        return 0;
      });
    }

    if (results[2] && results[2].status === 'fulfilled' && results[2].value) {
      fileInfo = results[2].value;
      if (telegramWorker) {
        telegramWorker.postMessage({
          type: 'REGISTER_FILE',
          ...fileInfo
        });
      }
    }
  } catch (e) {
    console.warn('Parallel fetch failed:', e);
  }

  state.player.audioTracks = tracks?.audioTracks || [];
  
  // Browsers ignore the MKV `default` flag and just play the first physical stream (index 0).
  // Therefore, the only track that plays natively without transcoding is track 0.
  state.player.defaultAudioTrack = 0;
  state.player.currentAudioTrack = 0;

  state.player.duration = tracks?.duration || 0;

  // Only use external subtitles natively on web
  state.player.subtitleTracks = [...externalSubs];

  // Safari/MKV fallback detect
  const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent);
  const isMKV = fileInfo && (fileInfo.mimeType === 'video/x-matroska' || fileInfo.fileName?.endsWith('.mkv'));
  
  state.player.useClientStreaming = telegramWorker && !(isSafari && isMKV);
  const streamBaseUrl = state.player.useClientStreaming ? '/vstream' : '/api/stream';

  video.src = `${streamBaseUrl}/${params.fileId}`;
  video.currentTime = 0;
  
  // Resume from where left off if available
  if (typeof fetchWatchProgress === 'function') {
    fetchWatchProgress().then(progressItems => {
      if (progressItems) {
        const prog = progressItems.find(p => String(p.file_id) === String(params.fileId));
        if (prog && prog.position_seconds > 5 && (prog.duration_seconds - prog.position_seconds > 30)) {
          const doSeek = () => {
            if (state.player.multipart && state.player.multipart.enabled) {
              multipartSeek(prog.position_seconds);
            } else {
              video.currentTime = prog.position_seconds;
            }
          };

          if (video.readyState >= 1) {
            // Metadata is already loaded and the duration map is corrected.
            // But we add a tiny delay to ensure the onFirstMeta event fully completed.
            setTimeout(doSeek, 10);
          } else {
            // Queue the seek to happen after metadata is loaded (and duration map is corrected)
            video.addEventListener('loadedmetadata', () => setTimeout(doSeek, 10), { once: true });
          }
        }
      }
    }).catch(e => console.warn('Failed to load resume position:', e));
  }
  
  video.load();

  // Apply native track and correct multipart duration when first part's actual duration is discovered
  video.addEventListener('loadedmetadata', function onFirstMeta() {
    applyNativeAudioTrack(video);
    if (state.player.multipart.enabled && isFinite(video.duration) && video.duration > 0) {
      multipartCorrectDuration(0, video.duration);
    }
  }, { once: true, signal: state.player.abortController?.signal });

  // Wire up controls BEFORE play() so 'playing' event listener catches the first play
  setupPlayerListeners();
  updateTrackInfoUI();

  // Check if default audio is unsupported and show modal automatically
  const defaultTrack = state.player.audioTracks[state.player.defaultAudioTrack];
  if (defaultTrack && !defaultTrack.browserPlayable) {
    const downloadUrl = state.config?.appDownloadUrl || 'https://github.com/StreamFlix/StreamFlix/releases';
    showAppNudgeModal(downloadUrl, true);
  }

  // Subtitles default to OFF based on user preference
  state.player.currentSubtitleTrack = -1;
  try {
    await video.play();
  } catch (e) { console.warn('Autoplay blocked:', e); }

  // Start heartbeat — keeps backend session alive during buffered playback
  startHeartbeat(params.fileId);

  // Watch Progress Heartbeat
  function triggerSaveProgress() {
    let currentPos = Math.floor(video.currentTime);
    let totalDur = Math.floor(video.duration);

    if (state.player.multipart && state.player.multipart.enabled) {
      currentPos = Math.floor(multipartCalculateGlobalTime(video));
      totalDur = Math.floor(state.player.multipart.totalDuration);
    }

    if (currentPos > 5 && totalDur > 0 && typeof saveWatchProgress === 'function') {
      let titleToSave = params.title || 'Movie';
      let posterToSave = params.poster;
      
      let mediaTypeToSave = params.isTV ? 'tv' : 'movie';
      let seasonToSave = params.season || null;
      let episodeToSave = params.episode || null;
      let showIdToSave = params.tmdbId ? String(params.tmdbId) : null;

      if (params.isTV) {
        if (!titleToSave || titleToSave === 'Movie') {
          titleToSave = 'TV Show';
        }
        if (!posterToSave) {
          const showInfo = state.data?.tvShows?.find(s => String(s.showTmdbId) === String(params.tmdbId)) || {};
          posterToSave = showInfo.poster || showInfo.backdrop;
          if (titleToSave === 'TV Show' && showInfo.showTitle) {
             titleToSave = showInfo.showTitle;
          }
        }
      } else {
        if (!posterToSave) {
          const movieInfo = state.data?.movies?.find(m => String(m.fileId) === String(params.fileId)) || {};
          posterToSave = movieInfo.poster || movieInfo.backdrop;
          if (titleToSave === 'Movie' && movieInfo.title) {
             titleToSave = movieInfo.title;
          }
        }
      }

      saveWatchProgress(params.fileId, currentPos, totalDur, titleToSave, posterToSave, mediaTypeToSave, seasonToSave, episodeToSave, showIdToSave);
    }
  }

  video.addEventListener('playing', () => {
    if (!state.player._watchProgressInterval) {
      state.player._watchProgressInterval = setInterval(triggerSaveProgress, 10000);
    }
  }, { signal: state.player.abortController?.signal });

  video.addEventListener('pause', () => {
    triggerSaveProgress();
    if (state.player._watchProgressInterval) {
      clearInterval(state.player._watchProgressInterval);
      state.player._watchProgressInterval = null;
    }
  }, { signal: state.player.abortController?.signal });

  // Export for closePlayer
  state.player._triggerSaveProgress = triggerSaveProgress;
  window.addEventListener('beforeunload', state.player._triggerSaveProgress, { signal: state.player.abortController?.signal });
  video.addEventListener('ended', state.player._triggerSaveProgress, { signal: state.player.abortController?.signal });
}

// ============================================================
// CLOSE PLAYER — Exit fullscreen first, then clean up
// ============================================================
async function closePlayer(pushState = true) {
  // Exit fullscreen FIRST — wait for browser to fully transition
  if (document.fullscreenElement) {
    try {
      await document.exitFullscreen();
      // Give browser time to finish fullscreen transition
      await new Promise(r => setTimeout(r, 100));
    } catch (e) { }
  }

  const screen = document.getElementById('player-screen');
  const video = document.getElementById('video-player');
  const subtitleDisplay = document.getElementById('subtitle-display');

  state.player.active = false;
  stopHeartbeat();

  clearTimeout(seekState.pendingSeekTimer);
  clearTimeout(seekState.keyboardTimer);
  seekState.pendingSeekTimer = null;
  seekState.keyboardTimer = null;
  seekState.keyboardAccum = 0;
  seekState.keyboardSeeking = false;
  seekState.dragging = false;
  seekState.lastActualSeek = 0;
  progressRefs.container = null;
  progressRefs.timeDisplay = null;
  progressRefs.video = null;

  // Abort all player event listeners
  if (state.player.abortController) {
    state.player.abortController.abort();
    state.player.abortController = null;
  }

  // Clear subtitles
  if (subtitleDisplay) subtitleDisplay.innerHTML = '';

  // Remove all track elements and revoke blob URLs
  video.querySelectorAll('track').forEach(track => {
    if (track.src && track.src.startsWith('blob:')) {
      URL.revokeObjectURL(track.src);
    }
    track.remove();
  });
  for (let i = 0; i < video.textTracks.length; i++) {
    video.textTracks[i].mode = 'disabled';
  }

  // Clear watch progress heartbeat
  if (state.player._triggerSaveProgress) {
    state.player._triggerSaveProgress();
    window.removeEventListener('beforeunload', state.player._triggerSaveProgress);
  }
  if (state.player._watchProgressInterval) {
    clearInterval(state.player._watchProgressInterval);
  }
  state.player._watchProgressInterval = null;
  state.player._triggerSaveProgress = null;

  // Reset subtitle state
  state.player.currentSubtitleTrack = -1;
  state.player.subtitleTracks = [];
  state.player.defaultAudioTrack = 0;
  state.player.duration = 0;
  state.player.parsedCues = null;
  state.player.subtitleVTTCache = {};
  state.player.subtitleOffset = 0;
  state.player._syncSeenTime = null;

  video.pause();
  video.removeAttribute('src');
  video.load();
  screen.classList.add('hidden');
  screen.classList.remove('cursor-none');
  document.body.style.overflow = '';

  // Roll back URL
  if (pushState) {
    let url = '/';
    if (state.currentRoute === 'movies') url = '/movies';
    else if (state.currentRoute === 'tvshows') url = '/tvshows';
    else if (state.currentRoute === 'search') {
      const queryParams = new URLSearchParams(window.location.search);
      url = queryParams.has('q') ? `/search?q=${queryParams.get('q')}` : '/search';
    }
    window.history.pushState({ route: state.currentRoute }, '', url);

    // Check if we need to restore a modal
    if (state.player.tmdbId) {
      openDetail(state.player.tmdbId, 'tv', true);
    }
  }
}

// ============================================================
// HEARTBEAT — Keeps backend session alive
// ============================================================
function startHeartbeat(fileId) {
  stopHeartbeat();
  fetch(`/api/stream/${fileId}/heartbeat`).catch(() => { });
  state.player.heartbeatTimer = setInterval(() => {
    fetch(`/api/stream/${fileId}/heartbeat`).catch(() => { });
  }, 20000);
}

function stopHeartbeat() {
  if (state.player.heartbeatTimer) {
    clearInterval(state.player.heartbeatTimer);
    state.player.heartbeatTimer = null;
  }
}

// ============================================================
// SETUP PLAYER LISTENERS — All via AbortController
// ============================================================
function setupPlayerListeners() {
  // Kill all previous listeners via AbortController
  if (state.player.abortController) state.player.abortController.abort();
  state.player.abortController = new AbortController();
  const signal = state.player.abortController.signal;

  const video = document.getElementById('video-player');
  const screen = document.getElementById('player-screen');
  const controls = document.getElementById('player-controls-layer');
  const buffering = document.getElementById('buffering-spinner');
  const nextBtn = document.getElementById('next-episode-btn');

  // Helper — all listeners automatically cleaned up when controller is aborted
  const on = (target, type, handler, opts = {}) => {
    target.addEventListener(type, handler, { signal, ...opts });
  };

  // ---- BUFFERING SPINNER ----
  on(video, 'waiting', () => { if (!video.paused) buffering.classList.remove('hidden'); });
  on(video, 'playing', () => buffering.classList.add('hidden'));
  on(video, 'canplay', () => buffering.classList.add('hidden'));
  on(video, 'canplaythrough', () => buffering.classList.add('hidden'));
  on(video, 'seeked', () => { if (!video.paused) buffering.classList.add('hidden'); });
  on(video, 'stalled', () => { if (!video.paused) buffering.classList.remove('hidden'); });

  // ---- PROGRESS / TIME ----
  on(video, 'timeupdate', () => {
    const duration = getEffectiveDuration(video);
    const currentTime = getEffectiveCurrentTime(video);

    if (hasEpisodeContext(state.player) &&
      duration > 0 && (duration - currentTime < 30)) {
      setNextEpisodeFloatingVisible(true);
    } else {
      setNextEpisodeFloatingVisible(false);
    }

  });
  on(video, 'progress', updateBuffer);

  // ---- MULTIPART: Auto-advance to next part on ended ----
  on(video, 'ended', async () => {
    if (state.player.multipart.enabled) {
      const mp = state.player.multipart;
      if (mp.currentPartIndex < mp.parts.length - 1) {
        console.log(`[Multipart] Part ${mp.currentPartIndex + 1} ended, advancing...`);
        const success = await multipartAdvanceToNext();
        if (success) return; // Playback continues
      }
      // All parts finished or advance failed — fall through to normal ended behavior
      console.log('[Multipart] Playback complete');
    }
  });

  // ---- PLAY/PAUSE STATE (driven by video events, not clicks) ----
  on(video, 'play', () => {
    updatePlayPauseIcon();
    if (state.player.fileId) startHeartbeat(state.player.fileId);
  });
  on(video, 'pause', () => {
    updatePlayPauseIcon();
    stopHeartbeat();
  });
  on(video, 'volumechange', updateVolumeUI);
  on(video, 'ratechange', updateSpeedUI);

  // ---- CLICK/TAP TO PLAY/PAUSE (with double-tap seek support) ----
  let singleTapTimer = null;
  let lastTapTime = 0;
  let lastTapX = 0;

  // For mouse clicks (desktop) — fire instantly
  on(screen, 'click', (e) => {
    // Ignore if this was a touch event (we handle touch separately below)
    if (e.sourceCapabilities && e.sourceCapabilities.firesTouchEvents) return;

    if (!e.target.closest('.player-controls-layer') &&
      !e.target.closest('.next-episode-btn') &&
      !e.target.closest('.track-panel')) {
      togglePlay();
    }
  });
  on(controls, 'click', (e) => {
    if (e.sourceCapabilities && e.sourceCapabilities.firesTouchEvents) return;
    if (e.target === controls) togglePlay();
  });

  // For touch — delay single-tap to allow double-tap detection
  let controlsWereHidden = false;

  on(screen, 'touchstart', () => {
    controlsWereHidden = document.getElementById('player-controls-layer').classList.contains('hidden');
    showControls();
  }, { passive: true });

  on(screen, 'touchend', (e) => {
    if (e.target.closest('.player-controls-layer') ||
      e.target.closest('.next-episode-btn') ||
      e.target.closest('.track-panel')) return;

    const now = Date.now();
    const touch = e.changedTouches[0];
    const x = touch.clientX;

    if (now - lastTapTime < 300 && Math.abs(x - lastTapX) < 80) {
      // === Double tap detected ===
      e.preventDefault();
      // Cancel the pending single-tap play/pause
      if (singleTapTimer) { clearTimeout(singleTapTimer); singleTapTimer = null; }

      const width = screen.clientWidth;
      if (x < width / 3) {
        seekRelative(-10);
        showRipple('left');
      } else if (x > (width * 2) / 3) {
        seekRelative(10);
        showRipple('right');
      }
      lastTapTime = 0; // Reset to prevent triple-tap
    } else {
      // === First tap ===
      lastTapTime = now;
      lastTapX = x;

      // If controls were hidden, this tap was just to show them. Do NOT toggle play.
      if (controlsWereHidden) return;

      if (singleTapTimer) clearTimeout(singleTapTimer);
      singleTapTimer = setTimeout(() => {
        singleTapTimer = null;
        togglePlay();
      }, 300);
    }
  });

  // ---- AUTO-HIDE CONTROLS ----
  let hideTimer;
  let isMenuHovered = false; // State to track hover on interactive menus

  const showControls = () => {
    controls.classList.remove('hidden');
    screen.classList.remove('cursor-none');
    clearTimeout(hideTimer);
    if (!video.paused && !isMenuHovered) {
      hideTimer = setTimeout(() => {
        controls.classList.add('hidden');
        screen.classList.add('cursor-none');
        document.getElementById('speed-menu')?.classList.add('hidden');
        document.getElementById('track-panel')?.classList.add('hidden');
      }, 3000);
    }
  };

  on(screen, 'mousemove', showControls);
  on(screen, 'click', showControls);

  // Keep controls visible when hovering over interactive components
  on(controls, 'mouseover', () => {
    isMenuHovered = true;
    showControls();
  });
  on(controls, 'mouseout', () => {
    isMenuHovered = false;
    showControls();
  });
  on(video, 'pause', () => {
    // Keep controls visible when paused
    controls.classList.remove('hidden');
    screen.classList.remove('cursor-none');
    clearTimeout(hideTimer);
  });
  on(video, 'play', showControls);



  // ---- CONTROL BUTTONS ----
  on(document.getElementById('btn-play-pause'), 'click', (e) => {
    e.stopPropagation();
    togglePlay();
  });
  on(document.getElementById('btn-ff-10'), 'click', (e) => {
    e.stopPropagation();
    seekRelative(10);
  });
  on(document.getElementById('btn-rw-10'), 'click', (e) => {
    e.stopPropagation();
    seekRelative(-10);
  });
  on(document.getElementById('close-player'), 'click', (e) => {
    e.stopPropagation();
    closePlayer();
  });

  // ---- VOLUME ----
  on(document.getElementById('btn-volume'), 'click', (e) => {
    e.stopPropagation();
    toggleMute();
  });
  on(document.getElementById('volume-slider'), 'input', (e) => {
    e.stopPropagation();
    setVolume(parseFloat(e.target.value));
  });
  on(document.getElementById('volume-slider'), 'click', (e) => e.stopPropagation());

  // ---- FULLSCREEN & PiP ----
  on(document.getElementById('btn-fullscreen'), 'click', (e) => {
    e.stopPropagation();
    toggleFullscreen();
  });

  on(document, 'fullscreenchange', () => {
    // Sync fullscreen icon
    const btn = document.getElementById('btn-fullscreen');
    if (document.fullscreenElement) {
      btn.innerHTML = `<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M8 3v3a2 2 0 0 1-2 2H3m18 0h-3a2 2 0 0 1-2-2V3m0 18v-3a2 2 0 0 1 2-2h3M3 16h3a2 2 0 0 1 2 2v3"></path></svg>`;
    } else {
      btn.innerHTML = `<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3"></path></svg>`;
    }
  });

  // ---- SPEED DROPDOWN (event delegation) ----
  const speedBtn = document.getElementById('btn-speed');
  const speedMenu = document.getElementById('speed-menu');
  on(speedBtn, 'click', (e) => {
    e.stopPropagation();
    speedMenu.classList.toggle('hidden');
  });
  on(speedMenu, 'click', (e) => {
    e.stopPropagation();
    const option = e.target.closest('[data-speed]');
    if (!option) return;
    const speed = parseFloat(option.dataset.speed);
    if (isNaN(speed)) return;
    video.playbackRate = speed;
    speedMenu.classList.add('hidden');
  });
  // Close speed menu when clicking elsewhere
  on(document, 'click', (e) => {
    if (!speedBtn.contains(e.target) && !speedMenu.contains(e.target)) {
      speedMenu.classList.add('hidden');
    }
  });

  // ---- TRACKS PANEL ----
  on(document.getElementById('btn-cc'), 'click', (e) => {
    e.stopPropagation();
    document.getElementById('track-panel').classList.toggle('hidden');
  });
  on(document.getElementById('close-tracks-btn'), 'click', () => {
    document.getElementById('track-panel').classList.add('hidden');
  });

  // Close track panel when clicking elsewhere (Mobile/Desktop)
  on(document, 'click', (e) => {
    const trackPanel = document.getElementById('track-panel');
    const ccBtn = document.getElementById('btn-cc');
    if (trackPanel && !trackPanel.classList.contains('hidden')) {
      if (!trackPanel.contains(e.target) && !ccBtn.contains(e.target)) {
        trackPanel.classList.add('hidden');
      }
    }
  });


  // ---- PREVENT AUTO-HIDE ON HOVER (Subtitle/Speed Menus) ----
  const preventHide = () => {
    isMenuHovered = true;
    if (hideTimer) clearTimeout(hideTimer);
    controls.classList.remove('hidden');
    screen.classList.remove('cursor-none');
  };
  const allowHide = () => {
    isMenuHovered = false;
    showControls(); // restarts the timer
  };

  const trackPanel = document.getElementById('track-panel');
  if (trackPanel) {
    on(trackPanel, 'mouseenter', preventHide);
    on(trackPanel, 'mouseleave', allowHide);
  }

  if (speedMenu) {
    on(speedMenu, 'mouseenter', preventHide);
    on(speedMenu, 'mouseleave', allowHide);
  }

  // ---- SEEK BAR ----
  setupSeekbar(video, signal);
  startProgressRAF(video, signal);

  // ---- KEYBOARD SHORTCUTS ----
  on(document, 'keydown', (e) => {
    if (!state.player.active) return;

    switch (e.key) {
      case ' ':
      case 'k':
      case 'K':
        e.preventDefault();
        togglePlay();
        break;
      case 'ArrowRight':
        e.preventDefault();
        seekRelative(10);
        break;
      case 'ArrowLeft':
        e.preventDefault();
        seekRelative(-10);
        break;
      case 'ArrowUp':
        e.preventDefault();
        setVolume(getVolume() + 0.1);
        break;
      case 'ArrowDown':
        e.preventDefault();
        setVolume(getVolume() - 0.1);
        break;
      case 'f':
      case 'F':
        e.preventDefault();
        toggleFullscreen();
        break;
      case 'm':
      case 'M':
        e.preventDefault();
        toggleMute();
        break;
      case '>':
        video.playbackRate = Math.min(2, video.playbackRate + 0.25);
        break;
      case '<':
        video.playbackRate = Math.max(0.25, video.playbackRate - 0.25);
        break;
      case '[':
        if (state.player.currentSubtitleTrack !== -1) {
          e.preventDefault();
          adjustSubOffset(-0.1);
        }
        break;
      case ']':
        if (state.player.currentSubtitleTrack !== -1) {
          e.preventDefault();
          adjustSubOffset(0.1);
        }
        break;
      case 'Escape':
        e.preventDefault();
        if (document.fullscreenElement) {
          document.exitFullscreen().catch(() => { });
        } else {
          closePlayer();
        }
        break;
    }
  });

  // ---- DOUBLE-CLICK ZONES ----
  on(screen, 'dblclick', (e) => {
    const width = screen.clientWidth;
    const x = e.clientX;
    if (x < width / 3) {
      seekRelative(-10);
      showRipple('left');
    } else if (x > (width * 2) / 3) {
      seekRelative(10);
      showRipple('right');
    } else {
      toggleFullscreen();
    }
  });

  // ---- NEXT EPISODE ----
  on(nextBtn, 'click', (e) => {
    e.stopPropagation();
    playNextEpisode();
  });

  const nextBtnControl = document.getElementById('btn-next-ep-control');
  if (nextBtnControl) {
    on(nextBtnControl, 'click', (e) => {
      e.stopPropagation();
      playNextEpisode();
    });
  }

  // ---- INITIAL STATE ----
  updatePlayPauseIcon();
  showControls();
}

// ============================================================
// SEEK BAR — Drag scrubbing with AbortController
// ============================================================
function setupSeekbar(video, signal) {
  const container = document.getElementById('progress-container');
  const tip = document.getElementById('time-tooltip');
  progressRefs.container = container;
  progressRefs.timeDisplay = document.getElementById('time-display');
  progressRefs.video = video;

  const getPctFromEvent = (e) => {
    const rect = container.getBoundingClientRect();
    let x = e.clientX - rect.left;
    x = Math.max(0, Math.min(x, rect.width));
    const pct = rect.width > 0 ? (x / rect.width) : 0;
    return { rect, x, pct };
  };

  const hideTooltip = () => {
    tip.style.display = 'none';
  };

  const updateVisualFromPct = (pct) => {
    const totalDuration = getDisplayTimelineState(video).displayTotalDuration;
    const targetTime = totalDuration > 0 ? pct * totalDuration : 0;
    setVisualProgress(targetTime, totalDuration);
    return { totalDuration, targetTime };
  };

  const updateTooltip = (x, targetTime, totalDuration) => {
    tip.style.display = 'block';
    tip.style.left = `${x}px`;
    tip.textContent = totalDuration > 0 ? fmtTime(targetTime) : '0:00';
  };

  function throttledSeek(pct) {
    if (state.player.multipart.enabled) return;

    const duration = video.duration;
    if (!isFinite(duration) || duration <= 0) return;

    const targetTime = pct * duration;
    const now = performance.now();
    const minInterval = 120;
    const sinceLast = now - (seekState.lastActualSeek || 0);

    const applySeek = () => {
      video.currentTime = targetTime;
      seekState.lastActualSeek = performance.now();
      seekState.pendingSeekTimer = null;
    };

    if (sinceLast >= minInterval) {
      clearTimeout(seekState.pendingSeekTimer);
      seekState.pendingSeekTimer = null;
      applySeek();
      return;
    }

    clearTimeout(seekState.pendingSeekTimer);
    seekState.pendingSeekTimer = setTimeout(applySeek, minInterval - sinceLast);
  }

  const onDown = (e) => {
    seekState.dragging = true;
    container.classList.add('dragging');

    const { x, pct } = getPctFromEvent(e);
    seekState.dragPct = pct;
    const { totalDuration, targetTime } = updateVisualFromPct(pct);
    throttledSeek(pct);
    updateTooltip(x, targetTime, totalDuration);
  };

  const onMove = (e) => {
    if (!seekState.dragging && !container.matches(':hover')) {
      hideTooltip();
      return;
    }

    const { x, pct } = getPctFromEvent(e);
    seekState.dragPct = pct;
    const { totalDuration, targetTime } = updateVisualFromPct(pct);

    if (seekState.dragging) {
      throttledSeek(pct);
    }

    updateTooltip(x, targetTime, totalDuration);
  };

  const onUp = () => {
    if (!seekState.dragging) return;

    seekState.dragging = false;
    container.classList.remove('dragging');
    hideTooltip();
    clearTimeout(seekState.pendingSeekTimer);
    seekState.pendingSeekTimer = null;

    // ---- MULTIPART: Seek to virtual position across parts ----
    if (state.player.multipart.enabled) {
      const totalDuration = state.player.multipart.totalDuration;
      if (totalDuration > 0) {
        multipartSeek(seekState.dragPct * totalDuration);
        seekState.lastActualSeek = performance.now();
      }
      return;
    }

    if (isFinite(video.duration)) {
      video.currentTime = seekState.dragPct * video.duration;
      seekState.lastActualSeek = performance.now();
    }
    if (video.paused && !video.ended) {
      video.play().catch(() => { });
    }
  };

  container.addEventListener('mousedown', onDown, { signal });
  document.addEventListener('mousemove', (e) => {
    onMove(e);
    if (seekState.dragging) e.preventDefault();
  }, { signal });
  document.addEventListener('mouseup', onUp, { signal });

  // ---- TOUCH SUPPORT ----
  const touchToMouse = (e) => ({ clientX: e.touches[0].clientX });
  container.addEventListener('touchstart', (e) => {
    e.preventDefault();
    onDown(touchToMouse(e));
  }, { signal, passive: false });
  document.addEventListener('touchmove', (e) => {
    if (seekState.dragging) {
      e.preventDefault();
      onMove(touchToMouse(e));
    }
  }, { signal, passive: false });
  document.addEventListener('touchend', () => {
    onUp();
    hideTooltip();
  }, { signal });
}


// ============================================================
// PLAYER ACTIONS
// ============================================================
function togglePlay() {
  if (playPauseDebounce) return;
  playPauseDebounce = true;
  setTimeout(() => { playPauseDebounce = false; }, 200);

  const video = document.getElementById('video-player');
  if (video.paused || video.ended) {
    video.play().catch(err => {
      console.warn('Play prevented:', err);
      updatePlayPauseIcon();
    });
    showCenterAnim('play');
  } else {
    video.pause();
    showCenterAnim('pause');
  }
}

function seekRelative(sec) {
  const video = progressRefs.video || document.getElementById('video-player');
  if (!video) return;

  const duration = getEffectiveDuration(video);
  if (!duration || !isFinite(duration)) return;

  const actualPosition = getEffectiveCurrentTime(video);

  seekState.keyboardSeeking = true;
  seekState.keyboardAccum += sec;

  const targetTime = Math.max(0, Math.min(actualPosition + seekState.keyboardAccum, duration));
  const pct = targetTime / duration;

  if (progressRefs.container) {
    progressRefs.container.style.setProperty('--progress', pct);
    if (progressRefs.timeDisplay) {
      progressRefs.timeDisplay.textContent = `${fmtTime(targetTime)} / ${fmtTime(duration)}`;
    }
  }
  setVisualProgress(targetTime, duration);

  clearTimeout(seekState.keyboardTimer);
  seekState.keyboardTimer = setTimeout(() => {
    const latestPosition = getEffectiveCurrentTime(video);
    const finalTarget = Math.max(0, Math.min(latestPosition + seekState.keyboardAccum, duration));

    // Multipart: use virtual seeking
    if (state.player.multipart.enabled) {
      multipartSeek(finalTarget);
    } else {
      video.currentTime = finalTarget;
      seekState.lastActualSeek = performance.now();
    }

    seekState.keyboardAccum = 0;
    seekState.keyboardTimer = null;
    seekState.keyboardSeeking = false;
  }, KEYBOARD_SEEK_DELAY);
}

function toggleMute() {
  const currentVol = getVolume();
  if (currentVol === 0) {
    const targetVol = (state.player._lastVolume && state.player._lastVolume > 0) ? state.player._lastVolume : 1;
    setVolume(targetVol);
  } else {
    state.player._lastVolume = currentVol;
    setVolume(0);
  }
}

async function toggleFullscreen() {
  const screen = document.getElementById('player-screen');
  if (document.fullscreenElement) {
    await document.exitFullscreen().catch(() => { });
  } else {
    await screen.requestFullscreen().catch(err => {
      console.warn('Fullscreen failed:', err);
      if (screen.webkitRequestFullscreen) screen.webkitRequestFullscreen();
    });
  }
}

function togglePiP() {
  const video = document.getElementById('video-player');
  if (document.pictureInPictureElement) document.exitPictureInPicture();
  else video.requestPictureInPicture().catch(() => { });
}

async function playNextEpisode() {
  if (!state.player.tmdbId || !state.player.season || !state.player.episode) return;

  let seasons = window._showSeasons;
  let showTitle = window._showTitle || state.player.title;

  if (!seasons) {
    const data = await api(`/api/tv/${state.player.tmdbId}`, true);
    seasons = data.seasons;
    showTitle = data.showTitle;
  }

  const currentS = state.player.season;
  const currentE = state.player.episode;
  const episodes = seasons[currentS] || [];
  const currentIndex = episodes.findIndex(ep => ep.tv.episodeNumber === currentE);

  let nextEp = null;
  let nextS = currentS;

  if (currentIndex !== -1 && currentIndex < episodes.length - 1) {
    nextEp = episodes[currentIndex + 1];
  } else {
    const seasonNums = Object.keys(seasons).map(Number).sort((a, b) => a - b);
    const currentSIdx = seasonNums.indexOf(currentS);
    if (currentSIdx !== -1 && currentSIdx < seasonNums.length - 1) {
      nextS = seasonNums[currentSIdx + 1];
      if (seasons[nextS] && seasons[nextS].length > 0) {
        nextEp = seasons[nextS][0];
      }
    }
  }

  if (nextEp) {
    playVideo({
      fileId: nextEp.fileId,
      title: showTitle,
      season: nextS,
      episode: nextEp.tv.episodeNumber,
      episodeTitle: nextEp.tv.episodeTitle || `Episode ${nextEp.tv.episodeNumber}`,
      tmdbId: state.player.tmdbId
    });
  } else {
    alert('No next episode found.');
  }
}


// ============================================================
// TV EPISODE PANEL LOGIC
// ============================================================
async function renderEpisodesPanel(params) {
  const sheet = document.getElementById('episodes-sheet');
  const overlay = document.getElementById('episodes-sheet-overlay');
  if (!sheet || !overlay) return;

  const btnEpisodes = document.getElementById('btn-episodes');
  const btnClose = document.getElementById('episodes-sheet-close');
  
  // Attach event toggles securely
  if (btnEpisodes) {
    btnEpisodes.onclick = () => {
      sheet.classList.remove('hidden');
      overlay.classList.remove('hidden');
      
      // Auto-scroll to active episode when opening
      setTimeout(() => {
        const listContainer = document.getElementById('episodes-list');
        const activeEp = listContainer.querySelector('.player-episode-item.active');
        if (activeEp) activeEp.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }, 300); // Wait for transition
    };
  }
  
  const closeSheet = () => {
    sheet.classList.add('hidden');
    overlay.classList.add('hidden');
  };
  
  if (btnClose) btnClose.onclick = closeSheet;
  overlay.onclick = closeSheet;

  // Set titles
  const titleEl = document.getElementById('episodes-sheet-title');
  const subtitleEl = document.getElementById('episodes-sheet-subtitle');
  if (titleEl) titleEl.textContent = params.title;
  if (subtitleEl) subtitleEl.textContent = `Season ${params.season} - playing Episode ${params.episode}`;

  // Fetch or use existing season data
  let seasons = window._showSeasons;
  if (!seasons || window._showTmdbId !== params.tmdbId) {
    const data = await api(`/api/tv/${params.tmdbId}`, true);
    if (data) {
      seasons = data.seasons;
      window._showSeasons = seasons;
      window._showTitle = data.showTitle;
      window._showTmdbId = data.showTmdbId;
    }
  }

  if (!seasons) return;

  const tabsContainer = document.getElementById('episodes-season-tabs');
  
  // Render tabs
  const seasonNums = Object.keys(seasons).map(Number).sort((a, b) => a - b);
  tabsContainer.innerHTML = seasonNums.map(n => 
    `<button class="season-tab ${n === Number(params.season) ? 'active' : ''}" data-season="${n}" onclick="switchEpisodesPanelSeason(${n}, ${params.tmdbId})">Season ${n}</button>`
  ).join('');

  // Render current season list
  renderEpisodesPanelList(seasons[params.season] || [], Number(params.episode));
}

window.switchEpisodesPanelSeason = function(seasonNum, tmdbId) {
  const seasons = window._showSeasons;
  if (!seasons) return;

  const tabsContainer = document.getElementById('episodes-season-tabs');
  tabsContainer.querySelectorAll('.season-tab').forEach(t => {
    t.classList.toggle('active', parseInt(t.dataset.season) === seasonNum);
  });

  const isCurrentPlayingSeason = Number(state.player.season) === seasonNum;
  const highlightEpisode = isCurrentPlayingSeason ? Number(state.player.episode) : -1;
  renderEpisodesPanelList(seasons[seasonNum] || [], highlightEpisode);
};

function renderEpisodesPanelList(episodes, highlightEpisode) {
  const listContainer = document.getElementById('episodes-list');
  const showTitle = window._showTitle || state.player.title;
  const tmdbId = window._showTmdbId || state.player.tmdbId;
  const poster = window._showPoster || '';

  if (!episodes || episodes.length === 0) {
    listContainer.innerHTML = '<div style="padding:15px; color:#888;">No episodes available.</div>';
    return;
  }

  listContainer.innerHTML = episodes.map(ep => {
    const s = ep.tv.seasonNumber;
    const e = ep.tv.episodeNumber;
    const title = ep.tv.episodeTitle || `Episode ${e}`;
    const overview = ep.tv.episodeOverview || 'No description available.';
    const isActive = e === highlightEpisode;
    const runtimeStr = ep.runtime || ep.tv.episodeRuntime;
    const runtimeHtml = runtimeStr ? `<span class="player-episode-item-runtime">${fmtRuntime(runtimeStr)}</span>` : '';
    
    // Custom handler to switch stream
    return `
      <div class="player-episode-item ${isActive ? 'active' : ''}" 
           onclick="handleEpisodesPanelClick('${ep.fileId}', '${escArg(showTitle)}', '${escArg(poster)}', ${s}, ${e}, '${escArg(title)}', ${tmdbId || 'null'})">
         <div class="player-episode-item-number">${e}</div>
         <div class="player-episode-item-content">
            <div class="player-episode-item-header">
               <div class="player-episode-item-title">${esc(title)}</div>
               ${runtimeHtml}
            </div>
            <div class="player-episode-item-overview">${esc(overview)}</div>
         </div>
      </div>`;
  }).join('');
}

window.handleEpisodesPanelClick = function(fileId, title, poster, season, episode, episodeTitle, tmdbId) {
  const sheet = document.getElementById('episodes-sheet');
  const overlay = document.getElementById('episodes-sheet-overlay');
  if (sheet) sheet.classList.add('hidden');
  if (overlay) overlay.classList.add('hidden');
  
  if (!poster && state.data && state.data.tvShows && tmdbId) {
    const show = state.data.tvShows.find(s => String(s.showTmdbId) === String(tmdbId));
    if (show) poster = show.poster || show.backdrop || '';
  }
  
  playVideo({
    fileId,
    title,
    poster,
    season,
    episode,
    episodeTitle,
    tmdbId
  }, true);
};

// ============================================================
// UI UPDATE HELPERS
// ============================================================
function updateProgress() {
  const video = document.getElementById('video-player');
  const timeline = getDisplayTimelineState(video);
  if (!timeline.displayTotalDuration) return;
  setVisualProgress(timeline.displayCurrentTime, timeline.displayTotalDuration);
}

function updateBuffer() {
  const video = document.getElementById('video-player');
  const timeline = getDisplayTimelineState(video);
  const totalDuration = timeline.displayTotalDuration;
  if (!totalDuration || video.buffered.length === 0) return;

  const multipartOffset = state.player.multipart.enabled ? timeline.accumulatedBeforePart : 0;
  const offset = multipartOffset;

  const bufEnd = video.buffered.end(video.buffered.length - 1) + offset;
  setVisualBuffer(bufEnd, totalDuration);
}

function updatePlayPauseIcon() {
  const video = document.getElementById('video-player');
  const btn = document.getElementById('btn-play-pause');
  if (video.paused) {
    btn.innerHTML = `<svg width="28" height="28" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>`;
  } else {
    btn.innerHTML = `<svg width="28" height="28" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>`;
  }
}

function getVolume() {
  const video = document.getElementById('video-player');
  return video && video._logicalVolume !== undefined ? video._logicalVolume : (video ? video.volume : 1);
}

function setVolume(val) {
   const video = document.getElementById('video-player');
   if (!video) return;
   val = Math.max(0, Math.min(3, val)); // Clamp between 0 and 3 (300%)
   video._logicalVolume = val;
   
   if (!video._audioContext) {
      try {
         const AudioCtx = window.AudioContext || window.webkitAudioContext;
         if (AudioCtx) {
             video._audioContext = new AudioCtx();
             video._gainNode = video._audioContext.createGain();
             video._sourceNode = video._audioContext.createMediaElementSource(video);
             video._sourceNode.connect(video._gainNode);
             video._gainNode.connect(video._audioContext.destination);
         }
      } catch (e) { console.warn("AudioContext init failed", e); }
   }

   if (video._audioContext && video._audioContext.state === 'suspended') {
      video._audioContext.resume().catch(()=>{});
   }

   if (val > 1) {
      video.volume = 1;
      if (video._gainNode) {
          video._gainNode.gain.value = val;
      }
   } else {
      video.volume = val;
      if (video._gainNode) {
          video._gainNode.gain.value = 1;
      }
   }
   
   video.muted = (val === 0);
   updateVolumeUI();
}

function updateVolumeUI() {
  const slider = document.getElementById('volume-slider');
  const icon = document.getElementById('btn-volume');

  const currentVol = getVolume();
  if (slider) slider.value = currentVol;

  let svg = '';
  if (currentVol === 0) {
    svg = `<path d="M11 5L6 9H2v6h4l5 4V5z"/><line x1="23" y1="9" x2="17" y2="15"/><line x1="17" y1="9" x2="23" y2="15"/>`;
  } else if (currentVol < 0.5) {
    svg = `<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M15.54 8.46a5 5 0 0 1 0 7.07"></path>`;
  } else {
    svg = `<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07"></path>`;
  }
  
  if (icon) {
    if (currentVol > 1) {
      // Show a green boost color when > 100%
      icon.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#46d369" stroke-width="2">${svg}</svg>`;
    } else {
      icon.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">${svg}</svg>`;
    }
  }

  // Show Volume Toast
  const toast = document.getElementById("volume-toast");
  if (toast) {
    const percent = Math.round(currentVol * 100);
    toast.textContent = `Volume: ${percent}%`;
    toast.classList.remove("hidden");
    
    if (window._volumeToastTimeout) {
      clearTimeout(window._volumeToastTimeout);
    }
    window._volumeToastTimeout = setTimeout(() => {
      toast.classList.add("hidden");
    }, 1000);
  }
}

function updateSpeedUI() {
  const video = document.getElementById('video-player');
  const rate = video.playbackRate;
  document.getElementById('btn-speed').textContent = rate + 'x';
  document.querySelectorAll('.speed-option').forEach(opt => {
    opt.classList.toggle('active', parseFloat(opt.dataset.speed) === rate);
  });
}

function showCenterAnim(type) {
  const overlay = document.getElementById('center-overlay');
  const icon = type === 'play'
    ? '<svg width="60" height="60" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>'
    : '<svg width="60" height="60" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>';

  const el = document.createElement('div');
  el.className = 'play-pause-animation';
  el.innerHTML = icon;
  overlay.appendChild(el);

  requestAnimationFrame(() => {
    el.style.opacity = '1';
    el.style.transform = 'scale(1.2)';
    setTimeout(() => {
      el.style.opacity = '0';
      el.style.transform = 'scale(1.5)';
      setTimeout(() => el.remove(), 200);
    }, 300);
  });
}

function showRipple(side) {
  const screen = document.getElementById('player-screen');
  const existing = screen.querySelector(`.seek-ripple-${side}`);
  if (existing) existing.remove();

  const ripple = document.createElement('div');
  ripple.className = `seek-ripple seek-ripple-${side}`;
  ripple.innerHTML = `<span class="seek-ripple-text">${side === 'left' ? '⟪ 10s' : '10s ⟫'}</span>`;
  screen.appendChild(ripple);

  setTimeout(() => ripple.remove(), 600);
}


// TRACKS (Audio/Sub) Logic
function updateTrackInfoUI() {
  const aList = document.getElementById('audio-track-list');
  const sList = document.getElementById('subtitle-track-list');
  const panel = document.getElementById('track-panel');
  const { audioTracks, subtitleTracks } = state.player;

  // Audio
  if (audioTracks.length === 0) {
    aList.innerHTML = '<div style="padding:10px; color:#666">No extra tracks</div>';
  } else {
    aList.innerHTML = audioTracks.map((t, i) => {
      const unsupported = !t.browserPlayable;
      return `<div class="track-item ${state.player.currentAudioTrack === i ? 'active' : ''} ${unsupported ? 'track-unsupported-warn' : ''}"
             onclick="switchAudio(${i}, event)">
             ${esc(t.language || 'Unknown')} - ${esc(t.title || 'Track ' + (i + 1))}
             ${unsupported ? ' ⚠️ (A/V may be desync - ' + (t.codec || '').toUpperCase() + ')' : ''}
           </div>`;
    }).join('');
  }

  // Subtitles — fully switchable, show source type
  let subHtml = `<div class="track-item ${state.player.currentSubtitleTrack === -1 ? 'active' : ''}" onclick="switchSubs(-1, event)">Off</div>`;
  subtitleTracks.forEach((t, i) => {
    const isEmbed = t.source === 'embedded';
    const icon = isEmbed ? '📦' : '🌐';
    const srcLabel = isEmbed ? (t.codec || 'embedded').toUpperCase() : (t.source || 'SubDL');
    subHtml += `<div class="track-item ${state.player.currentSubtitleTrack === i ? 'active' : ''}" 
         onclick="switchSubs(${i}, event)">
         <span class="track-name">${icon} ${esc(t.language || t.languageLabel || 'Unknown')}</span>
         <span class="track-detail">${srcLabel}${t.isDefault ? ' · Default' : ''}${t.rating ? ' · ' + t.rating : ''}</span>
       </div>`;
  });
  
  subHtml += `<input type="file" id="local-sub-upload" accept=".srt,.vtt" style="display:none" onchange="handleLocalSubtitleUpload(event)" />`;
  subHtml += `<div class="track-item" onclick="document.getElementById('local-sub-upload').click()">
         <span class="track-name">📁 Load Local Subtitle...</span>
         <span class="track-detail">From your device</span>
       </div>`;
       
  sList.innerHTML = subHtml;
  renderSubtitleSyncUI();
}
// ============================================================
// SUBTITLE SYNC TOOL — Bidirectional Quick Sync + Manual Offset
// ============================================================
function renderSubtitleSyncUI() {
  // Quick Sync is inserted as the FIRST child of the track-panel (sticky, always visible)
  let section = document.getElementById('subtitle-sync-section');

  if (!section) {
    section = document.createElement('div');
    section.id = 'subtitle-sync-section';
    const panel = document.getElementById('track-panel');
    if (!panel) return;
    // Insert AFTER audio list, BEFORE subtitle list (second .track-section)
    const trackSections = panel.querySelectorAll('.track-section');
    if (trackSections.length >= 2) {
      panel.insertBefore(section, trackSections[1]);
    } else {
      panel.appendChild(section);
    }
  }

  // Hide only if subtitles are OFF
  if (state.player.currentSubtitleTrack === -1) {
    section.innerHTML = '';
    return;
  }

  const offset = state.player.subtitleOffset || 0;
  const sign = offset >= 0 ? '+' : '';
  const step = state.player._syncStep || 0;
  const firstLabel = state.player._syncFirstLabel;

  // Build Quick Sync status
  let qsContent = '';
  if (step === 0) {
    // Idle — show Start Sync
    qsContent = `
      <div class="qs-status qs-idle">
        <span class="qs-status-dot"></span>
        <span class="qs-status-text">Tap a button when the first event happens</span>
      </div>
      <div class="qs-buttons">
        <button class="qs-action-btn qs-sub-btn" onclick="qsSyncMark('subtitle', event)">
          <span class="qs-btn-icon">💬</span>
          <span class="qs-btn-label">Subtitle Appeared</span>
        </button>
        <button class="qs-action-btn qs-audio-btn" onclick="qsSyncMark('audio', event)">
          <span class="qs-btn-icon">🔊</span>
          <span class="qs-btn-label">Voice Heard</span>
        </button>
      </div>`;
  } else if (step === 1) {
    // Waiting for the second event
    const secondLabel = firstLabel === 'subtitle' ? 'Voice Heard' : 'Subtitle Appeared';
    const secondIcon = firstLabel === 'subtitle' ? '🔊' : '💬';
    const secondType = firstLabel === 'subtitle' ? 'audio' : 'subtitle';
    qsContent = `
      <div class="qs-status qs-waiting">
        <span class="qs-status-dot qs-pulse"></span>
        <span class="qs-status-text">✓ ${firstLabel === 'subtitle' ? 'Subtitle' : 'Audio'} marked — now tap when you ${firstLabel === 'subtitle' ? 'hear the voice' : 'see the subtitle'}</span>
      </div>
      <div class="qs-buttons">
        <button class="qs-action-btn qs-second-btn qs-waiting-btn" onclick="qsSyncMark('${secondType}', event)">
          <span class="qs-btn-icon">${secondIcon}</span>
          <span class="qs-btn-label">${secondLabel}</span>
        </button>
        <button class="qs-cancel-btn" onclick="qsSyncReset(event)" title="Cancel">✕</button>
      </div>`;
  } else if (step === 2) {
    // Done — show result
    qsContent = `
      <div class="qs-status qs-applied">
        <span class="qs-status-dot qs-done-dot"></span>
        <span class="qs-status-text">Offset applied: <strong>${sign}${offset.toFixed(1)}s</strong></span>
      </div>`;
  }

  section.innerHTML = `
    <div class="sub-sync-panel">
      <div class="sub-sync-qs-section">
        <div class="sub-sync-qs-header">
          <span class="sub-sync-qs-title">⚡ Quick Sync</span>
          ${step === 2 || offset !== 0 ? `<button class="qs-reset-pill" onclick="qsSyncReset(event)">Reset</button>` : ''}
        </div>
        ${qsContent}
      </div>

      <div class="sub-sync-divider"></div>

      <div class="sub-sync-manual-section">
        <div class="sub-sync-header-row">
          <span class="sub-sync-label">Manual Adjust</span>
          <span class="sub-sync-offset-value">${sign}${offset.toFixed(1)}s</span>
        </div>
        <div class="sub-sync-manual">
          <button class="sub-sync-adj" onclick="adjustSubOffset(-0.5,event)">−0.5</button>
          <button class="sub-sync-adj" onclick="adjustSubOffset(-0.1,event)">−0.1</button>
          <button class="sub-sync-adj sub-sync-reset-btn" onclick="resetSubOffset(event)" ${offset === 0 ? 'disabled' : ''}>↺</button>
          <button class="sub-sync-adj" onclick="adjustSubOffset(0.1,event)">+0.1</button>
          <button class="sub-sync-adj" onclick="adjustSubOffset(0.5,event)">+0.5</button>
        </div>
      </div>
    </div>`;
}

// Quick Sync bidirectional mark
function qsSyncMark(type, event) {
  if (event) event.stopPropagation();
  const video = document.getElementById('video-player');
  const elapsed = isFinite(video.currentTime) ? video.currentTime : 0;
  const actualTime = elapsed;

  const step = state.player._syncStep || 0;

  if (step === 0) {
    // First mark
    state.player._syncFirstLabel = type;
    state.player._syncFirstTime = actualTime;
    state.player._syncSeenTime = actualTime; // backward compat
    state.player._syncStep = 1;
    renderSubtitleSyncUI();

    const audioInfo = document.getElementById('audio-info');
    audioInfo.textContent = `✓ ${type === 'subtitle' ? 'Subtitle' : 'Audio'} marked — now tap when you ${type === 'subtitle' ? 'hear the matching voice' : 'see the matching subtitle'}`;
    audioInfo.classList.remove('hidden');
    setTimeout(() => audioInfo.classList.add('hidden'), 4000);
  } else if (step === 1) {
    // Second mark — calculate offset
    const firstTime = state.player._syncFirstTime;
    const firstType = state.player._syncFirstLabel;
    let offset;

    if (firstType === 'subtitle') {
      // Subtitle appeared first, audio heard now → subs are early → positive offset (delay subs)
      offset = actualTime - firstTime;
    } else {
      // Audio heard first, subtitle appeared now → subs are late → negative offset (advance subs)
      offset = -(actualTime - firstTime);
    }

    state.player.subtitleOffset = Math.round(offset * 10) / 10;
    state.player._syncStep = 2;
    state.player._syncSeenTime = null;
    state.player._syncFirstTime = null;
    state.player._syncFirstLabel = null;
    renderSubtitleSyncUI();

    const sign = state.player.subtitleOffset >= 0 ? '+' : '';
    const audioInfo = document.getElementById('audio-info');
    audioInfo.textContent = `✓ Subtitle offset set to ${sign}${state.player.subtitleOffset.toFixed(1)}s`;
    audioInfo.classList.remove('hidden');
    setTimeout(() => audioInfo.classList.add('hidden'), 3000);

    // Auto-return to idle state after brief display
    setTimeout(() => {
      if (state.player._syncStep === 2) {
        state.player._syncStep = 0;
        renderSubtitleSyncUI();
      }
    }, 3000);
  }
}

function qsSyncReset(event) {
  if (event) event.stopPropagation();
  state.player.subtitleOffset = 0;
  state.player._syncStep = 0;
  state.player._syncSeenTime = null;
  state.player._syncFirstTime = null;
  state.player._syncFirstLabel = null;
  showSubOffsetNotification();
  renderSubtitleSyncUI();
}

function adjustSubOffset(delta, event) {
  if (event) event.stopPropagation();
  state.player.subtitleOffset = Math.round(((state.player.subtitleOffset || 0) + delta) * 10) / 10;
  showSubOffsetNotification();
  renderSubtitleSyncUI();
}

function resetSubOffset(event) {
  if (event) event.stopPropagation();
  qsSyncReset(event);
}

// Legacy compat — redirect old functions to new system
function markSubtitleSeen(event) { qsSyncMark('subtitle', event); }
function markVoiceHeard(event) { qsSyncMark('audio', event); }

async function switchAudio(index, event) {
  if (event) event.stopPropagation();

  // Web only supports the default audio track.
  if (index === state.player.defaultAudioTrack) {
    const track = state.player.audioTracks[index];
    if (track && !track.browserPlayable) {
      const downloadUrl = state.config?.appDownloadUrl || 'https://github.com/StreamFlix/StreamFlix/releases';
      showAppNudgeModal(downloadUrl, true);
    }
    
    state.player.currentAudioTrack = index;
    updateTrackInfoUI();
    const video = document.getElementById('video-player');
    // Apply native track selection just in case
    if (video.audioTracks && video.audioTracks.length > 0) {
      for (let i = 0; i < video.audioTracks.length; i++) {
        video.audioTracks[i].enabled = (i === index);
      }
    }
    return;
  }

  // Non-default track selected
  const downloadUrl = state.config?.appDownloadUrl || 'https://github.com/StreamFlix/StreamFlix/releases';
  showAppNudgeModal(downloadUrl);
}

function showAppNudgeModal(downloadUrl, isUnsupportedCodec = false) {
  let overlay = document.getElementById('app-nudge-overlay');
  
  const titleText = isUnsupportedCodec ? 'Audio Format Not Supported' : 'Use the App for Multi-Track Audio';
  const bodyText = isUnsupportedCodec 
    ? 'This video uses an audio format that browsers cannot play natively (it will play without sound). Download the StreamFlix app for full native playback.'
    : 'This audio track works best in the StreamFlix app. Download the app for native multi-track support without buffering.';
  const cancelBtnText = isUnsupportedCodec ? 'Play Without Sound' : 'Stay on Web (Default)';

  if (!overlay) {
    overlay = document.createElement('div');
    overlay.id = 'app-nudge-overlay';
    overlay.style.position = 'absolute';
    overlay.style.top = '0';
    overlay.style.left = '0';
    overlay.style.width = '100%';
    overlay.style.height = '100%';
    overlay.style.backgroundColor = 'var(--glass)';
    overlay.style.display = 'flex';
    overlay.style.alignItems = 'center';
    overlay.style.justifyContent = 'center';
    overlay.style.zIndex = '9999';
    
    const box = document.createElement('div');
    box.style.backgroundColor = 'var(--bg-card)';
    box.style.padding = '2rem';
    box.style.borderRadius = '8px';
    box.style.maxWidth = '400px';
    box.style.textAlign = 'center';
    box.style.border = '1px solid rgba(255,255,255,0.1)';
    box.style.boxShadow = '0 10px 30px rgba(0,0,0,0.5)';

    const icon = document.createElement('div');
    icon.innerHTML = '<svg width="48" height="48" viewBox="0 0 24 24" fill="var(--primary)"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 14.5v-9l6 4.5-6 4.5z"/></svg>';
    icon.style.marginBottom = '1rem';
    box.appendChild(icon);

    const title = document.createElement('h2');
    title.id = 'app-nudge-title';
    title.textContent = titleText;
    title.style.margin = '0 0 1rem 0';
    title.style.color = 'var(--text-main)';
    title.style.fontSize = '1.3rem';
    title.style.fontWeight = '700';
    box.appendChild(title);
    
    const text = document.createElement('p');
    text.id = 'app-nudge-text';
    text.textContent = bodyText;
    text.style.color = 'var(--text-muted)';
    text.style.marginBottom = '1.5rem';
    text.style.lineHeight = '1.5';
    text.style.fontSize = '0.95rem';
    box.appendChild(text);

    const buttons = document.createElement('div');
    buttons.style.display = 'flex';
    buttons.style.gap = '1rem';
    buttons.style.justifyContent = 'center';

    const cancelBtn = document.createElement('button');
    cancelBtn.id = 'app-nudge-cancel';
    cancelBtn.textContent = cancelBtnText;
    cancelBtn.className = 'btn';
    cancelBtn.style.backgroundColor = 'rgba(255,255,255,0.1)';
    cancelBtn.style.color = 'var(--text-main)';
    cancelBtn.onclick = (e) => {
      e.stopPropagation();
      overlay.style.display = 'none';
      if (!isUnsupportedCodec) {
        state.player.currentAudioTrack = state.player.defaultAudioTrack;
        updateTrackInfoUI();
      }
    };

    const downloadBtn = document.createElement('a');
    downloadBtn.id = 'app-nudge-download';
    downloadBtn.textContent = 'Download App';
    downloadBtn.href = downloadUrl;
    downloadBtn.target = '_blank';
    downloadBtn.className = 'btn btn-retry';
    downloadBtn.style.textDecoration = 'none';
    downloadBtn.onclick = (e) => {
      e.stopPropagation();
      overlay.style.display = 'none';
      if (!isUnsupportedCodec) {
        state.player.currentAudioTrack = state.player.defaultAudioTrack;
        updateTrackInfoUI();
      }
    };

    buttons.appendChild(cancelBtn);
    buttons.appendChild(downloadBtn);
    box.appendChild(buttons);
    overlay.appendChild(box);
    
    const playerScreen = document.getElementById('player-screen');
    playerScreen.appendChild(overlay);
  } else {
    const downloadBtn = overlay.querySelector('#app-nudge-download');
    if (downloadBtn) downloadBtn.href = downloadUrl;
    
    const titleEl = overlay.querySelector('#app-nudge-title');
    if (titleEl) titleEl.textContent = titleText;
    
    const textEl = overlay.querySelector('#app-nudge-text');
    if (textEl) textEl.textContent = bodyText;
    
    const cancelEl = overlay.querySelector('#app-nudge-cancel');
    if (cancelEl) cancelEl.textContent = cancelBtnText;
    
    // update click handlers to handle state correctly
    cancelEl.onclick = (e) => {
      e.stopPropagation();
      overlay.style.display = 'none';
      if (!isUnsupportedCodec) {
        state.player.currentAudioTrack = state.player.defaultAudioTrack;
        updateTrackInfoUI();
      }
    };
    downloadBtn.onclick = (e) => {
      e.stopPropagation();
      overlay.style.display = 'none';
      if (!isUnsupportedCodec) {
        state.player.currentAudioTrack = state.player.defaultAudioTrack;
        updateTrackInfoUI();
      }
    };

    overlay.style.display = 'flex';
  }
}

function showSubOffsetNotification() {
  const offset = state.player.subtitleOffset;
  const sign = offset >= 0 ? '+' : '';
  const audioInfo = document.getElementById('audio-info');
  audioInfo.textContent = `Subtitle offset: ${sign}${offset.toFixed(1)}s`;
  audioInfo.classList.remove('hidden');
  setTimeout(() => audioInfo.classList.add('hidden'), 1500);
}



// Helper to re-apply the native audio track when video reloads (like crossing parts)
function applyNativeAudioTrack(video) {
  const targetIndex = state.player.currentAudioTrack || 0;
  if (video.audioTracks && video.audioTracks.length > 0) {
    for (let i = 0; i < video.audioTracks.length; i++) {
      video.audioTracks[i].enabled = (i === targetIndex);
    }
  }
}

async function switchSubs(index, event, startTime = null) {
  if (event) event.stopPropagation();

  // Abort any ongoing subtitle fetch
  if (state.player.subtitleAbortController) {
    state.player.subtitleAbortController.abort();
  }
  state.player.subtitleAbortController = new AbortController();

  state.player.currentSubtitleTrack = index;
  state.player._syncSeenTime = null;  // ← ADD THIS LINE
  updateTrackInfoUI();

  const subtitleDisplay = document.getElementById('subtitle-display');
  // Only clear cues and display if this is not a seek-triggered restart
  if (startTime === null) {
    subtitleDisplay.innerHTML = '';
    state.player.parsedCues = null;
  }

  const video = document.getElementById('video-player');
  video.querySelectorAll('track').forEach((t) => {
    if (t.src && t.src.startsWith('blob:')) URL.revokeObjectURL(t.src);
    t.remove();
  });

  if (index === -1) {
    state.player.parsedCues = null;
    return;
  }

  const sub = state.player.subtitleTracks[index];
  if (!sub || !sub.endpoint) {
    state.player.parsedCues = null;
    return;
  }

  const audioInfo = document.getElementById('audio-info');
  audioInfo.textContent = 'Loading ' + (sub.language || sub.languageLabel || '') + ' subtitles...';
  audioInfo.classList.remove('hidden');

  try {
    let vttText = '';

    if (state.player.subtitleVTTCache[sub.endpoint] && startTime === null) {
      vttText = state.player.subtitleVTTCache[sub.endpoint];
      const cues = parseVTT(vttText);
      if (cues.length === 0) console.log('[Subtitle] No cues found in cached VTT');
      state.player.parsedCues = cues;
      renderSubtitleSyncUI();
      audioInfo.textContent = (sub.language || sub.languageLabel || 'Subtitles') + ' loaded (' + cues.length + ' cues)';
      setTimeout(() => audioInfo.classList.add('hidden'), 2000);
    } else {
      let fetchEndpoint = sub.endpoint;
      if (startTime !== null && fetchEndpoint.includes('/subtitle/')) {
        // Pre-buffer subtitles slightly from before the exact seek point
        const safeStart = Math.max(0, startTime - 10).toFixed(2);
        fetchEndpoint += `?start=${safeStart}`;
      }

      const response = await fetch(fetchEndpoint, { signal: state.player.subtitleAbortController.signal });
      if (!response.ok) throw new Error('HTTP ' + response.status);

      const reader = response.body.getReader();
      const decoder = new TextDecoder('utf-8');

      let isFirstChunk = true;
      state.player.parsedCues = [];

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        if (state.player.currentSubtitleTrack !== index) {
          reader.cancel();
          return;
        }

        vttText += decoder.decode(value, { stream: true });

        if (isFirstChunk && vttText.length > 0) {
          isFirstChunk = false;
          audioInfo.classList.add('hidden'); // Hide loader immediately
        }

        const cues = parseVTT(vttText);
        if (cues.length > 0) {
          state.player.parsedCues = cues;
        }
      }

      vttText += decoder.decode(); // flush remaining bytes
      if (startTime === null) {
        state.player.subtitleVTTCache[sub.endpoint] = vttText;
      }

      const cues = parseVTT(vttText);
      if (cues.length === 0 && (!state.player.parsedCues || state.player.parsedCues.length === 0)) {
        console.log('[Subtitle] No cues found in VTT for this segment.');
      }

      state.player.parsedCues = cues;
      renderSubtitleSyncUI();

      if (startTime === null) {
        audioInfo.textContent = (sub.language || sub.languageLabel || 'Subtitles') + ' loaded (' + state.player.parsedCues.length + ' cues)';
        setTimeout(() => audioInfo.classList.add('hidden'), 2000);
      }
    }
  } catch (err) {
    if (err.name === 'AbortError') {
      console.log('[Subtitle] Fetch aborted due to seek/change.');
      return;
    }
    console.error('[Subtitle] Load failed:', err);
    state.player.parsedCues = null;

    audioInfo.textContent = 'Failed to load subtitles: ' + err.message;
    setTimeout(() => audioInfo.classList.add('hidden'), 4000);

    // DO NOT automatically turn off the subtitle track
    // Let the user manually switch it off or try again.
    // state.player.currentSubtitleTrack = -1;
    // updateTrackInfoUI();
  }
}
// Clean and HTML escape for subtitle text (removes <i>, <b>, and ASS/SSA tags safely)
function escapeSubHTML(str) {
  if (!str) return "";
  
  // Match standard subtitle styling HTML tags (i, b, u, c, font, v) and ASS style overrides {\...}
  const tagRegex = /<\/?(?:i|b|u|c|font|v)(?:\s+[^>]*)?>/gi;
  const braceRegex = /\{\\[^}]*\}/g;
  
  const cleaned = str
    .replace(/<br\s*\/?>/gi, "\n") // Convert explicit BR tags to newlines
    .replace(tagRegex, "")
    .replace(braceRegex, "")
    .replace(/\\N/gi, "\n") // Replace ASS newline markers with actual newlines
    .replace(/\\h/gi, " ")   // Replace ASS non-breaking spaces with spaces
    .trim();

  // Escape remaining string safely for DOM injection
  const div = document.createElement('div');
  div.textContent = cleaned;
  return div.innerHTML;
}


// ============================================================
// INITIALIZATION
// ============================================================
document.addEventListener('DOMContentLoaded', () => {
  // Nav Click Handlers
  document.querySelectorAll('.nav-link').forEach(l => {
    l.onclick = (e) => { e.preventDefault(); navigate(l.dataset.route); };
  });

  // ---- HAMBURGER MENU ----
  const hamburgerBtn = document.getElementById('hamburger-btn');
  const mobileNav = document.getElementById('mobile-nav');
  const mobileNavClose = document.getElementById('mobile-nav-close');

  if (hamburgerBtn && mobileNav) {
    hamburgerBtn.addEventListener('click', () => {
      mobileNav.classList.remove('hidden');
      document.body.style.overflow = 'hidden';
    });

    mobileNavClose.addEventListener('click', () => {
      mobileNav.classList.add('hidden');
      document.body.style.overflow = '';
    });

    // Mobile nav link handlers
    document.querySelectorAll('.mobile-nav-link').forEach(link => {
      link.addEventListener('click', (e) => {
        e.preventDefault();
        navigate(link.dataset.route);
      });
    });

    // Close on backdrop tap
    mobileNav.addEventListener('click', (e) => {
      if (e.target === mobileNav) {
        mobileNav.classList.add('hidden');
        document.body.style.overflow = '';
      }
    });
  }

  // Navbar scroll listener
  window.addEventListener('scroll', () => {
    const nav = document.getElementById('navbar');
    if (window.scrollY > 20) nav.classList.add('scrolled');
    else nav.classList.remove('scrolled');
  });

  // Search
  let searchTimer;
  const sInput = document.querySelector('.search-input');
  sInput.oninput = (e) => {
    clearTimeout(searchTimer);
    const q = e.target.value.trim();
    searchTimer = setTimeout(() => {
      if (q.length > 0) {
        if (state.currentRoute !== 'search') navigate('search', { query: q });
        else renderSearch(document.getElementById('app'), q);
      } else {
        navigate('home');
      }
    }, 300);
  };

  // Handle Back/Forward browser buttons
  window.addEventListener('popstate', (e) => {
    if (e.state && e.state.route === 'play') {
      if (!state.player.active) playVideo(e.state.params, false);
      return;
    }
    if (e.state && e.state.modal) {
      openDetail(e.state.modal.id, e.state.modal.type, false);
      return;
    }

    // Close player/modal if moving back to browser grid
    if (state.player.active) closePlayer(false);
    if (!document.getElementById('detail-modal').classList.contains('hidden')) closeModal(false);

    if (e.state && e.state.route) {
      navigate(e.state.route, e.state.params, false);
    } else {
      // Fallback if no state
      parseUrlAndRoute(window.location.pathname, window.location.search);
    }
  });

  // Load
  loadLibrary();
});

function parseUrlAndRoute(path, search) {
  // Check modal links
  if (path.startsWith('/movie/')) {
    const id = path.replace('/movie/', '');
    navigate('home', {}, false); // background route
    openDetail(id, 'movie', false);
    return;
  }
  if (path.startsWith('/tv/')) {
    const id = path.replace('/tv/', '');
    navigate('home', {}, false); // background route
    openDetail(`show_${id}`, 'tv', false);
    return;
  }

  // Check player links
  if (path.startsWith('/play/')) {
    navigate('home', {}, false); // background route

    // /play/movie/123 or /play/tv/123
    const parts = path.split('/');
    const type = parts[2];
    const mainId = parts[3];

    const urlParams = new URLSearchParams(search);
    if (type === 'tv') {
      let title = 'Loading...';
      let poster = '';
      if (state.data && state.data.tvShows) {
        const show = state.data.tvShows.find(s => String(s.showTmdbId) === String(mainId) || String(s.id) === String(mainId) || String(s.fileId) === String(mainId));
        if (show) {
           title = show.showTitle || show.title || title;
           poster = show.poster || show.backdrop || '';
        }
      }
      
      // If mainId matches fileId, it means tmdbId was missing from the URL. Pass null so Smart Recovery runs.
      const actualTmdbId = (mainId === (urlParams.get('f') || mainId)) ? null : mainId;
      
      playVideo({
        fileId: urlParams.get('f') || mainId,
        tmdbId: actualTmdbId,
        poster: poster,
        season: urlParams.get('s'),
        episode: urlParams.get('e'),
        episodeTitle: urlParams.get('et'),
        title: title
      }, false);
    } else {
      let title = 'Playing Movie';
      if (state.data && state.data.movies) {
        const movie = state.data.movies.find(m => String(m.fileId) === String(mainId) || String(m.id) === String(mainId));
        if (movie) title = movie.title || title;
      }
      playVideo({ fileId: mainId, title: title }, false);
    }
    return;
  }

  // Base routing
  if (path === '/movies') navigate('movies', {}, false);
  else if (path === '/tvshows') navigate('tvshows', {}, false);
  else if (path === '/genres') navigate('genres', {}, false);
  else if (path.startsWith('/genres/')) {
    const slug = path.replace('/genres/', '');
    navigate('genre-detail', { slug, name: slug }, false);
  } else if (path === '/search') {
    const urlParams = new URLSearchParams(search);
    navigate('search', { query: urlParams.get('q') }, false);
  } else {
    navigate('home', {}, false);
  }
}

async function loadLibrary(skipAuth = false) {
  const app = document.getElementById('app');

  // Immediately show the appropriate skeleton before any async auth checks
  const path = window.location.pathname;
  if (path === '/movies') {
    app.innerHTML = buildBrowsePageSkeleton('Movies');
  } else if (path === '/tvshows') {
    app.innerHTML = buildBrowsePageSkeleton('TV Shows');
  } else if (path === '/genres' || path.startsWith('/genres/')) {
    app.innerHTML = buildGenresPageSkeleton();
  } else {
    app.innerHTML = buildHomePageSkeleton();
  }

  if (!skipAuth) {
    // Check auth first
    const session = await StreamFlixAuth.initialize();
    if (!session) {
      showLoginScreen();
      return;
    }

    // Verify backend status (Zero Trust)
    const status = await StreamFlixAuth.validateSessionWithBackend();
    if (status.requiresMembership) {
      showMembershipScreen(status.inviteLink);
      return;
    }
    if (!status.authorized) {
      showLoginScreen(status.error || 'Your session has expired. Please sign in again.');
      return;
    }

    // Session is valid! Setup profile display
    setupNavbarUser(StreamFlixAuth.user);
  }

  // Primary: /api/metadata reads JSON files directly (reliable TV detection)
  // Fallback: /api/movies/library uses Telegram cache (may miss TV shows)
  let data = await api('/api/metadata');
  if (!data) {
    console.log('[Library] /api/metadata failed, trying /api/movies/library fallback...');
    data = await api('/api/movies/library');
  }

  if (data) {
    // Normalize — handle multiple possible API response formats
    if (!data.tvShows && data.shows) data.tvShows = data.shows;
    if (!data.tvShows && data.tv) data.tvShows = data.tv;
    if (!data.tvShows) data.tvShows = [];
    if (!data.movies) data.movies = [];
    if (!data.genreRows) data.genreRows = [];
    if (!data.heroItems) data.heroItems = [];
    if (!data.counts) data.counts = { movies: data.movies.length, tvShows: data.tvShows.length };

    console.log('[Library] Loaded:', {
      movies: data.movies.length,
      tvShows: data.tvShows.length,
      genreRows: data.genreRows.length,
      heroItems: data.heroItems.length
    });

    state.data = data;

    // Initial Route based on URL
    parseUrlAndRoute(window.location.pathname, window.location.search);
  } else {
    app.innerHTML = `
      <div class="error-screen">
        <h2>Failed to load library</h2>
        <p style="color:var(--text-muted);margin:10px 0;">Could not connect to the server</p>
        <button class="btn btn-play" onclick="location.reload()">Retry</button>
      </div>`;
  }
}

// ============================================================
// HELPERS — Normalize mixed items, skeleton builders
// ============================================================
function normalizeItem(item) {
  // Normalizes a raw library item (movie or TV) into the shape card() expects
  if (item.type === 'tv' || item.showTmdbId || item.showTitle) {
    return {
      id: `show_${item.showTmdbId}`, type: 'tv',
      title: item.showTitle || item.title,
      poster: item.poster, rating: item.rating, year: item.year
    };
  }
  return {
    id: item.fileId || item.id, type: item.type || 'movie',
    title: item.title, poster: item.poster,
    rating: item.rating, year: item.year,
  };
}

function buildHomePageSkeleton() {
  const skeletonCards = Array(8).fill('')
    .map(() => '<div class="card skeleton-card"><div class="skeleton-poster shimmer"></div></div>')
    .join('');

  return `
    <section class="hero skeleton-hero">
      <div class="skeleton-hero-bg shimmer"></div>
      <div class="hero-gradient-bottom"></div>
      <div class="hero-gradient-left"></div>
      <div class="skeleton-hero-content">
        <div class="skeleton-line skeleton-title shimmer"></div>
        <div class="skeleton-line skeleton-meta shimmer"></div>
        <div class="skeleton-line skeleton-overview shimmer"></div>
        <div class="skeleton-line skeleton-overview-short shimmer"></div>
        <div class="skeleton-buttons">
          <div class="skeleton-btn shimmer"></div>
          <div class="skeleton-btn shimmer"></div>
        </div>
      </div>
    </section>
    <section class="content-section" style="margin-top: -10vh;">
      <div class="row skeleton-row">
        <div class="skeleton-line skeleton-row-title shimmer"></div>
        <div class="row-slider">${skeletonCards}</div>
      </div>
      <div class="row skeleton-row">
        <div class="skeleton-line skeleton-row-title shimmer"></div>
        <div class="row-slider">${skeletonCards}</div>
      </div>
      <div class="row skeleton-row">
        <div class="skeleton-line skeleton-row-title shimmer"></div>
        <div class="row-slider">${skeletonCards}</div>
      </div>
    </section>`;
}

function buildBrowsePageSkeleton(title) {
  const skeletonCards = Array(12).fill('')
    .map(() => '<div class="card skeleton-card"><div class="skeleton-poster shimmer"></div></div>')
    .join('');

  return `
    <div class="browse-page">
      <div class="browse-header">
        <div class="skeleton-line shimmer" style="width:200px;height:32px;"></div>
        <div class="skeleton-line shimmer" style="width:120px;height:36px;border-radius:4px;"></div>
      </div>
      <div class="browse-grid">${skeletonCards}</div>
    </div>`;
}


// ============================================================
// OFFLINE CONNECTION HANDLING
// ============================================================
function handleConnectionChange() {
  const offlineOverlay = document.getElementById('offline-overlay');
  if (!offlineOverlay) return;

  if (navigator.onLine) {
    offlineOverlay.classList.add('hidden');
  } else {
    offlineOverlay.classList.remove('hidden');
  }
}

window.addEventListener('online', handleConnectionChange);
window.addEventListener('offline', handleConnectionChange);

// Initial connection check and event binding
document.addEventListener('DOMContentLoaded', () => {
  handleConnectionChange();
  
  // Fetch app config
  fetch('/api/config')
    .then(r => r.json())
    .then(data => { state.config = data; })
    .catch(err => console.warn('Failed to load config', err));
  
  // Initialize login UI bindings
  initLoginFlow();
  
  const retryBtn = document.getElementById('btn-retry-connection');
  if (retryBtn) {
    retryBtn.addEventListener('click', () => {
      if (navigator.onLine) {
        handleConnectionChange();
      } else {
        const originalText = retryBtn.textContent;
        retryBtn.textContent = 'Still Offline...';
        retryBtn.style.opacity = '0.7';
        setTimeout(() => {
          retryBtn.textContent = originalText;
          retryBtn.style.opacity = '1';
        }, 1500);
      }
    });
  }
});

// ============================================================
// TELEGRAM AUTHENTICATION FLOW CONTROLLER
// ============================================================
let currentLoginSessionId = null;
let currentPhoneNumber = null;
let otpResendTimer = null;

function showLoginScreen(errorMessage = null) {
  document.getElementById('login-screen').classList.remove('hidden');
  document.getElementById('navbar').classList.add('hidden');
  resetLoginState();
  if (errorMessage) {
    showError(errorMessage);
  }
}

function showMembershipScreen(inviteLink) {
  document.getElementById('login-screen').classList.remove('hidden');
  document.getElementById('navbar').classList.add('hidden');
  
  // Transition directly to the membership step
  const phoneStep = document.getElementById('step-phone');
  const otpStep = document.getElementById('step-otp');
  const pwdStep = document.getElementById('step-password');
  const successStep = document.getElementById('step-success');
  const membershipStep = document.getElementById('step-membership');
  
  phoneStep.className = 'login-step';
  otpStep.className = 'login-step';
  pwdStep.className = 'login-step';
  successStep.className = 'login-step';
  membershipStep.className = 'login-step active';
  
  const joinBtn = document.getElementById('btn-join-channel');
  if (joinBtn) {
    joinBtn.href = inviteLink || '#';
  }
  
  hideError();
}

function resetLoginState() {
  currentLoginSessionId = null;
  currentPhoneNumber = null;
  if (otpResendTimer) clearInterval(otpResendTimer);
  
  document.getElementById('phone-number').value = '';
  document.getElementById('cloud-password').value = '';
  document.querySelectorAll('.otp-box').forEach(b => b.value = '');
  document.getElementById('btn-otp-verify').disabled = true;
  
  const phoneStep = document.getElementById('step-phone');
  const otpStep = document.getElementById('step-otp');
  const pwdStep = document.getElementById('step-password');
  const successStep = document.getElementById('step-success');
  const membershipStep = document.getElementById('step-membership');
  
  phoneStep.className = 'login-step active';
  otpStep.className = 'login-step enter-right';
  pwdStep.className = 'login-step enter-right';
  successStep.className = 'login-step enter-right';
  membershipStep.className = 'login-step enter-right';
  
  hideError();
}

function hideLoginScreen() {
  document.getElementById('login-screen').classList.add('hidden');
  document.getElementById('navbar').classList.remove('hidden');
}

function transitionStep(fromEl, toEl, direction = 'next') {
  hideError();
  if (direction === 'next') {
    fromEl.classList.remove('active');
    fromEl.classList.add('exit-left');
    
    toEl.classList.remove('exit-left');
    toEl.classList.remove('enter-right');
    toEl.classList.add('active');
  } else {
    fromEl.classList.remove('active');
    fromEl.classList.add('enter-right');
    
    toEl.classList.remove('exit-left');
    toEl.classList.remove('enter-right');
    toEl.classList.add('active');
  }
}

function showError(msg) {
  const errorCard = document.getElementById('login-error');
  const errorText = document.getElementById('login-error-text');
  errorText.textContent = msg;
  errorCard.classList.remove('hidden');
  
  const card = document.getElementById('login-card');
  card.classList.remove('shake-effect');
  void card.offsetWidth; // Trigger reflow
  card.classList.add('shake-effect');
  setTimeout(() => card.classList.remove('shake-effect'), 500);
}

function hideError() {
  document.getElementById('login-error').classList.add('hidden');
}

function initLoginFlow() {
  const phoneInput = document.getElementById('phone-number');
  const phoneBtn = document.getElementById('btn-phone-continue');
  const countrySelect = document.getElementById('phone-country');
  
  const otpInputs = document.querySelectorAll('.otp-box');
  const otpBtn = document.getElementById('btn-otp-verify');
  const otpBackBtn = document.getElementById('btn-otp-back');
  const resendLink = document.getElementById('btn-resend-otp');
  
  const pwdInput = document.getElementById('cloud-password');
  const pwdToggleBtn = document.getElementById('btn-password-toggle');
  const pwdBtn = document.getElementById('btn-password-submit');
  const pwdBackBtn = document.getElementById('btn-password-back');

  const membershipVerifyBtn = document.getElementById('btn-membership-verify');
  const membershipBackBtn = document.getElementById('btn-membership-back');
  
  phoneBtn.addEventListener('click', async () => {
    const rawNumber = phoneInput.value.trim();
    if (!rawNumber) {
      showError('Please enter your phone number.');
      return;
    }
    
    // Clean all spacing, brackets, dashes, and extra plus signs
    let cleanNumber = rawNumber.replace(/[\s\(\)\-\+]/g, '');
    
    // Check if the user typed the country code again
    const selectedCountryCode = countrySelect.value.replace('+', '');
    if (cleanNumber.startsWith(selectedCountryCode)) {
      cleanNumber = cleanNumber.substring(selectedCountryCode.length);
    }
    
    // Validate phone number format (must contain 7 to 15 digits)
    if (!/^\d{7,15}$/.test(cleanNumber)) {
      showError('Please enter a valid phone number.');
      return;
    }
    
    const fullNumber = countrySelect.value + cleanNumber;
    currentPhoneNumber = fullNumber;
    
    setButtonLoading(phoneBtn, true);
    hideError();
    
    try {
      const data = await StreamFlixAuth.sendOTP(fullNumber);
      currentLoginSessionId = data.loginSessionId;
      
      document.getElementById('otp-phone-display').textContent = formatPhoneForDisplay(fullNumber);
      transitionStep(document.getElementById('step-phone'), document.getElementById('step-otp'), 'next');
      startOtpCountdown();
      
      setTimeout(() => otpInputs[0].focus(), 200);
    } catch (err) {
      showError(err.message);
    } finally {
      setButtonLoading(phoneBtn, false);
    }
  });

  phoneInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      phoneBtn.click();
    }
  });
  
  otpInputs.forEach((input, index) => {
    input.addEventListener('input', (e) => {
      e.target.value = e.target.value.replace(/[^0-9]/g, '');
      const val = e.target.value;
      
      if (val.length === 1 && index < 4) {
        otpInputs[index + 1].focus();
      }
      checkOtpComplete();
    });
    
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Backspace' && e.target.value.length === 0 && index > 0) {
        otpInputs[index - 1].focus();
      }
    });
    
    input.addEventListener('paste', (e) => {
      e.preventDefault();
      const pastedData = (e.clipboardData || window.clipboardData).getData('text').trim().replace(/[^0-9]/g, '');
      if (pastedData.length >= 5) {
        for (let i = 0; i < 5; i++) {
          otpInputs[i].value = pastedData[i] || '';
        }
        otpInputs[4].focus();
        checkOtpComplete();
        otpBtn.click();
      }
    });
  });
  
  function checkOtpComplete() {
    let code = '';
    otpInputs.forEach(b => code += b.value);
    otpBtn.disabled = code.length !== 5;
  }
  
  otpBtn.addEventListener('click', async () => {
    let code = '';
    otpInputs.forEach(b => code += b.value);
    if (code.length !== 5) return;
    
    setButtonLoading(otpBtn, true);
    hideError();
    
    try {
      const result = await StreamFlixAuth.verifyOTP(currentLoginSessionId, code);
      if (result.requiresPassword) {
        transitionStep(document.getElementById('step-otp'), document.getElementById('step-password'), 'next');
        setTimeout(() => pwdInput.focus(), 200);
      } else if (result.requiresMembership) {
        showMembershipScreen(result.inviteLink);
      } else {
        showSuccessScreen(result.user);
      }
    } catch (err) {
      showError(err.message);
      otpInputs.forEach(b => b.value = '');
      otpInputs[0].focus();
      otpBtn.disabled = true;
    } finally {
      setButtonLoading(otpBtn, false);
    }
  });
  
  otpBackBtn.addEventListener('click', () => {
    transitionStep(document.getElementById('step-otp'), document.getElementById('step-phone'), 'back');
    if (otpResendTimer) clearInterval(otpResendTimer);
  });
  
  resendLink.addEventListener('click', async (e) => {
    e.preventDefault();
    if (!resendLink.classList.contains('active')) return;
    
    hideError();
    resendLink.classList.remove('active');
    
    try {
      const data = await StreamFlixAuth.sendOTP(currentPhoneNumber);
      currentLoginSessionId = data.loginSessionId;
      startOtpCountdown();
      otpInputs.forEach(b => b.value = '');
      otpInputs[0].focus();
      otpBtn.disabled = true;
    } catch (err) {
      showError(err.message);
      resendLink.classList.add('active');
    }
  });
  
  pwdToggleBtn.addEventListener('click', () => {
    const isPwd = pwdInput.type === 'password';
    pwdInput.type = isPwd ? 'text' : 'password';
    pwdToggleBtn.innerHTML = isPwd 
      ? `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
           <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/>
         </svg>`
      : `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
           <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>
         </svg>`;
  });
  
  pwdBtn.addEventListener('click', async () => {
    const password = pwdInput.value;
    if (!password) {
      showError('Please enter your 2-Step Verification password.');
      return;
    }
    
    setButtonLoading(pwdBtn, true);
    hideError();
    
    try {
      const result = await StreamFlixAuth.verify2FAPassword(currentLoginSessionId, password);
      if (result.requiresMembership) {
        showMembershipScreen(result.inviteLink);
      } else {
        showSuccessScreen(result.user);
      }
    } catch (err) {
      showError(err.message);
      pwdInput.value = '';
      pwdInput.focus();
    } finally {
      setButtonLoading(pwdBtn, false);
    }
  });

  pwdInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      pwdBtn.click();
    }
  });
  
  pwdBackBtn.addEventListener('click', () => {
    transitionStep(document.getElementById('step-password'), document.getElementById('step-otp'), 'back');
  });

  membershipVerifyBtn.addEventListener('click', async () => {
    setButtonLoading(membershipVerifyBtn, true);
    hideError();
    try {
      const status = await StreamFlixAuth.validateSessionWithBackend();
      if (status.authorized) {
        showSuccessScreen(status.user);
      } else if (status.requiresMembership) {
        showError('You must join the channel before you can proceed.');
        // shake card
        const card = document.getElementById('login-card');
        card.classList.remove('shake-effect');
        void card.offsetWidth;
        card.classList.add('shake-effect');
      } else {
        showError('Session expired. Please restart login.');
        setTimeout(() => showLoginScreen(), 1500);
      }
    } catch (err) {
      showError(err.message);
    } finally {
      setButtonLoading(membershipVerifyBtn, false);
    }
  });

  membershipBackBtn.addEventListener('click', () => {
    showLoginScreen();
  });
}

function startOtpCountdown() {
  const timerDisplay = document.getElementById('otp-timer');
  const resendLink = document.getElementById('btn-resend-otp');
  resendLink.classList.remove('active');
  
  let duration = 120;
  if (otpResendTimer) clearInterval(otpResendTimer);
  
  function updateTimer() {
    const minutes = Math.floor(duration / 60);
    const seconds = duration % 60;
    
    timerDisplay.textContent = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
    
    if (duration <= 0) {
      clearInterval(otpResendTimer);
      timerDisplay.textContent = '00:00';
      resendLink.classList.add('active');
    }
    duration--;
  }
  
  updateTimer();
  otpResendTimer = setInterval(updateTimer, 1000);
}

function showSuccessScreen(user) {
  hideError();
  
  const displayName = user.firstName + (user.lastName ? ' ' + user.lastName : '');
  document.getElementById('success-user-name').textContent = displayName;
  
  const activeStep = document.querySelector('.login-step.active');
  const successStep = document.getElementById('step-success');
  transitionStep(activeStep, successStep, 'next');
  
  setTimeout(() => {
    const loginScreen = document.getElementById('login-screen');
    loginScreen.style.transition = 'opacity 0.6s ease';
    loginScreen.style.opacity = '0';
    
    setTimeout(() => {
      loginScreen.classList.add('hidden');
      loginScreen.style.opacity = '1';
      
      document.getElementById('navbar').classList.remove('hidden');
      setupNavbarUser(user);
      loadLibrary(true);  // Skip auth re-check — we just authenticated
    }, 600);
    
  }, 2000);
}

function setButtonLoading(btn, isLoading) {
  btn.disabled = isLoading;
  if (isLoading) {
    btn.dataset.originalHtml = btn.innerHTML;
    btn.innerHTML = `<span class="button-spinner"></span>`;
  } else if (btn.dataset.originalHtml) {
    btn.innerHTML = btn.dataset.originalHtml;
  }
}

function formatPhoneForDisplay(phone) {
  if (phone.startsWith('+91') && phone.length === 13) {
    return `+91 ${phone.substring(3, 8)} ${phone.substring(8)}`;
  }
  return phone;
}

function setupNavbarUser(user) {
  const navbarRight = document.querySelector('.navbar-right');
  if (!navbarRight) return;
  
  const existing = navbarRight.querySelector('.nav-profile-container');
  if (existing) existing.remove();
  
  const initial = (user && user.firstName) ? user.firstName.charAt(0).toUpperCase() : 'U';
  const name = (user && user.firstName) ? (user.firstName + (user.lastName ? ' ' + user.lastName : '')) : 'StreamFlix User';
  const phone = user && user.phone ? user.phone : '';
  
  const container = document.createElement('div');
  container.className = 'nav-profile-container';
  container.innerHTML = `
    <button id="btn-user-profile" class="nav-profile-btn" aria-label="User Profile">
      <span>${initial}</span>
    </button>
    <div id="profile-dropdown" class="profile-dropdown hidden">
      <div class="dropdown-header">
        <div class="dropdown-name">${esc(name)}</div>
        ${phone ? `<div class="dropdown-phone">${esc(formatPhoneForDisplay(phone))}</div>` : ''}
      </div>
      <div class="dropdown-divider"></div>
      <button id="btn-logout" class="dropdown-item">Sign Out of StreamFlix</button>
    </div>
  `;
  
  navbarRight.appendChild(container);
  
  const profileBtn = container.querySelector('#btn-user-profile');
  const dropdown = container.querySelector('#profile-dropdown');
  
  profileBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    dropdown.classList.toggle('hidden');
  });
  
  document.addEventListener('click', () => {
    dropdown.classList.add('hidden');
  });
  
  container.querySelector('#btn-logout').addEventListener('click', async () => {
    container.querySelector('#btn-logout').textContent = 'Signing out...';
    await StreamFlixAuth.logout();
    state.data = null;
    navigate('home');
    showLoginScreen();
  });
}

// ==================== WATCH PROGRESS ====================

async function fetchWatchProgress() {
  if (!StreamFlixAuth.isLoggedIn()) return [];
  try {
    const res = await fetch('/api/progress', {
      headers: {
        'Authorization': `Bearer ${StreamFlixAuth.sessionToken}`
      }
    });
    const data = await res.json();
    return data.success && data.progress ? data.progress : [];
  } catch (e) {
    console.error('Failed to fetch watch progress:', e);
    return [];
  }
}

async function saveWatchProgress(fileId, positionSeconds, durationSeconds, title, posterPath, mediaType, season, episode, showId) {
  if (!StreamFlixAuth.isLoggedIn()) return;
  try {
    await fetch('/api/progress', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${StreamFlixAuth.sessionToken}`
      },
      body: JSON.stringify({
        fileId,
        positionSeconds,
        durationSeconds,
        title,
        posterPath,
        mediaType,
        season,
        episode,
        showId
      })
    });
  } catch (e) {
    console.error('Failed to save watch progress:', e);
  }
}

// ==================== LOCAL SUBTITLE UPLOAD ====================

window.handleLocalSubtitleUpload = async function(event) {
  const file = event.target.files[0];
  if (!file) return;

  const reader = new FileReader();
  reader.onload = async function(e) {
    const text = e.target.result;
    let vttText = text;

    // Very basic SRT to VTT conversion if needed
    if (file.name.endsWith('.srt')) {
      vttText = 'WEBVTT\n\n' + text
        .replace(/\r\n|\r/g, '\n')
        .replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, '$1.$2');
    }

    // Add to tracks
    const newTrackIndex = state.player.subtitleTracks.length;
    const blob = new Blob([vttText], { type: 'text/vtt' });
    const url = URL.createObjectURL(blob);

    state.player.subtitleTracks.push({
      language: 'Local File',
      languageLabel: file.name,
      source: 'local',
      endpoint: url
    });

    // Cache the VTT text so parseVTT can use it immediately without fetching from Blob if needed
    if (!state.player.subtitleVTTCache) state.player.subtitleVTTCache = {};
    state.player.subtitleVTTCache[url] = vttText;

    updateTrackInfoUI();
    
    // Switch to the newly added track
    switchSubs(newTrackIndex);
    
    // Reset file input so same file can be uploaded again if needed
    event.target.value = '';
  };
  reader.readAsText(file);
};
