/**
 * STREAMFLIX ADMIN CONSOLE — App Bootstrap & Module Registry
 * Initializes the SPA, registers modules, and handles layout rendering.
 */

const AppModules = (() => {
    const _modules = new Map();

    /**
     * Register a section module
     * @param {Object} mod
     * @param {string} mod.id - Route ID (e.g. 'dashboard')
     * @param {string} mod.title - Sidebar label
     * @param {string} mod.icon - Lucide icon name
     * @param {Function} mod.render - (container, params) => void
     * @param {Array<string>} mod.permissions - ['admin', 'operator'] (optional)
     * @param {Array<Object>} mod.commands - Command palette items (optional)
     */
    function register(mod) {
        _modules.set(mod.id, mod);
    }

    function get(id) { return _modules.get(id); }
    function getAll() { return Array.from(_modules.values()); }

    return { register, get, getAll };
})();

window.AppModules = AppModules;

// ══════════════════════════════════════
// APPLICATION INITIALIZATION
// ══════════════════════════════════════
const App = (() => {
    async function init() {
        console.log('[App] Starting...');

        // Setup Command Palette
        AppCommands.init();

        // Setup Router Auth Fallback
        AppRouter.setAuthFailedHandler(showLogin);

        // Check Auth
        if (Api.hasToken()) {
            await startSession();
        } else {
            showLogin();
        }
    }

    async function startSession() {
        document.getElementById('login-screen').classList.add('hidden');
        document.getElementById('app-layout').classList.remove('hidden');

        // Render Sidebar
        renderSidebar();

        // Init Router
        AppRouter.init(document.getElementById('main-body'));

        // Connect SSE — initial payload hydrates all state (logs, streams, workers)
        AppEvents.connect();
    }

    function showLogin() {
        AppEvents.disconnect();
        document.getElementById('login-screen').classList.remove('hidden');
        document.getElementById('app-layout').classList.add('hidden');
    }

    function handleLoginSubmit(e) {
        e.preventDefault();
        const btn = document.getElementById('login-btn');
        const errEl = document.getElementById('login-error');
        const username = document.getElementById('login-username').value.trim();
        const password = document.getElementById('login-password').value;

        btn.disabled = true;
        btn.innerHTML = '<i data-lucide="loader-2" class="animate-spin" style="width:18px;height:18px"></i>';
        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [btn] });
        errEl.textContent = '';

        Api.login(username, password)
            .then(() => {
                startSession();
            })
            .catch(err => {
                errEl.textContent = err.message || 'Login failed';
            })
            .finally(() => {
                btn.disabled = false;
                btn.textContent = 'Sign In';
            });
    }

    function handleLogout() {
        Api.logout();
        AppRouter.navigate('dashboard'); // reset route state
        showLogin();
    }

    function renderSidebar() {
        const navContainer = document.getElementById('sidebar-nav');
        if (!navContainer) return;
        navContainer.innerHTML = '';

        // Standard grouping based on user request layout
        const groups = {
            'Overview': ['dashboard', 'media', 'metadata', 'streaming'],
            'System': ['workers', 'telegram', 'logs', 'analytics'],
            'Admin': ['settings', 'system']
        };

        const user = AppState.get('user');
        const userRole = user ? user.role : 'admin';

        for (const [groupName, ids] of Object.entries(groups)) {
            // Find modules that exist and user has permission for
            const groupMods = ids
                .map(id => AppModules.get(id))
                .filter(m => m)
                .filter(m => !m.permissions || m.permissions.includes(userRole));

            if (groupMods.length > 0) {
                const label = document.createElement('div');
                label.className = 'sidebar-section-label';
                label.textContent = groupName;
                navContainer.appendChild(label);

                for (const mod of groupMods) {
                    const btn = document.createElement('button');
                    btn.className = 'nav-item';
                    btn.setAttribute('data-route', mod.id);
                    btn.innerHTML = `
                        <i data-lucide="${mod.icon}" style="width:18px;height:18px"></i>
                        <span>${mod.title}</span>
                    `;
                    btn.onclick = () => AppRouter.navigate(mod.id);
                    navContainer.appendChild(btn);
                }
            }
        }

        if (typeof lucide !== 'undefined') lucide.createIcons({ nodes: [navContainer] });
    }

    return { init, handleLoginSubmit, handleLogout };
})();

// Attach to window for HTML handlers
window.App = App;

// Bootstrap when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    // Attach login listener
    const form = document.getElementById('login-form');
    if (form) form.addEventListener('submit', App.handleLoginSubmit);
    
    // Attach logout listener
    const logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) logoutBtn.addEventListener('click', App.handleLogout);

    // Init App
    App.init();
});
