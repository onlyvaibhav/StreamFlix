/**
 * STREAMFLIX ADMIN CONSOLE — Settings Module
 */

const SettingsModule = (() => {
    let _container = null;

    function render(container) {
        _container = container;
        _renderUI();
    }

    function _renderUI() {
        if (!_container) return;

        _container.innerHTML = `
            <div class="section">
                <div class="data-card" style="margin-bottom:var(--space-2xl)">
                    <div class="data-card-header">
                        <h3>Quick Actions</h3>
                    </div>
                    <div class="data-card-body">
                        <div class="actions-grid">
                            <button class="action-card" onclick="SettingsModule.exec(Api.syncTelegram, 'Sync Telegram', 'Force a full sync with the Telegram channel now?')">
                                <i data-lucide="refresh-cw" style="width:18px"></i> Sync Telegram
                            </button>
                            <button class="action-card" onclick="SettingsModule.exec(Api.invalidateCache, 'Invalidate Cache', 'Clear all in-memory caches? This will temporarily increase database load.')">
                                <i data-lucide="trash-2" style="width:18px"></i> Invalidate Cache
                            </button>
                            <button class="action-card" onclick="SettingsModule.exec(Api.rebuildTVCaches, 'Rebuild TV Caches', 'Rebuild TV show season/episode caches? Run this if episodes are missing from UI.')">
                                <i data-lucide="folder-tree" style="width:18px"></i> Rebuild TV Caches
                            </button>
                            <button class="action-card" onclick="SettingsModule.exec(Api.fixBroken, 'Fix Broken Metadata', 'Queue all broken records for repair?')">
                                <i data-lucide="wrench" style="width:18px"></i> Fix Broken Metadata
                            </button>
                            <button class="action-card" onclick="SettingsModule.exec(Api.retryFailed, 'Retry Failed Lookups', 'Retry TMDB lookups for previously failed items?')">
                                <i data-lucide="rotate-ccw" style="width:18px"></i> Retry Failed Lookups
                            </button>
                            <button class="action-card" onclick="SettingsModule.exec(Api.refetchAllFailed, 'Refetch All Failed', 'Clear error states and force refetch for all FAILED metadata items?')">
                                <i data-lucide="refresh-ccw" style="width:18px;color:var(--danger)"></i> Refetch All Failed
                            </button>
                            <button class="action-card" onclick="SettingsModule.exec(Api.fetchMissingLogos, 'Fetch Missing Logos', 'Scan library and fetch missing TV/Movie logos from TMDB?')">
                                <i data-lucide="image" style="width:18px"></i> Fetch Missing Logos
                            </button>
                            <button class="action-card" onclick="SettingsModule.exec(Api.fetchMissingAudio, 'Fetch Missing Audio', 'Fetch missing language metadata for audio tracks?')">
                                <i data-lucide="mic" style="width:18px"></i> Fetch Missing Audio
                            </button>
                        </div>
                    </div>
                </div>

                <div class="data-card">
                    <div class="data-card-header">
                        <h3>Environment Configuration</h3>
                    </div>
                    <div class="data-card-body" style="padding:var(--space-3xl);text-align:center;color:var(--text-muted)">
                        <i data-lucide="settings" style="width:32px;height:32px;margin-bottom:var(--space-md);opacity:0.5"></i>
                        <p>Environment variable management and UI customization will be added in a future update.</p>
                    </div>
                </div>
            </div>
        `;

        lucide.createIcons({ nodes: [_container] });
    }

    async function _exec(apiCall, title, message) {
        const confirmed = await ConfirmDialog.show({ title, message });
        if (!confirmed) return;

        try {
            await apiCall();
            Toast.success(`${title} executed successfully`);
        } catch (err) {
            Toast.error(err.message);
        }
    }

    AppModules.register({
        id: 'settings',
        title: 'Settings',
        icon: 'settings',
        render
    });

    return { render, exec: _exec };
})();
