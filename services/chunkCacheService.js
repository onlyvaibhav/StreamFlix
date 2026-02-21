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
// Prevent Telegram FloodWaits by spacing out API calls to a max of 10 requests / second (~10 MB/s).
let lastRequestTime = 0;
const MIN_DELAY_MS = 100;

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
 * Helps prevent FloodWait errors when multiple streams or seeks hit the same file segment.
 */
async function getTelegramChunk(telegramClient, fileInfo, alignedOffset, limit) {
    const cacheKey = `${fileInfo.id}_${alignedOffset}_${limit}`;
    const cached = chunkCache.get(cacheKey);
    if (cached) {
        return cached;
    }

    if (pendingRequests.has(cacheKey)) {
        return pendingRequests.get(cacheKey);
    }

    const fetchPromise = (async () => {
        try {
            // Apply global rate limit spacing before calling Telegram API
            await throttleRequest();

            const result = await Promise.race([
                telegramClient.invoke(new Api.upload.GetFile({
                    location: fileInfo.inputLocation,
                    offset: bigInt(alignedOffset),
                    limit: limit,
                    precise: false,
                })),
                new Promise((_, reject) =>
                    setTimeout(() => reject(new Error('Chunk timeout')), 30000)
                ),
            ]);

            if (result && result.bytes && result.bytes.length > 0) {
                const data = Buffer.from(result.bytes);
                chunkCache.set(cacheKey, data);
                return data;
            }
            return null;
        } finally {
            // Remove from pending whether it succeeded or failed
            pendingRequests.delete(cacheKey);
        }
    })();

    pendingRequests.set(cacheKey, fetchPromise);
    return fetchPromise;
}

module.exports = {
    getTelegramChunk,
};
