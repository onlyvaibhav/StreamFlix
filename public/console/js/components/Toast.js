/**
 * Toast notification system — auto-dismiss, stacking, multiple types
 */
const Toast = (() => {
    let _container = null;

    function _ensureContainer() {
        if (_container) return;
        _container = document.createElement('div');
        _container.className = 'toast-container';
        document.body.appendChild(_container);
    }

    function show(message, type = 'success', duration = 3500) {
        _ensureContainer();

        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;

        const icons = { success: 'check-circle', error: 'alert-circle', warning: 'alert-triangle', info: 'info' };
        toast.innerHTML = `<i data-lucide="${icons[type] || 'info'}" style="width:18px;height:18px;flex-shrink:0"></i><span>${_esc(message)}</span>`;
        _container.appendChild(toast);

        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [toast] });

        setTimeout(() => {
            toast.classList.add('removing');
            setTimeout(() => toast.remove(), 300);
        }, duration);
    }

    function success(msg) { show(msg, 'success'); }
    function error(msg)   { show(msg, 'error'); }
    function warning(msg) { show(msg, 'warning'); }
    function info(msg)    { show(msg, 'info'); }

    function _esc(str) {
        const d = document.createElement('div');
        d.textContent = str || '';
        return d.innerHTML;
    }

    return { show, success, error, warning, info };
})();

window.Toast = Toast;
