/**
 * LogConsole component — full-featured log terminal
 */
const LogConsole = (() => {
    function render(container, logs = []) {
        container.innerHTML = `
            <div class="data-card animate-fade">
                <div class="data-card-body" style="padding:var(--space-md)">
                    <div class="log-toolbar" id="log-toolbar">
                        <!-- Toolbar populated below -->
                    </div>
                    <div class="log-terminal" id="log-terminal">
                        <!-- Logs populated below -->
                    </div>
                </div>
            </div>
        `;

        const toolbar = document.getElementById('log-toolbar');
        const terminal = document.getElementById('log-terminal');

        // State
        let isPaused = false;
        let filterSearch = '';
        let filterLevel = 'all';
        let autoScroll = true;

        // Toolbar HTML
        toolbar.innerHTML = `
            <button class="btn btn-secondary btn-sm" id="btn-pause">
                <i data-lucide="pause" style="width:14px;height:14px"></i> Pause
            </button>
            <div style="flex:1;max-width:300px">
                <input type="text" id="log-search" class="form-input" style="padding:0.3rem 0.6rem;font-size:var(--text-xs)" placeholder="Search logs...">
            </div>
            <select id="log-level" class="form-input form-select" style="width:auto;padding:0.3rem 1.8rem 0.3rem 0.6rem;font-size:var(--text-xs)">
                <option value="all">All Levels</option>
                <option value="info">Info</option>
                <option value="warn">Warnings</option>
                <option value="error">Errors</option>
                <option value="success">Success</option>
            </select>
            <div style="flex:1"></div>
            <label style="display:flex;align-items:center;gap:0.25rem;font-size:var(--text-xs);cursor:pointer;color:var(--text-muted)">
                <input type="checkbox" id="log-autoscroll" checked> Auto-scroll
            </label>
            <button class="btn btn-ghost btn-sm" id="btn-export">
                <i data-lucide="download" style="width:14px;height:14px"></i> Export
            </button>
            <button class="btn btn-ghost btn-sm" id="btn-clear" style="color:var(--danger)">
                <i data-lucide="trash-2" style="width:14px;height:14px"></i> Clear
            </button>
        `;

        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [toolbar] });

        // Handlers
        document.getElementById('btn-pause').onclick = (e) => {
            isPaused = !isPaused;
            const btn = e.currentTarget;
            btn.innerHTML = isPaused ? '<i data-lucide="play" style="width:14px;height:14px"></i> Resume' : '<i data-lucide="pause" style="width:14px;height:14px"></i> Pause';
            btn.classList.toggle('btn-warning', isPaused);
            btn.classList.toggle('btn-secondary', !isPaused);
            lucide.createIcons({ nodes: [btn] });
        };

        document.getElementById('log-search').oninput = (e) => {
            filterSearch = e.target.value.toLowerCase();
            updateDisplay(AppState.get('logs') || []);
        };

        document.getElementById('log-level').onchange = (e) => {
            filterLevel = e.target.value;
            updateDisplay(AppState.get('logs') || []);
        };

        document.getElementById('log-autoscroll').onchange = (e) => {
            autoScroll = e.target.checked;
        };

        document.getElementById('btn-clear').onclick = () => {
            AppState.reset('logs');
            terminal.innerHTML = '';
        };

        document.getElementById('btn-export').onclick = () => {
            const currentLogs = AppState.get('logs') || [];
            const text = currentLogs.map(l => `[${new Date(l.timestamp).toISOString()}] [${l.source.toUpperCase()}] [${l.type.toUpperCase()}] ${l.message}`).join('\n');
            const blob = new Blob([text], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `streamflix-logs-${new Date().toISOString().replace(/:/g, '-')}.txt`;
            a.click();
            URL.revokeObjectURL(url);
        };

        terminal.addEventListener('scroll', () => {
            const isAtBottom = terminal.scrollHeight - terminal.scrollTop <= terminal.clientHeight + 10;
            if (autoScroll && !isAtBottom) {
                autoScroll = false;
                document.getElementById('log-autoscroll').checked = false;
            } else if (!autoScroll && isAtBottom) {
                autoScroll = true;
                document.getElementById('log-autoscroll').checked = true;
            }
        });

        // Initial render
        updateDisplay(logs);

        // Sub logic
        function updateDisplay(logsArray) {
            if (isPaused) return;

            let filtered = logsArray;
            if (filterLevel !== 'all') {
                filtered = filtered.filter(l => l.type === filterLevel);
            }
            if (filterSearch) {
                filtered = filtered.filter(l => l.message.toLowerCase().includes(filterSearch) || l.source.toLowerCase().includes(filterSearch));
            }

            // Collapse repeated messages
            const collapsed = [];
            let lastMsg = null;
            let count = 1;

            for (let i = 0; i < filtered.length; i++) {
                const l = filtered[i];
                if (lastMsg && l.message === lastMsg.message && l.source === lastMsg.source && l.type === lastMsg.type) {
                    count++;
                } else {
                    if (lastMsg) collapsed.push({ ...lastMsg, _count: count });
                    lastMsg = l;
                    count = 1;
                }
            }
            if (lastMsg) collapsed.push({ ...lastMsg, _count: count });

            terminal.innerHTML = collapsed.map(l => {
                const time = new Date(l.timestamp).toLocaleTimeString();
                const cls = `log-${l.type}`;
                const countBadge = l._count > 1 ? `<span class="badge badge-default" style="font-size:10px;padding:0 4px;margin-left:4px">x${l._count}</span>` : '';
                
                // Highlight search term
                let msgHtml = _esc(l.message);
                if (filterSearch) {
                    const regex = new RegExp(`(${_esc(filterSearch)})`, 'gi');
                    msgHtml = msgHtml.replace(regex, '<mark style="background:var(--warning-subtle);color:var(--warning)">$1</mark>');
                }

                return `
                    <div class="log-entry">
                        <span class="log-time">${time}</span>
                        <span class="log-source">${_esc(l.source.toUpperCase())}</span>
                        <span class="log-message ${cls}">${msgHtml}${countBadge}</span>
                    </div>
                `;
            }).join('');

            if (autoScroll) {
                terminal.scrollTop = terminal.scrollHeight;
            }
        }

        return { updateDisplay };
    }

    function _esc(str) { const d = document.createElement('div'); d.textContent = str || ''; return d.innerHTML; }

    return { render };
})();

window.LogConsole = LogConsole;
