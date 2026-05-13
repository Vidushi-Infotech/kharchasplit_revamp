/**
 * Cache Service — in-memory LRU cache with TTL support.
 *
 * Uses a simple Map + doubly-linked-list for O(1) get/set/eviction.
 * Good for single-process deployments (which this app is).
 * If you scale to multiple processes, swap this for Redis by setting
 * REDIS_URL in env and implementing the same get/set/del/invalidate interface.
 *
 * Design decisions:
 * - Max 1000 entries by default (each entry is a small JSON object, ~1-5KB)
 * - TTL per entry — stale entries are lazy-evicted on access
 * - Pattern-based invalidation for "delete all keys matching group:123:*"
 * - Cache-aside pattern: caller checks cache → miss → query DB → set cache
 */

class CacheService {
  constructor(maxSize = 1000) {
    this.maxSize = maxSize;
    this.cache = new Map(); // Map preserves insertion order — we use this for LRU
    this.hits = 0;
    this.misses = 0;
  }

  /**
   * Get a value from cache. Returns null on miss or expired entry.
   */
  get(key) {
    const entry = this.cache.get(key);
    if (!entry) {
      this.misses++;
      return null;
    }

    // Check TTL
    if (entry.expiresAt && Date.now() > entry.expiresAt) {
      this.cache.delete(key);
      this.misses++;
      return null;
    }

    // Move to end (most recently used) — delete + re-insert in Map
    this.cache.delete(key);
    this.cache.set(key, entry);
    this.hits++;
    return entry.value;
  }

  /**
   * Set a value with optional TTL in seconds.
   */
  set(key, value, ttlSeconds = 60) {
    // If key exists, delete first to update insertion order
    if (this.cache.has(key)) {
      this.cache.delete(key);
    }

    // Evict LRU if at capacity
    if (this.cache.size >= this.maxSize) {
      // Map.keys().next() gives the oldest (least recently used) entry
      const oldestKey = this.cache.keys().next().value;
      this.cache.delete(oldestKey);
    }

    this.cache.set(key, {
      value,
      expiresAt: ttlSeconds ? Date.now() + (ttlSeconds * 1000) : null,
    });
  }

  /**
   * Delete a specific key.
   */
  del(key) {
    return this.cache.delete(key);
  }

  /**
   * Invalidate all keys matching a prefix.
   * E.g., invalidate('group:123') deletes group:123, group:123:members, group:123:balances, etc.
   */
  invalidate(prefix) {
    let count = 0;
    for (const key of this.cache.keys()) {
      if (key.startsWith(prefix)) {
        this.cache.delete(key);
        count++;
      }
    }
    return count;
  }

  /**
   * Cache-aside helper: get from cache or execute fn and cache the result.
   * @param {string} key - Cache key
   * @param {number} ttlSeconds - TTL in seconds
   * @param {Function} fn - Async function to call on cache miss
   * @returns {Promise<*>} - Cached or fresh value
   */
  async getOrSet(key, ttlSeconds, fn) {
    const cached = this.get(key);
    if (cached !== null) {
      return cached;
    }

    const value = await fn();

    // Don't cache null/undefined results (e.g., "group not found")
    if (value != null) {
      this.set(key, value, ttlSeconds);
    }

    return value;
  }

  /**
   * Get cache stats for monitoring.
   */
  getStats() {
    const total = this.hits + this.misses;
    return {
      size: this.cache.size,
      maxSize: this.maxSize,
      hits: this.hits,
      misses: this.misses,
      hitRate: total > 0 ? ((this.hits / total) * 100).toFixed(1) + '%' : '0%',
    };
  }

  /**
   * Clear all cached entries.
   */
  clear() {
    this.cache.clear();
    this.hits = 0;
    this.misses = 0;
  }
}

// Singleton instance — shared across the process
const cache = new CacheService(
  parseInt(process.env.CACHE_MAX_SIZE) || 1000
);

// TTL constants (seconds) — centralized for easy tuning
const TTL = {
  AUTH_USER: 300,         // 5 min — user identity rarely changes mid-session
  USER_PROFILE: 300,      // 5 min — profile updates are rare
  GROUP_DETAIL: 60,       // 1 min — group metadata changes on member/expense actions
  GROUP_MEMBERS: 120,     // 2 min — member list is fairly stable
  GROUP_BALANCES: 120,    // 2 min — most expensive computation, only changes on expense/settlement writes
  GROUP_EXPENSES: 60,     // 1 min — expense list page
  GROUP_SETTLEMENTS: 60,  // 1 min — settlement list
  MEMBER_ACCESS: 120,     // 2 min — isMember/isAdmin checks
};

export { cache, TTL };
export default cache;
