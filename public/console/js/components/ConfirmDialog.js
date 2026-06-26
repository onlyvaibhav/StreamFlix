/**
 * ConfirmDialog component — promise-based confirmation modal
 */
const ConfirmDialog = (() => {
    function show({ title, message, confirmText = 'Confirm', cancelText = 'Cancel', type = 'warning' }) {
        return new Promise((resolve) => {
            const body = document.createElement('div');
            body.className = 'confirm-dialog';
            
            const p = document.createElement('p');
            p.textContent = message;
            body.appendChild(p);

            const footer = document.createElement('div');
            footer.style.display = 'flex';
            footer.style.gap = 'var(--space-md)';
            footer.style.justifyContent = 'flex-end';
            footer.style.width = '100%';

            const cancelBtn = document.createElement('button');
            cancelBtn.className = 'btn btn-secondary';
            cancelBtn.textContent = cancelText;

            const confirmBtn = document.createElement('button');
            confirmBtn.className = type === 'danger' ? 'btn btn-danger' : 'btn btn-primary';
            confirmBtn.textContent = confirmText;

            footer.appendChild(cancelBtn);
            footer.appendChild(confirmBtn);

            const modal = Modal.open({
                title,
                body,
                footer,
                onClose: () => resolve(false)
            });

            cancelBtn.onclick = () => { modal.close(); resolve(false); };
            confirmBtn.onclick = () => { modal.close(); resolve(true); };
        });
    }

    return { show };
})();

window.ConfirmDialog = ConfirmDialog;
