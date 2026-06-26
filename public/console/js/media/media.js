/**
 * STREAMFLIX ADMIN CONSOLE — Media Library Section
 */

const MediaModule = (() => {
    let _container = null;
    let _drawer = null;
    let _lastQuery = '';
    let _lastType = 'all';

    async function render(container, params = {}) {
        _container = container;
        _container.innerHTML = `<div class="section">${SkeletonLoader.table()}</div>`;

        try {
            // Check if deep linked
            if (params.fileId) {
                setTimeout(() => _openFileDrawer(params.fileId), 100);
            }

            await _loadData();
            _renderUI();
        } catch (err) {
            _container.innerHTML = EmptyState.html(`Failed to load media: ${err.message}`, 'alert-triangle');
        }
    }

    async function _loadData(q = _lastQuery, type = _lastType) {
        _lastQuery = q;
        _lastType = type;
        await Api.searchMedia(q, type);
    }

    function _renderUI() {
        if (!_container) return;

        const data = AppState.get('media') || { results: [], total: 0 };
        
        _container.innerHTML = `
            <div class="section">
                <div class="data-card">
                    <div class="data-card-header" style="flex-wrap:wrap">
                        <div style="flex:1" id="media-search-wrap"></div>
                        <div id="media-filter-wrap"></div>
                        <div style="font-size:var(--text-sm);color:var(--text-muted);white-space:nowrap">
                            Found ${data.total || 0} items
                        </div>
                    </div>
                    <div id="media-table-wrap"></div>
                </div>
            </div>
        `;

        // Render Search Bar
        SearchBar.render(document.getElementById('media-search-wrap'), {
            placeholder: 'Search movies, tv shows, filenames...',
            value: _lastQuery,
            onSearch: async (q) => {
                const tableWrap = document.getElementById('media-table-wrap');
                if (tableWrap) tableWrap.innerHTML = SkeletonLoader.table();
                await _loadData(q, _lastType);
                _renderTable();
            }
        });

        // Render Filter Bar
        FilterBar.render(document.getElementById('media-filter-wrap'), {
            options: [
                { value: 'all', label: 'All Media' },
                { value: 'movie', label: 'Movies' },
                { value: 'tv', label: 'TV Shows' },
                { value: 'unsupported_audio', label: 'Unsupported Audio' }
            ],
            selected: _lastType,
            onChange: async (t) => {
                const tableWrap = document.getElementById('media-table-wrap');
                if (tableWrap) tableWrap.innerHTML = SkeletonLoader.table();
                await _loadData(_lastQuery, t);
                _renderTable();
            }
        });

        _renderTable();
    }

    function _renderTable() {
        const wrap = document.getElementById('media-table-wrap');
        if (!wrap) return;

        const data = AppState.get('media');
        
        DataTable.render(wrap, {
            columns: [
                { 
                    key: 'fileId', 
                    label: 'ID', 
                    width: '80px',
                    className: 'cell-id' 
                },
                { 
                    key: 'title', 
                    label: 'Title',
                    render: (row) => `
                        <div class="cell-title">${_esc(row.title || row.fileName || 'Unknown')}</div>
                        <div class="cell-subtitle">
                            ${row.year || ''} ${row.year && row.container ? '•' : ''} ${row.container?.toUpperCase() || ''}
                        </div>
                    `
                },
                {
                    key: 'type',
                    label: 'Type',
                    width: '100px',
                    render: (row) => Badge.mediaType(row.type)
                },
                {
                    key: 'audio',
                    label: 'Audio',
                    render: (row) => {
                        const t = row.audioTracks || [];
                        if (t.length === 0) return '<span class="cell-muted">None</span>';
                        const first = t[0];
                        const icon = first.browserPlayable !== false ? '<i data-lucide="check" style="color:var(--success);width:12px"></i>' : '<i data-lucide="alert-circle" style="color:var(--danger);width:12px"></i>';
                        let html = `<div style="display:flex;align-items:center;gap:4px;font-size:var(--text-sm)">${icon} ${first.codec?.toUpperCase()} (${first.channels}ch)</div>`;
                        if (t.length > 1) html += `<div class="cell-subtitle">+${t.length - 1} more track(s)</div>`;
                        return html;
                    }
                },
                {
                    key: 'status',
                    label: 'Status',
                    width: '120px',
                    render: (row) => Badge.status(row.metadataStatus || 'COMPLETE')
                }
            ],
            rows: data.results,
            onRowClick: (row) => _openFileDrawer(row.fileId),
            emptyMessage: 'No media found matching your filters.'
        });

        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [wrap] });
    }

    async function _openFileDrawer(fileId) {
        _drawer = Drawer.open({
            title: `File ${fileId}`,
            body: `<div style="padding:var(--space-3xl);text-align:center"><i data-lucide="loader-2" class="animate-spin" style="width:32px;height:32px;color:var(--text-muted)"></i></div>`
        });

        try {
            const m = await Api.getFileMetadata(fileId);
            if (!m) throw new Error('Metadata not found');

            const posterUrl = m.poster && m.poster !== 'N/A' ? m.poster : 'https://placehold.co/100x150/141414/ffffff?text=No+Poster';

            const audioHtml = (m.audioTracks || []).map(t => `
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:var(--space-sm)">
                    <div>
                        <span style="font-weight:var(--weight-medium)">${t.language || 'Unknown'}</span>
                        <span style="color:var(--text-muted);font-size:var(--text-xs);margin-left:var(--space-sm)">${t.codec?.toUpperCase()} (${t.channels}ch)</span>
                    </div>
                    ${t.browserPlayable !== false 
                        ? '<i data-lucide="check" style="width:16px;color:var(--success)"></i>' 
                        : '<i data-lucide="alert-circle" style="width:16px;color:var(--danger)"></i>'}
                </div>
            `).join('') || '<div style="color:var(--text-muted);font-size:var(--text-sm)">No audio tracks</div>';

            const html = `
                <div style="display:flex;gap:var(--space-lg);margin-bottom:var(--space-2xl)">
                    <img src="${posterUrl}" style="width:100px;border-radius:var(--radius-md);box-shadow:var(--shadow-md)">
                    <div>
                        <h3 style="font-size:var(--text-xl);font-weight:var(--weight-bold);margin-bottom:var(--space-sm)">${_esc(m.title)}</h3>
                        <div style="display:flex;gap:var(--space-sm);margin-bottom:var(--space-md);flex-wrap:wrap">
                            ${Badge.mediaType(m.type)}
                            ${m.year ? `<span class="badge badge-default">${m.year}</span>` : ''}
                            <span class="badge badge-default">${m.container?.toUpperCase() || 'RAW'}</span>
                            ${Badge.status(m.metadataStatus)}
                        </div>
                        <div style="font-size:var(--text-sm);color:var(--text-muted);font-family:var(--font-mono)">TMDB: ${m.tmdbId || 'N/A'}</div>
                    </div>
                </div>

                <div class="data-card" style="margin-bottom:var(--space-xl)">
                    <div class="data-card-body">
                        <div style="font-size:var(--text-xs);color:var(--text-muted);text-transform:uppercase;margin-bottom:var(--space-md)">Audio Experience</div>
                        ${audioHtml}
                    </div>
                </div>

                <div style="margin-bottom:var(--space-xl)">
                    <div style="font-size:var(--text-xs);color:var(--text-muted);text-transform:uppercase;margin-bottom:var(--space-sm)">Overview</div>
                    <p style="font-size:var(--text-sm);color:var(--text-secondary);line-height:var(--leading-relaxed)">${_esc(m.overview) || 'No overview available.'}</p>
                </div>

                <div style="margin-bottom:var(--space-2xl)">
                    <div style="font-size:var(--text-xs);color:var(--text-muted);text-transform:uppercase;margin-bottom:var(--space-sm)">Raw JSON</div>
                    <pre style="background:#000;padding:var(--space-md);border-radius:var(--radius-md);font-family:var(--font-mono);font-size:var(--text-xs);color:#a1a1aa;overflow-x:auto;max-height:200px;border:1px solid var(--border)">${_esc(JSON.stringify(m, null, 2))}</pre>
                </div>
                
                <div class="actions-grid">
                    <button class="btn btn-secondary" onclick="MediaModule.refetch('${m.fileId}')">
                        <i data-lucide="refresh-cw" style="width:16px"></i> Refetch TMDB
                    </button>
                    <button class="btn btn-primary" onclick="MediaModule.edit('${m.fileId}')">
                        <i data-lucide="edit" style="width:16px"></i> Manual Edit
                    </button>
                </div>
            `;

            _drawer.setBody(html);

        } catch (err) {
            _drawer.setBody(EmptyState.html(err.message, 'alert-triangle'));
        }
    }

    async function _handleRefetch(fileId) {
        const confirmed = await ConfirmDialog.show({
            title: 'Refetch Metadata',
            message: 'Are you sure you want to force a refetch from TMDB? This will overwrite existing data.',
            type: 'warning'
        });

        if (confirmed) {
            try {
                Toast.info('Refetching...');
                await Api.refetchMetadata(fileId);
                Toast.success('Refetch queued');
                if (_drawer) _drawer.close();
                _loadData(); // reload table
            } catch (err) {
                Toast.error(err.message);
            }
        }
    }

    function _handleEdit(fileId) {
        if (_drawer) _drawer.close();
        AppRouter.navigate('metadata', { action: 'edit', fileId });
    }

    function _esc(str) { const d = document.createElement('div'); d.textContent = str || ''; return d.innerHTML; }

    AppModules.register({
        id: 'media',
        title: 'Media Library',
        icon: 'film',
        render
    });

    // Exposed for drawer buttons
    return { 
        render, 
        refetch: _handleRefetch,
        edit: _handleEdit
    };
})();
