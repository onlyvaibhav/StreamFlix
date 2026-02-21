const { spawn, execFile } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

const TEMP_DIR = path.join(os.tmpdir(), 'cinestream');

// Create temp directory
if (!fs.existsSync(TEMP_DIR)) {
    fs.mkdirSync(TEMP_DIR, { recursive: true });
}

// Browser-compatible audio codecs
const COMPATIBLE_AUDIO_CODECS = [
    'aac', 'mp3', 'opus', 'vorbis', 'flac',
    'mp4a', 'mp4a.40.2', 'mp4a.40.5',
];

// Browser-compatible video codecs
const COMPATIBLE_VIDEO_CODECS = [
    'h264', 'h.264', 'avc', 'avc1',
    'vp8', 'vp9', 'av1',
    'hevc', 'h265', 'h.265', // partial support
];

// ==================== FFPROBE ====================

/**
 * Probe a file/buffer to get stream info
 * Can work with a file path or piped buffer
 */
function probeFile(filePath) {
    return new Promise((resolve, reject) => {
        const args = [
            '-v', 'quiet',
            '-print_format', 'json',
            '-show_format',
            '-show_streams',
            filePath,
        ];

        execFile('ffprobe', args, { timeout: 30000 }, (error, stdout, stderr) => {
            if (error) {
                reject(new Error(`ffprobe failed: ${error.message}`));
                return;
            }

            try {
                const info = JSON.parse(stdout);
                resolve(parseProbeInfo(info));
            } catch (e) {
                reject(new Error(`Failed to parse ffprobe output: ${e.message}`));
            }
        });
    });
}

/**
 * Probe from a buffer by writing to temp file
 */
async function probeBuffer(buffer) {
    const tempFile = path.join(TEMP_DIR, `probe_${Date.now()}.mkv`);

    try {
        fs.writeFileSync(tempFile, buffer);
        const result = await probeFile(tempFile);
        return result;
    } finally {
        try { fs.unlinkSync(tempFile); } catch (e) { }
    }
}

/**
 * Probe from stdin pipe
 */
function probeFromPipe(buffer) {
    return new Promise((resolve, reject) => {
        const args = [
            '-v', 'quiet',
            '-print_format', 'json',
            '-show_format',
            '-show_streams',
            '-i', 'pipe:0',
        ];

        const proc = spawn('ffprobe', args, {
            timeout: 30000,
        });

        let stdout = '';
        let stderr = '';

        proc.stdout.on('data', (data) => { stdout += data.toString(); });
        proc.stderr.on('data', (data) => { stderr += data.toString(); });

        // Handle EPIPE/EOF - ffprobe may close stdin before we finish writing
        proc.stdin.on('error', (err) => {
            if (err.code === 'EPIPE' || err.code === 'EOF' || err.errno === -4095) {
                // Expected: ffprobe got enough data and closed the pipe
                return;
            }
            console.error('   ⚠️ ffprobe stdin error:', err.message);
        });

        proc.on('close', (code) => {
            try {
                const info = JSON.parse(stdout);
                resolve(parseProbeInfo(info));
            } catch (e) {
                // If pipe probe fails, try temp file method
                probeBuffer(buffer).then(resolve).catch(reject);
            }
        });

        proc.on('error', (error) => {
            probeBuffer(buffer).then(resolve).catch(reject);
        });

        // Write buffer to ffprobe, catching any pipe errors
        try {
            proc.stdin.write(buffer);
            proc.stdin.end();
        } catch (err) {
            // EPIPE can also throw synchronously
            console.log('   ⚠️ ffprobe pipe write error (falling back to temp file)');
        }
    });
}

function parseProbeInfo(info) {
    const streams = info.streams || [];
    const format = info.format || {};

    const videoStreams = [];
    const audioStreams = [];
    const subtitleStreams = [];

    for (const stream of streams) {
        const streamInfo = {
            index: stream.index,
            codecName: stream.codec_name || '',
            codecLongName: stream.codec_long_name || '',
            codecType: stream.codec_type || '',
            profile: stream.profile || '',
            language: stream.tags?.language || stream.tags?.LANGUAGE || 'und',
            title: stream.tags?.title || stream.tags?.TITLE || '',
            isDefault: stream.disposition?.default === 1,
            isForced: stream.disposition?.forced === 1,
        };

        switch (stream.codec_type) {
            case 'video':
                videoStreams.push({
                    ...streamInfo,
                    width: stream.width || 0,
                    height: stream.height || 0,
                    fps: eval(stream.r_frame_rate) || 0,
                    bitRate: parseInt(stream.bit_rate) || 0,
                    pixelFormat: stream.pix_fmt || '',
                });
                break;

            case 'audio':
                audioStreams.push({
                    ...streamInfo,
                    sampleRate: parseInt(stream.sample_rate) || 0,
                    channels: stream.channels || 0,
                    channelLayout: stream.channel_layout || '',
                    bitRate: parseInt(stream.bit_rate) || 0,
                    bitsPerSample: stream.bits_per_raw_sample || 0,
                });
                break;

            case 'subtitle':
                subtitleStreams.push({
                    ...streamInfo,
                    subtitleType: getSubtitleType(stream.codec_name),
                });
                break;
        }
    }

    // Check compatibility
    const audioCompatible = audioStreams.length === 0 || audioStreams.some(
        (a) => COMPATIBLE_AUDIO_CODECS.includes(a.codecName.toLowerCase())
    );

    const videoCompatible = videoStreams.length === 0 || videoStreams.some(
        (v) => COMPATIBLE_VIDEO_CODECS.includes(v.codecName.toLowerCase())
    );

    return {
        format: {
            name: format.format_name || '',
            duration: parseFloat(format.duration) || 0,
            size: parseInt(format.size) || 0,
            bitRate: parseInt(format.bit_rate) || 0,
        },
        video: videoStreams,
        audio: audioStreams,
        subtitles: subtitleStreams,
        audioCompatible,
        videoCompatible,
        needsTranscoding: !audioCompatible,
    };
}

function getSubtitleType(codecName) {
    const textTypes = [
        'subrip', 'srt', 'ass', 'ssa', 'webvtt', 'mov_text',
        'text', 'subtitle',
    ];
    const bitmapTypes = ['hdmv_pgs_subtitle', 'dvd_subtitle', 'dvb_subtitle'];

    const lower = codecName.toLowerCase();
    if (textTypes.some((t) => lower.includes(t))) return 'text';
    if (bitmapTypes.some((t) => lower.includes(t))) return 'bitmap';
    return 'unknown';
}

// ==================== SUBTITLE EXTRACTION ====================

/**
 * Extract a subtitle track from a video file using ffmpeg
 * Much more reliable than binary parsing
 */
function extractSubtitle(inputPath, streamIndex, outputFormat = 'webvtt') {
    return new Promise((resolve, reject) => {
        const args = [
            '-v', 'warning',
            '-i', inputPath,
            '-map', `0:${streamIndex}`,
            '-f', outputFormat,
            '-'  // output to stdout
        ];

        const proc = spawn('ffmpeg', args, { timeout: 120000 });

        let stdout = Buffer.alloc(0);
        let stderr = '';

        proc.stdout.on('data', (data) => {
            stdout = Buffer.concat([stdout, data]);
        });

        proc.stderr.on('data', (data) => {
            stderr += data.toString();
        });

        proc.on('close', (code) => {
            if (code !== 0) {
                console.error(`   ❌ ffmpeg stderr: ${stderr.substring(0, 500)}`);
                reject(new Error(`ffmpeg subtitle extraction failed (code ${code}): ${stderr.substring(0, 500)}`));
                return;
            }

            const content = stdout.toString('utf-8');
            if (!content || content.trim().length === 0) {
                reject(new Error('Empty subtitle output'));
                return;
            }

            resolve(content);
        });

        proc.on('error', (error) => {
            reject(new Error(`ffmpeg not found or failed: ${error.message}`));
        });
    });
}

/**
 * Extract subtitle from a buffer (writes temp file, extracts, cleans up)
 */
async function extractSubtitleFromBuffer(buffer, streamIndex) {
    const tempFile = path.join(TEMP_DIR, `sub_extract_${Date.now()}.mkv`);

    try {
        console.log(`   📝 Writing ${(buffer.length / 1024 / 1024).toFixed(1)}MB to temp file...`);
        fs.writeFileSync(tempFile, buffer);

        console.log(`   🎬 Running ffmpeg to extract stream #${streamIndex}...`);
        const vttContent = await extractSubtitle(tempFile, streamIndex, 'webvtt');

        console.log(`   ✅ Extracted ${vttContent.length} chars of VTT content`);
        return vttContent;
    } finally {
        try {
            fs.unlinkSync(tempFile);
            console.log('   🗑️ Temp file cleaned up');
        } catch (e) { }
    }
}

/**
 * Extract subtitle by streaming data into ffmpeg via pipe.
 * Returns { stdin, promise } - caller writes chunks to stdin, then calls stdin.end().
 * Promise resolves with VTT content when ffmpeg finishes processing.
 * This avoids buffering the entire file in memory.
 */
function extractSubtitleFromStream(streamIndex, outputFormat = 'webvtt') {
    const args = [
        '-v', 'warning',
        '-i', 'pipe:0',
        '-map', `0:${streamIndex}`,
        '-f', outputFormat,
        '-'  // output to stdout
    ];

    const proc = spawn('ffmpeg', args);

    let stdout = Buffer.alloc(0);
    let stderr = '';

    proc.stdout.on('data', (data) => {
        stdout = Buffer.concat([stdout, data]);
    });

    proc.stderr.on('data', (data) => {
        stderr += data.toString();
    });

    // Handle EPIPE - ffmpeg may close stdin when it has enough subtitle data
    proc.stdin.on('error', (err) => {
        if (err.code === 'EPIPE' || err.code === 'EOF' || err.errno === -4095) {
            return; // Expected
        }
        console.error('   ⚠️ ffmpeg stdin error:', err.message);
    });

    const promise = new Promise((resolve, reject) => {
        proc.on('close', (code) => {
            if (code !== 0 && stdout.length === 0) {
                console.error(`   ❌ ffmpeg stderr: ${stderr.substring(0, 500)}`);
                reject(new Error(`ffmpeg subtitle extraction failed (code ${code}): ${stderr.substring(0, 500)}`));
                return;
            }

            const content = stdout.toString('utf-8');
            if (!content || content.trim().length === 0) {
                reject(new Error('Empty subtitle output'));
                return;
            }

            resolve(content);
        });

        proc.on('error', (error) => {
            reject(new Error(`ffmpeg not found or failed: ${error.message}`));
        });
    });

    return { stdin: proc.stdin, promise, process: proc };
}

// ==================== AUDIO TRANSCODING ====================

/**
 * Transcode a file: copy video, convert audio to AAC
 * Returns path to transcoded file
 */
function transcodeToCompatible(inputPath, outputPath) {
    return new Promise((resolve, reject) => {
        const args = [
            '-v', 'warning',
            '-i', inputPath,
            '-c:v', 'copy',           // Don't re-encode video
            '-c:a', 'aac',            // Transcode audio to AAC
            '-b:a', '192k',           // Audio bitrate
            '-ac', '2',               // Stereo (better compatibility)
            '-c:s', 'mov_text',       // Convert subtitles to mov_text for MP4
            '-movflags', '+faststart', // Enable streaming
            '-y',                      // Overwrite output
            outputPath,
        ];

        console.log(`   🎬 Transcoding: ${path.basename(inputPath)} → ${path.basename(outputPath)}`);

        const proc = spawn('ffmpeg', args);

        let stderr = '';
        let lastProgress = 0;

        proc.stderr.on('data', (data) => {
            const str = data.toString();
            stderr += str;

            // Parse progress
            const timeMatch = str.match(/time=(\d{2}):(\d{2}):(\d{2})/);
            if (timeMatch) {
                const seconds = parseInt(timeMatch[1]) * 3600 +
                    parseInt(timeMatch[2]) * 60 +
                    parseInt(timeMatch[3]);
                if (seconds - lastProgress >= 30) {
                    console.log(`   ⏱️ Transcoding progress: ${timeMatch[0]}`);
                    lastProgress = seconds;
                }
            }
        });

        proc.on('close', (code) => {
            if (code !== 0) {
                reject(new Error(`Transcode failed (code ${code}): ${stderr.substring(0, 300)}`));
                return;
            }

            if (!fs.existsSync(outputPath)) {
                reject(new Error('Transcode output file not created'));
                return;
            }

            const stats = fs.statSync(outputPath);
            console.log(`   ✅ Transcoded: ${(stats.size / 1024 / 1024).toFixed(1)}MB`);
            resolve(outputPath);
        });

        proc.on('error', (error) => {
            reject(new Error(`ffmpeg not found: ${error.message}`));
        });
    });
}

/**
 * Transcode from buffer, return path to transcoded MP4
 */
async function transcodeBuffer(buffer, movieId) {
    const inputPath = path.join(TEMP_DIR, `input_${movieId}_${Date.now()}.mkv`);
    const outputPath = path.join(TEMP_DIR, `transcoded_${movieId}.mp4`);

    // Check if already transcoded
    if (fs.existsSync(outputPath)) {
        const stats = fs.statSync(outputPath);
        if (stats.size > 0) {
            console.log(`   📦 Using cached transcode: ${outputPath}`);
            return outputPath;
        }
    }

    try {
        fs.writeFileSync(inputPath, buffer);
        await transcodeToCompatible(inputPath, outputPath);
        return outputPath;
    } finally {
        try { fs.unlinkSync(inputPath); } catch (e) { }
    }
}

// ==================== STREAMING TRANSCODE ====================

/**
 * Create a readable stream that pipes through ffmpeg
 * Input: readable stream from Telegram
 * Output: MP4 stream with AAC audio
 */
function createTranscodeStream(inputStream, startTime = 0, options = {}) {
    // options: { copyVideo: boolean, copyAudio: boolean, audioBitrate: '128k', audioStreamIndex: number }
    const copyVideo = options.copyVideo === true;
    const copyAudio = options.copyAudio === true;
    const audioBitrate = options.audioBitrate || '128k';
    const audioStreamIndex = options.audioStreamIndex;

    // Use optional audio map so ffmpeg tolerates missing audio streams.
    const audioMap = (audioStreamIndex !== undefined && audioStreamIndex !== null)
        ? `0:${audioStreamIndex}`
        : '0:a:0?';

    const args = [
        '-hide_banner',
        '-loglevel', 'warning',
        ...(startTime > 0 ? ['-ss', String(startTime)] : []), // Seek before input
        '-i', 'pipe:0',             // Read from stdin
        '-map', '0:v:0',            // Select first video stream
        '-map', audioMap,           // Select specific or first audio (optional)
        '-c:v', copyVideo ? 'copy' : 'libx264',
        '-c:a', copyAudio ? 'copy' : 'aac',
        ...(copyAudio ? [] : ['-b:a', audioBitrate, '-ac', '2', '-ar', '48000']),
        '-movflags', 'frag_keyframe+empty_moov+faststart+default_base_moof',
        '-f', 'mp4',                // Output MP4
        'pipe:1',                   // Write to stdout
    ];

    const ffmpegProcess = spawn('ffmpeg', args);

    // Pipe input to ffmpeg stdin
    inputStream.pipe(ffmpegProcess.stdin);

    ffmpegProcess.stderr.on('data', (data) => {
        if (process.env.DEBUG_FFMPEG) {
            console.log('ffmpeg:', data.toString());
        }
    });

    // Return both the output stream and the process so callers can manage lifecycle
    return { stream: ffmpegProcess.stdout, process: ffmpegProcess };
}

// ==================== UTILITIES ====================

function checkFFmpeg() {
    return new Promise((resolve) => {
        execFile('ffmpeg', ['-version'], (error) => {
            resolve(!error);
        });
    });
}

function checkFFprobe() {
    return new Promise((resolve) => {
        execFile('ffprobe', ['-version'], (error) => {
            resolve(!error);
        });
    });
}

function getTempDir() {
    return TEMP_DIR;
}

function cleanupTempFiles(maxAgeMs = 24 * 60 * 60 * 1000) {
    try {
        const files = fs.readdirSync(TEMP_DIR);
        const now = Date.now();
        let cleaned = 0;

        for (const file of files) {
            // Don't clean transcoded files (they're cached)
            if (file.startsWith('transcoded_')) continue;

            const filePath = path.join(TEMP_DIR, file);
            const stats = fs.statSync(filePath);

            if (now - stats.mtimeMs > maxAgeMs) {
                fs.unlinkSync(filePath);
                cleaned++;
            }
        }

        if (cleaned > 0) console.log(`🗑️ Cleaned ${cleaned} temp files`);
    } catch (e) { }
}

// ==================== URL-BASED OPERATIONS (NO FULL DOWNLOAD) ====================

/**
 * Extract a subtitle track using HTTP URL input.
 * ffmpeg will use HTTP range requests to read only what it needs.
 */
function extractSubtitleFromUrl(streamUrl, streamIndex, outputFormat = 'webvtt') {
    return new Promise((resolve, reject) => {
        // Reduce ffmpeg probing to avoid it reading large ranges from our HTTP stream.
        // -probesize and -analyzeduration limit how much ffmpeg inspects before deciding streams.
        // -rw_timeout sets IO timeout (microseconds) to avoid hanging.
        const args = [
            '-v', 'warning',
            '-probesize', '500000',           // 500 KB probe
            '-analyzeduration', '500000',     // 0.5s analyze
            '-rw_timeout', '2000000',         // 2s read/write timeout (in microseconds)
            '-headers', 'X-Internal-Request: ffmpeg\r\n',
            '-i', streamUrl,
            '-map', `0:${streamIndex}`,
            '-f', outputFormat,
            '-'  // output to stdout
        ];

        console.log(`   🌐 ffmpeg reading from: ${streamUrl}`);
        const proc = spawn('ffmpeg', args, { timeout: 120000 });

        let stdout = Buffer.alloc(0);
        let stderr = '';

        proc.stdout.on('data', (data) => {
            stdout = Buffer.concat([stdout, data]);
        });

        proc.stderr.on('data', (data) => {
            stderr += data.toString();
        });

        proc.on('close', (code) => {
            if (code !== 0) {
                reject(new Error(`ffmpeg subtitle extraction failed (code ${code}): ${stderr.substring(0, 300)}`));
                return;
            }

            const content = stdout.toString('utf-8');
            if (!content || content.trim().length === 0) {
                reject(new Error('Empty subtitle output'));
                return;
            }

            resolve(content);
        });

        proc.on('error', (error) => {
            reject(new Error(`ffmpeg not found or failed: ${error.message}`));
        });
    });
}

/**
 * Transcode using HTTP URL input — ffmpeg streams from our endpoint,
 * no need to download the full file into memory first.
 */
function transcodeFromUrl(streamUrl, outputPath) {
    return new Promise((resolve, reject) => {
        const args = [
            '-v', 'warning',
            '-headers', 'X-Internal-Request: ffmpeg\r\n',
            '-i', streamUrl,
            '-c:v', 'copy',           // Don't re-encode video
            '-c:a', 'aac',            // Transcode audio to AAC
            '-b:a', '192k',           // Audio bitrate
            '-ac', '2',               // Stereo (better compatibility)
            '-c:s', 'mov_text',       // Convert subtitles to mov_text for MP4
            '-movflags', '+faststart', // Enable streaming
            '-y',                      // Overwrite output
            outputPath,
        ];

        console.log(`   🌐 ffmpeg transcoding from: ${streamUrl}`);
        const proc = spawn('ffmpeg', args);

        let stderr = '';
        let lastProgress = 0;

        proc.stderr.on('data', (data) => {
            const str = data.toString();
            stderr += str;

            const timeMatch = str.match(/time=(\d{2}):(\d{2}):(\d{2})/);
            if (timeMatch) {
                const seconds = parseInt(timeMatch[1]) * 3600 +
                    parseInt(timeMatch[2]) * 60 +
                    parseInt(timeMatch[3]);
                if (seconds - lastProgress >= 30) {
                    console.log(`   ⏱️ Transcoding progress: ${timeMatch[0]}`);
                    lastProgress = seconds;
                }
            }
        });

        proc.on('close', (code) => {
            if (code !== 0) {
                reject(new Error(`Transcode failed (code ${code}): ${stderr.substring(0, 300)}`));
                return;
            }

            if (!fs.existsSync(outputPath)) {
                reject(new Error('Transcode output file not created'));
                return;
            }

            const stats = fs.statSync(outputPath);
            console.log(`   ✅ Transcoded: ${(stats.size / 1024 / 1024).toFixed(1)}MB`);
            resolve(outputPath);
        });

        proc.on('error', (error) => {
            reject(new Error(`ffmpeg not found: ${error.message}`));
        });
    });
}

// Clean temp files every hour
setInterval(() => cleanupTempFiles(), 60 * 60 * 1000);

module.exports = {
    probeFile,
    probeBuffer,
    probeFromPipe,
    extractSubtitle,
    extractSubtitleFromBuffer,
    extractSubtitleFromStream,
    extractSubtitleFromUrl,
    transcodeToCompatible,
    transcodeBuffer,
    transcodeFromUrl,
    createTranscodeStream,
    checkFFmpeg,
    checkFFprobe,
    getTempDir,
    cleanupTempFiles,
    COMPATIBLE_AUDIO_CODECS,
    COMPATIBLE_VIDEO_CODECS,
};
