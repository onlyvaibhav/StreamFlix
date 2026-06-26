/**
 * STREAMFLIX ADMIN CONSOLE — Hash-based Router
 * Reads location.hash, finds the registered module, calls render().
 * Supports query params: #metadata?fileId=229
 */

const AppRouter = (() => {
    let _currentRoute = null;
    let _container = null;
    let _onAuthFailed = null;

    /** Initialize router with the main content container */
    function init(containerEl) {
        _container = containerEl;
        window.addEventListener('hashchange', _handleRoute);
        _handleRoute();
    }

    /** Navigate to a route */
    function navigate(route, params = {}) {
        let hash = `#${route}`;
        const qs = Object.entries(params)
            .filter(([, v]) => v !== undefined && v !== null)
            .map(([k, v]) => `${k}=${encodeURIComponent(v)}`)
            .join('&');
        if (qs) hash += `?${qs}`;
        location.hash = hash;
    }

    /** Get current route info */
    function current() {
        return _parseHash();
    }

    /** Called when auth fails — show login */
    function onAuthFailed() {
        if (_onAuthFailed) _onAuthFailed();
    }

    function setAuthFailedHandler(fn) {
        _onAuthFailed = fn;
    }

    /** Parse location.hash into { route, params } */
    function _parseHash() {
        const raw = location.hash.slice(1) || 'dashboard';
        const [route, queryString] = raw.split('?');
        const params = {};
        if (queryString) {
            for (const pair of queryString.split('&')) {
                const [key, val] = pair.split('=');
                params[decodeURIComponent(key)] = decodeURIComponent(val || '');
            }
        }
        return { route, params };
    }

    let _activeModule = null;

    /** Handle hash change */
    function _handleRoute() {
        const { route, params } = _parseHash();

        if (route === _currentRoute && Object.keys(params).length === 0) return;
        _currentRoute = route;

        // Update sidebar active state
        document.querySelectorAll('.nav-item[data-route]').forEach(item => {
            item.classList.toggle('active', item.getAttribute('data-route') === route);
        });

        // Update header title
        const titleEl = document.getElementById('section-title');
        const mod = typeof AppModules !== 'undefined' ? AppModules.get(route) : null;
        if (titleEl) {
            titleEl.textContent = mod ? mod.title : route.charAt(0).toUpperCase() + route.slice(1);
        }

        // Destroy previous module if it exists
        if (_activeModule && _activeModule.destroy) {
            try {
                _activeModule.destroy();
            } catch (err) {
                console.error(`[Router] Error destroying module "${_activeModule.id}":`, err);
            }
        }
        _activeModule = null;

        // Render the section
        if (_container && mod && mod.render) {
            _container.innerHTML = '';
            try {
                const renderPromise = mod.render(_container, params);
                if (renderPromise && renderPromise.catch) {
                    renderPromise.catch(err => {
                        console.error(`[Router] Async render error for "${route}":`, err);
                        _container.innerHTML = `<div class="empty-state"><h3>Error loading section</h3><p>${err.message}</p></div>`;
                    });
                }
                _activeModule = mod;
            } catch (err) {
                console.error(`[Router] Render error for "${route}":`, err);
                _container.innerHTML = `<div class="empty-state"><h3>Error loading section</h3><p>${err.message}</p></div>`;
            }
        } else if (_container) {
            _container.innerHTML = `<div class="empty-state"><h3>Section not found</h3><p>The section "${_escHtml(route)}" is not registered.</p></div>`;
        }
    }

    function _escHtml(str) {
        const d = document.createElement('div');
        d.textContent = str;
        return d.innerHTML;
    }

    return {
        init,
        navigate,
        current,
        onAuthFailed,
        setAuthFailedHandler,
    };
})();

window.AppRouter = AppRouter;
