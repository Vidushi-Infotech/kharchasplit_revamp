/**
 * Cache Service — in-memory LRU cache with TTL support.
 *
 * Uses a simple Map + doubly-linked-list for O(1) get/set/eviction.
 *
 * Multi-process (PM2 cluster): every process has its own copy, so each
 * del()/invalidate() is also broadcast to the other processes through
 * services/cacheBus.js (Postgres LISTEN/NOTIFY). While the bus is not
 * connected the cache is bypassed entirely (`coherent = false`): slower,
 * but never stale. Single-process setups can opt out with CACHE_BUS=false.
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
    // False until cacheBus is listening (or CACHE_BUS=false). Scripts and
    // jobs run outside server.js therefore never cache.
    this.coherent = process.env.CACHE_BUS === 'false';
    // Bumped on every invalidation; getOrSet skips caching a value whose
    // read overlapped an invalidation (it may predate the write).
    this.epoch = 0;
    // Set by cacheBus: (op, key) => void, broadcasts to other processes.
    this.publisher = null;
    this.reinvalidateMs = parseInt(process.env.CACHE_REINVALIDATE_MS) || 1500;
  }

  /** Called by cacheBus when the listener connects / drops. */
  setCoherent(value) {
    if (this.coherent === value) return;
    this.coherent = value;
    // Anything cached may have missed invalidations while we were deaf.
    this.cache.clear();
    this.epoch++;
  }

  /**
   * Get a value from cache. Returns null on miss or expired entry.
   */
  get(key) {
    if (!this.coherent) {
      this.misses++;
      return null;
    }
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
    if (!this.coherent) return;
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
   * Delete a specific key — here and in every other process.
   */
  del(key) {
    return this._invalidate('del', key, true);
  }

  /**
   * Invalidate all keys matching a prefix — here and in every other process.
   * E.g., invalidate('group:123') deletes group:123, group:123:members, group:123:balances, etc.
   */
  invalidate(prefix) {
    return this._invalidate('prefix', prefix, true);
  }

  /** An invalidation received from another process (cacheBus). */
  applyRemote(op, key) {
    this._invalidate(op, key, false);
  }

  /**
   * Drop matching entries now and once more after `reinvalidateMs`.
   * The second pass catches a concurrent request that read the row before
   * the writer's transaction committed and cached it after our first
   * delete ("delayed double delete").
   */
  _invalidate(op, key, broadcast) {
    const count = this._dropLocal(op, key);
    if (broadcast && this.publisher) this.publisher(op, key);
    const timer = setTimeout(() => this._dropLocal(op, key), this.reinvalidateMs);
    timer.unref();
    return op === 'del' ? count > 0 : count;
  }

  _dropLocal(op, key) {
    this.epoch++;
    if (op === 'del') return this.cache.delete(key) ? 1 : 0;
    let count = 0;
    for (const k of this.cache.keys()) {
      if (k.startsWith(key)) {
        this.cache.delete(k);
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

    const epoch = this.epoch;
    const value = await fn();

    // Don't cache null/undefined results (e.g., "group not found"), nor a
    // value whose read raced an invalidation.
    if (value != null && epoch === this.epoch) {
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
      coherent: this.coherent,
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
