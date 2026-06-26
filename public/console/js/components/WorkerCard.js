/**
 * WorkerCard component — displays worker status with pulse animation
 */
const WorkerCard = (() => {
    function html({ title, paused, description, queueSize, activeCount }) {
        const statusText = paused ? 'Paused' : 'Active';
        const indicatorCls = paused ? 'paused' : 'active';
        const icon = paused ? 'pause' : 'play';
        const iconColor = paused ? 'var(--warning)' : 'var(--success)';

        return `
            <div class="data-card">
                <div class="data-card-body worker-status">
                    <div class="worker-indicator ${indicatorCls}">
                        <i data-lucide="${icon}" style="color:${iconColor};width:24px;height:24px"></i>
                    </div>
                    <div style="flex:1">
                        <h3 style="font-size:var(--text-lg);font-weight:var(--weight-semibold);margin-bottom:2px">
                            ${_esc(title)}
                        </h3>
                        <div style="font-size:var(--text-sm);color:var(--text-muted)">
                            ${_esc(description)}
                        </div>
                    </div>
                    <div style="text-align:right">
                        <div style="font-weight:var(--weight-bold);font-size:var(--text-lg);color:${iconColor}">
                            ${statusText}
                        </div>
                        ${queueSize !== undefined ? `<div style="font-size:var(--text-xs);color:var(--text-muted)">Queue: ${queueSize}</div>` : ''}
                        ${activeCount !== undefined ? `<div style="font-size:var(--text-xs);color:var(--text-muted)">Active: ${activeCount}</div>` : ''}
                    </div>
                </div>
            </div>
        `;
    }

    function _esc(str) { const d = document.createElement('div'); d.textContent = str || ''; return d.innerHTML; }

    return { html };
})();

window.WorkerCard = WorkerCard;
