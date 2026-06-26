/**
 * ViewerCard component — displays an active stream viewer session
 */
const ViewerCard = (() => {
    function html({ fileId, title, ip, duration, idle, ranges, buffered }) {
        return `
            <div class="viewer-card animate-fade">
                <div class="viewer-card-info">
                    <div class="viewer-card-title">${_esc(title || `File ${fileId}`)}</div>
                    <div class="viewer-card-meta">
                        <span style="font-family:var(--font-mono)">${_esc(ip)}</span> • 
                        ${ranges} range request(s) • 
                        ~${_esc(buffered || '0 MB')}
                    </div>
                </div>
                <div class="viewer-card-stats">
                    <div class="viewer-card-duration">${_esc(duration)}</div>
                    <div class="viewer-card-idle">idle ${_esc(idle)}</div>
                </div>
            </div>
        `;
    }

    function _esc(str) { const d = document.createElement('div'); d.textContent = str || ''; return d.innerHTML; }

    return { html };
})();

window.ViewerCard = ViewerCard;
