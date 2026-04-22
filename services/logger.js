/**
 * Simple in-memory logger for StreamFlix Admin Dashboard
 * Keeps a circular buffer of recent logs to show in the UI.
 */

class Logger {
    constructor(limit = 200) {
        this.limit = limit;
        this.logs = [];
    }

    /**
     * Add a log entry
     * @param {string} message 
     * @param {string} type - info, warn, error, success
     * @param {string} source - system, metadata, worker, etc.
     */
    log(message, type = 'info', source = 'system') {
        const entry = {
            timestamp: new Date().toISOString(),
            message,
            type,
            source
        };

        this.logs.push(entry);

        if (this.logs.length > this.limit) {
            this.logs.shift();
        }

        // Also output to console for standard logging
        const prefix = `[${source.toUpperCase()}]`;
        if (type === 'error') console.error(prefix, message);
        else if (type === 'warn') console.warn(prefix, message);
        else console.log(prefix, message);
    }

    info(message, source) { this.log(message, 'info', source); }
    warn(message, source) { this.log(message, 'warn', source); }
    error(message, source) { this.log(message, 'error', source); }
    success(message, source) { this.log(message, 'success', source); }

    getLogs() {
        return this.logs;
    }

    clear() {
        this.logs = [];
    }
}

const logger = new Logger();
module.exports = logger;
