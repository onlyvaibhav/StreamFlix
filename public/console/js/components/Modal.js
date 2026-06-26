/**
 * Modal component — reusable overlay dialog with title, body, footer
 */
const Modal = (() => {
    let _overlay = null;
    let _onClose = null;

    function open({ title, body, footer, className, onClose }) {
        close(); // Close existing

        _onClose = onClose || null;
        _overlay = document.createElement('div');
        _overlay.className = 'modal-overlay';
        _overlay.onclick = (e) => { if (e.target === _overlay) close(); };

        const panel = document.createElement('div');
        panel.className = `modal-panel ${className || ''}`;

        // Header
        const header = document.createElement('div');
        header.className = 'modal-header';
        header.innerHTML = `<h2>${_esc(title || '')}</h2>`;
        const closeBtn = document.createElement('button');
        closeBtn.className = 'btn-icon';
        closeBtn.innerHTML = '<i data-lucide="x" style="width:20px;height:20px"></i>';
        closeBtn.onclick = close;
        header.appendChild(closeBtn);
        panel.appendChild(header);

        // Body
        const bodyEl = document.createElement('div');
        bodyEl.className = 'modal-body';
        if (typeof body === 'string') bodyEl.innerHTML = body;
        else if (body instanceof HTMLElement) bodyEl.appendChild(body);
        panel.appendChild(bodyEl);

        // Footer
        if (footer) {
            const footerEl = document.createElement('div');
            footerEl.className = 'modal-footer';
            if (typeof footer === 'string') footerEl.innerHTML = footer;
            else if (footer instanceof HTMLElement) footerEl.appendChild(footer);
            panel.appendChild(footerEl);
        }

        _overlay.appendChild(panel);
        document.body.appendChild(_overlay);
        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [_overlay] });

        // Close on Escape
        document.addEventListener('keydown', _escHandler);
        return { close, getBody: () => bodyEl, getPanel: () => panel };
    }

    function close() {
        if (_overlay) {
            _overlay.remove();
            _overlay = null;
        }
        document.removeEventListener('keydown', _escHandler);
        if (_onClose) { _onClose(); _onClose = null; }
    }

    function isOpen() { return !!_overlay; }

    function _escHandler(e) {
        if (e.key === 'Escape') close();
    }

    function _esc(str) {
        const d = document.createElement('div');
        d.textContent = str || '';
        return d.innerHTML;
    }

    return { open, close, isOpen };
})();

window.Modal = Modal;
