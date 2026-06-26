/**
 * SkeletonLoader — animated loading placeholders
 */
const SkeletonLoader = (() => {
    function card(count = 1) {
        return Array(count).fill('<div class="skeleton skeleton-card" style="margin-bottom:var(--space-lg)"></div>').join('');
    }

    function stats(count = 4) {
        return `<div class="stats-grid">${Array(count).fill('<div class="skeleton skeleton-stat"></div>').join('')}</div>`;
    }

    function table(rows = 5) {
        const row = '<div style="display:flex;gap:var(--space-lg);padding:var(--space-md) 0"><div class="skeleton" style="width:60px;height:16px"></div><div class="skeleton" style="flex:1;height:16px"></div><div class="skeleton" style="width:80px;height:16px"></div></div>';
        return `<div style="padding:var(--space-xl)">${Array(rows).fill(row).join('')}</div>`;
    }

    function text(lines = 3) {
        return Array(lines).fill(0).map((_, i) =>
            `<div class="skeleton skeleton-text" style="width:${70 + Math.random() * 30}%"></div>`
        ).join('');
    }

    return { card, stats, table, text };
})();

window.SkeletonLoader = SkeletonLoader;
