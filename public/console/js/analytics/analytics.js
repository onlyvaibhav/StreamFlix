/**
 * STREAMFLIX ADMIN CONSOLE — Analytics Module
 */

const AnalyticsModule = (() => {
    let _container = null;
    let _chartInstance = null;

    async function render(container) {
        _container = container;
        _container.innerHTML = `<div class="section">${SkeletonLoader.stats()}${SkeletonLoader.card(2)}</div>`;

        try {
            await Promise.allSettled([
                Api.getStreams(),
                Api.getAdminHealth(),
                Api.getWorkerStatus(),
                Api.getStorage()
            ]);
            _renderUI();
            
            AppState.subscribe('streams', _renderUI);
            AppState.subscribe('adminHealth', _renderUI);
        } catch (err) {
            _container.innerHTML = EmptyState.html(`Failed to load analytics: ${err.message}`, 'alert-triangle');
        }
    }

    function _renderUI() {
        if (!_container) return;

        const streams = AppState.get('streams') || {};
        const health = AppState.get('adminHealth') || {};
        const workers = AppState.get('workers') || {};
        const storage = AppState.get('system')?.storage || {};

        const activeViewers = streams.activeSessions || 0;
        const peakViewers = streams.peakSessions || activeViewers;
        
        const movies = health.totalMovies || 0;
        const shows = health.totalShows || 0;
        const totalMedia = movies + shows;

        const metadataStats = [
            { label: 'Complete', value: health.totalValid || 0, color: 'success' },
            { label: 'Failed', value: health.totalBroken || 0, color: 'danger' },
            { label: 'Manual Probe', value: health.totalManualProbe || 0, color: 'warning' },
        ];

        _container.innerHTML = `
            <div class="section">
                <div class="stats-grid">
                    ${StatCard.html({ label: 'Current Viewers', value: activeViewers, icon: 'users', color: activeViewers > 0 ? 'success' : 'info' })}
                    ${StatCard.html({ label: 'Peak Viewers', value: peakViewers, icon: 'activity', color: 'accent' })}
                    ${StatCard.html({ label: 'Metadata Queue', value: workers.queueSize || 0, icon: 'list', color: 'warning' })}
                    ${StatCard.html({ label: 'Library Size', value: totalMedia, icon: 'film', color: 'info' })}
                </div>

                <div class="card-grid-2">
                    <div class="data-card">
                        <div class="data-card-header">
                            <h3>Metadata Status Breakdown</h3>
                        </div>
                        <div class="data-card-body" style="height:300px;display:flex;align-items:center;justify-content:center">
                            <canvas id="analytics-meta-chart"></canvas>
                        </div>
                    </div>

                    <div class="data-card">
                        <div class="data-card-header">
                            <h3>Most Watched (Coming Soon)</h3>
                        </div>
                        <div class="data-card-body">
                            ${EmptyState.html('Media-level analytics will be available in a future update.', 'bar-chart-2')}
                        </div>
                    </div>
                </div>

                <div class="data-card" style="margin-top:var(--space-2xl)">
                    <div class="data-card-header">
                        <h3>Telegram Requests (Coming Soon)</h3>
                    </div>
                    <div class="data-card-body">
                        ${EmptyState.html('Telegram request volume and analytics will be available here.', 'message-circle')}
                    </div>
                </div>
            </div>
        `;

        lucide.createIcons({ nodes: [_container] });
        _renderChart(metadataStats);
    }

    function _renderChart(stats) {
        const ctx = document.getElementById('analytics-meta-chart');
        if (!ctx) return;

        if (_chartInstance) _chartInstance.destroy();

        const style = getComputedStyle(document.body);
        const colors = stats.map(s => style.getPropertyValue(`--${s.color}`).trim());
        const colorText = style.getPropertyValue('--text-primary').trim();

        _chartInstance = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: stats.map(s => s.label),
                datasets: [{
                    data: stats.map(s => s.value),
                    backgroundColor: colors,
                    borderWidth: 0,
                    hoverOffset: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '70%',
                plugins: {
                    legend: {
                        position: 'right',
                        labels: { color: colorText, padding: 20, font: { family: 'Inter' } }
                    }
                }
            }
        });
    }

    function destroy() {
        AppState.unsubscribe('streams', _renderUI);
        AppState.unsubscribe('adminHealth', _renderUI);
        if (_chartInstance) {
            _chartInstance.destroy();
            _chartInstance = null;
        }
        _container = null;
    }

    AppModules.register({
        id: 'analytics',
        title: 'Analytics',
        icon: 'bar-chart-2',
        render,
        destroy
    });

    return { render, destroy };
})();
