/**
 * STREAMFLIX ADMIN CONSOLE — Dashboard Section
 */

const DashboardModule = (() => {
    let _container = null;
    let _chartInstance = null;

    async function render(container) {
        _container = container;
        container.innerHTML = `<div class="section">${SkeletonLoader.stats()}${SkeletonLoader.card(2)}</div>`;

        // Use Promise.allSettled so one failure doesn't crash the whole dashboard
        const results = await Promise.allSettled([
            AppState.isStale('adminHealth') ? Api.getAdminHealth() : Promise.resolve(),
            AppState.isStale('audioAudit') ? Api.getAudioAudit() : Promise.resolve(),
            AppState.isStale('system', 120000) ? Api.getStorage() : Promise.resolve()
        ]);

        // Log failures but render whatever we have
        results.forEach((r, i) => {
            if (r.status === 'rejected') {
                const names = ['adminHealth', 'audioAudit', 'storage'];
                console.warn(`[Dashboard] Failed to load ${names[i]}:`, r.reason?.message);
            }
        });
        
        _renderUI();

        // Subscribe to state changes for live updates
        AppState.subscribe('adminHealth', _renderUI);
        AppState.subscribe('streams', _renderUI);
        AppState.subscribe('workers', _renderUI);
    }

    function _renderUI() {
        if (!_container) return;

        const adminHealth = AppState.get('adminHealth') || {};
        const audio = AppState.get('audioAudit') || {};
        const storage = AppState.get('system')?.storage || {};
        const streams = AppState.get('streams') || {};

        const total = adminHealth.total || 0;
        const valid = adminHealth.valid || 0;
        const broken = adminHealth.broken || 0;
        const activeViewers = streams.activeViewers || 0;
        
        // Build stat cards
        const statsHtml = `
            <div class="stats-grid">
                ${StatCard.html({ label: 'Total Media', value: total, icon: 'film', color: 'info' })}
                ${StatCard.html({ label: 'Valid Metadata', value: valid, icon: 'check-circle', color: 'success' })}
                ${StatCard.html({ label: 'Active Viewers', value: activeViewers, icon: 'users', color: activeViewers > 0 ? 'success' : 'info', trend: activeViewers > 0 ? 'Live' : '', trendDir: 'up' })}
                ${StatCard.html({ label: 'Broken Files', value: broken, icon: 'alert-circle', color: broken > 0 ? 'danger' : 'success' })}
            </div>
        `;

        // Storage card content
        let storageContent;
        if (storage.error) {
            storageContent = `<div style="height:300px;display:flex;align-items:center;justify-content:center;color:var(--text-muted)">
                <div style="text-align:center">
                    <i data-lucide="hard-drive-download" style="width:32px;height:32px;margin-bottom:var(--space-md);opacity:0.4"></i>
                    <p>Storage info unavailable</p>
                </div>
            </div>`;
        } else {
            storageContent = `<div style="height:300px;display:flex;align-items:center;justify-content:center">
                <canvas id="dash-storage-chart"></canvas>
            </div>`;
        }

        // Content
        _container.innerHTML = `
            <div class="section">
                ${statsHtml}
                
                <div class="card-grid-2" style="margin-bottom:var(--space-2xl)">
                    <div class="data-card">
                        <div class="data-card-header">
                            <h3>Storage Usage</h3>
                        </div>
                        <div class="data-card-body">
                            ${storageContent}
                        </div>
                    </div>
                    
                    <div class="data-card">
                        <div class="data-card-header">
                            <h3>Metadata Health</h3>
                        </div>
                        <div class="data-card-body">
                            <div style="margin-bottom:var(--space-lg)">
                                <div style="display:flex;justify-content:space-between;margin-bottom:var(--space-xs);font-size:var(--text-sm)">
                                    <span style="color:var(--text-secondary)">Valid Metadata</span>
                                    <span style="font-weight:var(--weight-bold)">${valid}</span>
                                </div>
                                ${ProgressBar.html(100 * (valid / Math.max(1, total)), 'success')}
                            </div>
                            
                            <div style="margin-bottom:var(--space-lg)">
                                <div style="display:flex;justify-content:space-between;margin-bottom:var(--space-xs);font-size:var(--text-sm)">
                                    <span style="color:var(--text-secondary)">Needs Manual Probe</span>
                                    <span style="font-weight:var(--weight-bold);color:var(--warning)">${adminHealth.manualProbeNeeded || 0}</span>
                                </div>
                                ${ProgressBar.html(100 * ((adminHealth.manualProbeNeeded || 0) / Math.max(1, total)), 'warning')}
                            </div>
                            
                            <div>
                                <div style="display:flex;justify-content:space-between;margin-bottom:var(--space-xs);font-size:var(--text-sm)">
                                    <span style="color:var(--text-secondary)">Unsupported Audio</span>
                                    <span style="font-weight:var(--weight-bold);color:var(--danger)">${adminHealth.unsupportedAudio || 0}</span>
                                </div>
                                ${ProgressBar.html(100 * ((adminHealth.unsupportedAudio || 0) / Math.max(1, total)), 'danger')}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `;

        lucide.createIcons({ nodes: [_container] });

        // Render Chart (only if storage is available)
        if (!storage.error) {
            _renderChart(storage);
        }
    }

    function _renderChart(storage) {
        const ctx = document.getElementById('dash-storage-chart');
        if (!ctx) return;

        if (_chartInstance) _chartInstance.destroy();

        const usedRaw = storage.used || 0;
        const freeRaw = storage.free || 1; // avoid /0
        
        // CSS vars
        const style = getComputedStyle(document.body);
        const colorAccent = style.getPropertyValue('--accent').trim();
        const colorBorder = style.getPropertyValue('--border').trim();
        const colorText = style.getPropertyValue('--text-primary').trim();

        _chartInstance = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: ['Used', 'Free'],
                datasets: [{
                    data: [usedRaw, freeRaw],
                    backgroundColor: [colorAccent, colorBorder],
                    borderWidth: 0,
                    hoverOffset: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '75%',
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: { color: colorText, padding: 20, font: { family: 'Inter' } }
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                const label = context.label || '';
                                const valBytes = context.raw || 0;
                                const valGB = (valBytes / (1024*1024*1024)).toFixed(2);
                                return `${label}: ${valGB} GB`;
                            }
                        }
                    }
                }
            }
        });
    }

    // Cleanup when leaving route
    function destroy() {
        AppState.unsubscribe('adminHealth', _renderUI);
        AppState.unsubscribe('streams', _renderUI);
        AppState.unsubscribe('workers', _renderUI);
        if (_chartInstance) {
            _chartInstance.destroy();
            _chartInstance = null;
        }
        _container = null;
    }

    AppModules.register({
        id: 'dashboard',
        title: 'Dashboard',
        icon: 'layout-dashboard',
        render,
        destroy
    });

    return { render, destroy };
})();
