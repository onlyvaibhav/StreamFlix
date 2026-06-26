/**
 * STREAMFLIX ADMIN CONSOLE — Telegram Module
 */

const TelegramModule = (() => {
    let _container = null;

    async function render(container) {
        _container = container;
        _container.innerHTML = `<div class="section">${SkeletonLoader.card(1)}</div>`;

        try {
            await Api.getSyncStatus();
            _renderUI();
        } catch (err) {
            _container.innerHTML = EmptyState.html(`Failed to load sync status: ${err.message}`, 'alert-triangle');
        }
    }

    function _renderUI() {
        if (!_container) return;

        const sync = AppState.get('syncStatus') || {};
        const isSyncing = sync.isSyncing;

        const statusIcon = isSyncing ? 'refresh-cw' : 'check-circle';
        const statusColor = isSyncing ? 'var(--warning)' : 'var(--success)';
        const statusText = isSyncing ? 'Syncing Now...' : 'Idle (Ready)';

        _container.innerHTML = `
            <div class="section">
                <div class="data-card" style="margin-bottom:var(--space-2xl)">
                    <div class="data-card-header">
                        <h3>Telegram Channel Sync</h3>
                    </div>
                    <div class="data-card-body">
                        <div style="display:flex;align-items:center;gap:var(--space-lg);margin-bottom:var(--space-2xl)">
                            <div style="width:48px;height:48px;border-radius:50%;background:var(--bg-hover);display:flex;align-items:center;justify-content:center">
                                <i data-lucide="${statusIcon}" class="${isSyncing ? 'animate-spin' : ''}" style="color:${statusColor};width:24px;height:24px"></i>
                            </div>
                            <div style="flex:1">
                                <div style="font-weight:var(--weight-semibold);font-size:var(--text-lg)">${statusText}</div>
                                <div style="font-size:var(--text-sm);color:var(--text-muted)">
                                    Last Sync: ${sync.lastSync ? new Date(sync.lastSync).toLocaleString() : 'Never'}
                                </div>
                            </div>
                            <div style="text-align:right">
                                <div style="font-weight:var(--weight-bold);font-size:var(--text-2xl)">${sync.syncedFiles || 0}</div>
                                <div style="font-size:var(--text-sm);color:var(--text-muted)">Files Synced</div>
                            </div>
                        </div>

                        <div class="actions-grid">
                            <button class="action-card btn-primary" style="justify-content:center;color:white;border:none" onclick="TelegramModule.runSync()" ${isSyncing ? 'disabled' : ''}>
                                <i data-lucide="refresh-cw" style="width:18px"></i> Force Sync Now
                            </button>
                            <button class="action-card" style="justify-content:center" onclick="TelegramModule.rebuildTV()">
                                <i data-lucide="folder-tree" style="width:18px"></i> Rebuild TV Caches
                            </button>
                        </div>
                    </div>
                </div>

                <div class="data-card">
                    <div class="data-card-header">
                        <h3>Telegram Sessions (Future)</h3>
                    </div>
                    <div class="data-card-body" style="padding:var(--space-3xl);text-align:center;color:var(--text-muted)">
                        <i data-lucide="lock" style="width:32px;height:32px;margin-bottom:var(--space-md);opacity:0.5"></i>
                        <p>Multi-account Telegram session management will be added in a future update.</p>
                    </div>
                </div>
            </div>
        `;

        lucide.createIcons({ nodes: [_container] });
    }

    async function _runSync() {
        try {
            await Api.syncTelegram();
            Toast.success('Sync started. Check logs for progress.');
            _loadData();
        } catch (err) {
            Toast.error(err.message);
        }
    }

    async function _rebuildTV() {
        try {
            await Api.rebuildTVCaches();
            Toast.success('TV caches rebuilt successfully');
        } catch (err) {
            Toast.error(err.message);
        }
    }

    async function _loadData() {
        try {
            await Api.getSyncStatus();
            _renderUI();
        } catch (e) {}
    }

    AppModules.register({
        id: 'telegram',
        title: 'Telegram Sync',
        icon: 'send',
        render
    });

    return { render, runSync: _runSync, rebuildTV: _rebuildTV };
})();
