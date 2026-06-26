/**
 * STREAMFLIX ADMIN CONSOLE — Workers Module
 */

const WorkersModule = (() => {
    let _container = null;

    async function render(container) {
        _container = container;
        _container.innerHTML = `<div class="section">${SkeletonLoader.card(2)}</div>`;

        try {
            await Promise.allSettled([
                AppState.isStale('workers') ? Api.getWorkerStatus() : Promise.resolve(),
                AppState.isStale('audioAudit') ? Api.getAudioAudit() : Promise.resolve()
            ]);
            _renderUI();
            
            // Subscribe to live updates
            AppState.subscribe('workers', _renderUI);
            AppState.subscribe('audioAudit', _renderUI);
        } catch (err) {
            _container.innerHTML = EmptyState.html(`Failed to load workers: ${err.message}`, 'alert-triangle');
        }
    }

    function _renderUI() {
        if (!_container) return;

        const workers = AppState.get('workers') || {};
        const audio = AppState.get('audioAudit') || {};

        const isPaused = workers.workerPaused;

        // Action controls html
        const actionsHtml = `
            <div class="actions-grid" style="margin-top:var(--space-lg)">
                <button class="action-card ${isPaused ? 'btn-success' : 'btn-warning'}" style="justify-content:center" onclick="WorkersModule.togglePause()">
                    <i data-lucide="${isPaused ? 'play' : 'pause'}" style="width:18px"></i> 
                    ${isPaused ? 'Resume Worker' : 'Pause Worker'}
                </button>
                <button class="action-card" style="justify-content:center" onclick="WorkersModule.retryFailed()">
                    <i data-lucide="rotate-ccw" style="width:18px"></i> Retry Failed
                </button>
            </div>
        `;

        _container.innerHTML = `
            <div class="section">
                <!-- Metadata Worker Card -->
                <div style="margin-bottom:var(--space-2xl)">
                    ${WorkerCard.html({
                        title: 'Metadata Worker Loop',
                        description: 'Handles auto-matching, TMDB fetching, and repairing broken records.',
                        paused: isPaused,
                        queueSize: workers.queueSize,
                        activeCount: workers.activeSessions
                    })}
                    ${actionsHtml}
                </div>

                <!-- Audio Audit & Sweep Card -->
                <div class="data-card">
                    <div class="data-card-header">
                        <h3>Audio Compatibility Sweep</h3>
                    </div>
                    <div class="data-card-body">
                        <div class="stats-grid" style="margin-bottom:var(--space-xl)">
                            ${StatCard.html({ label: 'Analyzed Files', value: audio.auditedFiles, icon: 'file-audio', color: 'info' })}
                            ${StatCard.html({ label: 'Unsupported', value: audio.needsTranscode, icon: 'alert-triangle', color: audio.needsTranscode > 0 ? 'danger' : 'success' })}
                            ${StatCard.html({ label: 'Missing Info', value: audio.missingAudioInfo, icon: 'help-circle', color: 'warning' })}
                        </div>

                        <div style="background:var(--bg-elevated);padding:var(--space-xl);border-radius:var(--radius-lg);border:1px solid var(--border)">
                            <h4 style="font-size:var(--text-sm);font-weight:var(--weight-semibold);margin-bottom:var(--space-md)">Run FFProbe Sweep</h4>
                            <p style="font-size:var(--text-sm);color:var(--text-secondary);margin-bottom:var(--space-lg)">
                                Analyzes physical files to extract audio codec and channel information. Required for browser playability detection.
                            </p>
                            
                            <div style="display:flex;gap:var(--space-md);align-items:flex-end;flex-wrap:wrap">
                                <div style="flex:1;min-width:150px">
                                    <label class="form-label" style="font-size:var(--text-xs)">File Limit (0 = all)</label>
                                    <input type="number" id="audio-sweep-limit" class="form-input" value="10">
                                </div>
                                <div style="flex:1;min-width:150px">
                                    <label class="form-label" style="font-size:var(--text-xs)">Concurrency</label>
                                    <input type="number" id="audio-sweep-concurrency" class="form-input" value="3" max="10">
                                </div>
                                <button class="btn btn-primary" style="height:42px" onclick="WorkersModule.startAudioSweep()">
                                    <i data-lucide="play" style="width:16px"></i> Start Sweep
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `;

        lucide.createIcons({ nodes: [_container] });
    }

    async function _togglePause() {
        const workers = AppState.get('workers') || {};
        try {
            if (workers.workerPaused) {
                await Api.resumeWorker();
                Toast.success('Worker resumed');
            } else {
                await Api.pauseWorker();
                Toast.warning('Worker paused');
            }
        } catch (err) {
            Toast.error(err.message);
        }
    }

    async function _retryFailed() {
        try {
            await Api.retryFailed();
            Toast.success('Retry queued');
        } catch (err) {
            Toast.error(err.message);
        }
    }

    async function _startAudioSweep() {
        const limit = parseInt(document.getElementById('audio-sweep-limit').value) || 0;
        const conc = parseInt(document.getElementById('audio-sweep-concurrency').value) || 3;

        try {
            await Api.startAudioSweep(limit, conc);
            Toast.success(`Audio sweep started (limit: ${limit || 'all'}, concurrency: ${conc})`);
        } catch (err) {
            Toast.error(err.message);
        }
    }

    function destroy() {
        AppState.unsubscribe('workers', _renderUI);
        AppState.unsubscribe('audioAudit', _renderUI);
        _container = null;
    }

    AppModules.register({
        id: 'workers',
        title: 'Workers',
        icon: 'cpu',
        render,
        destroy,
        commands: [
            { id: 'audio-sweep', group: 'Actions', title: 'Start Audio Sweep', icon: 'file-audio', action: () => _execAction(Api.startAudioSweep, 'Sweep started') }
        ]
    });

    async function _execAction(apiCall, msg) {
        try { await apiCall(); Toast.success(msg); } catch (e) { Toast.error(e.message); }
    }

    return { render, destroy, togglePause: _togglePause, retryFailed: _retryFailed, startAudioSweep: _startAudioSweep };
})();
