// ============================================================
// STREAMFLIX ADMIN DASHBOARD
// ============================================================

const ADMIN_TOKEN_KEY = 'streamflix_admin_token';
let refreshTimer = null;

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
  e.preventDefault();

  const btn = document.getElementById('login-btn');
  const errEl = document.getElementById('login-error');
  const username = document.getElementById('login-username').value.trim();
  const password = document.getElementById('login-password').value;

  errEl.classList.remove('show');
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
    errEl.classList.add('show');
  } finally {
    btn.disabled = false;
    btn.textContent = 'Sign In';
  }
}

function logout() {
  clearToken();
  if (refreshTimer) clearInterval(refreshTimer);
  showLogin();
}

// ==================== VIEW SWITCHING ====================

function showLogin() {
  document.getElementById('login-screen').classList.remove('hidden');
  document.getElementById('dashboard').classList.remove('active');
  if (refreshTimer) clearInterval(refreshTimer);
}

function showDashboard() {
  document.getElementById('login-screen').classList.add('hidden');
  document.getElementById('dashboard').classList.add('active');
  loadDashboard();
  refreshTimer = setInterval(loadDashboard, 30000);
}

// ==================== DASHBOARD DATA ====================

async function loadDashboard() {
  try {
    const [health, adminHealth, workerStatus, syncStatus] = await Promise.all([
      adminApi('/api/health').catch(() => null),
      adminApi('/api/admin/health').catch(() => null),
      adminApi('/api/admin/worker-status').catch(() => null),
      adminApi('/api/admin/sync-status').catch(() => null),
    ]);

    renderStats(health, adminHealth);
    renderWorkerStatus(workerStatus);
    renderSyncStatus(syncStatus);
    renderMetadataHealth(adminHealth);

    document.getElementById('last-refresh').textContent =
      `Last updated: ${new Date().toLocaleTimeString()}`;

    // Load issues and metadata manager separately (slower endpoint)
    adminApi('/api/admin/metadata/issues')
      .then(data => renderIssues(data))
      .catch(() => {});
      
    loadMetadataManager();
  } catch (err) {
    console.error('Dashboard load failed:', err);
  }
}

// ==================== RENDER: STATS ====================

function renderStats(health, adminHealth) {
  const grid = document.getElementById('stats-grid');
  const lib = health?.library || {};
  const ah = adminHealth || {};

  grid.innerHTML = `
    <div class="stat-card accent">
      <div class="stat-label">Movies</div>
      <div class="stat-value">${lib.movies ?? '—'}</div>
    </div>
    <div class="stat-card info">
      <div class="stat-label">TV Episodes</div>
      <div class="stat-value">${lib.tvEpisodes ?? '—'}</div>
    </div>
    <div class="stat-card success">
      <div class="stat-label">Valid Metadata</div>
      <div class="stat-value">${ah.valid ?? lib.validEntries ?? '—'}</div>
      ${ah.total ? `<div class="stat-detail">of ${ah.total} total files</div>` : ''}
    </div>
    <div class="stat-card ${(ah.broken || 0) > 0 ? 'danger' : 'success'}">
      <div class="stat-label">Broken</div>
      <div class="stat-value">${ah.broken ?? '—'}</div>
    </div>
    <div class="stat-card ${(ah.needsRetry || 0) > 0 ? 'warning' : 'success'}">
      <div class="stat-label">Needs Retry</div>
      <div class="stat-value">${ah.needsRetry ?? '—'}</div>
    </div>
    <div class="stat-card info">
      <div class="stat-label">With Posters</div>
      <div class="stat-value">${ah.withPoster ?? '—'}</div>
      ${ah.total ? `<div class="stat-detail">${Math.round(((ah.withPoster || 0) / ah.total) * 100)}% coverage</div>` : ''}
    </div>
  `;
}

// ==================== RENDER: WORKER STATUS ====================

function renderWorkerStatus(data) {
  const el = document.getElementById('worker-panel-body');
  if (!data) {
    el.innerHTML = '<div class="info-row"><span class="info-label">Unavailable</span></div>';
    return;
  }

  const isPaused = data.workerPaused;
  const sessions = data.sessions || [];

  el.innerHTML = `
    <div class="info-row">
      <span class="info-label">Status</span>
      <span class="info-value">
        <span class="status-dot ${isPaused ? 'paused' : 'running'}"></span>
        ${isPaused ? ' Paused' : ' Running'}
      </span>
    </div>
    <div class="info-row">
      <span class="info-label">Active Streams</span>
      <span class="info-value">${data.activeSessions || 0}</span>
    </div>
    ${sessions.map(s => `
      <div class="info-row">
        <span class="info-label" style="font-size:12px">📺 File ${s.fileId}</span>
        <span class="info-value" style="font-size:12px">${s.watchDuration} (idle ${s.idleFor})</span>
      </div>
    `).join('')}
    <div class="info-row">
      <span class="info-label">Idle Timer</span>
      <span class="info-value">${data.idleTimerActive ? '⏳ Active' : '—'}</span>
    </div>
  `;

  // Update pause/resume button
  const btn = document.getElementById('btn-worker-toggle');
  if (btn) {
    btn.textContent = isPaused ? '▶ Resume Worker' : '⏸ Pause Worker';
    btn.onclick = () => toggleWorker(isPaused);
  }
}

// ==================== RENDER: SYNC STATUS ====================

function renderSyncStatus(data) {
  const el = document.getElementById('sync-panel-body');
  if (!data) {
    el.innerHTML = '<div class="info-row"><span class="info-label">Unavailable</span></div>';
    return;
  }

  const lastSync = data.lastSyncTime
    ? new Date(data.lastSyncTime).toLocaleString()
    : 'Never';

  el.innerHTML = `
    <div class="info-row">
      <span class="info-label">Last Sync</span>
      <span class="info-value">${lastSync}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Idle Loop</span>
      <span class="info-value">${data.idleLoopRunning ? '🔄 Running' : '⏹ Stopped'}</span>
    </div>
    ${data.nextSyncIn ? `
    <div class="info-row">
      <span class="info-label">Next Sync In</span>
      <span class="info-value">${Math.round(data.nextSyncIn / 60000)}m</span>
    </div>` : ''}
    ${data.totalSyncs !== undefined ? `
    <div class="info-row">
      <span class="info-label">Total Syncs</span>
      <span class="info-value">${data.totalSyncs}</span>
    </div>` : ''}
  `;
}

// ==================== RENDER: METADATA HEALTH ====================

function renderMetadataHealth(data) {
  const el = document.getElementById('health-panel-body');
  if (!data) {
    el.innerHTML = '<div class="info-row"><span class="info-label">Unavailable</span></div>';
    return;
  }

  const brokenItems = (data.brokenList || []).slice(0, 8);

  el.innerHTML = `
    <div class="info-row">
      <span class="info-label">With Backdrops</span>
      <span class="info-value">${data.withBackdrop ?? '—'}${data.total ? ` (${Math.round(((data.withBackdrop || 0) / data.total) * 100)}%)` : ''}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Audio Detected</span>
      <span class="info-value">${data.withAudioDetected ?? '—'}</span>
    </div>
    ${brokenItems.length > 0 ? `
      <div style="margin-top:12px; font-size:12px; color:var(--admin-text-muted); text-transform:uppercase; letter-spacing:0.5px; margin-bottom:8px;">
        Recent Broken (${data.broken || 0} total)
      </div>
      ${brokenItems.map(b => `
        <div class="info-row" style="font-size:12px;">
          <span class="info-label">${b.fileId}</span>
          <span class="info-value"><span class="issue-tag error">${b.reason}</span></span>
        </div>
      `).join('')}
    ` : ''}
  `;
}

// ==================== RENDER: ISSUES ====================

function renderIssues(data) {
  const el = document.getElementById('issues-panel-body');
  if (!data || !data.issues || data.issues.length === 0) {
    el.innerHTML = '<div style="padding:8px; color:var(--admin-text-muted); font-size:14px;">✅ No metadata issues found</div>';
    return;
  }

  const items = data.issues.slice(0, 30);

  el.innerHTML = `
    <div style="margin-bottom:12px; font-size:13px; color:var(--admin-text-muted);">${data.total} issues found (showing ${items.length})</div>
    <div class="issues-table-wrapper">
      <table class="issues-table">
        <thead>
          <tr>
            <th>File ID</th>
            <th>Title</th>
            <th>Type</th>
            <th>Issues</th>
          </tr>
        </thead>
        <tbody>
          ${items.map(item => `
            <tr>
              <td style="font-family:monospace; font-size:12px;">${item.fileId}</td>
              <td>${esc(item.title || item.fileName || '—')}</td>
              <td>${item.type || '—'}</td>
              <td>${(item.issues || []).map(i => `<span class="issue-tag${i.includes('missing') || i.includes('no_') ? ' error' : ''}">${i}</span>`).join(' ')}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    </div>
  `;
}

// ==================== ACTIONS ====================

async function runAction(btn, endpoint, method = 'POST') {
  const originalText = btn.textContent;
  btn.disabled = true;
  btn.textContent = '⏳ Running...';

  try {
    const result = await adminApi(endpoint, { method });
    showToast(result?.message || 'Action completed successfully', 'success');
    // Refresh dashboard data after action
    setTimeout(loadDashboard, 1000);
  } catch (err) {
    showToast(err.message || 'Action failed', 'error');
  } finally {
    btn.disabled = false;
    btn.textContent = originalText;
  }
}

async function toggleWorker(isPaused) {
  const endpoint = isPaused ? '/api/admin/worker/resume' : '/api/admin/worker/pause';
  const btn = document.getElementById('btn-worker-toggle');
  await runAction(btn, endpoint);
}

function handleSyncTelegram() {
  const btn = event.currentTarget;
  runAction(btn, '/api/admin/sync-telegram');
}

function handleInvalidateCache() {
  const btn = event.currentTarget;
  runAction(btn, '/api/admin/invalidate-cache');
}

function handleRebuildTVCaches() {
  const btn = event.currentTarget;
  runAction(btn, '/api/admin/rebuild-tv-caches');
}

function handleFixBroken() {
  const btn = event.currentTarget;
  runAction(btn, '/api/admin/fix-broken');
}

function handleRetryFailed() {
  const btn = event.currentTarget;
  runAction(btn, '/api/admin/retry-failed');
}

// ==================== TOAST ====================

function showToast(message, type = 'info') {
  const existing = document.querySelector('.toast');
  if (existing) existing.remove();

  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.textContent = message;
  document.body.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(30px)';
    toast.style.transition = 'all 0.3s ease';
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

// ==================== UTILS ====================

function esc(str) {
  if (!str) return '';
  const d = document.createElement('div');
  d.textContent = str;
  return d.innerHTML;
}

// ==================== INIT ====================

let metadataList = [];

async function loadMetadataManager() {
  const el = document.getElementById('metadata-manager-body');
  el.innerHTML = '<div class="skeleton" style="height:200px; margin: 20px;">&nbsp;</div>';
  
  try {
    const searchInput = document.getElementById('metadata-search');
    const typeSelect = document.getElementById('metadata-type-filter');
    const q = searchInput ? searchInput.value : '';
    const type = typeSelect ? typeSelect.value : 'all';
    
    // Fetch data using the new search endpoint
    const data = await adminApi(`/api/admin/metadata/search?q=${encodeURIComponent(q)}&type=${type}`);
    metadataList = data.results || [];
    renderMetadataManager();
  } catch (err) {
    el.innerHTML = `<div style="padding: 20px; color: var(--admin-danger);">${err.message}</div>`;
  }
}

let filterTimeout = null;
function filterMetadataTable() {
  if (filterTimeout) clearTimeout(filterTimeout);
  filterTimeout = setTimeout(loadMetadataManager, 500); // debounce API calls
}

// Make it available to inline handlers
window.filterMetadataTable = filterMetadataTable;
window.loadMetadataManager = loadMetadataManager;

function renderMetadataManager() {
  const el = document.getElementById('metadata-manager-body');
  if (metadataList.length === 0) {
    el.innerHTML = '<div style="padding:20px; color:var(--admin-text-muted); text-align:center;">No metadata found</div>';
    return;
  }

  el.innerHTML = `
    <div class="issues-table-wrapper" style="max-height: 500px; overflow-y: auto;">
      <table class="issues-table">
        <thead>
          <tr>
            <th>ID / File</th>
            <th>Type</th>
            <th>Title (TMDB ID)</th>
            <th style="width: 140px;">Actions</th>
          </tr>
        </thead>
        <tbody>
          ${metadataList.map(item => `
            <tr>
              <td style="font-size:12px;">
                <span style="font-family:monospace; color: var(--admin-info);">${item.fileId}</span><br>
                <span style="color:var(--admin-text-muted);" title="${esc(item.fileName)}">${esc(item.fileName.length > 35 ? item.fileName.substring(0, 32) + '...' : item.fileName)}</span>
              </td>
              <td>
                <span class="issue-tag" style="background: rgba(99, 102, 241, 0.1); color: #818cf8; border: 1px solid rgba(99,102,241,0.2);">
                   ${item.type === 'tv' ? '📺 TV' : '🎬 Movie'}
                </span>
              </td>
              <td>
                <div style="font-weight:600; font-size:14px; color: #fff;">${esc(item.title || 'Unknown')} ${item.year ? `(${item.year})` : ''}</div>
                ${item.type === 'tv' && item.season !== undefined ? `<div style="font-size:12px;color:var(--admin-accent); font-weight: 500;">S${String(item.season).padStart(2,'0')} E${String(item.episode).padStart(2,'0')}</div>` : ''}
                <div style="font-size:11px;color:var(--admin-text-muted); margin-top:4px;">TMDB: <span style="font-family:monospace;">${item.tmdbId || 'None'}</span></div>
              </td>
              <td style="vertical-align: middle;">
                <div style="display: flex; gap: 6px;">
                  <button class="action-btn" style="padding:4px 8px; font-size:11px;" onclick="openEditModal('${item.fileId}')">
                    ✏️ Edit
                  </button>
                  <button class="action-btn" style="padding:4px 8px; font-size:11px; border-color: rgba(59, 130, 246, 0.4); color: #60a5fa;" onclick="promptFixMetadata('${item.fileId}', ${item.tmdbId}, '${item.type}')">
                    🔄 Fetch TMDB
                  </button>
                </div>
              </td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    </div>
  `;
}

// ----------------------------------------------------
// EDIT MODAL LOGIC
// ----------------------------------------------------
let currentEditEntry = null;

window.openEditModal = function(fileId) {
  const entry = metadataList.find(m => m.fileId === fileId);
  if (!entry) return;
  
  currentEditEntry = entry;
  const modal = document.getElementById('edit-modal');
  
  document.getElementById('edit-file-id').value = entry.fileId;
  document.getElementById('edit-title').value = entry.title || '';
  document.getElementById('edit-year').value = entry.year || '';
  document.getElementById('edit-type').value = entry.type || 'movie';
  document.getElementById('edit-tmdb-id').value = entry.tmdbId || '';
  document.getElementById('edit-season').value = entry.season ?? '';
  document.getElementById('edit-episode').value = entry.episode ?? '';
  // Note: Overview might not be in the search results list directly (we stripped it for size),
  // but if it is, we show it. Otherwise we fetch full metadata for this entry if needed, but 
  // since the user wants to *force* fixes, they can provide it or leave it blank.
  // Actually, we can just leave it blank and backend uses EXISTING if empty.
  document.getElementById('edit-overview').value = entry.overview || '';
  
  toggleTvFields();
  modal.classList.remove('hidden');
};

window.closeEditModal = function() {
  document.getElementById('edit-modal').classList.add('hidden');
  currentEditEntry = null;
};

window.toggleTvFields = function() {
  const type = document.getElementById('edit-type').value;
  const tvFields = document.getElementById('tv-fields');
  if (type === 'tv') {
    tvFields.classList.remove('hidden');
  } else {
    tvFields.classList.add('hidden');
  }
};

document.getElementById('edit-metadata-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  
  const fileId = document.getElementById('edit-file-id').value;
  const btn = document.getElementById('save-edit-btn');
  
  const payload = {
    title: document.getElementById('edit-title').value,
    year: document.getElementById('edit-year').value,
    type: document.getElementById('edit-type').value,
    tmdbId: document.getElementById('edit-tmdb-id').value,
    overview: document.getElementById('edit-overview').value
  };
  
  if (payload.type === 'tv') {
    payload.season = document.getElementById('edit-season').value;
    payload.episode = document.getElementById('edit-episode').value;
  }
  
  const origText = btn.textContent;
  btn.disabled = true;
  btn.textContent = 'Saving...';
  
  try {
    await adminApi(`/api/admin/metadata/${fileId}/manual-override`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
    
    showToast('Metadata updated manually!', 'success');
    closeEditModal();
    loadDashboard(); // Refresh full dashboard to update issues lists & manager
  } catch (err) {
    showToast(err.message, 'error');
  } finally {
    btn.disabled = false;
    btn.textContent = origText;
  }
});

// ----------------------------------------------------

window.promptFixMetadata = async function(fileId, currentTmdbId, currentType) {
  const newTmdbId = prompt(`Enter new TMDB ID for file ${fileId} (Current: ${currentTmdbId || 'None'}):`, currentTmdbId || '');
  if (!newTmdbId) return;
  const parsedId = parseInt(newTmdbId, 10);
  if (isNaN(parsedId)) {
    return showToast('Invalid TMDB ID', 'error');
  }
  
  const newType = prompt(`Enter type (movie or tv) for file ${fileId} (Current: ${currentType}):`, currentType || 'movie');
  if (!newType || !['movie', 'tv'].includes(newType.toLowerCase())) {
    return showToast('Invalid type - must be movie or tv', 'error');
  }

  if (confirm(`Refetch metadata for file ${fileId} with TMDB ID ${parsedId} (${newType})?`)) {
    try {
      showToast('Fixing metadata (This may take a moment)...', 'info');
      await adminApi(`/api/admin/metadata/${fileId}/fix`, {
        method: 'POST',
        body: JSON.stringify({ tmdbId: parsedId, type: newType.toLowerCase() })
      });
      showToast('Metadata updated successfully!', 'success');
      loadDashboard(); // Fully refresh dashboard!
    } catch (err) {
      showToast(err.message, 'error');
    }
  }
};

window.promptRefetchMetadata = async function(fileId) {
  if (confirm(`Refetch metadata for file ${fileId} using existing TMDB ID?`)) {
    try {
      showToast('Refetching metadata...', 'info');
      await adminApi(`/api/admin/metadata/${fileId}/refetch`, { method: 'POST' });
      showToast('Refetch completed!', 'success');
      loadDashboard(); // Fully refresh dashboard!
    } catch (err) {
      showToast(err.message, 'error');
    }
  }
};

document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('login-form').addEventListener('submit', handleLogin);

  // Check if already logged in
  const token = getToken();
  if (token) {
    // Verify token is still valid by making a test request
    adminApi('/api/admin/health')
      .then(data => {
        if (data) {
          showDashboard();
        } else {
          showLogin();
        }
      })
      .catch(() => showLogin());
  } else {
    showLogin();
  }
});
