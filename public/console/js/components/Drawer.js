/**
 * Drawer component — right slide-in detail panel
 */
const Drawer = (() => {
    let _overlay = null;
    let _panel = null;

    function open({ title, body, onClose }) {
        close();

        _overlay = document.createElement('div');
        _overlay.className = 'drawer-overlay';
        _overlay.onclick = close;

        _panel = document.createElement('div');
        _panel.className = 'drawer-panel';

        // Header
        const header = document.createElement('div');
        header.className = 'drawer-header';
        header.innerHTML = `<h2>${_esc(title || 'Details')}</h2>`;
        const closeBtn = document.createElement('button');
        closeBtn.className = 'btn-icon';
        closeBtn.innerHTML = '<i data-lucide="x" style="width:20px;height:20px"></i>';
        closeBtn.onclick = close;
        header.appendChild(closeBtn);
        _panel.appendChild(header);

        // Body
        const bodyEl = document.createElement('div');
        bodyEl.className = 'drawer-body';
        bodyEl.id = 'drawer-body';
        if (typeof body === 'string') bodyEl.innerHTML = body;
        else if (body instanceof HTMLElement) bodyEl.appendChild(body);
        _panel.appendChild(bodyEl);

        document.body.appendChild(_overlay);
        document.body.appendChild(_panel);

        // Animate in
        requestAnimationFrame(() => {
            _overlay.classList.add('active');
            _panel.classList.add('active');
        });

        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [_panel] });
        document.addEventListener('keydown', _escHandler);

        return { close, getBody: () => bodyEl, setBody };
    }

    function setBody(content) {
        const bodyEl = document.getElementById('drawer-body');
        if (!bodyEl) return;
        if (typeof content === 'string') bodyEl.innerHTML = content;
        else if (content instanceof HTMLElement) { bodyEl.innerHTML = ''; bodyEl.appendChild(content); }
        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [bodyEl] });
    }

    function close() {
        if (_panel) {
            _panel.classList.remove('active');
            _overlay.classList.remove('active');
            setTimeout(() => {
                _panel?.remove();
                _overlay?.remove();
                _panel = null;
                _overlay = null;
            }, 300);
        }
        document.removeEventListener('keydown', _escHandler);
    }

    function isOpen() { return !!_panel; }

    function _escHandler(e) { if (e.key === 'Escape') close(); }
    function _esc(str) { const d = document.createElement('div'); d.textContent = str || ''; return d.innerHTML; }

    return { open, close, setBody, isOpen };
})();

window.Drawer = Drawer;
