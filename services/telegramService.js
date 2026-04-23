// backend/services/telegramService.js

const { TelegramClient, Api } = require('telegram');
const { StringSession } = require('telegram/sessions');
const bigInt = require('big-integer');
const path = require('path');
const fs = require('fs');
const { getTelegramChunk } = require('./chunkCacheService');
const config = require('../config/telegram');
const { LRUCache } = require('lru-cache');
const {
  subtitleCache,
  detectAndConvert,
  extractSubtitleInfo,
  srtToVtt,
  assToVtt,
} = require('./subtitleService');
const {
  MKVSubtitleExtractor,
  getLanguageLabel,
  cuesToVTT,
  TEXT_SUBTITLE_CODECS,
} = require('./mkvExtractor');
const workerService = require('./workerService');
const { hasMetadata } = require('./metadataService');
const { saveMetadata } = require('./metadataWorker');

// Try to load ffmpeg service (optional dependency)
let ffmpegService = null;
let ffmpegAvailable = false;

try {
  ffmpegService = require('./ffmpegService');
  ffmpegAvailable = true;
} catch (e) {
  console.log('⚠️ ffmpegService not loaded:', e.message);
  ffmpegAvailable = false;
}

// ==================== STATE ====================

let client = null;
let channelEntity = null;

/**
 * Resolves the correct DC sender for a document.
 * Helps prevent FILE_MIGRATE and DC_ID_INVALID errors.
 */
async function resolveSender(doc) {
  if (!client) return null;
  const dcId = doc?.dcId;
  if (!dcId) return client;
  try {
    return await client.getSender(dcId);
  } catch (e) {
    console.warn(`⚠️ [Telegram] Failed to get sender for DC ${dcId}, falling back to main client:`, e.message);
    return client;
  }
}

// LRU Cache for file chunks
const chunkCache = new LRUCache({
  maxSize: config.maxCacheSize,
  sizeCalculation: (value) => value.length,
  ttl: 1000 * 60 * 10,
  dispose: (value, key) => {
    console.log(`🗑️ Evicted: ${key.substring(0, 40)}...`);
  },
});

// Movie metadata cache
const movieCache = new LRUCache({
  max: 500,
  ttl: 1000 * 60 * 30,
});

function invalidateCache() {
  movieCache.clear();
  console.log('🗑️ [Telegram] Movie cache invalidated');
}

function getAlignedLimit(offset) {
  return 1048576; // 1MB chunks globally
}

function isCleanText(str) {
  if (!str || str.length === 0) return false;
  if (str.length > 50) return false;
  const printable = str.replace(/[^\x20-\x7E\u00C0-\u024F\u0900-\u097F]/g, '');
  return printable.length >= str.length * 0.8;
}

const { cleanMediaFilename } = require('../utils/filenameUtils');

function formatFileSize(bytes) {
  if (bytes === 0) return '0 B';
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return parseFloat((bytes / Math.pow(1024, i)).toFixed(2)) + ' ' + sizes[i];
}

function formatDuration(seconds) {
  if (!seconds) return '0:00';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0)
    return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function getFileName(message) {
  const doc = message?.media?.document;
  if (!doc?.attributes) return null;
  const attr = doc.attributes.find(
    (a) => a.className === 'DocumentAttributeFilename'
  );
  return attr?.fileName || null;
}

function isSubtitleFile(fileName, mimeType) {
  if (!fileName && !mimeType) return false;

  if (fileName) {
    const ext = fileName.toLowerCase().split('.').pop();
    const subtitleExts = [
      'srt', 'vtt', 'ass', 'ssa', 'sub', 'idx',
      'smi', 'sami', 'txt', 'lrc', 'ttml', 'dfxp',
      'sbv', 'stl', 'usf',
    ];
    if (subtitleExts.includes(ext)) return true;
  }

  if (mimeType) {
    const subtitleMimes = [
      'text/vtt', 'text/srt', 'application/x-subrip',
      'text/x-ssa', 'text/x-ass', 'application/x-ass',
      'text/plain',
    ];
    if (subtitleMimes.includes(mimeType)) return true;
  }

  if (fileName) {
    const lower = fileName.toLowerCase();
    if (
      lower.includes('subtitle') || lower.includes('.sub.') ||
      lower.includes('.subs.') || lower.includes('_sub_')
    ) {
      return true;
    }
  }

  return false;
}

function getSearchTerms(title, fileName) {
  const terms = [];
  const cleaned = title
    .replace(/[._-]/g, ' ')
    .replace(/\[.*?\]/g, '')
    .replace(/\(.*?\)/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  if (cleaned.length > 2) terms.push(cleaned);

  const beforeYear = cleaned.match(/^(.+?)\s*\d{4}/);
  if (beforeYear && beforeYear[1].trim().length > 2) {
    terms.push(beforeYear[1].trim());
  }

  const words = cleaned.split(/\s+/);
  if (words.length >= 2) {
    terms.push(words.slice(0, 3).join(' '));
    terms.push(words.slice(0, 2).join(' '));
  }

  if (fileName) {
    const cleanFn = fileName.replace(/\.[^.]+$/, '').replace(/[._-]/g, ' ').trim();
    const fnYear = cleanFn.match(/^(.+?)\s*\d{4}/);
    if (fnYear && fnYear[1].trim().length > 2 && !terms.includes(fnYear[1].trim())) {
      terms.push(fnYear[1].trim());
    }
  }

  return [...new Set(terms)];
}

// ==================== INITIALIZATION ====================

async function initTelegram() {
  const sessionString = config.sessionString;

  if (!sessionString) {
    throw new Error('TELEGRAM_SESSION_STRING is required! Run: node generateSession.js');
  }

    client = new TelegramClient(
    new StringSession(sessionString),
    config.apiId,
    config.apiHash,
    {
      connectionRetries: 1000000, // Effectively Infinity
      useWSS: true,
      requestRetries: 3,
      floodSleepThreshold: 60,
      autoReconnect: true,
      deviceModel: 'StreamFlix Server',
      systemVersion: 'Node.js',
      appVersion: '1.0.0',
      // Keep the connection alive to prevent frequent disconnects
      pingInterval: 60,
    }
  );

  await client.connect();

  if (!(await client.checkAuthorization())) {
    throw new Error('Session expired! Run: node generateSession.js');
  }

  const me = await client.getMe();
  console.log(`✅ Logged in as: ${me.firstName} ${me.lastName || ''} (@${me.username || 'N/A'})`);

  try {
    channelEntity = await client.getEntity(config.channelId);
    console.log(`📺 Channel: ${channelEntity.title || channelEntity.id}`);
  } catch (error) {
    console.error('❌ Cannot access channel:', error.message);
    throw error;
  }

  // Check ffmpeg availability
  if (ffmpegService) {
    try {
      const hasFF = await ffmpegService.checkFFmpeg();
      const hasProbe = await ffmpegService.checkFFprobe();
      ffmpegAvailable = hasFF && hasProbe;
      console.log(`🎬 ffmpeg: ${hasFF ? '✅' : '❌'} | ffprobe: ${hasProbe ? '✅' : '❌'}`);
    } catch (e) {
      ffmpegAvailable = false;
      console.log('⚠️ ffmpeg check failed:', e.message);
    }
  }

  if (!ffmpegAvailable) {
    console.log('⚠️ ffmpeg not available. Embedded subtitle extraction is disabled to avoid full-file downloads.');
    console.log('   Install ffmpeg and ffprobe: choco install ffmpeg (Windows) or sudo apt install ffmpeg (Linux)');
  }

  return client;
}

// ==================== LIST MOVIES ====================

async function getMoviesList(limit = 50, offset = 0, search = '', enrich = true) {
  console.log(`🎬 getMoviesList called: limit=${limit}, offset=${offset}, search="${search}"`);
  const cacheKey = `movies_${limit}_${offset}_${search}_${enrich ? '1' : '0'}`;
  const cached = movieCache.get(cacheKey);
  if (cached) {
    console.log('✅ Serving from cache');
    return cached;
  }

  if (!client || !channelEntity) {
    console.error('❌ Telegram not initialized');
    throw new Error('Telegram not initialized');
  }

  let messages;

  try {
    console.log('📡 Fetching messages from Telegram...');
    if (search && search.trim() !== '') {
      messages = await client.invoke(
        new Api.messages.Search({
          peer: channelEntity,
          q: search,
          filter: new Api.InputMessagesFilterDocument(),
          minDate: 0,
          maxDate: 0,
          offsetId: offset,
          addOffset: 0,
          limit: limit,
          maxId: 0,
          minId: 0,
          hash: bigInt(0),
        })
      );
      messages = messages.messages || [];
    } else {
      messages = await client.getMessages(channelEntity, {
        limit: limit,
        offsetId: offset || 0,
      });
    }
    console.log(`✅ Fetched ${messages.length} messages`);
  } catch (error) {
    console.error('Fetch error:', error.message);
    if (search) {
      messages = await client.getMessages(channelEntity, { limit: 200 });
      const q = search.toLowerCase();
      messages = messages.filter((msg) => {
        if (!msg?.media) return false;
        const text = (msg.message || '').toLowerCase();
        const fn = getFileName(msg)?.toLowerCase() || '';
        return text.includes(q) || fn.includes(q);
      });
    } else {
      throw error;
    }
  }


  const movies = [];
  for (const msg of messages) {
    if (msg?.media) {
      let movie = extractMovieData(msg);
      if (movie) {
        movies.push(movie);
      }
    }
  }
  console.log(`🎥 Extracted ${movies.length} movies`);

  // Enrich with metadata
  if (enrich) {
    console.log('✨ Enriching metadata...');
    try {
      const enriched = await metadataService.enrichMovieList(movies);
      movies.length = 0;
      movies.push(...enriched);
      console.log('✅ Enrichment complete');
    } catch (e) {
      console.error('❌ Enrichment failed:', e);
    }
  }

  // GROUP SPLIT FILES
  const groupedMovies = groupSplitFiles(movies);

  const lastMessage = messages[messages.length - 1];
  const nextOffset = lastMessage ? lastMessage.id : 0;

  movieCache.set(cacheKey, { movies: groupedMovies, nextOffset });
  console.log(`📋 ${groupedMovies.length} movies (grouped) ${search ? ` matching "${search}"` : ''}`);

  return { movies: groupedMovies, nextOffset };
}

function groupSplitFiles(movies) {
  // STEP 1: Clean all filenames and build groups
  const groupMap = new Map(); // key: normalizedTitle_year → [movie, movie, ...]

  for (const movie of movies) {
    // If movie already has cleaned info (from enrichment?), use it, else clean now.
    // Ideally extractMovieData should have used cleanMediaFilename.
    // Let's ensure we have raw cleaned data for grouping.

    // We re-clean here to be sure, or use what's in movie if trusted.
    // But extractMovieData puts title as "Cleaned Title".
    // We need strict "Title + Year" grouping.

    // We'll re-run cleaner on the filename to be safe for grouping logic
    const cleaned = cleanMediaFilename(movie.fileName || '');

    // Normalize key: "avatar_2009"
    const normalizedKey = cleaned.title.toLowerCase().replace(/[^a-z0-9]/g, '')
      + '_' + (cleaned.year || '');

    movie._cleanedTitle = cleaned.title;
    movie._cleanedYear = cleaned.year;
    movie._explicitPart = cleaned.partNumber;

    if (!groupMap.has(normalizedKey)) {
      groupMap.set(normalizedKey, []);
    }
    groupMap.get(normalizedKey).push(movie);
  }

  // STEP 2: Process each group
  const result = [];

  for (const [key, group] of groupMap) {
    if (group.length === 1) {
      const movie = group[0];
      // It's a single file
      result.push({
        ...movie,
        isSplit: false,
        parts: null,
      });
      continue;
    }

    // Multiple files - sort them
    group.sort((a, b) => {
      if (a._explicitPart && b._explicitPart) return a._explicitPart - b._explicitPart;
      if (a._explicitPart) return a._explicitPart - 1; // a is part X, b is unknown
      if (b._explicitPart) return 1 - b._explicitPart;
      // fallback to message id
      return parseInt(a.id) - parseInt(b.id);
    });

    // Assign part info
    const parts = group.map((movie, index) => ({
      fileId: movie.id,
      messageId: parseInt(movie.id),
      partNumber: movie._explicitPart || (index + 1),
      fileName: movie.fileName,
      size: movie.size || 0,
      sizeFormatted: movie.sizeFormatted || formatFileSize(movie.size || 0),
      duration: movie.duration || 0,
    }));

    const main = group[0];
    const totalSize = group.reduce((sum, m) => sum + (m.size || 0), 0);
    const totalDuration = group.reduce((sum, m) => sum + (m.duration || 0), 0);

    // Create the grouped entry
    result.push({
      ...main,
      title: main._cleanedTitle || main.title, // Ensure we use the clean title 
      isSplit: true,
      totalParts: parts.length,
      size: totalSize,
      sizeFormatted: formatFileSize(totalSize),
      duration: totalDuration,
      durationFormatted: formatDuration(totalDuration),
      parts: parts,
    });
  }

  return result;
}

// ==================== EXTRACT MOVIE DATA ====================

function extractMovieData(message) {
  if (!message?.media?.document) return null;

  const doc = message.media.document;
  const mimeType = doc.mimeType || '';
  const fileName = getFileName(message) || '';

  const isVideo =
    mimeType.startsWith('video/') ||
    /\.(mp4|mkv|avi|mov|webm|flv|wmv|m4v|ts|3gp)$/i.test(fileName);

  if (!isVideo) return null;

  const videoAttr = doc.attributes?.find(
    (a) => a.className === 'DocumentAttributeVideo'
  );

  return {
    id: message.id.toString(),
    messageId: message.id,
    title: cleanMediaFilename(fileName || message.message || `Video_${message.id}`).title,
    fileName: fileName || `video_${message.id}.mp4`,
    size: Number(doc.size),
    sizeFormatted: formatFileSize(Number(doc.size)),
    mimeType: mimeType || 'video/mp4',
    duration: videoAttr?.duration || 0,
    durationFormatted: formatDuration(videoAttr?.duration || 0),
    width: videoAttr?.w || 0,
    height: videoAttr?.h || 0,
    date: message.date,
    dateFormatted: new Date(message.date * 1000).toLocaleDateString(),
    description: message.message || '',
  };
}

// ==================== METADATA ENRICHMENT ====================

const metadataService = require('./metadataService');

async function enrichMovieData(movie) {
  try {
    const meta = await metadataService.getMetadata(movie.id, movie.fileName);
    if (meta) {
      if (meta.poster) movie.poster = meta.poster;
      if (meta.backdrop) movie.backdrop = meta.backdrop;
      if (meta.overview) movie.description = meta.overview;
      if (meta.rating) movie.rating = meta.rating;
      if (meta.year) movie.year = meta.year;
      if (meta.title) movie.title = meta.title;
    }
  } catch (e) {
    console.error(`Metadata enrichment failed for ${movie.id}:`, e.message);
  }
  return movie;
}

// ==================== SINGLE MOVIE ====================

async function getMovieById(messageId) {
  const cacheKey = `movie_${messageId}`;
  const cached = movieCache.get(cacheKey);
  if (cached) return cached;

  if (!client || !channelEntity) throw new Error('Telegram not initialized');

  // 1. Get the target file first
  const messages = await client.getMessages(channelEntity, {
    ids: [parseInt(messageId)],
  });

  if (!messages?.[0]) throw new Error('Movie not found');
  let targetMovie = extractMovieData(messages[0]);
  if (!targetMovie) throw new Error('Not a video file');

  // 2. Search for siblings (Strategy: Search by title)
  // We use the cleaned title to find potential parts
  const cleaned = cleanMediaFilename(targetMovie.fileName);
  const searchTitle = cleaned.title;

  // If we have a title, search for it to find other parts
  // We'll limit the search to avoid huge delays, but enough to find parts
  // If it's a TV episode, this might return many files, but groupSplitFiles handles standard grouping

  let siblings = [];
  if (searchTitle.length > 2) {
    try {
      // Use getMoviesList logic to search (reusing existing flow)
      // We set enrich=false for speed, we just want to group
      const { movies } = await getMoviesList(100, 0, searchTitle, false);
      siblings = movies;
    } catch (e) {
      console.warn("Sibling search failed", e);
    }
  }

  if (siblings.length === 0) {
    siblings.push(targetMovie);
  }

  // 3. Group them
  const groups = groupSplitFiles(siblings);

  // 4. Find the group that contains our requested messageId
  // The 'groups' array contains grouped movie objects.
  // One of them should have our fileId in its parts (if split) or be the file itself (if not).

  const foundGroup = groups.find(g => {
    if (g.isSplit) {
      return g.parts.some(p => p.fileId == messageId);
    }
    return g.id == messageId;
  });

  // If found, enrich it individually if needed (since we passed enrich=false above)
  let finalMovie = foundGroup || targetMovie;

  // Enrich if strictly needed (usually frontend needs poster/etc)
  // getMoviesList above was false, so we might need to enrich this specific one.
  // BUT the user asked to modify getMovieById. 
  // Let's just enrich the final result.
  finalMovie = await enrichMovieData(finalMovie);

  // Let's return the Group Leader.
  movieCache.set(cacheKey, finalMovie);
  return finalMovie;
}

// ==================== METADATA ONLY (LAZY LOAD) ====================

async function getMovieMetadata(messageId) {
  let movie = await getMovieById(messageId);
  movie = await enrichMovieData(movie);

  return {
    id: movie.id,
    title: movie.title,
    year: movie.year,
    poster: movie.poster,
    backdrop: movie.backdrop,
    rating: movie.rating,
    description: movie.description,
    hasMetadata: true,
    imdbId: movie.imdbId,
    tmdbId: movie.tmdbId,
    source: movie.source
  };
}

// ==================== THUMBNAIL ====================

async function getThumbnail(messageId) {
  const cacheKey = `thumb_${messageId}`;
  const cached = chunkCache.get(cacheKey);
  if (cached) return cached;

  if (!client || !channelEntity) throw new Error('Telegram not initialized');

  const messages = await client.getMessages(channelEntity, {
    ids: [parseInt(messageId)],
  });

  if (!messages?.[0]?.media?.document) throw new Error('No media');

  const doc = messages[0].media.document;
  if (!doc.thumbs?.length) throw new Error('No thumbnail');

  try {
    const thumb = await client.downloadMedia(messages[0].media, {
      thumb: doc.thumbs.length - 1,
    });
    if (thumb) {
      const buffer = Buffer.isBuffer(thumb) ? thumb : Buffer.from(thumb);
      chunkCache.set(cacheKey, buffer);
      return buffer;
    }
  } catch (e) {
    console.log(`⚠️ Thumb failed for ${messageId}`);
  }

  return null;
}

// ==================== STREAM (Robust & Chunked) ====================
async function streamFile(messageId, start, end) {
  if (!client || !channelEntity) throw new Error('Telegram not initialized');

  const messages = await client.getMessages(channelEntity, { ids: [parseInt(messageId)] });
  if (!messages?.[0]?.media?.document) throw new Error('No media found');

  const message = messages[0];
  const doc = message.media.document;
  const fileSize = Number(doc.size);
  const chunkSize = config.chunkSize;

  const rangeStart = start || 0;
  const rangeEnd = (end !== undefined && end !== null)
    ? Math.min(end, fileSize - 1)
    : Math.min(rangeStart + chunkSize - 1, fileSize - 1);

  const cacheKey = `chunk_${messageId}_${rangeStart}_${rangeEnd}`;
  const cachedChunk = chunkCache.get(cacheKey);
  if (cachedChunk) {
    return {
      buffer: cachedChunk,
      contentLength: cachedChunk.length,
      mimeType: doc.mimeType || 'video/mp4',
    };
  }

  const inputLocation = new Api.InputDocumentFileLocation({
    id: doc.id,
    accessHash: doc.accessHash,
    fileReference: doc.fileReference,
    thumbSize: '',
  });

  const fileInfo = { id: doc.id, location: inputLocation };
  let currentSender = await resolveSender(doc);

  try {
    const chunks = [];
    let currentOffset = rangeStart;
    const totalToDownload = rangeEnd - rangeStart + 1;
    let downloaded = 0;

    while (downloaded < totalToDownload) {
      const remaining = totalToDownload - downloaded;

      const alignedOffset = currentOffset - (currentOffset % 1048576);
      const skipBytes = currentOffset - alignedOffset;
      const limit = getAlignedLimit(alignedOffset);

      let resultData;
      try {
        resultData = await getTelegramChunk(client, fileInfo, alignedOffset, limit, currentSender);
      } catch (error) {
        if (error.isMigrationError && error.newDcId) {
          console.log(`[Telegram] Mid-stream migration to DC ${error.newDcId} for ${messageId}`);
          currentSender = await client.getSender(error.newDcId);
          resultData = await getTelegramChunk(client, fileInfo, alignedOffset, limit, currentSender);
        } else {
          throw error;
        }
      }

      if (!resultData || resultData.length === 0) break;

      let buffer = Buffer.from(resultData);

      if (skipBytes > 0) {
        buffer = buffer.slice(skipBytes);
      }

      if (buffer.length > remaining) {
        buffer = buffer.slice(0, remaining);
      }

      if (buffer.length === 0) break;

      chunks.push(buffer);
      downloaded += buffer.length;
      currentOffset += buffer.length;
    }

    const finalBuffer = Buffer.concat(chunks);
    chunkCache.set(cacheKey, finalBuffer);

    return {
      buffer: finalBuffer,
      contentLength: finalBuffer.length,
      mimeType: doc.mimeType || 'video/mp4',
    };
  } catch (error) {
    console.error(`❌ Stream failed: ${error.message}`);
    throw error;
  }
}

/**
 * Returns a Readable stream that downloads the file chunk-by-chunk from Telegram.
 */
async function getDownloadStream(messageId) {
  if (!client || !channelEntity) throw new Error('Telegram not initialized');

  const messages = await client.getMessages(channelEntity, { ids: [parseInt(messageId)] });
  if (!messages?.[0]?.media?.document) throw new Error('No media found');

  const doc = messages[0].media.document;
  const fileSize = Number(doc.size);
  const CHUNK_SIZE = 1024 * 1024;

  const { Readable } = require('stream');
  let currentOffset = 0;
  let isReading = false;

  return new Readable({
    async read(size) {
      if (isReading) return;
      isReading = true;

      try {
        while (currentOffset < fileSize) {
          if (this.destroyed) return;

          const end = Math.min(currentOffset + CHUNK_SIZE - 1, fileSize - 1);
          const chunkData = await streamFile(messageId, currentOffset, end);

          currentOffset += chunkData.buffer.length;

          const keepPushing = this.push(chunkData.buffer);

          if (!keepPushing) {
            isReading = false;
            return;
          }
        }

        this.push(null);
      } catch (err) {
        if (!this.destroyed) this.destroy(err);
      } finally {
        isReading = false;
      }
    }
  });
}

// ==================== DOWNLOAD BYTES HELPER ====================

async function downloadBytes(doc, startOffset, length) {
  const inputLocation = new Api.InputDocumentFileLocation({
    id: doc.id,
    accessHash: doc.accessHash,
    fileReference: doc.fileReference,
    thumbSize: '',
  });

  const fileInfo = { id: doc.id, location: inputLocation };
  let currentSender = await resolveSender(doc);

  const chunks = [];
  let downloaded = 0;
  let currentOffset = startOffset;
  let lastLog = 0;

  while (downloaded < length) {
    const alignedOffset = currentOffset - (currentOffset % 1048576);
    const skipBytes = currentOffset - alignedOffset;
    const limit = getAlignedLimit(alignedOffset);

    let resultData;
    try {
      resultData = await getTelegramChunk(client, fileInfo, alignedOffset, limit, currentSender);
    } catch (error) {
      if (error.isMigrationError && error.newDcId) {
        console.log(`[Telegram] Mid-download migration to DC ${error.newDcId}`);
        currentSender = await client.getSender(error.newDcId);
        resultData = await getTelegramChunk(client, fileInfo, alignedOffset, limit, currentSender);
      } else {
        throw error;
      }
    }

    if (!resultData || resultData.length === 0) break;

    let buf = Buffer.from(resultData);

    if (skipBytes > 0) {
      buf = buf.slice(skipBytes);
    }

    const remaining = length - downloaded;
    if (buf.length > remaining) {
      buf = buf.slice(0, remaining);
    }

    chunks.push(buf);
    downloaded += buf.length;
    currentOffset += buf.length;

    if (downloaded - lastLog >= 10 * 1024 * 1024) {
      console.log(`   📊 Download progress: ${formatFileSize(downloaded)}/${formatFileSize(length)} (${Math.round((downloaded / length) * 100)}%)`);
      lastLog = downloaded;
    }

    if (resultData.length < limit) break;
  }

  return Buffer.concat(chunks);
}

// ==================== ON-DEMAND HELPERS ====================

async function getFileInfo(messageId) {
  if (!client || !channelEntity) throw new Error('Telegram not initialized');

  let messages;
  try {
    messages = await client.getMessages(channelEntity, { ids: [parseInt(messageId)] });
  } catch (e) {
    console.warn(`[Telegram] ⚠️ getFileInfo initial fetch failed: ${e.message}`);
  }

  if (!messages?.[0]?.media?.document) {
    console.log(`[Telegram] ⚠️ getFileInfo failed for ID ${messageId}. Refreshing entity and retrying...`);
    try {
      channelEntity = await client.getEntity(config.channelId);
      messages = await client.getMessages(channelEntity, { ids: [parseInt(messageId)] });
    } catch (retryErr) {
      console.error(`[Telegram] ❌ getFileInfo retry failed: ${retryErr.message}`);
    }
  }

  if (!messages?.[0]?.media?.document) {
    console.warn(`[Telegram] ❌ getFileInfo permanently failed for ID ${messageId}`);
    return null;
  }

  const doc = messages[0].media.document;

  return {
    id: messageId,
    fileSize: Number(doc.size),
    mimeType: doc.mimeType,
    fileName: getFileName(messages[0]),
    dcId: doc.dcId || null,
    inputLocation: new Api.InputDocumentFileLocation({
      id: doc.id,
      accessHash: doc.accessHash,
      fileReference: doc.fileReference,
      thumbSize: '',
    }),
  };
}

// ==================== MEDIA INFO (FFPROBE) ====================

const activeProbes = new Map();

async function probeMovieFile(messageId) {
  if (!ffmpegAvailable || !ffmpegService) {
    console.log('   ⚠️ ffprobe not available, skipping media probe');
    return null;
  }

  const cacheKey = `probe_${messageId}`;
  const cached = subtitleCache.get(cacheKey);
  if (cached) return cached;

  if (activeProbes.has(messageId)) {
    console.log(`   ⏳ Waiting for existing ffprobe to finish for ${messageId}...`);
    return activeProbes.get(messageId);
  }

  const probePromise = (async () => {
    const messages = await client.getMessages(channelEntity, {
      ids: [parseInt(messageId)],
    });

    if (!messages?.[0]?.media?.document) throw new Error('No media');

    const doc = messages[0].media.document;
    const fileSize = Number(doc.size);

    const PROBE_SIZE = Math.min(5 * 1024 * 1024, fileSize);
    console.log(`   📡 Downloading ${formatFileSize(PROBE_SIZE)} for ffprobe...`);

    const headerBuffer = await downloadBytes(doc, 0, PROBE_SIZE);

    console.log(`   🔍 Running ffprobe...`);
    const result = await ffmpegService.probeFromPipe(headerBuffer);

    console.log(`   📊 Found: ${result.video.length} video, ${result.audio.length} audio, ${result.subtitles.length} subtitle streams`);

    if (result.needsTranscoding) {
      console.log('   ⚠️ Audio needs transcoding for browser playback');
    }

    subtitleCache.set(cacheKey, result);
    return result;
  })();

  activeProbes.set(messageId, probePromise);

  try {
    const result = await probePromise;
    activeProbes.delete(messageId);
    return result;
  } catch (err) {
    activeProbes.delete(messageId);
    throw err;
  }
}

async function getMediaInfo(messageId) {
  try {
    return await probeMovieFile(messageId);
  } catch (error) {
    console.error('Media info error:', error.message);
    return null;
  }
}

// ==================== TRANSCODING ====================

async function transcodeMovie(messageId) {
  if (!ffmpegAvailable || !ffmpegService) {
    throw new Error('ffmpeg is not installed. Cannot transcode.');
  }

  const outputPath = path.join(ffmpegService.getTempDir(), `transcoded_${messageId}.mp4`);
  if (fs.existsSync(outputPath)) {
    const stats = fs.statSync(outputPath);
    if (stats.size > 0) {
      console.log(`   ✅ Already transcoded: ${outputPath}`);
      return outputPath;
    }
  }

  const PORT = process.env.PORT || 5000;
  const streamUrl = `http://localhost:${PORT}/api/stream/${messageId}`;

  console.log(`\n🎬 Transcoding movie #${messageId} via HTTP stream...`);
  console.log(`   🌐 Using stream URL: ${streamUrl}`);

  const result = await ffmpegService.transcodeFromUrl(streamUrl, outputPath);
  console.log(`   ✅ Transcode complete: ${result}\n`);

  return result;
}

// ==================== SUBTITLES ====================

async function getSubtitlesForMovie(messageId) {
  const cacheKey = `subs_${messageId}`;
  const subtitles = [];
  subtitleCache.set(cacheKey, subtitles);
  return subtitles;
}

// ==================== MKV FALLBACK ====================

async function extractMKVSubtitleTracksFallback(messageId) {
  const cacheKey = `mkv_tracks_fallback_${messageId}`;
  const cached = subtitleCache.get(cacheKey);
  if (cached) return cached;

  const messages = await client.getMessages(channelEntity, {
    ids: [parseInt(messageId)],
  });

  if (!messages?.[0]?.media?.document) throw new Error('No media');

  const doc = messages[0].media.document;
  const fileSize = Number(doc.size);

  const HEADER_SIZE = Math.min(10 * 1024 * 1024, fileSize);
  console.log(`   ⬇️ Downloading ${formatFileSize(HEADER_SIZE)} for MKV header parse...`);

  const headerBuffer = await downloadBytes(doc, 0, HEADER_SIZE);

  const extractor = new MKVSubtitleExtractor();
  const tracks = extractor.parseHeader(headerBuffer);

  console.log(`   🎯 Fallback found ${tracks.length} subtitle track(s)`);

  const subtitles = tracks.map((track) => {
    const langLabel = getLanguageLabel(track.language);
    const displayName = isCleanText(track.name) ? track.name : langLabel;

    return {
      id: `sub_emb_${messageId}_${track.trackNumber}`,
      messageId: parseInt(messageId),
      trackNumber: track.trackNumber,
      type: 'embedded',
      fileName: `${displayName}.${track.format}`,
      language: track.language,
      label: `${displayName}${track.isDefault ? ' ★' : ''}`,
      format: track.format,
      codecId: track.codecId,
      isDefault: track.isDefault,
      isForced: track.isForced,
    };
  });

  subtitleCache.set(cacheKey, subtitles);
  return subtitles;
}

// ==================== GET SUBTITLE CONTENT ====================

async function getSubtitleContent(subtitleId) {
  if (subtitleId.startsWith('sub_emb_')) {
    const parts = subtitleId.replace('sub_emb_', '').split('_');
    const messageId = parts[0];
    const streamIndex = parseInt(parts[1]);
    return await getEmbeddedSubtitleViaFFmpeg(messageId, streamIndex);
  }

  const messageId = subtitleId.replace('sub_ext_', '').replace('sub_', '');
  return await getExternalSubtitleContent(messageId);
}

async function getEmbeddedSubtitleViaFFmpeg(messageId, streamIndex) {
  const cacheKey = `sub_ffmpeg_${messageId}_${streamIndex}`;
  const cached = subtitleCache.get(cacheKey);
  if (cached) return cached;

  if (!client || !channelEntity) throw new Error('Telegram not initialized');

  const messages = await client.getMessages(channelEntity, {
    ids: [parseInt(messageId)],
  });

  if (!messages?.[0]?.media?.document) throw new Error('No media');

  const doc = messages[0].media.document;
  const fileSize = Number(doc.size);

  console.log(`   📥 Extracting subtitle stream #${streamIndex} via streaming pipe...`);
  console.log(`   📦 File size: ${formatFileSize(fileSize)} — streaming without full download`);

  try {
    const { stdin, promise } = ffmpegService.extractSubtitleFromStream(streamIndex);

    const inputLocation = new Api.InputDocumentFileLocation({
      id: doc.id,
      accessHash: doc.accessHash,
      fileReference: doc.fileReference,
      thumbSize: '',
    });

    const fileInfo = { id: doc.id, location: inputLocation };
    let currentSender = await resolveSender(doc);

    let streamed = 0;
    let currentOffset = 0;
    let stdinClosed = false;

    stdin.on('close', () => { stdinClosed = true; });

    try {
      while (currentOffset < fileSize && !stdinClosed) {
        const alignedOffset = currentOffset - (currentOffset % 1048576);
        const skipBytes = currentOffset - alignedOffset;
        const limit = getAlignedLimit(alignedOffset);

        let resultData;
        try {
          resultData = await getTelegramChunk(client, fileInfo, alignedOffset, limit, currentSender);
        } catch (error) {
          if (error.isMigrationError && error.newDcId) {
            console.log(`[Telegram] Subtitle pipe migration to DC ${error.newDcId}`);
            currentSender = await client.getSender(error.newDcId);
            resultData = await getTelegramChunk(client, fileInfo, alignedOffset, limit, currentSender);
          } else {
            throw error;
          }
        }

        if (!resultData || resultData.length === 0) break;

        let chunk = Buffer.from(resultData);

        if (skipBytes > 0) {
          chunk = chunk.slice(skipBytes);
        }

        try {
          if (!stdinClosed) {
            stdin.write(chunk);
          }
        } catch (e) {
          break;
        }

        streamed += chunk.length;
        currentOffset += chunk.length;

        if (streamed % (50 * 1024 * 1024) < limit) {
          console.log(`   📊 Streamed ${formatFileSize(streamed)}/${formatFileSize(fileSize)} to ffmpeg`);
        }

        if (resultData.length < limit) break;
      }
    } finally {
      try { if (!stdinClosed) stdin.end(); } catch (e) { /* EPIPE is fine */ }
    }

    console.log(`   ✅ Finished streaming ${formatFileSize(streamed)} to ffmpeg, waiting for output...`);

    const vttContent = await promise;

    if (!vttContent || vttContent.trim().length < 10) {
      throw new Error('ffmpeg returned empty subtitle content');
    }

    let finalContent = vttContent;
    if (!finalContent.trim().startsWith('WEBVTT')) {
      finalContent = 'WEBVTT\n\n' + finalContent;
    }

    console.log(`   ✅ Extracted subtitle: ${finalContent.length} chars`);

    const result = {
      content: finalContent,
      fileName: `subtitle_stream${streamIndex}.vtt`,
      format: 'vtt',
      mimeType: 'text/vtt',
    };

    subtitleCache.set(cacheKey, result);
    return result;
  } catch (pipeErr) {
    console.error('   ⚠️ ffmpeg pipe extraction failed:', pipeErr.message);
    try {
      const PORT = process.env.PORT || 5000;
      const streamUrl = `http://localhost:${PORT}/api/stream/${messageId}`;
      const vttContent = await ffmpegService.extractSubtitleFromUrl(streamUrl, streamIndex, 'webvtt');

      if (!vttContent || vttContent.trim().length < 10) {
        throw new Error('ffmpeg HTTP extraction returned empty content');
      }

      let finalContent = vttContent;
      if (!finalContent.trim().startsWith('WEBVTT')) finalContent = 'WEBVTT\n\n' + finalContent;

      const result = {
        content: finalContent,
        fileName: `subtitle_stream${streamIndex}.vtt`,
        format: 'vtt',
        mimeType: 'text/vtt',
      };

      subtitleCache.set(cacheKey, result);
      return result;
    } catch (httpErr) {
      console.error('   ❌ ffmpeg HTTP extraction failed:', httpErr.message);
      throw pipeErr;
    }
  }
}

async function getEmbeddedSubtitleViaMKVParser(messageId, trackNumber) {
  throw new Error('MKV binary parser disabled to avoid full-file downloads. Use FFmpeg extraction only.');
}

async function getExternalSubtitleContent(messageId) {
  const cacheKey = `sub_ext_content_${messageId}`;
  const cached = subtitleCache.get(cacheKey);
  if (cached) return cached;

  if (!client || !channelEntity) throw new Error('Telegram not initialized');

  const messages = await client.getMessages(channelEntity, {
    ids: [parseInt(messageId)],
  });

  if (!messages?.[0]?.media?.document) throw new Error('Subtitle not found');

  const doc = messages[0].media.document;
  const fileName =
    doc.attributes?.find((a) => a.className === 'DocumentAttributeFilename')
      ?.fileName || 'subtitle.srt';
  const fileSize = Number(doc.size);

  console.log(`📥 Downloading external subtitle: ${fileName}`);

  const rawContent = await downloadBytes(doc, 0, fileSize);
  const trimmed = rawContent.subarray(0, fileSize);
  const textContent = trimmed.toString('utf-8');
  const vttContent = detectAndConvert(textContent, fileName);

  const result = {
    content: vttContent,
    fileName,
    format: 'vtt',
    mimeType: 'text/vtt',
  };

  subtitleCache.set(cacheKey, result);
  return result;
}

function convertSubtitleText(text, format = 'srt') {
  if (format === 'srt') return srtToVtt(text);
  if (format === 'ass' || format === 'ssa') return assToVtt(text);
  if (format === 'vtt') return text;
  return srtToVtt(text);
}

// ==================== TRANSCODING & STREAMING ====================

function getFileReadStream(doc) {
  const { Readable } = require('stream');

  const inputLocation = new Api.InputDocumentFileLocation({
    id: doc.id,
    accessHash: doc.accessHash,
    fileReference: doc.fileReference,
    thumbSize: '',
  });

  const fileInfo = { id: doc.id, location: inputLocation };

  const readable = new Readable({
    read() { }
  });

  (async () => {
    let offset = 0;
    let currentSender = await resolveSender(doc);

    try {
      while (true) {
        const limit = getAlignedLimit(offset);

        let resultData;
        try {
          resultData = await getTelegramChunk(client, fileInfo, offset, limit, currentSender);
        } catch (error) {
          if (error.isMigrationError && error.newDcId) {
            console.log(`[Telegram] ReadStream migration to DC ${error.newDcId}`);
            currentSender = await client.getSender(error.newDcId);
            resultData = await getTelegramChunk(client, fileInfo, offset, limit, currentSender);
          } else {
            throw error;
          }
        }

        if (!resultData || resultData.length === 0) {
          readable.push(null);
          break;
        }

        readable.push(Buffer.from(resultData));
        offset += resultData.length;

        if (resultData.length < limit) {
          readable.push(null);
          break;
        }
      }
    } catch (e) {
      console.error('Streaming download error:', e);
      readable.destroy(e);
    }
  })();

  return readable;
}

// Second transcodeMovie definition using getFileReadStream
async function transcodeMovieStream(messageId) {
  if (!ffmpegAvailable || !ffmpegService) throw new Error('FFmpeg not available');
  if (!client || !channelEntity) throw new Error('Telegram not initialized');

  const messages = await client.getMessages(channelEntity, { ids: [parseInt(messageId)] });
  if (!messages?.[0]?.media?.document) throw new Error('No media found');

  const doc = messages[0].media.document;
  const inputStream = getFileReadStream(doc);
  const tempDir = ffmpegService.getTempDir();
  const outputPath = require('path').join(tempDir, `transcoded_${messageId}.mp4`);

  console.log(`🎬 Transcoding movie #${messageId} to ${outputPath}...`);

  const outputStream = require('fs').createWriteStream(outputPath);
  const { stream: ffmpegStream, process: ffmpegProc } = ffmpegService.createTranscodeStream(inputStream);

  return new Promise((resolve, reject) => {
    ffmpegStream.pipe(outputStream);

    let finished = false;
    outputStream.on('finish', () => {
      finished = true;
      console.log(`✅ Transcode finished: ${outputPath}`);
      resolve(outputPath);
    });

    ffmpegProc.on('error', (err) => {
      if (!finished) {
        console.error('ffmpeg process error:', err.message);
        reject(err);
      }
    });

    ffmpegProc.on('close', (code, signal) => {
      if (code !== 0 && !finished) {
        const err = new Error(`ffmpeg exited with code ${code} signal ${signal}`);
        console.error('Transcode failed:', err.message);
        reject(err);
      }
    });

    ffmpegStream.on('error', (err) => {
      if (!finished) {
        console.error('Transcode stream error:', err.message);
        reject(err);
      }
    });

    outputStream.on('error', (err) => {
      if (!finished) reject(err);
    });
  });
}

async function streamTranscodedVideo(messageId, audioStreamIndex, options = {}) {
  if (!ffmpegAvailable || !ffmpegService) throw new Error('FFmpeg not available');
  if (!client || !channelEntity) throw new Error('Telegram not initialized');

  const messages = await client.getMessages(channelEntity, { ids: [parseInt(messageId)] });
  if (!messages?.[0]?.media?.document) throw new Error('No media found');

  const doc = messages[0].media.document;
  const inputStream = getFileReadStream(doc);

  const { stream, process } = ffmpegService.createTranscodeStream(inputStream, audioStreamIndex, options);
  return { stream, process };
}

// ==================== DEBUG ====================

async function getDebugMessages(messageId, range = 20) {
  if (!client || !channelEntity) throw new Error('Telegram not initialized');

  const msgId = parseInt(messageId);

  const messages = await client.getMessages(channelEntity, {
    limit: range * 2,
    offsetId: msgId + range,
  });

  const result = [];

  for (const msg of messages) {
    if (!msg) continue;

    let type = 'text';
    let fileName = null;
    let mimeType = null;
    let fileSize = null;

    if (msg.media?.document) {
      const doc = msg.media.document;
      mimeType = doc.mimeType || 'unknown';
      fileName = getFileName(msg);
      fileSize = Number(doc.size);

      const videoAttr = doc.attributes?.find(
        (a) => a.className === 'DocumentAttributeVideo'
      );

      if (videoAttr || mimeType.startsWith('video/')) {
        type = 'video';
      } else if (isSubtitleFile(fileName, mimeType)) {
        type = 'subtitle';
      } else {
        type = 'document';
      }
    } else if (msg.media?.photo) {
      type = 'photo';
    }

    result.push({
      id: msg.id,
      type,
      fileName,
      mimeType,
      fileSize,
      text: msg.message?.substring(0, 100) || '',
      date: new Date(msg.date * 1000).toISOString(),
      distance: msg.id - msgId,
      isTarget: msg.id === msgId,
    });
  }

  result.sort((a, b) => a.id - b.id);

  console.log('\n📋 Messages around #' + msgId + ':');
  console.log('─'.repeat(80));
  for (const m of result) {
    const marker = m.isTarget ? ' ◄── THIS VIDEO' : '';
    const subMarker = m.type === 'subtitle' ? ' 🔤 SUBTITLE!' : '';
    console.log(
      `  #${m.id} [${m.type.padEnd(8)}] ${(m.fileName || m.text || '(no name)').substring(0, 50)}${marker}${subMarker}`
    );
  }
  console.log('─'.repeat(80) + '\n');

  return result;
}

// ==================== CACHE STATS ====================

function getCacheStats() {
  return {
    chunkCache: {
      size: chunkCache.calculatedSize,
      sizeFormatted: formatFileSize(chunkCache.calculatedSize || 0),
      entries: chunkCache.size,
      maxSize: config.maxCacheSize,
      maxSizeFormatted: formatFileSize(config.maxCacheSize),
    },
    movieCache: { entries: movieCache.size },
    ffmpegAvailable,
  };
}

// ==================== TRACK DETECTION ====================

function normalizeLanguage(code) {
  const map = {
    'hin': 'Hindi', 'eng': 'English', 'jpn': 'Japanese', 'kor': 'Korean',
    'spa': 'Spanish', 'fra': 'French', 'fre': 'French', 'deu': 'German', 'ger': 'German',
    'ita': 'Italian', 'por': 'Portuguese', 'rus': 'Russian', 'zho': 'Chinese', 'chi': 'Chinese',
    'ara': 'Arabic', 'tur': 'Turkish', 'tha': 'Thai', 'vie': 'Vietnamese', 'ind': 'Indonesian',
    'may': 'Malay', 'msa': 'Malay', 'tam': 'Tamil', 'tel': 'Telugu', 'ben': 'Bengali',
    'mal': 'Malayalam', 'kan': 'Kannada', 'mar': 'Marathi', 'guj': 'Gujarati', 'pan': 'Punjabi',
    'urd': 'Urdu', 'und': 'Unknown',
  };
  const lower = (code || 'und').toLowerCase().substring(0, 3);
  return map[lower] || code || 'Unknown';
}

async function detectAllTracks(doc, fileId) {
  if (!ffmpegAvailable || !ffmpegService) {
    return {
      audioTracks: [],
      subtitleTracks: [],
      format: null,
      error: 'ffprobe not available',
    };
  }

  let probeSize = 15 * 1024 * 1024; // Tier 1: 15MB
  let retryCount = 0;
  const MAX_RETRY_COUNT = 2;

  while (retryCount <= MAX_RETRY_COUNT) {
    const tempDir = require('os').tmpdir();
    // Unique name per tier to avoid conflicts
    const tempFile = path.join(tempDir, `probe_${fileId}_t${retryCount}_${Date.now()}.mkv`);

    try {
      const currentProbeSize = Math.min(probeSize, Number(doc.size));
      const tierLabel = retryCount === 0 ? 'Tier 1' : retryCount === 1 ? 'Tier 2' : 'Tier 3';
      console.log(`🔍 Probing "${fileId}" (${formatFileSize(currentProbeSize)}, ${tierLabel})...`);

      const buffer = await downloadProbeChunk(doc, currentProbeSize);
      if (!buffer || buffer.length === 0) throw new Error('Downloaded empty probe chunk');

      await fs.promises.writeFile(tempFile, buffer);

      const info = await ffmpegService.probeFile(tempFile);
      try { await fs.promises.unlink(tempFile); } catch (e) { }

      if (!info || (!info.audio?.length && !info.video?.length)) {
        throw new Error('ffprobe returned no streams');
      }

      const audioTracks = [];
      const subtitleTracks = [];

      (info.audio || []).forEach((stream, idx) => {
        const codec = (stream.codecName || 'unknown').toLowerCase();
        const browserPlayable = [
          'aac', 'mp3', 'opus', 'vorbis', 'flac',
          'mp4a', 'mp4a.40.2', 'mp4a.40.5',
        ].includes(codec);

        audioTracks.push({
          index: idx,
          streamIndex: stream.index,
          codec: codec,
          language: normalizeLanguage(stream.language),
          languageCode: stream.language,
          title: stream.title,
          channels: stream.channels,
          channelLayout: stream.channelLayout,
          browserPlayable,
          isDefault: stream.isDefault
        });
      });

      (info.subtitles || []).forEach((stream, idx) => {
        subtitleTracks.push({
          index: idx,
          streamIndex: stream.index,
          codec: (stream.codecName || 'unknown').toLowerCase(),
          language: normalizeLanguage(stream.language),
          languageCode: stream.language,
          title: stream.title,
          isTextBased: stream.subtitleType === 'text',
          isImageBased: stream.subtitleType === 'bitmap',
          extractable: stream.subtitleType === 'text',
          isDefault: stream.isDefault,
          isForced: stream.isForced
        });
      });

      return { audioTracks, subtitleTracks, format: info.format || null };

    } catch (error) {
      try { if (require('fs').existsSync(tempFile)) require('fs').unlinkSync(tempFile); } catch (e) { }
      
      retryCount++;
      if (retryCount <= MAX_RETRY_COUNT) {
        // Tier 2: 40MB, Tier 3: 80MB
        probeSize = retryCount === 1 ? 40 * 1024 * 1024 : 80 * 1024 * 1024;
        console.warn(`⚠️ Probe failed for "${fileId}" (Attempt ${retryCount}): ${error.message}. Retrying with ${formatFileSize(probeSize)}...`);
        continue;
      }

      console.error(`[Telegram] ❌ Track detection permanently failed for "${fileId}":`, error.message);
      return { audioTracks: [], subtitleTracks: [], format: null, error: error.message };
    }
  }
}

async function getDocument(messageId) {
  if (!client || !channelEntity) return null;
  const messages = await client.getMessages(channelEntity, { ids: [parseInt(messageId)] });
  return messages?.[0]?.media?.document;
}

// FIXED: downloadPartial now uses getAlignedLimit internally
async function downloadPartial(doc, offset, totalNeeded) {
  if (!doc || !doc.id) {
    throw new Error('Invalid document for partial download');
  }

  const inputLocation = new Api.InputDocumentFileLocation({
    id: doc.id,
    accessHash: doc.accessHash,
    fileReference: doc.fileReference,
    thumbSize: '',
  });

  const fileInfo = { id: doc.id, location: inputLocation };
  let currentSender = await resolveSender(doc);

  const chunks = [];
  let currentOffset = offset;
  let downloaded = 0;

  while (downloaded < totalNeeded) {
    const alignedOffset = currentOffset - (currentOffset % 1048576);
    const skipBytes = currentOffset - alignedOffset;
    const limit = getAlignedLimit(alignedOffset);

    let resultData;
    try {
      resultData = await getTelegramChunk(client, fileInfo, alignedOffset, limit, currentSender);
    } catch (error) {
      if (error.isMigrationError && error.newDcId) {
        console.log(`[Telegram] Partial download migration to DC ${error.newDcId}`);
        currentSender = await client.getSender(error.newDcId);
        resultData = await getTelegramChunk(client, fileInfo, alignedOffset, limit, currentSender);
      } else {
        throw error;
      }
    }

    if (!resultData || resultData.length === 0) break;

    let buf = Buffer.from(resultData);

    if (skipBytes > 0) {
      buf = buf.slice(skipBytes);
    }

    const remaining = totalNeeded - downloaded;
    if (buf.length > remaining) {
      buf = buf.slice(0, remaining);
    }

    chunks.push(buf);
    downloaded += buf.length;
    currentOffset += buf.length;

    if (resultData.length < limit) break;
  }

  return Buffer.concat(chunks);
}

// ==================== SAFE PROBE DOWNLOAD ====================

async function downloadProbeChunk(doc, targetSize) {
  const chunks = [];
  let offset = 0;

  const inputLocation = new Api.InputDocumentFileLocation({
    id: doc.id,
    accessHash: doc.accessHash,
    fileReference: doc.fileReference,
    thumbSize: '',
  });

  const fileInfo = { id: doc.id, location: inputLocation };
  let currentSender = await resolveSender(doc);

  while (offset < targetSize) {
    let chunkData = null;
    let retries = 0;
    const MAX_RETRIES = 3;

    while (retries <= MAX_RETRIES) {
      try {
        const limit = getAlignedLimit(offset);
        chunkData = await getTelegramChunk(client, fileInfo, offset, limit, currentSender);
        break; // Success!
      } catch (error) {
        if (error.isMigrationError && error.newDcId) {
          console.log(`[Telegram] Probe migration to DC ${error.newDcId}`);
          currentSender = await client.getSender(error.newDcId);
          // Retry immediately without consuming a standard retry attempt
          continue; 
        }

        retries++;
        const isTimeout = error.message.includes('timeout') || error.message.includes('TIMEOUT');
        const isConnection = error.message.includes('connection') || error.message.includes('NOT_CONNECTED');
        
        if (retries <= MAX_RETRIES && (isTimeout || isConnection)) {
          const delay = Math.pow(2, retries) * 1000;
          console.warn(`⚠️ [Telegram] Probe chunk failed at offset ${offset} (Attempt ${retries}/${MAX_RETRIES}). Retrying in ${delay}ms...`);
          await new Promise(r => setTimeout(r, delay));
          continue;
        }
        
        console.error(`❌ [Telegram] Probe chunk failed after ${retries} attempts at offset ${offset}:`, error.message);
        if (chunks.length > 0) break; 
        throw error;
      }
    }

    if (!chunkData || chunkData.length === 0) break;

    chunks.push(Buffer.from(chunkData));
    offset += chunkData.length;
  }

  if (chunks.length === 0) return Buffer.alloc(0);
  return Buffer.concat(chunks);
}


// ==================== SIMPLIFIED AUDIO DETECTION ====================

async function detectAudioCodec(messageId) {
  if (!ffmpegAvailable || !ffmpegService) {
    console.warn('⚠️ ffprobe not available, cannot detect audio codec');
    return { codec: 'unknown', browserPlayable: false };
  }

  const messages = await client.getMessages(channelEntity, { ids: [parseInt(messageId)] });
  if (!messages?.[0]?.media?.document) throw new Error('No media found');
  const doc = messages[0].media.document;

  let probeSize = 15 * 1024 * 1024; // Tier 1: 15MB
  let retryCount = 0;
  const MAX_RETRY_COUNT = 2;
  let result = null;

  while (retryCount <= MAX_RETRY_COUNT) {
    try {
      const currentProbeSize = Math.min(probeSize, Number(doc.size));
      const tierLabel = retryCount === 0 ? 'Tier 1' : retryCount === 1 ? 'Tier 2' : 'Tier 3';
      console.log(`🔍 Probing "${messageId}" (${formatFileSize(currentProbeSize)}, ${tierLabel})...`);

      const chunk = await downloadProbeChunk(doc, currentProbeSize);
      if (!chunk || chunk.length === 0) throw new Error('Downloaded empty probe chunk');

      result = await ffmpegService.probeFromPipe(chunk);
      
      if (!result || !result.audio || result.audio.length === 0) {
        throw new Error('ffprobe returned no audio streams');
      }
      break; 
    } catch (error) {
       retryCount++;
       if (retryCount <= MAX_RETRY_COUNT) {
         // Tier 2: 40MB, Tier 3: 80MB
         probeSize = retryCount === 1 ? 40 * 1024 * 1024 : 80 * 1024 * 1024;
         console.warn(`⚠️ Audio detection failed for "${messageId}" (Attempt ${retryCount}): ${error.message}. Retrying with ${formatFileSize(probeSize)}...`);
         continue;
       }
       return { codec: 'unknown', browserPlayable: false };
    }
  }

  const defaultAudio = result.audio[0];
  const codec = defaultAudio.codecName.toLowerCase();
  const DIRECT_PLAY_CODECS = ['aac', 'mp3', 'opus', 'vorbis', 'flac', 'mp4a', 'mp4a.40.2', 'mp4a.40.5'];
  const isCompatible = DIRECT_PLAY_CODECS.includes(codec);

  console.log(`🎵 Detected Audio: ${codec} (${isCompatible ? 'Direct' : 'Transmux'})`);

  return { codec: codec, browserPlayable: isCompatible };
}

// ==================== CHANNEL SCAN (Lightweight) ====================

async function scanChannelFiles() {
  if (!client || !channelEntity) throw new Error('Telegram not initialized');

  console.log('📡 Scanning channel for files...');
  const files = [];
  let offsetId = 0;
  const BATCH_SIZE = 100;

  while (true) {
    const messages = await client.getMessages(channelEntity, {
      limit: BATCH_SIZE,
      offsetId: offsetId,
    });

    if (!messages || messages.length === 0) break;

    for (const msg of messages) {
      if (msg.media && msg.media.document) {
        const isVideo = msg.media.document.mimeType.startsWith('video/') ||
          (getFileName(msg) || '').match(/\.(mkv|mp4|avi|mov|webm)$/i);

        if (isVideo) {
          files.push({
            id: msg.id.toString(),
            messageId: msg.id,
            date: new Date(msg.date * 1000).toISOString(),
            fileName: getFileName(msg) || `video_${msg.id}.mp4`,
            size: Number(msg.media.document.size),
            mimeType: msg.media.document.mimeType
          });
        }
      }
    }

    offsetId = messages[messages.length - 1].id;
    console.log(`.. Scanned up to ID ${offsetId} (Found ${files.length} files so far)`);

    if (messages.length < BATCH_SIZE) break;
  }

  return files;
}

// ==================== EXPORTS ====================

module.exports = {
  initTelegram,
  getMoviesList,
  getMovieById,
  groupSplitFiles,
  getMovieMetadata,
  getThumbnail,
  streamFile,
  getDownloadStream,
  getCacheStats: () => ({ size: chunkCache.size }),
  getSubtitlesForMovie,
  getMediaInfo,
  transcodeMovie,
  probeMovieFile,
  getFileInfo,
  downloadBytes,
  getDocument: async (messageId) => {
    if (!client || !channelEntity) return null;
    const msgs = await client.getMessages(channelEntity, { ids: [parseInt(messageId)] });
    return msgs[0]?.media?.document || null;
  },
  detectAudioCodec,
  saveMetadataDirectly: async (id, data) => {
    try {
      const { saveMetadata } = require('./metadataWorker');
      await saveMetadata({ ...data, fileId: id });
    } catch (e) {
      console.error('Save metadata failed:', e);
    }
  },
  getClient: () => client,
  getDcSender: async (dcId, forceReconnect = false) => {
    if (!client || !dcId) return null;
    try {
      if (forceReconnect) {
        if (client._exportedSenderPromises && client._exportedSenderPromises[dcId]) {
          delete client._exportedSenderPromises[dcId];
        }
        if (client._exportedSenders && client._exportedSenders[dcId]) {
          try { await client._exportedSenders[dcId].disconnect(); } catch(e){}
          delete client._exportedSenders[dcId];
        }
      }
      return await client.getSender(dcId);
    } catch (e) {
      console.warn(`⚠️ [Telegram] getDcSender(${dcId}) failed:`, e.message);
      return null;
    }
  },
  downloadProbeChunk: typeof downloadProbeChunk !== 'undefined' ? downloadProbeChunk : null,
  invalidateCache,
  scanChannelFiles,
  detectAllTracks
};
