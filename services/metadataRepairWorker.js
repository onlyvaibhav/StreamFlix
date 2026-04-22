require('dotenv').config();
const fs = require('fs').promises;
const path = require('path');
const { initTelegram, getDocument, detectAllTracks } = require('./telegramService');

const DATA_DIR = path.join(__dirname, '../data/metadata');
const CONCURRENCY_LIMIT = 1; // Reduced to 1 for long-term stability
const PROBE_TIMEOUT_MS = 180000; // 3 minutes per file hard timeout

// Stats
const stats = {
    total: 0,
    incomplete: 0,
    fixed: 0,
    failed: 0,
    totalAudioFixed: 0,
    totalDurationFixed: 0
};

/**
 * Utility: Sleep for MS
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Utility: Timeout wrapper for promises
 */
function withTimeout(promise, ms, name) {
    const timeout = new Promise((_, reject) =>
        setTimeout(() => reject(new Error(`Timeout: ${name} took more than ${ms}ms`)), ms)
    );
    return Promise.race([promise, timeout]);
}

/**
 * Check if metadata is incomplete based on audio/container fields
 */
function isIncomplete(meta) {
    // A file is incomplete if:
    // - audioTracks is missing OR empty
    // - OR _tracksDetected !== true
    // - OR audioCodec missing
    // - OR duration missing
    const hasAudioTracks = meta.audioTracks && meta.audioTracks.length > 0;
    const hasTracksDetected = meta._tracksDetected === true;
    const hasAudioCodec = !!meta.audioCodec;
    const hasDuration = !!meta.duration || (meta.tv && !!meta.tv.episodeRuntime) || !!meta.runtime;

    return !hasAudioTracks || !hasTracksDetected || !hasAudioCodec || !hasDuration;
}

/**
 * Save metadata atomically by writing to a temp file and renaming
 */
async function saveMetadataAtomic(fileId, data) {
    const filePath = path.join(DATA_DIR, `${fileId}.json`);
    const tempPath = `${filePath}.tmp_${Date.now()}`;
    
    try {
        await fs.writeFile(tempPath, JSON.stringify(data, null, 2), 'utf-8');
        await fs.rename(tempPath, filePath);
    } catch (error) {
        console.error(`[Repair] Error saving metadata for ${fileId}:`, error.message);
        try { await fs.unlink(tempPath); } catch (e) {}
        throw error;
    }
}

/**
 * Repair a single metadata file
 */
async function repairFile(fileName) {
    const fileId = fileName.replace('.json', '');
    const metaPath = path.join(DATA_DIR, fileName);
    
    try {
        const raw = await fs.readFile(metaPath, 'utf-8');
        const meta = JSON.parse(raw);
        
        if (!isIncomplete(meta)) {
            return;
        }

        stats.incomplete++;
        console.log(`[Repair] [${stats.incomplete}] Probing: ${meta.title} (${fileId})`);

        // Wrap the entire file-level probe in a timeout
        await withTimeout((async () => {
            const doc = await getDocument(fileId);
            if (!doc) {
                console.warn(`[Repair] Message not found for fileId: ${fileId}`);
                stats.failed++;
                return;
            }

            const info = await detectAllTracks(doc, fileId);
            
            if (info.error) {
                console.error(`[Repair] Failed to probe ${fileId}: ${info.error}`);
                stats.failed++;
                return;
            }

            // Merge updates
            let updated = false;
            
            if (info.audioTracks && info.audioTracks.length > 0) {
                meta.audioTracks = info.audioTracks;
                const defaultAudio = info.audioTracks.find(t => t.isDefault) || info.audioTracks[0];
                meta.audioCodec = defaultAudio ? defaultAudio.codec : 'unknown';
                meta.browserPlayable = defaultAudio ? defaultAudio.browserPlayable : true;
                stats.totalAudioFixed++;
                updated = true;
            }

            if (info.subtitleTracks && info.subtitleTracks.length > 0) {
                meta.subtitleTracks = info.subtitleTracks;
                updated = true;
            }

            if (info.format) {
                meta.container = info.format.name;
                if (info.format.duration > 0) {
                    meta.duration = Math.round(info.format.duration);
                    // Also update runtime/episodeRuntime for consistency if missing
                    if (!meta.runtime) meta.runtime = Math.round(info.format.duration / 60);
                    if (meta.tv && !meta.tv.episodeRuntime) meta.tv.episodeRuntime = Math.round(info.format.duration / 60);
                    stats.totalDurationFixed++;
                }
                updated = true;
            }

            if (updated) {
                meta._tracksDetected = true;
                await saveMetadataAtomic(fileId, meta);
                stats.fixed++;
                console.log(`[Repair] ✓ Fixed: ${meta.title}`);
            } else {
                console.log(`[Repair] ~ No new info for: ${meta.title}`);
            }
        })(), PROBE_TIMEOUT_MS, `Probe for ${fileId}`);

    } catch (error) {
        console.error(`[Repair] ⚠️ Skipping ${fileName}:`, error.message);
        stats.failed++;
    }
}

/**
 * Main execution
 */
async function run() {
    console.log('────────────────────────────────────────────────────────────');
    console.log('🚀 StreamFlix Metadata Repair Worker (Stability Mode)');
    console.log('────────────────────────────────────────────────────────────');

    try {
        // Initialize Telegram
        console.log('[Repair] Connecting to Telegram...');
        await initTelegram();
        console.log('[Repair] Telegram connected.');

        // Scan directory
        console.log('[Repair] Scanning metadata directory...');
        const files = (await fs.readdir(DATA_DIR)).filter(f => f.endsWith('.json'));
        stats.total = files.length;
        console.log(`[Repair] Found ${files.length} metadata files.`);

        // Process in batches (parallel with limit)
        for (let i = 0; i < files.length; i += CONCURRENCY_LIMIT) {
            const batch = files.slice(i, i + CONCURRENCY_LIMIT);
            await Promise.all(batch.map(file => repairFile(file)));
            
            // Progress update
            const progress = (((i + batch.length) / files.length) * 100).toFixed(1);
            process.stdout.write(`\r[Repair] Progress: ${progress}% (${i + batch.length}/${files.length})`);

            // Mandatory cooldown between batches to let the Telegram update loop breathe
            if (i + batch.length < files.length) {
                await sleep(1000); 
            }
        }

        console.log('\n\n────────────────────────────────────────────────────────────');
        console.log('✅ Repair Job Complete');
        console.log(`- Total Files Scanned: ${stats.total}`);
        console.log(`- Incomplete Found:    ${stats.incomplete}`);
        console.log(`- Successfully Fixed:  ${stats.fixed}`);
        console.log(`- Failed/Skipped:      ${stats.failed}`);
        console.log(`- Audio Fixed:         ${stats.totalAudioFixed}`);
        console.log(`- Duration Fixed:      ${stats.totalDurationFixed}`);
        console.log('────────────────────────────────────────────────────────────');

        process.exit(0);
    } catch (error) {
        console.error('[Repair] RUN CRASHED:', error);
        process.exit(1);
    }
}

run();
