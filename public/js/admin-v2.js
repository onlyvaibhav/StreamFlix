/**
 * STREAMFLIX ADMIN DASHBOARD V2
 * CORE LOGIC & COMPONENT SYSTEM
 */

const ADMIN_TOKEN_KEY = 'streamflix_admin_token';
let refreshTimer = null;
let logRefreshTimer = null;
let currentSection = 'overview';
let metadataList = [];
let charts = {};

// ==================== AUTH ====================

function getToken() {
    return localStorage.getItem(ADMIN_TOKEN_KEY);
}

function setToken(token) {
    localStorage.setItem(ADMIN_TOKEN_KEY, token);
}

function clearToken() {
    localStorage.removeItem(ADMIN_TOKEN_KEY);
}

async function adminApi(endpoint, options = {}) {
    const token = getToken();
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;

    try {
        const res = await fetch(endpoint, { ...options, headers });

        if (res.status === 401 || res.status === 403) {
            clearToken();
            showLogin();
            return null;
        }

        if (!res.ok) {
            const errData = await res.json().catch(() => ({}));
            throw new Error(errData.error || `HTTP ${res.status}`);
        }

        return await res.json();
    } catch (err) {
        console.error(`Admin API error [${endpoint}]:`, err);
        throw err;
    }
}

async function handleLogin(e) {
    if (e) e.preventDefault();

    const btn = document.getElementById('login-btn');
    const errEl = document.getElementById('login-error');
    const username = document.getElementById('login-username').value.trim();
    const password = document.getElementById('login-password').value;

    errEl.classList.add('hidden');
    btn.disabled = true;
    btn.textContent = 'Signing in...';

    try {
        const res = await fetch('/api/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password }),
        });

        const data = await res.json();

        if (!res.ok || !data.success) {
            throw new Error(data.error || 'Login failed');
        }

        if (data.user?.role !== 'admin') {
            throw new Error('Admin access required');
        }

        setToken(data.token);
        showDashboard();
    } catch (err) {
        errEl.textContent = err.message;
        errEl.classList.remove('hidden');
    } finally {
        btn.disabled = false;
        btn.textContent = 'Sign In';
    }
}

function logout() {
    clearToken();
    if (refreshTimer) clearInterval(refreshTimer);
    if (logRefreshTimer) clearInterval(logRefreshTimer);
    showLogin();
}

// ==================== NAVIGATION ====================

function showLogin() {
    document.getElementById('login-screen').classList.remove('hidden');
    document.getElementById('dashboard').classList.add('hidden');
}

function showDashboard() {
    document.getElementById('login-screen').classList.add('hidden');
    document.getElementById('dashboard').classList.remove('hidden');
    loadDashboard();
    // Auto refresh every 30s
    if (refreshTimer) clearInterval(refreshTimer);
    refreshTimer = setInterval(loadDashboard, 30000);
    
    // Log refresh every 5s
    if (logRefreshTimer) clearInterval(logRefreshTimer);
    logRefreshTimer = setInterval(loadLogs, 5000);
}

document.querySelectorAll('.nav-item[data-section]').forEach(item => {
    item.addEventListener('click', (e) => {
        e.preventDefault();
        const section = item.getAttribute('data-section');
        switchSection(section);
    });
});

function switchSection(sectionId) {
    currentSection = sectionId;
    
    // Update Nav
    document.querySelectorAll('.nav-item[data-section]').forEach(item => {
        item.classList.toggle('active', item.getAttribute('data-section') === sectionId);
    });

    // Update View
    document.querySelectorAll('.section').forEach(section => {
        section.classList.add('hidden');
    });
    const target = document.getElementById(`section-${sectionId}`);
    if (target) {
        target.classList.remove('hidden');
        document.getElementById('section-title').textContent = sectionId.charAt(0).toUpperCase() + sectionId.slice(1);
    }

    // Special handlers
    if (sectionId === 'media') loadMetadataManager();
    if (sectionId === 'workers') loadLogs();
}

// ==================== CORE DATA LOADING ====================

async function loadDashboard() {
    try {
        const [health, adminHealth, workerStatus, audioAudit, storage] = await Promise.all([
            adminApi('/api/health').catch(() => null),
            adminApi('/api/admin/health').catch(() => null),
            adminApi('/api/admin/worker-status').catch(() => null),
            adminApi('/api/admin/audio/audit').catch(() => null),
            adminApi('/api/admin/system/storage').catch(() => ({ total: 0, used: 0, free: 0, percent: 0 }))
        ]);

        renderOverview(health, adminHealth, audioAudit, storage);
        renderWorkerStatus(workerStatus);
        renderCharts(adminHealth, storage);
        
        // Manual Probe List in Health Section
        if (currentSection === 'health' && audioAudit?.manualProbeNeeded) {
            renderManualProbeList(audioAudit.manualProbeNeeded);
        }
        
        if (currentSection === 'health') {
            adminApi('/api/admin/metadata/issues')
                .then(data => renderIssues(data))
                .catch(() => {});
        }

        document.getElementById('last-refresh').textContent = 
            `Last updated: ${new Date().toLocaleTimeString()}`;
            
        lucide.createIcons();
    } catch (err) {
        console.error('Dashboard load failed:', err);
    }
}

function renderOverview(health, adminHealth, audioAudit, storage) {
    const grid = document.getElementById('stats-grid');
    const lib = health?.library || {};
    const ah = adminHealth || {};
    const audio = audioAudit?.summary || {};
    
    const stats = [
        { label: 'Movies', value: lib.movies ?? '0', icon: 'film', trend: null },
        { label: 'TV Shows', value: lib.tvShows ?? '0', icon: 'tv', trend: `${lib.tvEpisodes ?? 0} EPs` },
        { label: 'Valid Metadata', value: ah.valid ?? lib.validEntries ?? '0', icon: 'check-circle', trend: ah.total ? `${Math.round((ah.valid/ah.total)*100)}% coverage` : null, color: 'success' },
        { label: 'Broken', value: ah.broken ?? '0', icon: 'alert-triangle', trend: (ah.broken > 0 ? 'Needs repair' : 'System healthy'), color: ah.broken > 0 ? 'danger' : 'success' },
        { label: 'Manual Probe', value: audio.manualProbeCount ?? ah.manualProbeNeededCount ?? '0', icon: 'search', trend: 'Tier-3 failures', color: (audio.manualProbeCount > 0 ? 'warning' : 'success') },
        { label: 'Needs Transcoding', value: audio.unsupportedFiles ?? ah.unsupportedAudio ?? '0', icon: 'refresh-cw', trend: `${audio.unsupportedTrackCount ?? 0} tracks`, color: (audio.unsupportedFiles > 0 ? 'warning' : 'success') }
    ];

    grid.innerHTML = stats.map(s => `
        <div class="stat-card animate-fade">
            <div style="display: flex; justify-content: space-between; align-items: flex-start;">
                <div>
                    <div class="stat-label">${s.label}</div>
                    <div class="stat-value ${s.color ? `text-${s.color}` : ''}">${s.value}</div>
                </div>
                <div class="logo-icon" style="background: ${s.color ? `var(--${s.color})` : 'var(--glass)'}; opacity: 0.8;">
                    <i data-lucide="${s.icon}" size="18" color="white"></i>
                </div>
            </div>
            ${s.trend ? `<div class="stat-trend">${s.trend}</div>` : ''}
        </div>
    `).join('');

    // Storage Details
    const storageEl = document.getElementById('storage-details');
    if (storageEl) {
        storageEl.innerHTML = `
            <div style="display: flex; justify-content: space-between; margin-bottom: 0.5rem; font-size: 0.875rem;">
                <span style="color: var(--text-secondary);">Used</span>
                <span style="font-weight: 600;">${(storage.used / (1024**3)).toFixed(1)} GB</span>
            </div>
            <div style="display: flex; justify-content: space-between; margin-bottom: 0.5rem; font-size: 0.875rem;">
                <span style="color: var(--text-secondary);">Free</span>
                <span style="font-weight: 600; color: var(--success);">${(storage.free / (1024**3)).toFixed(1)} GB</span>
            </div>
            <div class="progress-bar">
                <div class="progress-fill" style="width: ${storage.percent}%"></div>
            </div>
            <div style="margin-top: 0.5rem; font-size: 0.75rem; color: var(--text-muted);">
                Drive ${storage.drive} (${storage.percent}% full)
            </div>
        `;
    }
}

// ==================== RENDER: CHARTS ====================

function renderCharts(adminHealth, storage) {
    // 1. Storage Donut
    const storageCtx = document.getElementById('storage-chart');
    if (storageCtx && !charts.storage) {
        charts.storage = new Chart(storageCtx, {
            type: 'doughnut',
            data: {
                labels: ['Used', 'Free'],
                datasets: [{
                    data: [storage.percent, 100 - storage.percent],
                    backgroundColor: ['#E50914', '#262626'],
                    borderWidth: 0,
                    hoverOffset: 4
                }]
            },
            options: {
                cutout: '75%',
                plugins: { legend: { display: false } },
                maintainAspectRatio: false
            }
        });
    } else if (charts.storage) {
        charts.storage.data.datasets[0].data = [storage.percent, 100 - storage.percent];
        charts.storage.update();
    }

    // 2. Main Progress Line (Mocking current snapshot as a baseline)
    const mainCtx = document.getElementById('main-chart');
    if (mainCtx && !charts.main) {
        const total = adminHealth?.total || 100;
        const valid = adminHealth?.valid || 0;
        const broken = adminHealth?.broken || 0;
        const needsRetry = adminHealth?.needsRetry || 0;

        charts.main = new Chart(mainCtx, {
            type: 'bar',
            data: {
                labels: ['Valid', 'Broken', 'Needs Retry'],
                datasets: [{
                    label: 'Files',
                    data: [valid, broken, needsRetry],
                    backgroundColor: ['#22c55e', '#ef4444', '#eab308'],
                    borderRadius: 6
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: { beginAtZero: true, grid: { color: '#262626' }, ticks: { color: '#737373' } },
                    x: { grid: { display: false }, ticks: { color: '#737373' } }
                },
                plugins: { legend: { display: false } }
            }
        });
    } else if (charts.main) {
        charts.main.data.datasets[0].data = [adminHealth?.valid || 0, adminHealth?.broken || 0, adminHealth?.needsRetry || 0];
        charts.main.update();
    }
}

// ==================== RENDER: METADATA ====================

async function loadMetadataManager() {
    const el = document.getElementById('metadata-manager-body');
    el.innerHTML = '<div style="padding: 3rem; text-align: center;"><i data-lucide="loader-2" class="animate-spin" size="32"></i><p style="margin-top: 1rem; color: var(--text-muted);">Scanning library...</p></div>';
    lucide.createIcons();

    try {
        const q = document.getElementById('media-search').value;
        const type = document.getElementById('media-type-filter').value;
        const data = await adminApi(`/api/admin/metadata/search?q=${encodeURIComponent(q)}&type=${type}`);
        metadataList = data.results || [];
        
        if (metadataList.length === 0) {
            el.innerHTML = '<div style="padding: 3rem; text-align: center; color: var(--text-muted);">No media found matching filters</div>';
            return;
        }

        el.innerHTML = `
            <table>
                <thead>
                    <tr>
                        <th style="width: 80px;">ID</th>
                        <th>Title</th>
                        <th>Type</th>
                        <th>Audio Tracks</th>
                        <th>Status</th>
                        <th style="width: 100px;">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${metadataList.map(item => `
                        <tr onclick="openFileDrawer('${item.fileId}')" style="cursor: pointer;">
                            <td style="font-family: 'JetBrains Mono'; font-size: 0.75rem; color: var(--info);">${item.fileId}</td>
                            <td>
                                <div style="font-weight: 600;">${esc(item.title || 'Unknown')}</div>
                                <div style="font-size: 0.75rem; color: var(--text-muted);">${item.year ? item.year : ''} ${item.container ? `• ${item.container.toUpperCase()}` : ''}</div>
                            </td>
                            <td>
                                <span class="chip ${item.type === 'tv' ? 'chip-info' : 'chip-warning'}">
                                    ${item.type === 'tv' ? 'TV SHOW' : 'MOVIE'}
                                </span>
                            </td>
                            <td>
                                <div style="display: flex; gap: 0.25rem;">
                                    ${(item.audioTracks || []).slice(0, 3).map(t => {
                                        const rawCodec = String(t.codec || t.codecName || '').toLowerCase();
                                        const ok = ['aac', 'mp3', 'opus', 'vorbis', 'flac', 'mp4a'].some(c => rawCodec.includes(c));
                                        return `<span class="chip" style="background: ${ok ? 'rgba(255,255,255,0.05)' : 'rgba(239,68,68,0.1)'}; color: ${ok ? 'var(--text-secondary)' : 'var(--danger)'}; border: 1px solid ${ok ? 'transparent' : 'rgba(239,68,68,0.2)'}; font-size: 0.65rem;">${t.language || t.languageCode || '??'}: ${rawCodec.toUpperCase()}</span>`;
                                    }).join('')}
                                    ${(item.audioTracks || []).length > 3 ? `<span class="chip" style="font-size: 0.65rem;">+${item.audioTracks.length - 3}</span>` : ''}
                                    ${(!item.audioTracks || item.audioTracks.length === 0) ? '<span class="text-muted">None detected</span>' : ''}
                                </div>
                            </td>
                            <td>
                                ${item.tracksDetected ? '<span class="chip chip-success">PROBED</span>' : '<span class="chip chip-error">MISSING PROBE</span>'}
                            </td>
                            <td onclick="event.stopPropagation()">
                                <button class="nav-item" style="padding: 0.5rem; background: var(--glass); border: none; cursor: pointer;" onclick="openFileDrawer('${item.fileId}')">
                                    <i data-lucide="external-link" size="16"></i>
                                </button>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
        lucide.createIcons();
    } catch (err) {
        el.innerHTML = `<div style="padding: 2rem; color: var(--danger);">Error: ${err.message}</div>`;
    }
}

let filterTimeout = null;
function filterMetadataTable() {
    if (filterTimeout) clearTimeout(filterTimeout);
    filterTimeout = setTimeout(loadMetadataManager, 500);
}

// ==================== RENDER: ISSUES ====================

function renderIssues(data) {
    const el = document.getElementById('issues-panel-body');
    if (!data || !data.issues || data.issues.length === 0) {
        el.innerHTML = '<div style="padding: 3rem; text-align: center; color: var(--success);"><i data-lucide="check-circle" size="32"></i><p style="margin-top: 1rem;">No metadata issues detected</p></div>';
        lucide.createIcons();
        return;
    }

    el.innerHTML = `
        <table>
            <thead>
                <tr>
                    <th>File</th>
                    <th>Issues</th>
                    <th style="width: 100px;">Actions</th>
                </tr>
            </thead>
            <tbody>
                ${data.issues.map(item => `
                    <tr>
                        <td>
                            <div style="font-weight: 600;">${esc(item.title || item.fileName || 'Unknown')}</div>
                            <div style="font-family: 'JetBrains Mono'; font-size: 0.75rem; color: var(--text-muted);">${item.fileId}</div>
                        </td>
                        <td>
                            <div style="display: flex; flex-wrap: wrap; gap: 0.5rem;">
                                ${item.issues.map(i => `<span class="chip ${i === 'manual_probe_needed' ? 'chip-warning' : 'chip-error'}">${i.replace(/_/g, ' ')}</span>`).join('')}
                            </div>
                        </td>
                        <td>
                            <button class="nav-item" style="padding: 0.5rem; background: var(--glass); border: none; cursor: pointer;" onclick="openFileDrawer('${item.fileId}')">
                                <i data-lucide="edit-3" size="16"></i>
                            </button>
                        </td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
    lucide.createIcons();
}

function renderManualProbeList(files) {
    const card = document.getElementById('manual-probe-card');
    const el = document.getElementById('manual-probe-list');
    
    if (!files || files.length === 0) {
        card.classList.add('hidden');
        return;
    }
    
    card.classList.remove('hidden');
    el.innerHTML = `
        <div style="display: grid; gap: 0.75rem;">
            ${files.map(f => `
                <div style="background: var(--glass); border: 1px solid var(--border); padding: 1rem; border-radius: 12px; display: flex; justify-content: space-between; align-items: center;">
                    <div>
                        <div style="font-weight: 600;">${esc(f.title || f.fileName || f.fileId)}</div>
                        <div style="font-size: 0.75rem; color: var(--text-muted);">Action required: Run ffprobe manually and paste JSON.</div>
                    </div>
                    <button class="nav-item" style="background: var(--info); border: none; color: white;" onclick="openFileDrawer('${f.fileId}')">
                        <i data-lucide="wrench" size="16"></i> Fix Now
                    </button>
                </div>
            `).join('')}
        </div>
    `;
    lucide.createIcons();
}

// ==================== WORKERS & LOGS ====================

async function loadLogs() {
    const terminal = document.getElementById('log-terminal');
    try {
        const logs = await adminApi('/api/admin/worker/logs');
        if (!logs || logs.length === 0) return;

        const isAtBottom = terminal.scrollHeight - terminal.scrollTop <= terminal.clientHeight + 50;

        terminal.innerHTML = logs.map(l => `
            <div class="log-entry">
                <span class="log-time">${new Date(l.timestamp).toLocaleTimeString()}</span>
                <span class="chip" style="background: rgba(255,255,255,0.05); font-size: 0.65rem; padding: 0.1rem 0.4rem; margin-right: 0.5rem;">${l.source.toUpperCase()}</span>
                <span class="log-${l.type}">${esc(l.message)}</span>
            </div>
        `).join('');

        if (isAtBottom) {
            terminal.scrollTop = terminal.scrollHeight;
        }
    } catch (err) {}
}

function clearLogs() {
    document.getElementById('log-terminal').innerHTML = '';
}

function renderWorkerStatus(data) {
    const el = document.getElementById('worker-panel-body');
    if (!data) {
        el.innerHTML = '<p class="text-muted">Unavailable</p>';
        return;
    }

    const isPaused = data.workerPaused;
    el.innerHTML = `
        <div style="display: flex; gap: 1rem; align-items: center; margin-bottom: 1.5rem;">
            <div style="position: relative; width: 48px; height: 48px; border-radius: 50%; background: ${isPaused ? 'rgba(234,179,8,0.1)' : 'rgba(34,197,94,0.1)'}; display: flex; align-items: center; justify-content: center;">
                <i data-lucide="${isPaused ? 'pause' : 'play'}" color="${isPaused ? 'var(--warning)' : 'var(--success)'}"></i>
                ${!isPaused ? '<div style="position: absolute; width: 100%; height: 100%; border-radius: 50%; border: 2px solid var(--success); animation: pulse 2s infinite;"></div>' : ''}
            </div>
            <div>
                <div style="font-weight: 600; font-size: 1.125rem;">${isPaused ? 'Paused' : 'Active'}</div>
                <div style="font-size: 0.875rem; color: var(--text-secondary);">${data.activeSessions || 0} active streams</div>
            </div>
        </div>

        ${data.sessions && data.sessions.length > 0 ? `
            <div style="font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.75rem;">Active Sessions</div>
            ${data.sessions.map(s => `
                <div style="background: var(--glass); padding: 0.75rem; border-radius: 8px; margin-bottom: 0.5rem; display: flex; justify-content: space-between; align-items: center;">
                    <div>
                        <div style="font-weight: 500; font-size: 0.875rem;">File ${s.fileId}</div>
                        <div style="font-size: 0.75rem; color: var(--text-muted);">${s.ip}</div>
                    </div>
                    <div style="text-align: right;">
                        <div style="font-weight: 500; font-size: 0.875rem;">${s.watchDuration}</div>
                        <div style="font-size: 0.75rem; color: var(--text-muted);">idle ${s.idleFor}</div>
                    </div>
                </div>
            `).join('')}
        ` : ''}
    `;

    const btn = document.getElementById('btn-worker-toggle');
    if (btn) {
        btn.innerHTML = isPaused ? '<i data-lucide="play" size="16"></i> Resume' : '<i data-lucide="pause" size="16"></i> Pause';
        btn.onclick = () => runAction(btn, isPaused ? '/api/admin/worker/resume' : '/api/admin/worker/pause');
    }
    lucide.createIcons();
}

// ==================== DRAWER & ACTIONS ====================

function openDrawer() {
    document.getElementById('drawer-overlay').style.display = 'block';
    setTimeout(() => document.getElementById('drawer').classList.add('active'), 10);
}

function closeDrawer() {
    document.getElementById('drawer').classList.remove('active');
    setTimeout(() => document.getElementById('drawer-overlay').style.display = 'none', 300);
}

async function submitManualProbe(fileId) {
    const jsonText = document.getElementById('manual-probe-json').value.trim();
    if (!jsonText) {
        showToast('Please paste the ffprobe JSON output', 'error');
        return;
    }

    let probeResult;
    try {
        probeResult = JSON.parse(jsonText);
    } catch (err) {
        showToast('Invalid JSON format', 'error');
        return;
    }

    if (!probeResult.streams || !Array.isArray(probeResult.streams)) {
        showToast('JSON does not appear to be output from ffprobe (missing streams)', 'error');
        return;
    }

    const btn = event.currentTarget;
    await runAction(btn, `/api/admin/metadata/${fileId}/set-probe-result`, probeResult);
    closeDrawer();
}

async function openFileDrawer(fileId) {
    const content = document.getElementById('drawer-content');
    content.innerHTML = '<div style="padding: 3rem; text-align: center;"><i data-lucide="loader-2" class="animate-spin" size="32"></i></div>';
    lucide.createIcons();
    openDrawer();

    try {
        const metadata = await adminApi(`/api/metadata/${fileId}`);
        if (!metadata) throw new Error('Metadata not found');

        content.innerHTML = `
            <div style="margin-bottom: 2rem;">
                <div style="display: flex; gap: 1rem; margin-bottom: 1.5rem;">
                    <img src="${metadata.poster && metadata.poster !== 'N/A' ? metadata.poster : 'https://placehold.co/100x150/141414/ffffff?text=No+Poster'}" style="width: 100px; border-radius: 8px; box-shadow: 0 10px 20px rgba(0,0,0,0.5);">
                    <div>
                        <h3 style="font-size: 1.25rem; font-weight: 700; margin-bottom: 0.5rem;">${esc(metadata.title)}</h3>
                        <div style="display: flex; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 0.5rem;">
                            <span class="chip chip-info">${metadata.type.toUpperCase()}</span>
                            ${metadata.year ? `<span class="chip">${metadata.year}</span>` : ''}
                            <span class="chip">${metadata.container?.toUpperCase() || 'RAW'}</span>
                        </div>
                        <div style="font-size: 0.875rem; color: var(--text-muted);">TMDB ID: ${metadata.tmdbId}</div>
                    </div>
                </div>

                <div style="background: var(--glass); padding: 1rem; border-radius: 12px; margin-bottom: 1.5rem;">
                    <div style="font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; margin-bottom: 0.75rem;">Audio Experience</div>
                    <div style="display: grid; gap: 0.75rem;">
                        ${(metadata.audioTracks || []).map(t => `
                            <div style="display: flex; justify-content: space-between; align-items: center;">
                                <div>
                                    <span style="font-weight: 500;">${t.language || 'Unknown'}</span>
                                    <span style="color: var(--text-muted); font-size: 0.75rem; margin-left: 0.5rem;">${t.codec?.toUpperCase()} (${t.channels}ch)</span>
                                </div>
                                ${t.browserPlayable !== false ? '<i data-lucide="check" size="16" color="var(--success)"></i>' : '<i data-lucide="alert-circle" size="16" color="var(--danger)"></i>'}
                            </div>
                        `).join('')}
                    </div>
                </div>

                <div style="margin-bottom: 1.5rem;">
                    <div style="font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; margin-bottom: 0.5rem;">Overview</div>
                    <p style="font-size: 0.875rem; line-height: 1.6; color: var(--text-secondary);">${esc(metadata.overview) || 'No overview available.'}</p>
                </div>

                <div>
                    <div style="font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; margin-bottom: 1rem;">Raw Metadata</div>
                    <pre style="background: #000; padding: 1rem; border-radius: 8px; font-size: 0.75rem; color: #aaa; overflow-x: auto; max-height: 200px;">${JSON.stringify(metadata, null, 2)}</pre>
                </div>

                ${metadata.manualProbeNeeded ? `
                    <div style="margin-top: 1.5rem; padding: 1.5rem; background: rgba(234,179,8,0.05); border: 1px dashed var(--warning); border-radius: 12px;">
                        <h4 style="color: var(--warning); font-size: 0.875rem; font-weight: 600; margin-bottom: 0.5rem; display: flex; align-items: center; gap: 0.5rem;">
                            <i data-lucide="alert-circle" size="16"></i> Manual Probe Required
                        </h4>
                        <p style="font-size: 0.75rem; color: var(--text-muted); margin-bottom: 1rem;">
                            Automated probing failed. Run ffprobe on the full file and paste the JSON output here:
                        </p>
                        <textarea id="manual-probe-json" class="search-input" style="height: 120px; font-family: 'JetBrains Mono'; font-size: 0.75rem; padding: 0.75rem; margin-bottom: 1rem;" placeholder='Paste ffprobe JSON output here...'></textarea>
                        <button class="nav-item" style="width: 100%; justify-content: center; background: var(--warning); border: none; color: #000; font-weight: 600;" onclick="submitManualProbe('${metadata.fileId}')">
                            <i data-lucide="upload" size="16"></i> Apply Probe Result
                        </button>
                    </div>
                ` : ''}
            </div>
            
            <div style="margin-top: 2rem; display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                <button class="nav-item" style="justify-content: center; background: var(--glass); border: 1px solid var(--border);" onclick="promptRefetch('${metadata.fileId}')">
                    <i data-lucide="refresh-cw" size="16"></i>
                    <span>Refetch TMDB</span>
                </button>
                <button class="nav-item" style="justify-content: center; border: 1px solid var(--border);" onclick="openLegacyEdit('${metadata.fileId}')">
                    <i data-lucide="edit" size="16"></i>
                    <span>Manual Edit</span>
                </button>
            </div>
        `;
        lucide.createIcons();
    } catch (err) {
        content.innerHTML = `<div style="padding: 2rem; color: var(--danger); text-align: center;">${err.message}</div>`;
    }
}

async function runAction(btn, endpoint, payload = null) {
    const originalContent = btn.innerHTML;
    btn.disabled = true;
    btn.innerHTML = '<i data-lucide="loader-2" class="animate-spin" size="16"></i> Processing...';
    lucide.createIcons();

    try {
        const res = await adminApi(endpoint, {
            method: 'POST',
            body: payload ? JSON.stringify(payload) : undefined
        });
        showToast(res?.message || 'Done!', 'success');
        setTimeout(loadDashboard, 1000);
    } catch (err) {
        showToast(err.message, 'error');
    } finally {
        btn.disabled = false;
        btn.innerHTML = originalContent;
        lucide.createIcons();
    }
}

// Handlers for HTML calls
window.handleFixBroken = () => runAction(event.currentTarget, '/api/admin/fix-broken');
window.handleRetryFailed = () => runAction(event.currentTarget, '/api/admin/retry-failed');
window.handleFetchMissingAudio = () => {
    const limit = parseInt(document.getElementById('audio-sweep-limit').value);
    const concurrency = parseInt(document.getElementById('audio-sweep-concurrency').value);
    runAction(event.currentTarget, '/api/admin/audio/sweep', { limit, concurrency });
};

function promptRefetch(fileId) {
    if (confirm('Re-fetch metadata from TMDB?')) {
        runAction(event.currentTarget, `/api/admin/metadata/${fileId}/refetch`);
        closeDrawer();
    }
}

// ==================== UTILS ====================

function showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.style.cssText = `
        position: fixed; bottom: 2rem; right: 2rem; padding: 1rem 1.5rem;
        background: ${type === 'success' ? 'var(--success)' : 'var(--danger)'};
        color: white; border-radius: 8px; font-weight: 600; z-index: 1000;
        box-shadow: 0 10px 30px rgba(0,0,0,0.5); 
        animation: fadeIn 0.3s ease forwards;
    `;
    toast.textContent = message;
    document.body.appendChild(toast);
    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateY(10px)';
        toast.style.transition = 'all 0.3s ease';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

function esc(str) {
    if (!str) return '';
    const d = document.createElement('div');
    d.textContent = str;
    return d.innerHTML;
}

// ==================== INIT ====================

document.getElementById('login-form').addEventListener('submit', handleLogin);
document.getElementById('logout-btn').addEventListener('click', (e) => { e.preventDefault(); logout(); });

// Check token on start
if (getToken()) {
    showDashboard();
} else {
    showLogin();
}

// Exposed to window for inline calls
window.loadDashboard = loadDashboard;
window.loadMetadataManager = loadMetadataManager;
window.filterMetadataTable = filterMetadataTable;
window.openFileDrawer = openFileDrawer;
window.closeDrawer = closeDrawer;
window.clearLogs = clearLogs;
window.switchSection = switchSection;
