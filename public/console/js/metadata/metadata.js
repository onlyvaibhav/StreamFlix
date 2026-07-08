/**
 * STREAMFLIX ADMIN CONSOLE — Metadata Module
 * Handles issues table, auto-match, and the metadata editor modal.
 */

const MetadataModule = (() => {
    let _container = null;
    let _modal = null;

    async function render(container, params = {}) {
        _container = container;
        _container.innerHTML = `<div class="section">${SkeletonLoader.table()}</div>`;

        try {
            if (params.action === 'edit' && params.fileId) {
                setTimeout(() => _openEditor(params.fileId), 100);
            }

            await _loadData();
            _renderUI();
        } catch (err) {
            _container.innerHTML = EmptyState.html(`Failed to load issues: ${err.message}`, 'alert-triangle');
        }
    }

    async function _loadData() {
        await Api.getIssues();
    }

    function _renderUI() {
        if (!_container) return;

        const data = AppState.get('metadata') || [];

        _container.innerHTML = `
            <div class="section">
                <div class="data-card">
                    <div class="data-card-header" style="flex-wrap:wrap">
                        <h3>Metadata Health Issues <span class="badge badge-danger">${data.length}</span></h3>
                        <div style="display:flex;gap:var(--space-md)">
                            <button class="btn btn-secondary" onclick="MetadataModule.retryFailed()">
                                <i data-lucide="refresh-cw" style="width:16px"></i> Retry Failed
                            </button>
                            <button class="btn btn-secondary" onclick="MetadataModule.autoMatchAll()">
                                <i data-lucide="wand-2" style="width:16px"></i> Auto Match All
                            </button>
                            <button class="btn btn-primary" onclick="MetadataModule.fixBroken()">
                                <i data-lucide="wrench" style="width:16px"></i> Run Repair Worker
                            </button>
                        </div>
                    </div>
                    <div id="metadata-table-wrap"></div>
                </div>
            </div>
        `;

        _renderTable(data);
    }

    function _renderTable(data) {
        const wrap = document.getElementById('metadata-table-wrap');
        if (!wrap) return;

        DataTable.render(wrap, {
            columns: [
                { key: 'fileId', label: 'ID', width: '80px', className: 'cell-id' },
                { 
                    key: 'title', 
                    label: 'File / Title',
                    render: (row) => `
                        <div class="cell-title truncate" style="max-width:300px" title="${_esc(row.title || row.fileName)}">${_esc(row.title || row.fileName)}</div>
                        <div class="cell-subtitle">${row.year || ''}</div>
                    `
                },
                {
                    key: 'status',
                    label: 'State & Issues',
                    render: (row) => {
                        let html = `<div style="display:flex;gap:4px;flex-wrap:wrap">`;
                        html += Badge.status(row.metadataStatus);
                        if (row.issues) {
                            html += row.issues.map(i => Badge.issue(i)).join('');
                        }
                        html += `</div>`;
                        return html;
                    }
                },
                {
                    key: 'lastError',
                    label: 'Last Error',
                    render: (row) => {
                        if (!row.lastError) return '<span class="cell-muted">—</span>';
                        return `<div class="truncate cell-muted" style="max-width:250px" title="${_esc(row.lastError)}">${_esc(row.lastError)}</div>`;
                    }
                },
                {
                    key: 'actions',
                    label: 'Actions',
                    width: '180px',
                    render: (row) => `
                        <div style="display:flex;gap:var(--space-sm)">
                            <button class="btn btn-secondary btn-sm" onclick="event.stopPropagation(); MetadataModule.autoMatch('${row.fileId}')" title="Auto Match">
                                <i data-lucide="wand-2" style="width:14px"></i> Match
                            </button>
                            <button class="btn btn-primary btn-sm" onclick="event.stopPropagation(); MetadataModule.edit('${row.fileId}')">
                                <i data-lucide="edit" style="width:14px"></i> Fix
                            </button>
                        </div>
                    `
                }
            ],
            rows: data,
            onRowClick: (row) => _openEditor(row.fileId),
            emptyMessage: 'No metadata issues found. Your library is healthy.'
        });

        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [wrap] });
    }

    async function _openEditor(fileId) {
        // Show loading modal first
        _modal = Modal.open({
            title: `Edit Metadata (ID: ${fileId})`,
            body: `<div style="padding:var(--space-2xl);text-align:center"><i data-lucide="loader-2" class="animate-spin" style="width:32px;color:var(--text-muted)"></i></div>`
        });

        try {
            const m = await Api.getFileMetadata(fileId);
            if (!m) throw new Error('Metadata not found');

            const isTV = m.type === 'tv';

            const bodyHtml = `
                <div style="display:flex;gap:var(--space-xl);margin-bottom:var(--space-xl)">
                    <div style="flex:1">
                        <div class="form-group">
                            <label class="form-label">Filename</label>
                            <div class="form-input" style="background:var(--bg-elevated);color:var(--text-muted);font-family:var(--font-mono);font-size:var(--text-xs);word-break:break-all">${_esc(m.fileName)}</div>
                        </div>
                        
                        <div class="form-row">
                            <div class="form-group">
                                <label class="form-label">Title</label>
                                <input type="text" id="edit-title" class="form-input" value="${_esc(m.title)}">
                            </div>
                            <div class="form-group">
                                <label class="form-label">Year</label>
                                <input type="number" id="edit-year" class="form-input" value="${m.year || ''}">
                            </div>
                        </div>

                        <div class="form-row">
                            <div class="form-group">
                                <label class="form-label">Type</label>
                                <select id="edit-type" class="form-input form-select" onchange="MetadataModule.toggleTVSettings(this.value)">
                                    <option value="movie" ${!isTV ? 'selected' : ''}>Movie</option>
                                    <option value="tv" ${isTV ? 'selected' : ''}>TV Show</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label class="form-label">TMDB ID</label>
                                <input type="number" id="edit-tmdb" class="form-input" value="${m.tmdbId || ''}" placeholder="Optional">
                            </div>
                        </div>

                        <div class="form-row" id="edit-tv-fields" style="display:${isTV ? 'grid' : 'none'}">
                            <div class="form-group">
                                <label class="form-label">Season</label>
                                <input type="number" id="edit-season" class="form-input" value="${m.season || ''}">
                            </div>
                            <div class="form-group">
                                <label class="form-label">Episode</label>
                                <input type="number" id="edit-episode" class="form-input" value="${m.episode || ''}">
                            </div>
                        </div>

                        <div class="form-group">
                            <label class="form-label">Overview</label>
                            <textarea id="edit-overview" class="form-input" style="min-height:100px">${_esc(m.overview || '')}</textarea>
                        </div>
                    </div>

                    <div style="width:200px;display:flex;flex-direction:column;gap:var(--space-md)">
                        <img src="${m.poster && m.poster !== 'N/A' ? m.poster : 'https://placehold.co/200x300/141414/ffffff?text=No+Poster'}" style="width:100%;border-radius:var(--radius-md);border:1px solid var(--border)">
                        
                        <div class="data-card">
                            <div class="data-card-body" style="padding:var(--space-md);font-size:var(--text-xs)">
                                <div style="margin-bottom:var(--space-sm);color:var(--text-muted)">State</div>
                                <div style="margin-bottom:var(--space-md)">${Badge.status(m.metadataStatus)}</div>
                                
                                <div style="margin-bottom:var(--space-sm);color:var(--text-muted)">Confidence</div>
                                <div style="margin-bottom:var(--space-md)">${m.confidence ? Math.round(m.confidence*100)+'%' : 'N/A'}</div>
                                
                                <div style="color:var(--text-muted)">Last Fetched</div>
                                <div>${m.fetchedAt ? new Date(m.fetchedAt).toLocaleDateString() : 'Never'}</div>
                            </div>
                        </div>
                        
                        <a href="https://www.themoviedb.org/search?query=${encodeURIComponent(m.title || m.fileName)}" target="_blank" class="btn btn-secondary btn-sm" style="width:100%">
                            <i data-lucide="external-link" style="width:14px"></i> Search TMDB
                        </a>
                    </div>
                </div>
            `;

            const footerHtml = `
                <button class="btn btn-secondary" onclick="MetadataModule.closeEditor()">Cancel</button>
                <button class="btn btn-success" onclick="MetadataModule.saveFix('${fileId}', true)">
                    <i data-lucide="check" style="width:16px"></i> Save & Queue Fetch
                </button>
                <button class="btn btn-primary" onclick="MetadataModule.saveManual('${fileId}')">
                    Save Only
                </button>
            `;

            _modal = Modal.open({
                title: `Edit Metadata (ID: ${fileId})`,
                body: bodyHtml,
                footer: footerHtml,
                className: 'modal-large'
            });

            // Adjust width for this specific modal
            _modal.getPanel().style.width = '720px';

        } catch (err) {
            _modal = Modal.open({
                title: 'Error',
                body: EmptyState.html(err.message, 'alert-triangle'),
                footer: `<button class="btn btn-secondary" onclick="MetadataModule.closeEditor()">Close</button>`
            });
        }
    }

    // ── Exposed Action Handlers ──

    async function _handleAutoMatchAll() {
        const confirmed = await ConfirmDialog.show({
            title: 'Auto Match All',
            message: 'Queue all missing items for TMDB auto-discovery? This may take a while depending on TMDB limits.',
        });
        if (!confirmed) return;

        try {
            await Api.autoMatchAll();
            Toast.success('Auto-match queue started');
            _loadData();
        } catch (err) {
            Toast.error(err.message);
        }
    }

    async function _handleRetryFailed() {
        const confirmed = await ConfirmDialog.show({
            title: 'Retry Failed',
            message: 'Reset all MANUAL_REVIEW items back to NEW? They will be retried automatically.',
        });
        if (!confirmed) return;

        try {
            await Api.retryFailed();
            Toast.success('Retry queue started');
            _loadData();
        } catch (err) {
            Toast.error(err.message);
        }
    }

    async function _handleAutoMatch(fileId) {
        try {
            await Api.fixMetadata(fileId, null, null); // passing null triggers auto-match in backend
            Toast.success('Match queued');
            _loadData();
        } catch (err) {
            Toast.error(err.message);
        }
    }

    async function _handleFixBroken() {
        try {
            await Api.fixBroken();
            Toast.success('Repair worker started');
        } catch (err) {
            Toast.error(err.message);
        }
    }

    function _toggleTVSettings(val) {
        const el = document.getElementById('edit-tv-fields');
        if (el) el.style.display = val === 'tv' ? 'grid' : 'none';
    }

    async function _handleSaveFix(fileId, queueFetch = false) {
        const tmdbId = document.getElementById('edit-tmdb').value;
        const type = document.getElementById('edit-type').value;

        if (queueFetch && !tmdbId) {
            Toast.warning('TMDB ID is required to queue a fetch.');
            return;
        }

        try {
            const btn = event.currentTarget;
            btn.disabled = true;
            btn.innerHTML = '<i data-lucide="loader-2" class="animate-spin" style="width:16px"></i> Saving...';
            lucide.createIcons({ nodes: [btn] });

            if (queueFetch) {
                await Api.fixMetadata(fileId, tmdbId, type);
                Toast.success('Saved and fetch queued');
            } else {
                await _handleSaveManual(fileId);
            }

            if (_modal) _modal.close();
            _loadData();
        } catch (err) {
            Toast.error(err.message);
            event.currentTarget.disabled = false;
        }
    }

    async function _handleSaveManual(fileId) {
        const fields = {
            title: document.getElementById('edit-title').value,
            year: parseInt(document.getElementById('edit-year').value) || null,
            type: document.getElementById('edit-type').value,
            overview: document.getElementById('edit-overview').value,
            tmdbId: parseInt(document.getElementById('edit-tmdb').value) || null,
            metadataStatus: 'MANUAL_REVIEW'
        };

        if (fields.type === 'tv') {
            fields.season = parseInt(document.getElementById('edit-season').value) || 1;
            fields.episode = parseInt(document.getElementById('edit-episode').value) || 1;
        }

        try {
            const btn = event.currentTarget;
            btn.disabled = true;
            await Api.manualOverride(fileId, fields);
            Toast.success('Saved overrides');
            if (_modal) _modal.close();
            _loadData();
        } catch (err) {
            Toast.error(err.message);
            event.currentTarget.disabled = false;
        }
    }

    function _esc(str) { const d = document.createElement('div'); d.textContent = str || ''; return d.innerHTML; }

    AppModules.register({
        id: 'metadata',
        title: 'Metadata Health',
        icon: 'database',
        render
    });

    return {
        render,
        autoMatchAll: _handleAutoMatchAll,
        autoMatch: _handleAutoMatch,
        fixBroken: _handleFixBroken,
        edit: _openEditor,
        closeEditor: () => { if (_modal) _modal.close(); },
        toggleTVSettings: _toggleTVSettings,
        saveFix: _handleSaveFix,
        saveManual: _handleSaveManual,
        retryFailed: _handleRetryFailed
    };
})();
