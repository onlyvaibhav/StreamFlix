/**
 * STREAMFLIX ADMIN CONSOLE — Command Palette (Ctrl+K)
 * Fuzzy search across all registered commands, actions, and media.
 */

const AppCommands = (() => {
    let _overlay = null;
    let _input = null;
    let _resultsList = null;
    let _commands = [];
    let _filtered = [];
    let _activeIndex = 0;
    let _mediaSearchTimer = null;

    function init() {
        document.addEventListener('keydown', (e) => {
            if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
                e.preventDefault();
                toggle();
            }
        });
    }

    /** Register global commands */
    function register(cmdList) {
        _commands.push(...cmdList);
    }

    function toggle() {
        if (_overlay) close();
        else open();
    }

    function open() {
        if (_overlay) return;

        // Build command list from all modules + core
        _commands = [
            { id: 'nav-dash', group: 'Navigation', title: 'Go to Dashboard', icon: 'layout-dashboard', action: () => AppRouter.navigate('dashboard') },
            { id: 'nav-media', group: 'Navigation', title: 'Go to Media Library', icon: 'film', action: () => AppRouter.navigate('media') },
            { id: 'nav-meta', group: 'Navigation', title: 'Go to Metadata', icon: 'database', action: () => AppRouter.navigate('metadata') },
            { id: 'nav-stream', group: 'Navigation', title: 'Go to Streaming', icon: 'radio', action: () => AppRouter.navigate('streaming') },
            { id: 'nav-work', group: 'Navigation', title: 'Go to Workers', icon: 'cpu', action: () => AppRouter.navigate('workers') },
            { id: 'nav-tg', group: 'Navigation', title: 'Go to Telegram', icon: 'send', action: () => AppRouter.navigate('telegram') },
            { id: 'nav-logs', group: 'Navigation', title: 'Go to Logs', icon: 'terminal', action: () => AppRouter.navigate('logs') },
            { id: 'nav-sys', group: 'Navigation', title: 'Go to System', icon: 'server', action: () => AppRouter.navigate('system') },
            { id: 'nav-set', group: 'Navigation', title: 'Go to Settings', icon: 'settings', action: () => AppRouter.navigate('settings') },
            
            { id: 'act-sync', group: 'Actions', title: 'Run Telegram Sync', icon: 'refresh-cw', action: () => _execAction(Api.syncTelegram, 'Sync started') },
            { id: 'act-fix', group: 'Actions', title: 'Fix Broken Metadata', icon: 'wrench', action: () => _execAction(Api.fixBroken, 'Fix running') },
            { id: 'act-retry', group: 'Actions', title: 'Retry Failed Lookups', icon: 'rotate-ccw', action: () => _execAction(Api.retryFailed, 'Retry running') },
            { id: 'act-pause', group: 'Actions', title: 'Pause Worker', icon: 'pause', action: () => _execAction(Api.pauseWorker, 'Worker paused') },
            { id: 'act-resume', group: 'Actions', title: 'Resume Worker', icon: 'play', action: () => _execAction(Api.resumeWorker, 'Worker resumed') },
        ];

        // Gather from registered modules
        if (typeof AppModules !== 'undefined') {
            AppModules.getAll().forEach(m => {
                if (m.commands) _commands.push(...m.commands);
            });
        }

        _overlay = document.createElement('div');
        _overlay.className = 'command-overlay';
        _overlay.onclick = (e) => { if (e.target === _overlay) close(); };

        const palette = document.createElement('div');
        palette.className = 'command-palette';

        const wrap = document.createElement('div');
        wrap.className = 'command-input-wrap';
        wrap.innerHTML = `<i data-lucide="search" style="width:20px;height:20px"></i>`;

        _input = document.createElement('input');
        _input.className = 'command-input';
        _input.type = 'text';
        _input.placeholder = 'Search commands, media, or actions...';
        _input.oninput = _handleInput;
        _input.onkeydown = _handleKeydown;

        wrap.appendChild(_input);
        palette.appendChild(wrap);

        _resultsList = document.createElement('div');
        _resultsList.className = 'command-results';
        palette.appendChild(_resultsList);

        const footer = document.createElement('div');
        footer.className = 'command-footer';
        footer.innerHTML = `
            <span><kbd class="header-kbd">↑↓</kbd> to navigate</span>
            <span><kbd class="header-kbd">↵</kbd> to select</span>
            <span><kbd class="header-kbd">Esc</kbd> to close</span>
        `;
        palette.appendChild(footer);

        _overlay.appendChild(palette);
        document.body.appendChild(_overlay);

        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [_overlay] });
        
        _input.focus();
        _filter('');
    }

    function close() {
        if (_overlay) {
            _overlay.remove();
            _overlay = null;
            _input = null;
            _resultsList = null;
        }
    }

    async function _execAction(apiCall, successMsg) {
        close();
        try {
            await apiCall();
            Toast.success(successMsg);
        } catch (err) {
            Toast.error(err.message);
        }
    }

    function _handleInput() {
        const q = _input.value.trim().toLowerCase();
        
        // If typing, perhaps search media via API if no local matches?
        if (_mediaSearchTimer) clearTimeout(_mediaSearchTimer);
        
        _filter(q);

        if (q.length >= 3 && _filtered.length < 5) {
            _mediaSearchTimer = setTimeout(() => _searchMediaApi(q), 500);
        }
    }

    async function _searchMediaApi(q) {
        try {
            const data = await Api.searchMedia(q);
            if (data && data.results && data.results.length > 0) {
                const mediaCmds = data.results.slice(0, 5).map(m => ({
                    id: `media-${m.fileId}`,
                    group: 'Media Library',
                    title: m.title || `File ${m.fileId}`,
                    subtitle: `ID: ${m.fileId} • ${m.type.toUpperCase()}`,
                    icon: m.type === 'tv' ? 'tv' : 'film',
                    action: () => {
                        close();
                        AppRouter.navigate('media', { fileId: m.fileId });
                    }
                }));
                
                // Add to current filtered list
                const existingIds = new Set(_filtered.map(f => f.id));
                const newCmds = mediaCmds.filter(c => !existingIds.has(c.id));
                _filtered.push(...newCmds);
                _renderResults();
            }
        } catch (err) {
            // silent fail for auto-search
        }
    }

    function _filter(q) {
        if (!q) {
            _filtered = _commands;
        } else {
            _filtered = _commands.filter(c => 
                c.title.toLowerCase().includes(q) || 
                (c.group && c.group.toLowerCase().includes(q))
            );
        }
        _activeIndex = 0;
        _renderResults();
    }

    function _renderResults() {
        if (!_resultsList) return;
        _resultsList.innerHTML = '';

        if (_filtered.length === 0) {
            _resultsList.innerHTML = `<div style="padding:var(--space-xl);text-align:center;color:var(--text-muted)">No results found.</div>`;
            return;
        }

        // Group results
        const groups = {};
        for (const cmd of _filtered) {
            const g = cmd.group || 'Other';
            if (!groups[g]) groups[g] = [];
            groups[g].push(cmd);
        }

        let globalIndex = 0;
        for (const [groupName, cmds] of Object.entries(groups)) {
            const glabel = document.createElement('div');
            glabel.className = 'command-group-label';
            glabel.textContent = groupName;
            _resultsList.appendChild(glabel);

            for (const cmd of cmds) {
                const item = document.createElement('div');
                item.className = 'command-item';
                if (globalIndex === _activeIndex) item.classList.add('active');
                
                const idx = globalIndex; // capture for closure
                item.onclick = () => {
                    cmd.action();
                };
                item.onmouseenter = () => {
                    _activeIndex = idx;
                    _updateActiveItem();
                };

                const subtitleHtml = cmd.subtitle ? `<div style="font-size:var(--text-xs);color:var(--text-muted)">${_esc(cmd.subtitle)}</div>` : '';

                item.innerHTML = `
                    <i data-lucide="${cmd.icon || 'chevron-right'}" style="width:16px;height:16px;color:var(--text-muted)"></i>
                    <div class="command-label">
                        <div>${_esc(cmd.title)}</div>
                        ${subtitleHtml}
                    </div>
                `;
                _resultsList.appendChild(item);
                globalIndex++;
            }
        }

        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [_resultsList] });
        _scrollActiveIntoView();
    }

    function _updateActiveItem() {
        if (!_resultsList) return;
        const items = _resultsList.querySelectorAll('.command-item');
        items.forEach((item, idx) => {
            if (idx === _activeIndex) item.classList.add('active');
            else item.classList.remove('active');
        });
    }

    function _scrollActiveIntoView() {
        if (!_resultsList) return;
        const activeItem = _resultsList.querySelector('.command-item.active');
        if (activeItem) {
            activeItem.scrollIntoView({ block: 'nearest' });
        }
    }

    function _handleKeydown(e) {
        if (e.key === 'ArrowDown') {
            e.preventDefault();
            _activeIndex = Math.min(_activeIndex + 1, _filtered.length - 1);
            _updateActiveItem();
            _scrollActiveIntoView();
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            _activeIndex = Math.max(_activeIndex - 1, 0);
            _updateActiveItem();
            _scrollActiveIntoView();
        } else if (e.key === 'Enter') {
            e.preventDefault();
            const cmd = _filtered[_activeIndex];
            if (cmd) cmd.action();
        } else if (e.key === 'Escape') {
            e.preventDefault();
            close();
        }
    }

    function _esc(str) { const d = document.createElement('div'); d.textContent = str || ''; return d.innerHTML; }

    return { init, register, toggle, open, close };
})();

window.AppCommands = AppCommands;
