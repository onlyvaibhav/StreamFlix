const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'public', 'js', 'app.js');
let content = fs.readFileSync(filePath, 'utf-8');

function replaceBlock(startMarker, endMarker, replacement) {
  const startIdx = content.indexOf(startMarker);
  if (startIdx === -1) {
    console.error('Could not find start marker:\n', startMarker);
    return false;
  }
  const endIdx = content.indexOf(endMarker, startIdx);
  if (endIdx === -1) {
    console.error('Could not find end marker:\n', endMarker);
    return false;
  }
  content = content.substring(0, startIdx) + replacement + content.substring(endIdx + endMarker.length);
  return true;
}

// 1. Fix state.player.multipart definition
const stateStart = '    // ---- Multipart seamless playback state ----';
const stateEnd = '    },';
const stateReplacement = `    // ---- Multipart seamless playback state ----
    multipart: {
      enabled: false,
      parts: [],             // [{fileId, partNumber, duration, estimated}, ...]
      durationMap: [],       // [{part, fileId, start, end}, ...] cumulative
      currentPartIndex: 0,
      totalDuration: 0,
      completedDuration: 0,  // Sum of durations of finished parts
      _switchLog: [],        // Analytics: [{from, to, delay, success, timestamp}]
    },`;
replaceBlock(stateStart, stateEnd, stateReplacement);

// 2. Fix resetPlayerState
const resetStart = '  // Reset multipart state';
const resetEnd = '  };';
const resetReplacement = `  // Reset multipart state
  state.player.multipart = {
    enabled: false,
    parts: [],
    durationMap: [],
    currentPartIndex: 0,
    totalDuration: 0,
    completedDuration: 0,
    _switchLog: [],
  };`;
replaceBlock(resetStart, resetEnd, resetReplacement);

// 3. Fix getEffectiveDuration
const durationStart = 'function getEffectiveDuration(video) {';
const durationEnd = '  return d > 0 ? d : 0;\r\n}';
const durationReplacement = `function getEffectiveDuration(video) {
  // Multipart: return total combined duration of all parts
  if (state.player.multipart.enabled && state.player.multipart.totalDuration > 0) {
    return state.player.multipart.totalDuration;
  }
  if (state.player.isRemuxing) {
    const d = Number(state.player.duration || video.duration || 0);
    return d > 0 ? d : 0;
  }
  const d = Number(video.duration || 0);
  return d > 0 ? d : 0;
}`;
if(!replaceBlock(durationStart, durationEnd, durationReplacement)) {
  replaceBlock(durationStart, '  return d > 0 ? d : 0;\n}', durationReplacement);
}

// 4. Fix getEffectiveCurrentTime
const timeStart = 'function getEffectiveCurrentTime(video) {';
const timeEnd = '  return elapsed;\r\n}';
const timeReplacement = `function getEffectiveCurrentTime(video) {
  const elapsed = isFinite(video.currentTime) ? video.currentTime : 0;
  // Multipart: add completed parts duration
  if (state.player.multipart.enabled) {
    return state.player.multipart.completedDuration + elapsed +
      (state.player.isRemuxing ? Number(state.player._seekOffset || 0) : 0);
  }
  if (state.player.isRemuxing) {
    return elapsed + Number(state.player._seekOffset || 0);
  }
  return elapsed;
}`;
if(!replaceBlock(timeStart, timeEnd, timeReplacement)) {
    replaceBlock(timeStart, '  return elapsed;\n}', timeReplacement);
}

// 5. Replace MULTIPART SEAMLESS PLAYBACK ENGINE entirely
const engineStart = '// ============================================================\r\n// MULTIPART SEAMLESS PLAYBACK ENGINE';
const engineEnd = '  console.log(`[Multipart] Initialized basic sequential playback: ${mp.parts.length} parts`);\r\n  return true;\r\n}';
const engineReplacement = `// ============================================================
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
  // If beyond all parts, return last part at end
  const last = map[map.length - 1];
  return { index: map.length - 1, part: last, offsetInPart: last.end - last.start };
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

  console.log(\`[Multipart] Correcting part \${partIndex + 1} duration: \${oldDuration.toFixed(1)}s → \${actualDuration.toFixed(1)}s\`);

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

  // Recalculate completedDuration
  mp.completedDuration = 0;
  for (let i = 0; i < mp.currentPartIndex; i++) {
    mp.completedDuration += mp.parts[i].duration;
  }
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

  // Update completed duration using actual video duration if available
  const actualPartDuration = isFinite(video.duration) && video.duration > 0
    ? video.duration : multipartCurrentPartDuration(video);
  mp.completedDuration += actualPartDuration;

  // Correct duration map with actual duration
  multipartCorrectDuration(mp.currentPartIndex, actualPartDuration);

  mp.currentPartIndex = nextIndex;
  const nextPart = mp.parts[nextIndex];

  console.log(\`[Multipart] Switching to part \${nextPart.partNumber}/\${mp.parts.length} (fileId: \${nextPart.fileId})\`);
  buffering?.classList.remove('hidden');

  try {
    video.src = \`/api/stream/\${nextPart.fileId}\`;
    state.player.fileId = nextPart.fileId;
    state.player.isRemuxing = false;
    state.player._seekOffset = 0;

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
        // Correct duration with actual value
        if (isFinite(video.duration) && video.duration > 0) {
          multipartCorrectDuration(nextIndex, video.duration);
        }
        resolve();
      }, { once: true });
      video.addEventListener('error', () => {
        clearTimeout(timeout);
        reject(new Error(\`Failed to load part \${nextPart.partNumber}\`));
      }, { once: true });
    });

    await video.play();
    buffering?.classList.add('hidden');

    // Update heartbeat to new fileId
    startHeartbeat(nextPart.fileId);

    // Restore subtitle track
    if (preservedState.subtitleTrackIndex >= 0) {
      const sub = state.player.subtitleTracks[preservedState.subtitleTrackIndex];
      if (sub && sub.source !== 'embedded') {
        // External subs are per-movie, keep them
      } else if (sub && sub.source === 'embedded') {
        state.player.subtitleTracks[preservedState.subtitleTrackIndex].endpoint =
          \`/api/stream/\${nextPart.fileId}/subtitle/\${sub.streamIndex}\`;
        switchSubs(preservedState.subtitleTrackIndex, null, 0).catch(() => {});
      }
    }

    const switchDelay = performance.now() - switchStart;
    console.log(\`[Multipart] Part switch completed in \${switchDelay.toFixed(0)}ms\`);

    mp._switchLog.push({
      from: nextIndex - 1,
      to: nextIndex,
      delay: Math.round(switchDelay),
      success: true,
      timestamp: Date.now(),
    });

    return true;
  } catch (error) {
    console.error(\`[Multipart] Part switch failed:\`, error.message);
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
function multipartSeek(virtualTime) {
  const mp = state.player.multipart;
  if (!mp.enabled) return;

  const video = document.getElementById('video-player');
  const buffering = document.getElementById('buffering-spinner');
  const totalDuration = mp.totalDuration;

  // Clamp to valid range
  const clamped = Math.max(0, Math.min(virtualTime, totalDuration));

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
    console.log(\`[Multipart] Boundary snap: jumping to part \${finalIndex + 1}\`);
  }

  // Recalculate completedDuration for the target part
  let newCompleted = 0;
  for (let i = 0; i < finalIndex; i++) {
    newCompleted += mp.parts[i].duration;
  }
  mp.completedDuration = newCompleted;

  if (finalIndex === mp.currentPartIndex) {
    // Same part — just seek within it
    if (state.player.isRemuxing) {
      remuxSeek(finalOffset);
    } else {
      video.currentTime = finalOffset;
    }
    return;
  }

  // Different part — switch source
  mp.currentPartIndex = finalIndex;
  const targetPart = mp.parts[finalIndex];
  state.player.fileId = targetPart.fileId;

  console.log(\`[Multipart] Cross-part seek to part \${targetPart.partNumber} at \${finalOffset.toFixed(1)}s\`);
  buffering?.classList.remove('hidden');

  state.player.isRemuxing = false;
  state.player._seekOffset = 0;

  // Pause gracefully to avoid 'play request interrupted' error
  const wasPlaying = !video.paused;
  if (wasPlaying) video.pause();

  video.src = \`/api/stream/\${targetPart.fileId}\`;
  video.load();

  video.addEventListener('loadedmetadata', function onMeta() {
    if (isFinite(video.duration) && video.duration > 0) {
      multipartCorrectDuration(finalIndex, video.duration);
    }
    if (finalOffset > 0 && finalOffset < video.duration) {
      video.currentTime = finalOffset;
    }
    if (wasPlaying) video.play().catch(() => {});
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
    const partInfo = await api(\`/api/stream/\${fileId}/part-info\`);
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

    console.log(\`[Multipart] Initialized: \${mp.parts.length} parts, total \${mp.totalDuration.toFixed(0)}s\`);
    console.log('[Multipart] Duration map:', mp.durationMap.map(d =>
      \`Part \${d.part}: \${d.start.toFixed(0)}s-\${d.end.toFixed(0)}s\${d.estimated ? ' (est)' : ''}\`
    ).join(', '));

    return true;
  } catch (error) {
    console.warn('[Multipart] Init failed:', error.message);
    mp.enabled = false;
    return false;
  }
}`;

if (!replaceBlock(engineStart, engineEnd, engineReplacement)) {
  const engineStartLF = '// ============================================================\n// MULTIPART SEAMLESS PLAYBACK ENGINE';
  const engineEndLF = '  console.log(`[Multipart] Initialized basic sequential playback: ${mp.parts.length} parts`);\n  return true;\n}';
  replaceBlock(engineStartLF, engineEndLF, engineReplacement);
}

// 6. Fix playVideo - Add loadedmetadata correction handler
const playVideoTracksEndMarker = '  video.currentTime = 0;\r\n  video.load();\r\n';
const loadedMetaHandler = `  video.currentTime = 0;\r\n  video.load();\r\n\r\n  // Correct multipart duration map when first part's actual duration is discovered\r\n  if (state.player.multipart.enabled) {\r\n    video.addEventListener('loadedmetadata', function onFirstPartMeta() {\r\n      if (isFinite(video.duration) && video.duration > 0) {\r\n        multipartCorrectDuration(0, video.duration);\r\n      }\r\n    }, { once: true });\r\n  }\r\n`;

content = content.replace('  video.currentTime = 0;\r\n  video.load();\r\n', loadedMetaHandler);
content = content.replace('  video.currentTime = 0;\n  video.load();\n', loadedMetaHandler.replace(/\r\n/g, '\n'));

// 7. Fix seek bar onUp
const onUpMarker = `    if (state.player.isRemuxing) {
      const duration = state.player.duration || video.duration;`;

const onUpReplacement = `    // ---- MULTIPART: Seek to virtual position across parts ----
    if (state.player.multipart.enabled) {
      const totalDuration = state.player.multipart.totalDuration;
      if (totalDuration > 0) {
        multipartSeek(seekState.dragPct * totalDuration);
      }
      return;
    }

    if (state.player.isRemuxing) {
      const duration = state.player.duration || video.duration;`;

content = content.replace(onUpMarker, onUpReplacement);
// if using \r\n
content = content.replace(`    if (state.player.isRemuxing) {\r\n      const duration = state.player.duration || video.duration;`, onUpReplacement.replace(/\n/g, '\r\n'));


// 8. Fix seekRelative
const seekRelativeMarker = `    if (state.player.isRemuxing) {
      remuxSeek(finalTarget);
    } else {`;
const seekRelativeReplacement = `    // Multipart: use virtual seeking
    if (state.player.multipart.enabled) {
      multipartSeek(finalTarget);
    } else if (state.player.isRemuxing) {
      remuxSeek(finalTarget);
    } else {`;

content = content.replace(seekRelativeMarker, seekRelativeReplacement);
content = content.replace(`    if (state.player.isRemuxing) {\r\n      remuxSeek(finalTarget);\r\n    } else {`, seekRelativeReplacement.replace(/\n/g, '\r\n'));

fs.writeFileSync(filePath, content, 'utf-8');
console.log('✅ implement_combined_timeline.js executed successfully!');
