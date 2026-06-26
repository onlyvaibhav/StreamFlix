/**
 * STREAMFLIX ADMIN CONSOLE — System Module
 */

const SystemModule = (() => {
    let _container = null;

    async function render(container) {
        _container = container;
        _container.innerHTML = `<div class="section">${SkeletonLoader.stats(4)}</div>`;

        try {
            await Promise.allSettled([
                Api.getStorage(),
                Api.getSystemInfo(),
                Api.getWorkerStatus(),
                Api.getIncompleteMetadata()
            ]);
            _renderUI();
            
            AppState.subscribe('system', _renderUI);
            AppState.subscribe('workers', _renderUI);
        } catch (err) {
            _container.innerHTML = EmptyState.html(`Failed to load system info: ${err.message}`, 'alert-triangle');
        }
    }

    function _renderUI() {
        if (!_container) return;

        const sys = AppState.get('system') || {};
        const storage = sys.storage || {};
        const info = sys.info || {};
        const workers = AppState.get('workers') || {};

        const memoryMb = info.memory ? Math.round(info.memory.rss / 1024 / 1024) : 0;
        const storageGb = storage.diskUsedRaw ? (storage.diskUsedRaw / 1024 / 1024 / 1024).toFixed(1) : 0;
        const storagePercent = storage.diskUsedRaw && storage.diskTotalRaw ? 
            Math.round((storage.diskUsedRaw / storage.diskTotalRaw) * 100) : 0;

        _container.innerHTML = `
            <div class="section">
                <div class="stats-grid">
                    ${StatCard.html({ label: 'Memory (RSS)', value: `${memoryMb} MB`, icon: 'cpu', color: memoryMb > 500 ? 'warning' : 'info' })}
                    ${StatCard.html({ label: 'Storage Used', value: `${storageGb} GB`, icon: 'hard-drive', color: storagePercent > 90 ? 'danger' : 'success', trend: `${storagePercent}%`, trendDir: storagePercent > 90 ? 'down' : 'up' })}
                    ${StatCard.html({ label: 'Node Version', value: info.nodeVersion || 'Unknown', icon: 'code', color: 'info' })}
                    ${StatCard.html({ label: 'Worker Queue', value: workers.queueSize || 0, icon: 'list', color: 'warning' })}
                </div>

                <div class="card-grid-2" style="margin-top:var(--space-2xl)">
                    <div class="data-card">
                        <div class="data-card-header">
                            <h3>Environment</h3>
                        </div>
                        <div class="data-card-body no-pad">
                            <table class="data-table">
                                <tbody>
                                    <tr>
                                        <td class="cell-muted" style="width:40%">NODE_ENV</td>
                                        <td style="font-family:var(--font-mono)">${_esc(info.env || 'development')}</td>
                                    </tr>
                                    <tr>
                                        <td class="cell-muted">Platform</td>
                                        <td style="font-family:var(--font-mono)">${_esc(info.platform || 'unknown')}</td>
                                    </tr>
                                    <tr>
                                        <td class="cell-muted">Architecture</td>
                                        <td style="font-family:var(--font-mono)">${_esc(info.arch || 'unknown')}</td>
                                    </tr>
                                    <tr>
                                        <td class="cell-muted">Process ID</td>
                                        <td style="font-family:var(--font-mono)">${info.pid || 'unknown'}</td>
                                    </tr>
                                    <tr>
                                        <td class="cell-muted">Uptime</td>
                                        <td style="font-family:var(--font-mono)">${_formatUptime(info.uptime)}</td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <div class="data-card">
                        <div class="data-card-header">
                            <h3>Queues & Caches</h3>
                        </div>
                        <div class="data-card-body no-pad">
                            <table class="data-table">
                                <tbody>
                                    <tr>
                                        <td class="cell-muted" style="width:40%">Metadata Queue</td>
                                        <td style="font-weight:var(--weight-bold);color:var(--warning)">${workers.queueSize || 0}</td>
                                    </tr>
                                    <tr>
                                        <td class="cell-muted">Active Metadata Jobs</td>
                                        <td style="font-weight:var(--weight-bold);color:var(--success)">${workers.activeSessions || 0}</td>
                                    </tr>
                                    <tr>
                                        <td class="cell-muted">Telegram Queue (Future)</td>
                                        <td class="cell-muted">—</td>
                                    </tr>
                                    <tr>
                                        <td class="cell-muted">Database Status (Future)</td>
                                        <td class="cell-muted">—</td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        `;

        lucide.createIcons({ nodes: [_container] });
    }

    function _formatUptime(seconds) {
        if (!seconds) return 'Unknown';
        const d = Math.floor(seconds / (3600*24));
        const h = Math.floor(seconds % (3600*24) / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        if (d > 0) return `${d}d ${h}h`;
        if (h > 0) return `${h}h ${m}m`;
        return `${m}m`;
    }

    function _esc(str) { const d = document.createElement('div'); d.textContent = str || ''; return d.innerHTML; }

    function destroy() {
        AppState.unsubscribe('system', _renderUI);
        AppState.unsubscribe('workers', _renderUI);
        _container = null;
    }

    AppModules.register({
        id: 'system',
        title: 'System',
        icon: 'server',
        render,
        destroy
    });

    return { render, destroy };
})();
