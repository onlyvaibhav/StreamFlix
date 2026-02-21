const { LRUCache } = require('lru-cache');

class CacheService {
  constructor() {
    this.responseCache = new LRUCache({
      max: 200,
      ttl: 1000 * 60 * 5, // 5 minutes
    });
  }

  get(key) {
    return this.responseCache.get(key);
  }

  set(key, value, ttl) {
    this.responseCache.set(key, value, { ttl });
  }

  delete(key) {
    this.responseCache.delete(key);
  }

  clear() {
    this.responseCache.clear();
  }

  stats() {
    return {
      size: this.responseCache.size,
      max: this.responseCache.max,
    };
  }
}

module.exports = new CacheService();