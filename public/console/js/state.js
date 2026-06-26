/**
 * STREAMFLIX ADMIN CONSOLE — Central State Store
 * Pub/sub reactive state management. All sections subscribe to state keys.
 * Prevents duplicate fetches. SSE events push directly into state.
 */

const AppState = (() => {
    const _data = {
        user: null,
        system: null,
        workers: null,
        streams: null,
        logs: [],
        media: null,
        metadata: null,
        health: null,
        adminHealth: null,
        audioAudit: null,
        storage: null,
        syncStatus: null,
        settings: null,
        analytics: null,
    };

    const _subscribers = new Map();
    const _timestamps = new Map(); // Track when data was last fetched

    /** Get a state value */
    function get(key) {
        return _data[key];
    }

    /** Set a state value and notify subscribers */
    function set(key, value) {
        const prev = _data[key];
        _data[key] = value;
        _timestamps.set(key, Date.now());
        _notify(key, value, prev);
    }

    /** Merge partial update into an object state key */
    function merge(key, partial) {
        const current = _data[key] || {};
        const merged = { ...current, ...partial };
        set(key, merged);
    }

    /** Append to an array state key (e.g., logs) with optional limit */
    function append(key, item, maxLength = 500) {
        const arr = Array.isArray(_data[key]) ? [..._data[key]] : [];
        arr.push(item);
        if (arr.length > maxLength) arr.shift();
        set(key, arr);
    }

    /** Subscribe to changes on a state key */
    function subscribe(key, callback) {
        if (!_subscribers.has(key)) {
            _subscribers.set(key, new Set());
        }
        _subscribers.get(key).add(callback);
        return () => unsubscribe(key, callback);
    }

    /** Unsubscribe from a state key */
    function unsubscribe(key, callback) {
        const subs = _subscribers.get(key);
        if (subs) subs.delete(callback);
    }

    /** Check if data is stale (older than ttl ms) */
    function isStale(key, ttlMs = 30000) {
        const ts = _timestamps.get(key);
        if (!ts) return true;
        return (Date.now() - ts) > ttlMs;
    }

    /** Get the timestamp of last update for a key */
    function lastUpdated(key) {
        return _timestamps.get(key) || null;
    }

    /** Reset a specific key to null */
    function reset(key) {
        set(key, key === 'logs' ? [] : null);
    }

    /** Reset all state (e.g., on logout) */
    function resetAll() {
        for (const key of Object.keys(_data)) {
            _data[key] = key === 'logs' ? [] : null;
        }
        _timestamps.clear();
    }

    /** Notify subscribers for a given key */
    function _notify(key, value, prev) {
        const subs = _subscribers.get(key);
        if (!subs) return;
        for (const cb of subs) {
            try {
                cb(value, prev, key);
            } catch (err) {
                console.error(`[State] Subscriber error for "${key}":`, err);
            }
        }
    }

    /** Debug: log current state */
    function debug() {
        console.table(
            Object.entries(_data).map(([key, val]) => ({
                key,
                type: Array.isArray(val) ? `Array(${val.length})` : typeof val,
                stale: isStale(key),
                lastUpdated: _timestamps.get(key) ? new Date(_timestamps.get(key)).toLocaleTimeString() : 'never',
            }))
        );
    }

    return {
        get,
        set,
        merge,
        append,
        subscribe,
        unsubscribe,
        isStale,
        lastUpdated,
        reset,
        resetAll,
        debug,
    };
})();

// Expose globally
window.AppState = AppState;
