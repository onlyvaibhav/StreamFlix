/**
 * ProgressBar — animated fill bar with optional label
 */
const ProgressBar = (() => {
    function html(percent, color) {
        const p = Math.max(0, Math.min(100, percent || 0));
        const c = color ? `background:var(--${color})` : '';
        return `<div class="progress-bar"><div class="progress-fill" style="width:${p}%;${c}"></div></div>`;
    }

    return { html };
})();

window.ProgressBar = ProgressBar;
