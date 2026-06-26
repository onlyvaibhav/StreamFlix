/**
 * Badge / Chip factory — inline status indicators
 */
const Badge = (() => {
    /**
     * @param {string} text
     * @param {string} type - default|success|warning|danger|info|accent
     * @param {boolean} dot - show pulsing dot
     */
    function html(text, type = 'default', dot = false) {
        const cls = `badge badge-${type}` + (dot ? ' badge-live' : '');
        return `<span class="${cls}">${dot ? '<span class="badge-dot"></span>' : ''}${_esc(text)}</span>`;
    }

    /** Map metadata status to a badge */
    function status(statusStr) {
        const map = {
            'COMPLETE':       ['COMPLETE', 'success'],
            'MATCHED':        ['MATCHED', 'info'],
            'MATCHING':       ['MATCHING', 'info'],
            'FETCHING':       ['FETCHING', 'info'],
            'NEW':            ['NEW', 'default'],
            'STUB':           ['STUB', 'default'],
            'FAILED':         ['FAILED', 'danger'],
            'MANUAL_REVIEW':  ['MANUAL REVIEW', 'warning'],
        };
        const [label, type] = map[statusStr] || [statusStr || 'UNKNOWN', 'default'];
        return html(label, type);
    }

    /** Map issue strings to badges */
    function issue(issueStr) {
        if (issueStr === 'tmdb_missing' || issueStr === 'no_tmdb_id') return html('TMDB Missing', 'danger');
        if (issueStr === 'no_title') return html('No Title', 'danger');
        if (issueStr === 'no_poster' || issueStr === 'poster_file_missing') return html('No Poster', 'warning');
        if (issueStr === 'no_backdrop' || issueStr === 'backdrop_file_missing') return html('No Backdrop', 'warning');
        if (issueStr === 'needs_retry') return html('Needs Retry', 'warning');
        if (issueStr === 'manual_probe_needed') return html('Probe Needed', 'warning');
        if (issueStr === 'unsupported_audio') return html('Bad Audio', 'danger');
        if (issueStr === 'never_fetched') return html('Never Fetched', 'default');
        return html(issueStr.replace(/_/g, ' '), 'default');
    }

    /** Media type badge */
    function mediaType(type) {
        return type === 'tv' ? html('TV SHOW', 'info') : html('MOVIE', 'warning');
    }

    function _esc(str) { const d = document.createElement('div'); d.textContent = str || ''; return d.innerHTML; }

    return { html, status, issue, mediaType };
})();

window.Badge = Badge;
