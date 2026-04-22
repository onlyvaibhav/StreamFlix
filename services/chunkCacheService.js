const { Api } = require('telegram');
const bigInt = require('big-integer');
const { LRUCache } = require('lru-cache');

// --- SHARED CHUNK CACHE ---
// Keep around 150 chunks in memory (assuming typical 1MB chunks = ~150MB RAM max)
const chunkCache = new LRUCache({
    max: 150,
    // 5 minutes TTL for chunks
    ttl: 1000 * 60 * 5,
});

// --- IN-FLIGHT REQUESTS ---
// Deduplicate concurrent requests for the exact same chunk
const pendingRequests = new Map();

// --- RATE LIMITER (LEAKY BUCKET) ---
// Prevent Telegram FloodWaits by spacing out API calls to a max of 5 requests / second (~5 MB/s).
let lastRequestTime = 0;
const MIN_DELAY_MS = 200;

async function throttleRequest() {
    const now = Date.now();
    const scheduledTime = Math.max(now, lastRequestTime + MIN_DELAY_MS);
    lastRequestTime = scheduledTime;

    const delay = scheduledTime - now;
    if (delay > 0) {
        await new Promise(resolve => setTimeout(resolve, delay));
    }
}

/**
 * Fetches a chunk of a file from Telegram and caches it in memory.
 * Promotes deduplication of concurrent requests and LRU caching for subsequent requests.
 * sender can be a specific DC sender obtained via client.getSender(dcId).
 */
async function getTelegramChunk(client, fileInfo, alignedOffset, limit, sender = null) {
    const cacheKey = `${fileInfo.id}_${alignedOffset}_${limit}`;
    const cached = chunkCache.get(cacheKey);
    if (cached) {
        return cached;
    }

    if (pendingRequests.has(cacheKey)) {
        return pendingRequests.get(cacheKey);
    }

    const fetchPromise = (async () => {
        let attempts = 0;
        const maxAttempts = 3;

        while (attempts < maxAttempts) {
            try {
                attempts++;
                // Apply global rate limit spacing before calling Telegram API
                await throttleRequest();

                const getFileRequest = new Api.upload.GetFile({
                    location: fileInfo.location || fileInfo.inputLocation,
                    offset: bigInt(alignedOffset),
                    limit: limit,
                    precise: false,
                });

                let result;
                try {
                    // If a specific sender is provided and it's not the client itself,
                    // we must use invokeWithSender to route the request correctly.
                    if (sender && sender !== client) {
                        result = await Promise.race([
                            client.invokeWithSender(getFileRequest, sender),
                            new Promise((_, reject) =>
                                setTimeout(() => reject(new Error('Chunk timeout (Sender)')), 60000)
                            ),
                        ]);
                    } else {
                        result = await Promise.race([
                            client.invoke(getFileRequest),
                            new Promise((_, reject) =>
                                setTimeout(() => reject(new Error('Chunk timeout')), 60000)
                            ),
                        ]);
                    }
                } catch (error) {
                    const errorMsg = error.message || error.errorMessage || '';
                    
                    // Specific handling for disconnection and "hanging states"
                    // These are often recoverable if we wait for GramJS to reconnect.
                    if (
                        errorMsg.includes('Not connected') || 
                        errorMsg.includes('connection closed') || 
                        errorMsg.includes('hanging states') ||
                        errorMsg.includes('Disconnect')
                    ) {
                        if (attempts < maxAttempts) {
                            const delay = 2000;
                            console.warn(`⚠️ [Telegram] Connection issue during chunk download (Attempt ${attempts}/${maxAttempts}). Retrying in ${delay}ms: ${errorMsg}`);
                            await new Promise(r => setTimeout(r, delay));
                            continue; // Retry
                        }
                    }

                    // If it's a migration error, we bubble it up so the caller can switch senders
                    if (errorMsg.includes('FILE_MIGRATE') || errorMsg.includes('DC_ID_INVALID')) {
                        error.isMigrationError = true;
                        const match = errorMsg.match(/\d+/);
                        if (match) error.newDcId = parseInt(match[0]);
                    }
                    throw error;
                }

                if (result && result.bytes && result.bytes.length > 0) {
                    const data = Buffer.from(result.bytes);
                    chunkCache.set(cacheKey, data);
                    return data;
                }
                return null;

            } catch (err) {
                if (attempts >= maxAttempts) throw err;
                // If it wasn't a connection error but we still have attempts, wait slightly and retry
                await new Promise(r => setTimeout(r, 1000));
            }
        }
    })().finally(() => {
        pendingRequests.delete(cacheKey);
    });

    pendingRequests.set(cacheKey, fetchPromise);
    return fetchPromise;
}

module.exports = {
    getTelegramChunk,
};
