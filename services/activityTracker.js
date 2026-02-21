const EventEmitter = require('events');

class ActivityTracker extends EventEmitter {
    constructor() {
        super();
        this.activeSessions = new Map(); // Key: fileId, Value: Session Object
        this.workerPaused = false;
        this.idleTimer = null;
        this.IDLE_DELAY_MS = 10000; // 10 seconds
        this.SESSION_TIMEOUT_MS = 30000; // 30 seconds
        this.pausePromise = null;
        this.pauseResolve = null;
    }

    /**
     * Register activity for a file (creates or refreshes session)
     * @param {string} fileId - The file being streamed
     * @param {object} info - { ip }
     */
    registerActivity(fileId, info) {
        // Clear global idle timer if active (someone is streaming!)
        if (this.idleTimer) {
            clearTimeout(this.idleTimer);
            this.idleTimer = null;
        }

        const now = Date.now();

        if (this.activeSessions.has(fileId)) {
            // REFRESH existing session
            const session = this.activeSessions.get(fileId);

            // Update activity timestamp
            session.lastActivity = now;

            // Reset expiry timer
            if (session.expiryTimer) clearTimeout(session.expiryTimer);
            session.expiryTimer = setTimeout(() => {
                this._handleSessionExpiry(fileId);
            }, this.SESSION_TIMEOUT_MS);

            // No log spam for refreshes
        } else {
            // NEW SESSION
            const session = {
                fileId,
                ip: info.ip,
                startTime: now,
                lastActivity: now,
                expiryTimer: setTimeout(() => {
                    this._handleSessionExpiry(fileId);
                }, this.SESSION_TIMEOUT_MS)
            };

            this.activeSessions.set(fileId, session);

            if (!this.workerPaused) {
                // Pause the worker
                this.workerPaused = true;
                this.pausePromise = new Promise(resolve => {
                    this.pauseResolve = resolve;
                });
                console.log(`[Tracker] ⏸️ Worker PAUSED — streaming: ${fileId}`);
                this.emit('pause');
            } else {
                console.log(`[Tracker] 📺 New file streaming: ${fileId} (${this.activeSessions.size} active)`);
            }
        }
    }

    _handleSessionExpiry(fileId) {
        const session = this.activeSessions.get(fileId);
        if (!session) return;

        const duration = ((Date.now() - session.startTime) / 1000).toFixed(0);
        console.log(`[Tracker] 📺 Stream session expired: ${fileId} (watched for ${duration}s)`);

        this.activeSessions.delete(fileId);

        if (this.activeSessions.size === 0) {
            console.log(`[Tracker] ⏳ No active streams — waiting ${this.IDLE_DELAY_MS / 1000}s to resume...`);
            this.idleTimer = setTimeout(() => {
                this.resumeWorker();
            }, this.IDLE_DELAY_MS);
        }
    }

    /**
     * Manual force unregister (optional, mostly for admin or strict cleanup)
     */
    unregisterStream(fileId) {
        if (this.activeSessions.has(fileId)) {
            const session = this.activeSessions.get(fileId);
            if (session.expiryTimer) clearTimeout(session.expiryTimer);
            this._handleSessionExpiry(fileId);
        }
    }

    resumeWorker() {
        if (!this.workerPaused) return;

        this.workerPaused = false;
        this.idleTimer = null;

        // Resolve the blocking promise to let waiting tasks continue
        if (this.pauseResolve) {
            this.pauseResolve();
            this.pauseResolve = null;
            this.pausePromise = null;
        }

        console.log('[Tracker] ▶️ Worker RESUMED — server idle');
        this.emit('resume');
    }

    isPaused() {
        return this.workerPaused;
    }

    isStreaming() {
        return this.activeSessions.size > 0;
    }

    /**
     * Blocks execution if worker is paused. Resolves immediately if running.
     */
    async waitIfBusy() {
        if (!this.workerPaused) return;

        console.log('[Tracker] 💤 Worker task waiting for streams to finish...');
        await this.pausePromise;
    }

    /**
     * Blocks with timeout. Returns true if timed out (throttled), false if resumed normally.
     */
    async waitIfBusyWithTimeout(maxWaitMs = 300000) { // 5 minutes default
        if (!this.workerPaused) return false;

        console.log('[Tracker] 💤 Worker waiting (with timeout)...');

        let timer;
        const timeoutPromise = new Promise(resolve => {
            timer = setTimeout(() => resolve(true), maxWaitMs);
        });

        const resumedPromise = this.pausePromise.then(() => false);

        const result = await Promise.race([timeoutPromise, resumedPromise]);
        clearTimeout(timer);
        return result;
    }

    forcePause() {
        if (this.workerPaused) return false;

        // Clear idle timer if active
        if (this.idleTimer) {
            clearTimeout(this.idleTimer);
            this.idleTimer = null;
        }

        this.workerPaused = true;
        this.pausePromise = new Promise(resolve => {
            this.pauseResolve = resolve;
        });

        console.log('[Tracker] ⏸️ Worker MANUALLY PAUSED');
        this.emit('pause');
        return true;
    }

    forceResume() {
        if (!this.workerPaused) return false;

        // Clear any idle timer
        if (this.idleTimer) {
            clearTimeout(this.idleTimer);
            this.idleTimer = null;
        }

        this.resumeWorker(); // Handles promise resolution and logging
        return true;
    }

    onPause(callback) {
        this.on('pause', callback);
    }

    onResume(callback) {
        this.on('resume', callback);
    }

    getStatus() {
        return {
            workerPaused: this.workerPaused,
            activeSessions: this.activeSessions.size,
            idleTimerActive: !!this.idleTimer,
            pendingWorkerTasks: 0,
            sessions: Array.from(this.activeSessions.values()).map(session => ({
                fileId: session.fileId,
                ip: session.ip,
                startTime: new Date(session.startTime).toISOString(),
                lastActivity: new Date(session.lastActivity).toISOString(),
                watchDuration: `${((Date.now() - session.startTime) / 1000).toFixed(0)}s`,
                idleFor: `${((Date.now() - session.lastActivity) / 1000).toFixed(0)}s`
            }))
        };
    }
}

// Export singleton instance
module.exports = new ActivityTracker();
