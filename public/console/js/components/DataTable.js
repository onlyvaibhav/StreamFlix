/**
 * DataTable component — sortable table with column definitions
 */
const DataTable = (() => {
    /**
     * Render a data table into a container
     * @param {HTMLElement} container
     * @param {Object} options
     * @param {Array} options.columns - [{ key, label, width, render, className }]
     * @param {Array} options.rows - Array of data objects
     * @param {Function} options.onRowClick - (row) => {}
     * @param {string} options.emptyMessage
     */
    function render(container, { columns, rows, onRowClick, emptyMessage }) {
        container.innerHTML = '';

        if (!rows || rows.length === 0) {
            container.innerHTML = EmptyState.html(emptyMessage || 'No data found', 'database');
            if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [container] });
            return;
        }

        const wrap = document.createElement('div');
        wrap.className = 'data-table-wrap';

        const table = document.createElement('table');
        table.className = 'data-table';

        // Head
        const thead = document.createElement('thead');
        const headRow = document.createElement('tr');
        for (const col of columns) {
            const th = document.createElement('th');
            th.textContent = col.label || col.key;
            if (col.width) th.style.width = col.width;
            headRow.appendChild(th);
        }
        thead.appendChild(headRow);
        table.appendChild(thead);

        // Body
        const tbody = document.createElement('tbody');
        for (const row of rows) {
            const tr = document.createElement('tr');
            if (onRowClick) {
                tr.classList.add('clickable');
                tr.onclick = () => onRowClick(row);
            }
            for (const col of columns) {
                const td = document.createElement('td');
                if (col.className) td.className = col.className;
                if (col.render) {
                    const content = col.render(row);
                    if (typeof content === 'string') td.innerHTML = content;
                    else if (content instanceof HTMLElement) td.appendChild(content);
                } else {
                    td.textContent = row[col.key] ?? '—';
                }
                tr.appendChild(td);
            }
            tbody.appendChild(tr);
        }
        table.appendChild(tbody);
        wrap.appendChild(table);
        container.appendChild(wrap);

        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [container] });
    }

    return { render };
})();

window.DataTable = DataTable;
