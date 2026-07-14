/**
 * STREAMFLIX ADMIN CONSOLE — API Abstraction Layer
 * All backend communication goes through here.
 * UI never calls fetch() directly. Future Supabase swap only touches this file.
 */

const Api = (() => {
    const TOKEN_KEY = 'streamflix_admin_token';

    // ── Token Management ──
    function getToken() { return localStorage.getItem(TOKEN_KEY); }
    function setToken(t) { localStorage.setItem(TOKEN_KEY, t); }
    function clearToken() { localStorage.removeItem(TOKEN_KEY); }
    function hasToken() { return !!getToken(); }

    // ── Core Request ──
    async function request(endpoint, options = {}) {
        const token = getToken();
        const headers = { 'Content-Type': 'application/json' };
        if (token) headers['Authorization'] = `Bearer ${token}`;

        const config = { ...options, headers: { ...headers, ...options.headers } };

        try {
            const res = await fetch(endpoint, config);

            if (res.status === 401 || res.status === 403) {
                clearToken();
                AppState.set('user', null);
                if (typeof AppRouter !== 'undefined') AppRouter.onAuthFailed();
                return null;
            }

            if (!res.ok) {
                const errData = await res.json().catch(() => ({}));
                throw new Error(errData.error || `HTTP ${res.status}`);
            }

            return await res.json();
        } catch (err) {
            console.error(`[API] ${options.method || 'GET'} ${endpoint}:`, err.message);
            throw err;
        }
    }

    function get(endpoint)          { return request(endpoint); }
    function post(endpoint, body)   { return request(endpoint, { method: 'POST', body: body ? JSON.stringify(body) : undefined }); }

    // ══════════════════════════════════════
    // AUTH
    // ══════════════════════════════════════
    async function login(username, password) {
        const data = await request('/api/auth/login', {
            method: 'POST',
            body: JSON.stringify({ username, password }),
        });
        if (data?.success && data.token) {
            setToken(data.token);
            AppState.set('user', data.user);
        }
        return data;
    }

    function logout() {
        clearToken();
        AppState.resetAll();
    }

    // ══════════════════════════════════════
    // DASHBOARD & HEALTH
    // ══════════════════════════════════════
    async function getAdminHealth() {
        const data = await get('/api/admin/health');
        AppState.set('adminHealth', data);
        return data;
    }

    async function getStorage() {
        const data = await get('/api/admin/system/storage');
        AppState.merge('system', { storage: data });
        return data;
    }

    async function getSystemInfo() {
        const data = await get('/api/admin/system/info');
        AppState.merge('system', { info: data });
        return data;
    }

    // ══════════════════════════════════════
    // MEDIA LIBRARY
    // ══════════════════════════════════════
    async function searchMedia(query = '', type = 'all') {
        const data = await get(`/api/admin/metadata/search?q=${encodeURIComponent(query)}&type=${type}`);
        AppState.set('media', data);
        return data;
    }

    async function getFileMetadata(fileId) {
        return await get(`/api/metadata/${fileId}`);
    }

    // ══════════════════════════════════════
    // METADATA MANAGEMENT
    // ══════════════════════════════════════
    async function getIssues() {
        const response = await get('/api/admin/metadata/issues');
        const data = response.issues || response || [];
        AppState.set('metadata', data);
        return data;
    }

    async function fixMetadata(fileId, tmdbId, type) {
        return await post(`/api/admin/metadata/${fileId}/fix`, { tmdbId: Number(tmdbId), type });
    }

    async function refetchMetadata(fileId) {
        return await post(`/api/admin/metadata/${fileId}/refetch`);
    }

    async function manualOverride(fileId, fields) {
        return await post(`/api/admin/metadata/${fileId}/manual-override`, fields);
    }

    async function setProbeResult(fileId, probeJson) {
        return await post(`/api/admin/metadata/${fileId}/set-probe-result`, probeJson);
    }

    async function autoMatchAll() {
        return await post('/api/admin/metadata/auto-match-all');
    }

    async function fixBroken() {
        return await post('/api/admin/fix-broken');
    }

    async function retryFailed() {
        return await post('/api/admin/metadata/retry-failed');
    }

    async function refetchAllFailed() {
        return await post('/api/admin/metadata/refetch-all-failed');
    }

    async function downloadMissingStills() {
        return await post('/api/admin/metadata/download-missing-stills');
    }

    // ══════════════════════════════════════
    // WORKERS
    // ══════════════════════════════════════
    async function getWorkerStatus() {
        const data = await get('/api/admin/worker-status');
        AppState.set('workers', data);
        return data;
    }

    async function pauseWorker() {
        return await post('/api/admin/worker/pause');
    }

    async function resumeWorker() {
        return await post('/api/admin/worker/resume');
    }

    async function getAudioAudit() {
        const data = await get('/api/admin/audio/audit');
        AppState.set('audioAudit', data);
        return data;
    }

    async function startAudioSweep(limit = 0, concurrency = 3) {
        return await post('/api/admin/audio/sweep', { limit, concurrency });
    }

    // ══════════════════════════════════════
    // TELEGRAM
    // ══════════════════════════════════════
    async function syncTelegram() {
        return await post('/api/admin/sync-telegram');
    }

    async function getSyncStatus() {
        const data = await get('/api/admin/sync-status');
        AppState.set('syncStatus', data);
        return data;
    }

    async function rebuildTVCaches() {
        return await post('/api/admin/rebuild-tv-caches');
    }

    // ══════════════════════════════════════
    // STREAMS
    // ══════════════════════════════════════
    async function getStreams() {
        const data = await get('/api/admin/streams');
        AppState.set('streams', data);
        return data;
    }

    // ══════════════════════════════════════
    // LOGS
    // ══════════════════════════════════════
    async function getLogs() {
        const data = await get('/api/admin/worker/logs');
        AppState.set('logs', data || []);
        return data;
    }

    // ══════════════════════════════════════
    // SYSTEM & CACHE
    // ══════════════════════════════════════
    async function invalidateCache() {
        return await post('/api/admin/invalidate-cache');
    }

    async function fetchMissingLogos() {
        return await post('/api/admin/refetch-logos');
    }

    async function fetchMissingAudio() {
        return await post('/api/admin/refetch-audio');
    }

    async function getIncompleteMetadata() {
        return await get('/api/admin/incomplete-metadata');
    }

    return {
        // Auth
        login, logout, getToken, hasToken, clearToken,
        // Dashboard
        getAdminHealth, getStorage, getSystemInfo,
        // Media
        searchMedia, getFileMetadata,
        // Metadata
        getIssues,
        fixMetadata,
        refetchMetadata,
        manualOverride,
        setProbeResult,
        autoMatchAll,
        fixBroken,
        retryFailed,
        refetchAllFailed,
        downloadMissingStills,
        // Workers
        getWorkerStatus, pauseWorker, resumeWorker, getAudioAudit, startAudioSweep,
        // Telegram
        syncTelegram, getSyncStatus, rebuildTVCaches,
        // Streams
        getStreams,
        // Logs
        getLogs,
        // System
        invalidateCache, fetchMissingLogos, fetchMissingAudio, getIncompleteMetadata,
    };
})();

window.Api = Api;
