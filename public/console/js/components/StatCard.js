/**
 * StatCard component — renders a stat card with icon, value, label, trend
 */
const StatCard = (() => {
    /**
     * @param {Object} opts
     * @param {string} opts.label
     * @param {string|number} opts.value
     * @param {string} opts.icon - Lucide icon name
     * @param {string} opts.color - success|warning|danger|info|accent
     * @param {string} opts.trend - trend text
     * @param {string} opts.trendDir - 'up' | 'down' | null
     */
    function html({ label, value, icon, color, trend, trendDir }) {
        const c = color || 'accent';
        const colorVar = `var(--${c})`;
        const bgVar = `var(--${c}-subtle, var(--glass))`;

        return `
            <div class="stat-card animate-fade">
                <div class="stat-card-header">
                    <div>
                        <div class="stat-card-label">${_esc(label)}</div>
                        <div class="stat-card-value">${_esc(String(value ?? '0'))}</div>
                    </div>
                    <div class="stat-card-icon" style="background:${bgVar}">
                        <i data-lucide="${icon || 'hash'}" style="width:18px;height:18px;color:${colorVar}"></i>
                    </div>
                </div>
                ${trend ? `<div class="stat-card-trend ${trendDir || ''}">${_esc(trend)}</div>` : ''}
            </div>
        `;
    }

    /**
     * Render multiple stat cards into a grid container
     * @param {HTMLElement} container
     * @param {Array} stats - Array of stat objects
     */
    function renderGrid(container, stats) {
        container.innerHTML = stats.map(s => html(s)).join('');
        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [container] });
    }

    function _esc(str) { const d = document.createElement('div'); d.textContent = str || ''; return d.innerHTML; }

    return { html, renderGrid };
})();

window.StatCard = StatCard;
