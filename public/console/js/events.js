/**
 * STREAMFLIX ADMIN CONSOLE — Server-Sent Events (Real-time)
 * Single authenticated SSE connection. No polling fallback.
 * Detects auth failures and stops reconnecting.
 */

const AppEvents = (() => {
    let _source = null;
    let _reconnectTimer = null;
    let _reconnectDelay = 1000;
    let _maxReconnectDelay = 30000;
    let _connected = false;
    let _authFailed = false;
    let _intentionalDisconnect = false;

    // Connection stats
    let _connectTime = null;
    let _reconnectCount = 0;
    let _lastEventTime = null;

    /** Connect to SSE endpoint */
    function connect() {
        if (_source) disconnect();
        _authFailed = false;
        _intentionalDisconnect = false;

        const token = Api.getToken();
        if (!token) {
            console.warn('[SSE] No token available, skipping connection');
            return;
        }

        try {
            _source = new EventSource(`/api/admin/events?token=${encodeURIComponent(token)}`);

            _source.onopen = () => {
                _connected = true;
                _reconnectDelay = 1000; // Reset backoff on success
                _connectTime = Date.now();
                _lastEventTime = Date.now();
                console.log('[SSE] Connected');
            };

            // ── Typed Event Listeners ──

            _source.addEventListener('connected', (e) => {
                try {
                    const info = JSON.parse(e.data);
                    console.log(`[SSE] Server assigned clientId: ${info.clientId}, active clients: ${info.activeClients}`);
                } catch (err) {}
            });

            _source.addEventListener('log.initial', (e) => {
                try {
                    _lastEventTime = Date.now();
                    const logs = JSON.parse(e.data);
                    if (Array.isArray(logs)) {
                        AppState.set('logs', logs);
                    }
                } catch (err) {}
            });

            _source.addEventListener('log.entry', (e) => {
                try {
                    _lastEventTime = Date.now();
                    const entry = JSON.parse(e.data);
                    AppState.append('logs', entry, 500);
                } catch (err) {}
            });

            _source.addEventListener('stream.updated', (e) => {
                try {
                    _lastEventTime = Date.now();
                    const status = JSON.parse(e.data);
                    AppState.set('streams', status);
                } catch (err) {}
            });

            _source.addEventListener('worker.updated', (e) => {
                try {
                    _lastEventTime = Date.now();
                    const status = JSON.parse(e.data);
                    AppState.set('workers', status);
                } catch (err) {}
            });

            _source.addEventListener('backfill.updated', (e) => {
                try {
                    _lastEventTime = Date.now();
                    const status = JSON.parse(e.data);
                    AppState.set('backfill', status);
                } catch (err) {}
            });

            _source.addEventListener('health', (e) => {
                try {
                    _lastEventTime = Date.now();
                    const data = JSON.parse(e.data);
                    AppState.merge('system', data);
                } catch (err) {}
            });

            _source.onerror = (evt) => {
                _connected = false;

                // EventSource.CLOSED (2) means the server closed the connection.
                // This happens on 401/403 responses — do NOT reconnect.
                if (_source && _source.readyState === EventSource.CLOSED) {
                    console.warn('[SSE] Connection rejected by server (likely 401/403)');
                    _source.close();
                    _source = null;
                    _authFailed = true;

                    // Notify the app that auth failed
                    if (typeof AppRouter !== 'undefined') {
                        AppRouter.onAuthFailed();
                    }
                    return;
                }

                // Temporary error — schedule reconnect with backoff
                if (!_intentionalDisconnect) {
                    _source.close();
                    _source = null;
                    _scheduleReconnect();
                }
            };
        } catch (err) {
            console.warn('[SSE] EventSource not supported');
        }
    }

    /** Disconnect SSE (intentional) */
    function disconnect() {
        _intentionalDisconnect = true;
        if (_source) {
            _source.close();
            _source = null;
        }
        _connected = false;
        _authFailed = false;
        if (_reconnectTimer) {
            clearTimeout(_reconnectTimer);
            _reconnectTimer = null;
        }
    }

    /** Is connected? */
    function isConnected() {
        return _connected;
    }

    /** Has auth failed? */
    function isAuthFailed() {
        return _authFailed;
    }

    /** Get connection stats */
    function getStats() {
        return {
            connected: _connected,
            authFailed: _authFailed,
            connectTime: _connectTime,
            reconnectCount: _reconnectCount,
            lastEventTime: _lastEventTime,
            uptime: _connectTime ? Math.round((Date.now() - _connectTime) / 1000) : 0
        };
    }

    /** Schedule reconnection with exponential backoff */
    function _scheduleReconnect() {
        if (_reconnectTimer || _authFailed || _intentionalDisconnect) return;
        
        _reconnectCount++;
        console.log(`[SSE] Reconnecting in ${_reconnectDelay}ms (attempt ${_reconnectCount})...`);
        
        _reconnectTimer = setTimeout(() => {
            _reconnectTimer = null;
            _reconnectDelay = Math.min(_reconnectDelay * 2, _maxReconnectDelay);
            connect();
        }, _reconnectDelay);
    }

    return {
        connect,
        disconnect,
        isConnected,
        isAuthFailed,
        getStats,
    };
})();

window.AppEvents = AppEvents;
