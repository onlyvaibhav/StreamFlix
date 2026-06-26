/**
 * EmptyState — placeholder for empty sections
 */
const EmptyState = (() => {
    function html(message, icon = 'inbox', actionLabel, actionFn) {
        const actionId = actionFn ? `empty-action-${Date.now()}` : '';
        const actionHtml = actionLabel ? `<button class="btn btn-secondary" style="margin-top:var(--space-lg)" id="${actionId}">${_esc(actionLabel)}</button>` : '';
        if (actionFn) setTimeout(() => { const el = document.getElementById(actionId); if (el) el.onclick = actionFn; }, 0);
        return `
            <div class="empty-state">
                <i data-lucide="${icon}" style="width:40px;height:40px"></i>
                <h3>${_esc(message)}</h3>
                ${actionHtml}
            </div>
        `;
    }

    function _esc(str) { const d = document.createElement('div'); d.textContent = str || ''; return d.innerHTML; }
    return { html };
})();

window.EmptyState = EmptyState;
