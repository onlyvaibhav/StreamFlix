const telegramService = require('../services/telegramService');
const ffmpegService = require('../services/ffmpegService');
const { Api } = require('telegram');
const { spawn } = require('child_process');
const { loadMetadata, saveMetadata } = require('../services/metadataWorker');
const bigInt = require('big-integer');
const { getTelegramChunk } = require('../services/chunkCacheService');

// ==================== CHECK DEPENDENCIES ====================
let HAS_FFMPEG = false;
(async () => {
  try {
    HAS_FFMPEG = await ffmpegService.checkFFmpeg();
  } catch { }
})();

// ==================== TELEGRAM LIMIT HELPERS ====================
const BROWSER_AUDIO_CODECS = ['aac', 'mp3', 'opus', 'vorbis', 'flac'];
// fileId -> { process, res }
const activeTranscodes = new Map();
const subtitleCache = new Map(); // key: "fileId_streamIndex" -> vtt text
const SUBTITLE_CACHE_MAX_ENTRIES = 50;

function getAlignedLimit(offset) {
  return 1048576; // 1MB chunks globally
}

function alignOffset(offset) {
  return offset - (offset % 1048576); // Snap to 1MB barrier
}



function getFileExtension(fileName) {
  const raw = (fileName || '').trim();
  if (!raw.includes('.')) return '';
  return raw.split('.').pop().toLowerCase();
}

function isMatroskaContainer(containerName, fileName) {
  const container = String(containerName || '').toLowerCase();
  const ext = getFileExtension(fileName);
  return (
    container.includes('matroska') ||
    container.includes('mkv') ||
    ext === 'mkv'
  );
}

function normalizeLanguage(code) {
  const map = {
    hin: 'Hindi',
    eng: 'English',
    jpn: 'Japanese',
    kor: 'Korean',
    spa: 'Spanish',
    fra: 'French',
    fre: 'French',
    deu: 'German',
    ger: 'German',
    ita: 'Italian',
    por: 'Portuguese',
    rus: 'Russian',
    zho: 'Chinese',
    chi: 'Chinese',
    ara: 'Arabic',
    tur: 'Turkish',
    tha: 'Thai',
    vie: 'Vietnamese',
    ind: 'Indonesian',
    may: 'Malay',
    msa: 'Malay',
    tam: 'Tamil',
    tel: 'Telugu',
    ben: 'Bengali',
    mal: 'Malayalam',
    kan: 'Kannada',
    mar: 'Marathi',
    guj: 'Gujarati',
    pan: 'Punjabi',
    urd: 'Urdu',
    und: 'Unknown',
  };
  const lower = (code || 'und').toLowerCase().substring(0, 3);
  return map[lower] || code || 'Unknown';
}

function mapAudioTracks(streams = []) {
  return streams.map((stream, idx) => {
    const codec = (stream.codecName || 'unknown').toLowerCase();
    return {
      index: idx,
      streamIndex: stream.index,
      codec,
      language: normalizeLanguage(stream.language),
      languageCode: stream.language || 'und',
      title: stream.title || '',
      channels: stream.channels || 0,
      channelLayout: stream.channelLayout || '',
      browserPlayable: BROWSER_AUDIO_CODECS.includes(codec),
      isDefault: stream.isDefault === true,
    };
  });
}

function mapSubtitleTracks(streams = []) {
  return streams.map((stream, idx) => {
    const subtitleType = (stream.subtitleType || 'unknown').toLowerCase();
    return {
      index: idx,
      streamIndex: stream.index,
      codec: (stream.codecName || 'unknown').toLowerCase(),
      language: normalizeLanguage(stream.language),
      languageCode: stream.language || 'und',
      title: stream.title || '',
      isTextBased: subtitleType === 'text',
      isImageBased: subtitleType === 'bitmap',
      extractable: subtitleType === 'text',
      isDefault: stream.isDefault === true,
      isForced: stream.isForced === true,
    };
  });
}

function killTranscode(fileId) {
  const key = String(fileId);
  const active = activeTranscodes.get(key);
  if (!active?.process) return;

  try {
    active.process.kill('SIGKILL');
  } catch { }

  if (active.res && !active.res.writableEnded && !active.res.destroyed) {
    try { active.res.end(); } catch { }
  }

  activeTranscodes.delete(key);
}

function killAllTranscodes() {
  for (const [fileId, active] of activeTranscodes.entries()) {
    try {
      active.process.kill('SIGKILL');
    } catch { }

    if (active.res && !active.res.writableEnded && !active.res.destroyed) {
      try { active.res.end(); } catch { }
    }

    activeTranscodes.delete(fileId);
  }
}

const SHUTDOWN_HOOK_FLAG = '__STREAMFLIX_TRANSCODE_HOOKS__';
if (!process[SHUTDOWN_HOOK_FLAG]) {
  process[SHUTDOWN_HOOK_FLAG] = true;
  process.on('SIGINT', () => killAllTranscodes());
  process.on('SIGTERM', () => killAllTranscodes());
}

async function resolveFileInfo(id) {
  let fileInfo = await telegramService.getFileInfo(id);
  let resolvedId = String(id);

  // FALLBACK 1: list cache
  if (!fileInfo) {
    try {
      const fs = require('fs');
      const path = require('path');
      const listPath = path.join(__dirname, '..', 'data', 'list_caches.json');

      if (fs.existsSync(listPath)) {
        const raw = await fs.promises.readFile(listPath, 'utf-8');
        const list = JSON.parse(raw);
        const found = list.find((f) =>
          String(f.id) === String(id) ||
          String(f.messageId) === String(id) ||
          String(f.fileId) === String(id)
        );

        const lookupId = found?.messageId || found?.id || found?.fileId;
        if (lookupId) {
          fileInfo = await telegramService.getFileInfo(lookupId);
          resolvedId = String(lookupId);
        }
      }
    } catch (error) {
      console.error('[Stream] List cache fallback failed:', error.message);
    }
  }

  // FALLBACK 2: metadata
  if (!fileInfo) {
    try {
      const meta = await loadMetadata(id);
      if (meta?.fileId) {
        fileInfo = await telegramService.getFileInfo(meta.fileId);
        resolvedId = String(meta.fileId);
      }
    } catch (error) {
      console.error('[Stream] Metadata fallback failed:', error.message);
    }
  }

  if (fileInfo?.id) {
    resolvedId = String(fileInfo.id);
  }

  return { fileInfo, resolvedId };
}

async function ensurePlaybackMetadata(id, fileInfo, metadata) {
  const enriched = metadata && typeof metadata === 'object'
    ? { ...metadata }
    : { fileId: String(id), title: 'Unknown' };

  enriched.fileId = String(enriched.fileId || id);
  if (fileInfo?.fileName && !enriched.fileName) {
    enriched.fileName = fileInfo.fileName;
  }

  let shouldSave = false;

  const missingContainer = !enriched.container;
  const missingDuration = !Number.isFinite(Number(enriched.duration)) || Number(enriched.duration) <= 0;
  const incompleteAudioTracks = Array.isArray(enriched.audioTracks)
    ? enriched.audioTracks.some((t) => !t || !String(t.codec || '').trim())
    : true;
  const incompleteSubtitleTracks = Array.isArray(enriched.subtitleTracks)
    ? enriched.subtitleTracks.some((t, idx) => {
      const streamIndex = Number(t?.streamIndex);
      const fallbackIndex = Number(t?.index ?? idx);
      return !Number.isInteger(streamIndex) && !Number.isInteger(fallbackIndex);
    })
    : true;
  const missingTracks = !Array.isArray(enriched.audioTracks) || !Array.isArray(enriched.subtitleTracks) ||
    incompleteAudioTracks || incompleteSubtitleTracks;

  if (missingContainer || missingDuration || missingTracks) {
    try {
      const mediaInfo = await telegramService.getMediaInfo(id);
      if (mediaInfo) {
        if (mediaInfo.format?.name) {
          enriched.container = mediaInfo.format.name;
        }
        if (Number.isFinite(Number(mediaInfo.format?.duration))) {
          enriched.duration = Number(mediaInfo.format.duration);
        }

        const audioTracks = mapAudioTracks(mediaInfo.audio || []);
        const subtitleTracks = mapSubtitleTracks(mediaInfo.subtitles || []);

        enriched.audioTracks = audioTracks;
        enriched.subtitleTracks = subtitleTracks;

        if ((!enriched.audioCodec || enriched.audioCodec === 'unknown') && audioTracks.length > 0) {
          enriched.audioCodec = audioTracks[0].codec;
        }

        if (typeof enriched.browserPlayable !== 'boolean' && audioTracks.length > 0) {
          enriched.browserPlayable = audioTracks[0].browserPlayable;
        }

        shouldSave = true;
      }
    } catch (error) {
      console.warn(`[Stream] Media probe failed for ${id}:`, error.message);
    }
  }

  if (!enriched.container && (fileInfo?.fileName || enriched.fileName)) {
    enriched.container = getFileExtension(fileInfo?.fileName || enriched.fileName);
  }

  if (!Number.isFinite(Number(enriched.duration)) || Number(enriched.duration) < 0) {
    const runtimeMinutes = Number(enriched.runtime);
    enriched.duration = Number.isFinite(runtimeMinutes) && runtimeMinutes > 0
      ? runtimeMinutes * 60
      : 0;
  }

  if (!Array.isArray(enriched.audioTracks)) enriched.audioTracks = [];
  if (!Array.isArray(enriched.subtitleTracks)) enriched.subtitleTracks = [];
  if (!enriched.audioCodec && enriched.audioTracks.length > 0) {
    enriched.audioCodec = enriched.audioTracks[0].codec;
  }
  if (typeof enriched.browserPlayable !== 'boolean') {
    enriched.browserPlayable = true;
  }

  if (shouldSave) {
    try {
      await saveMetadata(enriched);
    } catch (error) {
      console.warn(`[Stream] Metadata save failed for ${id}:`, error.message);
    }
  }

  return enriched;
}

function getAudioTrackAt(metadata, index) {
  const tracks = Array.isArray(metadata?.audioTracks) ? metadata.audioTracks : [];
  if (tracks.length === 0) {
    return { tracks, index: 0, track: null };
  }
  const safeIndex = Number.isInteger(index) && index >= 0
    ? Math.min(index, tracks.length - 1)
    : 0;
  return { tracks, index: safeIndex, track: tracks[safeIndex] };
}

// ==================== STREAM PREPARATION ====================

// GET /api/stream/:fileId/tracks
exports.getTracks = async (req, res) => {
  const { id } = req.params;

  try {
    const { fileInfo, resolvedId } = await resolveFileInfo(id);
    if (!fileInfo) {
      return res.status(404).json({ error: 'File not found' });
    }

    let metadata = await loadMetadata(id);
    if (!metadata && resolvedId !== String(id)) {
      metadata = await loadMetadata(resolvedId);
    }

    const enrichedMetadata = await ensurePlaybackMetadata(resolvedId, fileInfo, metadata);
    const outputAudioTracks = (Array.isArray(enrichedMetadata.audioTracks) ? enrichedMetadata.audioTracks : [])
      .map((track, idx) => {
        const codec = String(track?.codec || track?.codecName || 'unknown').toLowerCase();
        return {
          ...track,
          index: Number.isInteger(track?.index) ? track.index : idx,
          codec,
          browserPlayable: typeof track?.browserPlayable === 'boolean'
            ? track.browserPlayable
            : BROWSER_AUDIO_CODECS.includes(codec),
        };
      });
    const outputSubtitleTracks = (Array.isArray(enrichedMetadata.subtitleTracks) ? enrichedMetadata.subtitleTracks : [])
      .map((track, idx) => {
        const streamIndex = Number(track?.streamIndex);
        const fallbackIndex = Number(track?.index ?? idx);
        return {
          ...track,
          index: Number.isInteger(fallbackIndex) ? fallbackIndex : idx,
          streamIndex: Number.isInteger(streamIndex)
            ? streamIndex
            : (Number.isInteger(fallbackIndex) ? fallbackIndex : idx),
          codec: String(track?.codec || track?.codecName || 'unknown').toLowerCase(),
        };
      });
    const hasUnsupportedAudio = outputAudioTracks.some((track) => !track.browserPlayable);
    const duration = Number.isFinite(Number(enrichedMetadata.duration))
      ? Number(enrichedMetadata.duration)
      : 0;

    res.json({
      fileId: id,
      audioCodec: enrichedMetadata.audioCodec || 'unknown',
      browserPlayable: enrichedMetadata.browserPlayable !== false,
      audioTracks: outputAudioTracks,
      subtitleTracks: outputSubtitleTracks,
      hasUnsupportedAudio,
      duration,
      ready: true,
    });
  } catch (error) {
    console.error(`❌ Track detection error for ${id}:`, error.message);
    res.status(500).json({ error: 'Track detection failed' });
  }
};

exports.getSubtitle = async (req, res) => {
  const { id, streamIndex } = req.params;

  try {
    const parsedStreamIndex = parseInt(streamIndex, 10);
    if (!Number.isInteger(parsedStreamIndex) || parsedStreamIndex < 0) {
      return res.status(400).json({ error: 'Invalid subtitle stream index' });
    }

    const cacheKey = `${String(id)}_${parsedStreamIndex}`;
    const startOffset = req.query.start ? parseFloat(req.query.start) : 0;

    if (startOffset === 0) {
      const cachedVtt = subtitleCache.get(cacheKey);
      if (cachedVtt && cachedVtt.includes('WEBVTT')) {
        res.setHeader('Content-Type', 'text/vtt; charset=utf-8');
        res.setHeader('Cache-Control', 'public, max-age=86400');
        return res.send(cachedVtt);
      }
    }

    const { fileInfo, resolvedId } = await resolveFileInfo(id);
    if (!fileInfo) {
      return res.status(404).json({ error: 'File not found' });
    }

    const internalPort = req.app.get('internalPort') || 3000;
    const inputUrl = `http://127.0.0.1:${internalPort}/internal/raw/${resolvedId}`;

    // Disable Node.js idle timeout. FFmpeg seeking over HTTP can take several minutes 
    // for large MKV files over Telegram, triggering ECONNRESET if not disabled.
    req.setTimeout(0);
    res.setTimeout(0);

    const ffmpegArgs = [];
    if (startOffset > 0) {
      ffmpegArgs.push('-ss', startOffset.toString(), '-copyts');
    }

    ffmpegArgs.push(
      '-i', inputUrl,
      '-map', `0:${parsedStreamIndex}`,
      '-c:s', 'webvtt',
      '-f', 'webvtt',
      '-nostdin',
      '-hide_banner',
      '-loglevel', 'error',
      'pipe:1'
    );

    const ffmpeg = spawn('ffmpeg', ffmpegArgs, {
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    res.setHeader('Content-Type', 'text/vtt; charset=utf-8');
    res.setHeader('Cache-Control', 'public, max-age=86400');

    let stderrData = '';
    let clientDisconnected = false;
    let vttBuffer = '';

    ffmpeg.stdout.on('data', (chunk) => {
      if (!clientDisconnected) {
        res.write(chunk);
      }
      vttBuffer += chunk.toString('utf-8');
    });

    ffmpeg.stderr.on('data', (data) => { stderrData += data.toString(); });

    req.on('close', () => {
      clientDisconnected = true;
      try { ffmpeg.kill('SIGKILL'); } catch { }
    });

    ffmpeg.on('close', (code) => {
      if (!clientDisconnected) {
        res.end();
      }

      const isValidOutput = code === 0 && vttBuffer && vttBuffer.includes('WEBVTT');

      if (isValidOutput) {
        if (subtitleCache.has(cacheKey)) subtitleCache.delete(cacheKey);
        subtitleCache.set(cacheKey, vttBuffer);
        while (subtitleCache.size > SUBTITLE_CACHE_MAX_ENTRIES) {
          const oldestKey = subtitleCache.keys().next().value;
          subtitleCache.delete(oldestKey);
        }
      }

      if (code !== 0 && !clientDisconnected) {
        console.error(`[Subtitle] FFmpeg failed for ${resolvedId} track ${parsedStreamIndex}: code ${code}, stderr: ${stderrData}`);
      }
    });

    ffmpeg.on('error', (error) => {
      console.error('[Subtitle] FFmpeg spawn error:', error.message);
      if (!clientDisconnected && !res.headersSent) {
        res.status(500).json({ error: 'FFmpeg spawn failed' });
      } else if (!clientDisconnected) {
        res.end();
      }
    });
  } catch (error) {
    console.error('[Subtitle] Error:', error);
    if (!res.headersSent && !res.writableEnded) {
      res.status(500).json({ error: 'Subtitle extraction error' });
    }
  }
};

// ==================== STREAMING ====================

// GET /api/stream/:id
exports.stream = async (req, res) => {
  const { id } = req.params;

  try {
    const hasAudioTrackParam = Object.prototype.hasOwnProperty.call(req.query, 'audioTrack');
    const parsedStart = parseFloat(req.query.start);
    const startTime = Number.isFinite(parsedStart) && parsedStart > 0 ? parsedStart : 0;
    const parsedAudioTrack = parseInt(req.query.audioTrack, 10);
    const requestedAudioTrack = Number.isInteger(parsedAudioTrack) && parsedAudioTrack >= 0
      ? parsedAudioTrack
      : NaN;

    if (hasAudioTrackParam && Number.isNaN(requestedAudioTrack)) {
      return res.status(400).json({ error: 'Invalid audioTrack parameter' });
    }

    const { fileInfo, resolvedId } = await resolveFileInfo(id);
    if (!fileInfo) {
      console.error(`[Stream] ❌ File ${id} not found in any source`);
      return res.status(404).json({ error: 'File not found' });
    }

    let metadata = await loadMetadata(id);
    if (!metadata && resolvedId !== String(id)) {
      metadata = await loadMetadata(resolvedId);
    }

    const playbackMetadata = await ensurePlaybackMetadata(resolvedId, fileInfo, metadata);
    const fileSize = Number(fileInfo.fileSize);
    if (!Number.isFinite(fileSize) || fileSize <= 0) {
      return res.status(404).json({ error: 'File not found' });
    }

    const range = req.headers.range;
    let start = 0;
    let end = fileSize - 1;

    if (range) {
      const match = range.match(/bytes=(\d+)-(\d*)/);
      if (match) {
        start = parseInt(match[1], 10);
        end = match[2] ? parseInt(match[2], 10) : fileSize - 1;
      }
      if (start < 0) start = 0;
      if (end >= fileSize) end = fileSize - 1;
      if (start > end) {
        return res.status(416).set('Content-Range', `bytes */${fileSize}`).end();
      }
    }

    if (hasAudioTrackParam) {
      if (!HAS_FFMPEG) {
        return res.status(503).json({ error: 'FFmpeg not available for remux stream' });
      }

      const selected = getAudioTrackAt(playbackMetadata, requestedAudioTrack);
      await streamWithRemux(req, res, resolvedId, {
        startTime,
        audioTrack: selected.index,
        transcodeAudio: !selected.track?.browserPlayable
      });
      return;
    }

    await streamDirect(fileInfo, fileSize, start, end, range, res);
  } catch (error) {
    console.error(`❌ Stream error for ${id}:`, error.message);
    if (!res.headersSent) {
      res.status(500).json({ error: `Stream failed: ${error.message}` });
    } else {
      try { res.end(); } catch { }
    }
  }
};

exports.transmuxStream = exports.stream;
exports.seek = exports.stream;

// ==================== DIRECT STREAM â€” full seek support ====================
async function streamDirect(fileInfo, fileSize, start, end, range, res) {
  const telegramClient = telegramService.getClient();
  if (!telegramClient) throw new Error('Telegram client not ready');

  const contentLength = end - start + 1;
  const contentType = getContentType(fileInfo.fileName || '');

  if (range) {
    res.writeHead(206, {
      'Content-Range': `bytes ${start}-${end}/${fileSize}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': contentLength,
      'Content-Type': contentType,
      'Cache-Control': 'no-cache',
    });
  } else {
    res.writeHead(200, {
      'Accept-Ranges': 'bytes',
      'Content-Length': fileSize,
      'Content-Type': contentType,
      'Cache-Control': 'no-cache',
    });
  }

  let clientDisconnected = false;
  res.on('close', () => { clientDisconnected = true; });

  let currentPosition = start;
  let bytesRemaining = contentLength;

  while (bytesRemaining > 0 && !clientDisconnected) {
    try {
      const aligned = alignOffset(currentPosition);
      const skipBytes = currentPosition - aligned;
      const limit = getAlignedLimit(aligned);

      let data = await getTelegramChunk(telegramClient, fileInfo, aligned, limit);

      if (clientDisconnected) break;
      if (!data) break;

      if (skipBytes > 0) {
        data = data.slice(skipBytes);
      }
      if (data.length > bytesRemaining) {
        data = data.slice(0, bytesRemaining);
      }
      if (data.length === 0) break;

      const ok = res.write(data);
      currentPosition += data.length;
      bytesRemaining -= data.length;

      if (!ok && !clientDisconnected) {
        await new Promise((resolve) => res.once('drain', resolve));
      }
    } catch (error) {
      if (clientDisconnected) break;

      console.error(`❌ Stream error at position ${currentPosition}:`, error.message);

      await new Promise((r) => setTimeout(r, 1500));
      if (clientDisconnected) break;

      try {
        const retryAligned = alignOffset(currentPosition);
        const retrySkip = currentPosition - retryAligned;
        const retryLimit = getAlignedLimit(retryAligned);

        let data = await getTelegramChunk(telegramClient, fileInfo, retryAligned, retryLimit);

        if (data && data.length > 0) {
          if (retrySkip > 0) {
            data = data.slice(retrySkip);
          }
          if (data.length > bytesRemaining) {
            data = data.slice(0, bytesRemaining);
          }
          if (data.length > 0) {
            res.write(data);
            currentPosition += data.length;
            bytesRemaining -= data.length;
          }
        } else {
          break;
        }
      } catch (retryError) {
        console.error(`❌ Retry failed at ${currentPosition}:`, retryError.message);
        break;
      }
    }
  }

  if (!clientDisconnected) {
    res.end();
  }
}

// ==================== FFMPEG REMUX STREAM ====================
async function streamWithRemux(req, res, fileId, options = {}) {
  const startTime = Number(options.startTime) > 0 ? Number(options.startTime) : 0;
  const audioTrack = Number.isFinite(Number(options.audioTrack))
    ? Math.max(0, parseInt(options.audioTrack, 10) || 0)
    : 0;

  const transcodeAudio = options.transcodeAudio === true;

  const internalPort = req.app.get('internalPort') || process.env.PORT || 5000;
  const inputUrl = `http://127.0.0.1:${internalPort}/internal/raw/${fileId}`;
  const key = String(fileId);

  killTranscode(key);

  const ffmpegArgs = [
    '-fflags', '+genpts+discardcorrupt',
    ...(startTime > 0 ? ['-ss', String(startTime)] : []),
    '-i', inputUrl,
    '-map', '0:v:0',
    '-map', `0:a:${audioTrack}`,
    '-c:v', 'copy',
    ...(transcodeAudio ? ['-c:a', 'aac', '-b:a', '192k', '-ac', '2'] : ['-c:a', 'copy']),
    '-avoid_negative_ts', 'make_zero',
    '-max_delay', '0',
    '-flush_packets', '1',
    '-f', 'mp4',
    '-movflags', 'frag_keyframe+empty_moov+default_base_moof',
    '-frag_duration', '1000000',
    '-threads', '2',
    '-nostdin',
    '-hide_banner',
    '-loglevel', 'warning',
    'pipe:1'
  ];

  let ffmpeg;
  try {
    ffmpeg = spawn('ffmpeg', ffmpegArgs, { stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (error) {
    console.error(`[FFmpeg] Failed to spawn for ${fileId}:`, error.message);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Failed to start transcoder' });
    } else if (!res.writableEnded) {
      res.end();
    }
    return;
  }

  activeTranscodes.set(key, { process: ffmpeg, res });

  res.setHeader('Content-Type', 'video/mp4');
  res.setHeader('Transfer-Encoding', 'chunked');
  res.setHeader('Cache-Control', 'no-cache, no-store');
  res.setHeader('X-Transcode', 'true');

  return new Promise((resolve) => {
    let settled = false;

    const cleanup = () => {
      if (settled) return;
      settled = true;

      const active = activeTranscodes.get(key);
      if (active?.process === ffmpeg) {
        activeTranscodes.delete(key);
      }

      if (!res.writableEnded && !res.destroyed) {
        try { res.end(); } catch { }
      }

      resolve();
    };

    ffmpeg.stdout.pipe(res);

    ffmpeg.stderr.on('data', (data) => {
      const msg = data.toString().trim();
      if (msg) {
        console.log(`[FFmpeg:${fileId}] ${msg}`);
      }
    });

    ffmpeg.on('exit', (code, signal) => {
      if (code !== 0 && signal !== 'SIGKILL') {
        console.warn(`[FFmpeg:${fileId}] exited with code ${code}, signal ${signal || 'none'}`);
      }
      cleanup();
    });

    ffmpeg.on('error', (error) => {
      console.error(`[FFmpeg:${fileId}] process error:`, error.message);
      cleanup();
    });

    ffmpeg.stdout.on('error', (error) => {
      console.error(`[FFmpeg:${fileId}] stdout error:`, error.message);
      cleanup();
    });

    req.on('close', () => {
      try { ffmpeg.stdout.unpipe(res); } catch { }
      const active = activeTranscodes.get(key);
      if (active?.process === ffmpeg) {
        killTranscode(key);
      }
      cleanup();
    });

    res.on('error', (error) => {
      if (error.code !== 'ERR_STREAM_WRITE_AFTER_END') {
        console.error(`[FFmpeg:${fileId}] response error:`, error.message);
      }
      try { ffmpeg.stdout.unpipe(res); } catch { }
      const active = activeTranscodes.get(key);
      if (active?.process === ffmpeg) {
        killTranscode(key);
      }
      cleanup();
    });
  });
}

function getContentType(filename) {
  const ext = (filename || '').split('.').pop().toLowerCase();
  const map = {
    mp4: 'video/mp4',
    mkv: 'video/x-matroska',
    webm: 'video/webm',
    avi: 'video/x-msvideo',
    mov: 'video/quicktime',
    flv: 'video/x-flv',
    ts: 'video/mp2t',
    m4v: 'video/mp4',
  };
  return map[ext] || 'video/mp4';
}
