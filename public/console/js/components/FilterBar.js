/**
 * FilterBar — dropdown filter group
 */
const FilterBar = (() => {
    /**
     * @param {HTMLElement} container
     * @param {Array} options - [{ value, label }]
     * @param {Function} onChange - (value) => {}
     * @param {string} selected - initial value
     */
    function render(container, { options, onChange, selected }) {
        const select = document.createElement('select');
        select.className = 'form-input form-select';
        select.style.width = 'auto';
        select.style.minWidth = '140px';

        for (const opt of options) {
            const o = document.createElement('option');
            o.value = opt.value;
            o.textContent = opt.label;
            if (opt.value === selected) o.selected = true;
            select.appendChild(o);
        }

        select.onchange = () => onChange(select.value);
        container.appendChild(select);

        return { getValue: () => select.value, setValue: (v) => { select.value = v; } };
    }

    return { render };
})();

window.FilterBar = FilterBar;
