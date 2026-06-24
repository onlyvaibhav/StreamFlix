const fs = require('fs').promises;
const path = require('path');

const DATA_DIR = path.join(__dirname, '../data/metadata');

/**
 * Gets a human-readable display title for a file ID.
 * Tries to use the in-memory cache first, then falls back to disk.
 * @param {string} fileId 
 * @returns {Promise<string>}
 */
async function getDisplayTitle(fileId) {
    try {
        // Try to access global metadata cache if it exists (set by server.js or metadataWorker)
        if (global._metadataCache) {
            const cached = global._metadataCache.find(m => m.fileId === fileId);
            if (cached) return formatTitle(cached);
        }

        // Fallback to reading from disk
        const filePath = path.join(DATA_DIR, `${fileId}.json`);
        const raw = await fs.readFile(filePath, 'utf-8');
        const meta = JSON.parse(raw);
        return formatTitle(meta);
    } catch (err) {
        return `File ${fileId}`; // Fallback if not found
    }
}

function formatTitle(meta) {
    if (meta.type === 'tv' && meta.tv) {
        const sNum = String(meta.tv.seasonNumber || 1).padStart(2, '0');
        const eNum = String(meta.tv.episodeNumber || 1).padStart(2, '0');
        const showTitle = meta.tv.showTitle || meta.title;
        return `${showTitle} S${sNum}E${eNum}`;
    }
    
    // Movie
    const year = meta.year ? ` (${meta.year})` : '';
    return `${meta.title || meta.fileName || meta.fileId}${year}`;
}

module.exports = {
    getDisplayTitle
};
