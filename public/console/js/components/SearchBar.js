/**
 * SearchBar component — debounced search input with clear button
 */
const SearchBar = (() => {
    /**
     * @param {HTMLElement} container
     * @param {Object} opts
     * @param {string} opts.placeholder
     * @param {Function} opts.onSearch - (query) => {}
     * @param {number} opts.debounce - ms (default 400)
     * @param {string} opts.value - initial value
     */
    function render(container, { placeholder, onSearch, debounce = 400, value = '' }) {
        let timer = null;
        const wrap = document.createElement('div');
        wrap.className = 'search-bar';
        wrap.innerHTML = `<i data-lucide="search" style="width:16px;height:16px"></i>`;

        const input = document.createElement('input');
        input.type = 'text';
        input.className = 'form-input';
        input.placeholder = placeholder || 'Search...';
        input.value = value;

        input.oninput = () => {
            if (timer) clearTimeout(timer);
            timer = setTimeout(() => onSearch(input.value), debounce);
        };

        wrap.appendChild(input);
        container.appendChild(wrap);
        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [wrap] });

        return { getValue: () => input.value, setValue: (v) => { input.value = v; }, focus: () => input.focus() };
    }

    return { render };
})();

window.SearchBar = SearchBar;
