/**
 * STREAMFLIX ADMIN CONSOLE — Streaming Module
 */

const StreamingModule = (() => {
    let _container = null;

    async function render(container) {
        _container = container;
        _container.innerHTML = `<div class="section">${SkeletonLoader.stats(2)}${SkeletonLoader.table()}</div>`;

        try {
            if (AppState.isStale('streams')) {
                await Api.getStreams();
            }
            _renderUI();
            
            // Subscribe to live SSE updates
            AppState.subscribe('streams', _renderUI);
        } catch (err) {
            _container.innerHTML = EmptyState.html(`Failed to load streams: ${err.message}`, 'alert-triangle');
        }
    }

    function _renderUI() {
        if (!_container) return;

        const streams = AppState.get('streams') || {};
        const activeViewers = streams.activeSessions || 0;
        const peakViewers = streams.peakSessions || activeViewers;
        const totalRequests = streams.activeRangeRequests || 0;

        const sessions = streams.sessions || [];

        let sessionsHtml = '';
        if (sessions.length === 0) {
            sessionsHtml = EmptyState.html('No active viewer sessions.', 'radio');
        } else {
            sessionsHtml = `<div class="card-grid-2">` + sessions.map(s => ViewerCard.html(s)).join('') + `</div>`;
        }

        _container.innerHTML = `
            <div class="section">
                <div class="stats-grid">
                    ${StatCard.html({ label: 'Current Viewers', value: activeViewers, icon: 'users', color: activeViewers > 0 ? 'success' : 'info', trend: activeViewers > 0 ? 'Live' : '', trendDir: 'up' })}
                    ${StatCard.html({ label: 'Peak Viewers', value: peakViewers, icon: 'activity', color: 'accent' })}
                    ${StatCard.html({ label: 'Active Range Requests', value: totalRequests, icon: 'download-cloud', color: 'info' })}
                </div>

                <div class="data-card" style="margin-top:var(--space-2xl)">
                    <div class="data-card-header">
                        <h3>Active Sessions <span class="badge badge-success" style="margin-left:var(--space-sm)">${sessions.length}</span></h3>
                    </div>
                    <div class="data-card-body">
                        ${sessionsHtml}
                    </div>
                </div>
            </div>
        `;

        lucide.createIcons({ nodes: [_container] });
    }

    function destroy() {
        AppState.unsubscribe('streams', _renderUI);
        _container = null;
    }

    AppModules.register({
        id: 'streaming',
        title: 'Streaming',
        icon: 'radio',
        render,
        destroy
    });

    return { render, destroy };
})();
