module.exports = {
  apiId: parseInt(process.env.TELEGRAM_API_ID),
  apiHash: process.env.TELEGRAM_API_HASH,
  sessionString: process.env.TELEGRAM_SESSION_STRING || '',
  channelId: process.env.TELEGRAM_CHANNEL_ID,
  chunkSize: parseInt(process.env.CHUNK_SIZE) || 1024 * 1024,
  maxCacheSize: parseInt(process.env.MAX_CACHE_SIZE) || 100 * 1024 * 1024,
};