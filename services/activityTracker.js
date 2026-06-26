const EventEmitter = require('events');
const crypto = require('crypto');
const { getDisplayTitle } = require('../utils/metadataUtils');

class ActivityTracker extends EventEmitter {
    constructor() {
        super();
        this.activeSessions = new Map(); // Key: sessionKey (grouped), Value: Session Object
        this.activeRangeRequestsCount = 0; // Total active range requests
        this.mediaViewerCounts = new Map(); // Key: fileId, Value: count
        this.sessionCounter = 0; // Cumulative viewer session counter
        this.workerPaused = false;
        this.idleTimer = null;
        this.IDLE_DELAY_MS = 15000; // 15 seconds debounce for worker resume
        this.SESSION_TIMEOUT_MS = 60000; // 60 seconds inactivity timeout
        this.pausePromise = null;
        this.pauseResolve = null;

        // Statistics
        this.peakViewers = 0;
        this.totalSessionDurationSec = 0;
        this.completedSessions = 0;

        // Dashboard
        this.dashboardInterval = null;
        if (process.env.STREAM_MONITOR === 'true') {
            this._startDashboard();
        }

        // Safety sweep for leaked requests (every 60s)
        this.safetySweepInterval = setInterval(() => {
            this.runSafetySweep();
        }, 60000);
    }

    _startDashboard() {
        if (this.dashboardInterval) return;
        this.dashboardInterval = setInterval(() => {
            if (this.activeSessions.size === 0 && this.activeRangeRequestsCount === 0) return;

            console.log('\n=========================');
            console.log('ACTIVE VIEWERS');
            console.log('==============');

            for (const session of this.activeSessions.values()) {
                const lastActivitySec = Math.round((Date.now() - session.lastSeen) / 1000);
                console.log(`\nViewer #${session.viewerSessionNumber}`);
                console.log(`Title: ${session.title}`);
                console.log(`File ID: ${session.fileId}`);
                console.log(`Active Requests: ${session.activeRequests.size}`);
                console.log(`Last Activity: ${lastActivitySec}s ago`);

                if (session.activeRequests.size > 0) {
                    console.log('Range Requests:');
                    let maxPosition = 0;
                    for (const req of session.activeRequests.values()) {
                        console.log(`* ${req.rangeHeader}`);
                        if (req.currentPosition > maxPosition) {
                            maxPosition = req.currentPosition;
                        }
                    }
                    console.log(`Buffered Position Estimate:\n~${this.formatBytes(maxPosition)}`);
                }

                const watchDuration = (Date.now() - session.firstSeen) / 1000;
                console.log(`Duration:\n${this.formatDuration(watchDuration)}`);
            }

            console.log(`\nTotal Active Viewers: ${this.activeSessions.size}`);
            console.log(`Total Active Range Requests: ${this.activeRangeRequestsCount}`);
            console.log('=========================\n');
        }, 30000);
    }

    /**
     * Builds session key for grouping browser requests
     */
    buildSessionKey({ userId, ip, userAgent, fileId }) {
        if (userId) {
            return `${userId}_${fileId}`;
        }
        return `${ip}_${userAgent}_${fileId}`;
    }

    /**
     * Helper to retrieve session key from parameters
     */
    getSessionKey(ip, userAgent, fileId) {
        return this.buildSessionKey({ userId: null, ip, userAgent, fileId });
    }

    /**
     * Register active viewer (starts or refreshes session)
     */
    registerActivity(fileId, info) {
        const ip = info.ip || 'unknown';
        const userAgent = info.userAgent || 'unknown';
        const sessionKey = this.getSessionKey(ip, userAgent, fileId);
        const now = Date.now();

        if (this.activeSessions.has(sessionKey)) {
            const session = this.activeSessions.get(sessionKey);
            
            // Calculate playbackTime (delta since lastSeen up to 25s threshold)
            const delta = now - session.lastSeen;
            if (delta <= 25000) {
                session.playbackTime += delta;
            }
            
            session.lastSeen = now;

            if (session.expiryTimer) clearTimeout(session.expiryTimer);
            session.expiryTimer = setTimeout(() => {
                this._handleSessionExpiry(sessionKey);
            }, this.SESSION_TIMEOUT_MS);

            console.log(`[Session] Session merged: Session #${session.viewerSessionNumber} (${session.title})`);
            return sessionKey;
        }

        // Create new viewer session (synchronous shell to avoid concurrency race conditions)
        const sessionNumber = ++this.sessionCounter;
        const viewerSessionId = crypto.randomUUID();

        const session = {
            viewerSessionId,
            viewerSessionNumber: sessionNumber,
            sessionKey,
            userId: null, // Reserved for future auth
            fileId,
            title: `File ${fileId}`, // Placeholder until async title resolved
            ip,
            userAgent,
            firstSeen: now,
            lastSeen: now,
            activeRequests: new Map(),
            totalBytesSent: 0,
            playbackTime: 0,
            rangeRequests: [], // For analytics / history tracking
            expiryTimer: setTimeout(() => {
                this._handleSessionExpiry(sessionKey);
            }, this.SESSION_TIMEOUT_MS)
        };

        this.activeSessions.set(sessionKey, session);
        this.peakViewers = Math.max(this.peakViewers, this.activeSessions.size);

        // Increment media-level viewer count in real time
        const currentCount = this.mediaViewerCounts.get(fileId) || 0;
        this.mediaViewerCounts.set(fileId, currentCount + 1);

        // Asynchronously fetch and populate the display title
        getDisplayTitle(fileId).then(title => {
            session.title = title;
            console.log(`[Session] Session created: Session #${sessionNumber} - Title: ${title} (IP: ${ip}, User-Agent: ${userAgent})`);
            console.log(`[Viewer] ▶ Session Started\nSession: #${sessionNumber}\nTitle: ${title}\nFile ID: ${fileId}`);
        }).catch(() => {
            console.log(`[Session] Session created (fallback title): Session #${sessionNumber} (IP: ${ip}, User-Agent: ${userAgent})`);
            console.log(`[Viewer] ▶ Session Started\nSession: #${sessionNumber}\nTitle: ${session.title}\nFile ID: ${fileId}`);
        });

        // Cancel worker resume countdown if active
        if (this.idleTimer) {
            clearTimeout(this.idleTimer);
            this.idleTimer = null;
            console.log('[Tracker] ⏳ Resume countdown cancelled');
        }

        // Pause worker if first session started
        if (!this.workerPaused) {
            this.workerPaused = true;
            this.pausePromise = new Promise(resolve => {
                this.pauseResolve = resolve;
            });
            console.log(`[Tracker] ⏸ Worker paused`);
            this.emit('pause');
        }

        this.emit('stream.started', sessionKey);
        return sessionKey;
    }

    _handleSessionExpiry(sessionKey) {
        const session = this.activeSessions.get(sessionKey);
        if (!session) return;

        // Perform final check and add final playbackTime slice if applicable
        const now = Date.now();
        const delta = now - session.lastSeen;
        if (delta > 0 && delta <= 25000) {
            session.playbackTime += delta;
        }

        console.log(`[Session] Session expired: Session #${session.viewerSessionNumber} (${session.title})`);

        const watchDuration = this.formatDuration(Math.round(session.playbackTime / 1000));
        const totalBytes = this.formatBytes(session.totalBytesSent);

        console.log(`[Viewer] ■ Session Ended\nSession: #${session.viewerSessionNumber}\nTitle: ${session.title}\nWatch Duration: ${watchDuration}\nTotal Bytes: ${totalBytes}`);

        // Decrement media viewer counts with negative validation protection
        const fileId = session.fileId;
        const currentCount = this.mediaViewerCounts.get(fileId) || 0;
        if (currentCount <= 0) {
            console.warn(`[Tracker][WARN]\nNegative viewer count prevented\nFile: ${fileId}`);
            this.mediaViewerCounts.set(fileId, 0);
        } else {
            this.mediaViewerCounts.set(fileId, currentCount - 1);
        }
        if (this.mediaViewerCounts.get(fileId) === 0) {
            this.mediaViewerCounts.delete(fileId);
        }

        // Cleanup session resources to prevent memory leaks
        if (session.expiryTimer) clearTimeout(session.expiryTimer);
        for (const reqInfo of session.activeRequests.values()) {
            this.activeRangeRequestsCount = Math.max(0, this.activeRangeRequestsCount - 1);
        }
        session.activeRequests.clear();
        session.rangeRequests = [];

        this.completedSessions++;
        this.totalSessionDurationSec += (now - session.firstSeen) / 1000;

        this.activeSessions.delete(sessionKey);

        // Resume worker with a 15-second debounce delay
        if (this.activeSessions.size === 0) {
            console.log(`[Tracker] ⏳ No active streams — waiting ${this.IDLE_DELAY_MS / 1000}s to resume...`);
            this.idleTimer = setTimeout(() => {
                this.resumeWorker();
            }, this.IDLE_DELAY_MS);
        }
        
        this.emit('stream.ended', sessionKey);
    }

    /**
     * Registers an HTTP range request under a viewer session
     */
    registerRangeRequest(sessionKey, rangeInfo) {
        let session = this.activeSessions.get(sessionKey);
        if (!session) {
            // Re-create the session if it expired or doesn't exist
            this.registerActivity(rangeInfo.fileId, { ip: rangeInfo.ip, userAgent: rangeInfo.userAgent });
            session = this.activeSessions.get(sessionKey);
        } else {
            // Refresh activity time
            const now = Date.now();
            const delta = now - session.lastSeen;
            if (delta <= 25000) {
                session.playbackTime += delta;
            }
            session.lastSeen = now;

            if (session.expiryTimer) clearTimeout(session.expiryTimer);
            session.expiryTimer = setTimeout(() => {
                this._handleSessionExpiry(sessionKey);
            }, this.SESSION_TIMEOUT_MS);
        }

        const { rangeHeader, startOffset, reqId } = rangeInfo;

        session.activeRequests.set(reqId, {
            rangeHeader: rangeHeader || 'full',
            startOffset: startOffset || 0,
            currentPosition: startOffset || 0,
            bytesSent: 0,
            lastUpdate: Date.now()
        });

        this.activeRangeRequestsCount++;

        console.log(`[Range]\nSession: #${session.viewerSessionNumber}\nbytes=${rangeHeader}`);
    }

    /**
     * Updates the byte counter and position of an active range request
     */
    updateRangeRequestProgress(sessionKey, reqId, bytesTransferred) {
        const session = this.activeSessions.get(sessionKey);
        if (!session) return;

        const reqInfo = session.activeRequests.get(reqId);
        if (reqInfo) {
            reqInfo.bytesSent = bytesTransferred;
            reqInfo.currentPosition = reqInfo.startOffset + bytesTransferred;
            reqInfo.lastUpdate = Date.now();
        }

        const now = Date.now();
        const delta = now - session.lastSeen;
        if (delta <= 25000) {
            session.playbackTime += delta;
        }
        session.lastSeen = now;

        if (session.expiryTimer) clearTimeout(session.expiryTimer);
        session.expiryTimer = setTimeout(() => {
            this._handleSessionExpiry(sessionKey);
        }, this.SESSION_TIMEOUT_MS);
    }

    /**
     * Deregisters a completed range request and adds its bytes to total bytes
     */
    deregisterRangeRequest(sessionKey, reqId, finalBytesTransferred) {
        const session = this.activeSessions.get(sessionKey);
        if (session) {
            const reqInfo = session.activeRequests.get(reqId);
            if (reqInfo) {
                session.totalBytesSent += finalBytesTransferred;
                session.activeRequests.delete(reqId);
            }

            const now = Date.now();
            const delta = now - session.lastSeen;
            if (delta <= 25000) {
                session.playbackTime += delta;
            }
            session.lastSeen = now;

            if (session.expiryTimer) clearTimeout(session.expiryTimer);
            session.expiryTimer = setTimeout(() => {
                this._handleSessionExpiry(sessionKey);
            }, this.SESSION_TIMEOUT_MS);
        }

        this.activeRangeRequestsCount = Math.max(0, this.activeRangeRequestsCount - 1);
    }

    /**
     * Safety sweep to clean up range requests that haven't updated in 120s
     */
    runSafetySweep() {
        const now = Date.now();
        for (const session of this.activeSessions.values()) {
            for (const [reqId, reqInfo] of session.activeRequests.entries()) {
                if (now - reqInfo.lastUpdate > 120000) {
                    console.warn(`[Tracker][WARN] Force cleaning up stale request ${reqId} for Session #${session.viewerSessionNumber} (stale for ${Math.round((now - reqInfo.lastUpdate)/1000)}s)`);
                    session.totalBytesSent += reqInfo.bytesSent;
                    session.activeRequests.delete(reqId);
                    this.activeRangeRequestsCount = Math.max(0, this.activeRangeRequestsCount - 1);
                }
            }
        }
    }

    resumeWorker() {
        if (!this.workerPaused) return;

        this.workerPaused = false;
        this.idleTimer = null;

        if (this.pauseResolve) {
            this.pauseResolve();
            this.pauseResolve = null;
            this.pausePromise = null;
        }

        console.log('[Tracker] ▶ Worker resumed');
        console.log('[Tracker] ✓ Worker idle');
        this.emit('resume');
        this.emit('stream.updated');
    }

    isPaused() {
        return this.workerPaused;
    }

    isStreaming() {
        return this.activeSessions.size > 0;
    }

    async waitIfBusy() {
        while (this.workerPaused) {
            await this.pausePromise;
        }
    }

    async waitIfBusyWithTimeout(maxWaitMs = 300000) {
        if (!this.workerPaused) return false;

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

        if (this.idleTimer) {
            clearTimeout(this.idleTimer);
            this.idleTimer = null;
        }

        this.workerPaused = true;
        this.pausePromise = new Promise(resolve => {
            this.pauseResolve = resolve;
        });

        console.log('[Tracker] ⏸ Worker paused');
        this.emit('pause');
        this.emit('stream.updated');
        return true;
    }

    forceResume() {
        if (!this.workerPaused) return false;

        if (this.idleTimer) {
            clearTimeout(this.idleTimer);
            this.idleTimer = null;
        }

        this.resumeWorker();
        return true;
    }

    onPause(callback) {
        this.on('pause', callback);
    }

    onResume(callback) {
        this.on('resume', callback);
    }

    getStatus() {
        const uniqueFileIds = new Set(Array.from(this.activeSessions.values()).map(s => s.fileId));
        return {
            activeViewers: this.activeSessions.size,
            activeRangeRequests: this.activeRangeRequestsCount,
            activeMedia: uniqueFileIds.size,
            sessions: Array.from(this.activeSessions.values()).map(session => ({
                viewerSessionId: session.viewerSessionId,
                viewerSessionNumber: session.viewerSessionNumber,
                sessionKey: session.sessionKey,
                userId: session.userId,
                fileId: session.fileId,
                title: session.title,
                ip: session.ip,
                userAgent: session.userAgent,
                firstSeen: new Date(session.firstSeen).toISOString(),
                lastSeen: new Date(session.lastSeen).toISOString(),
                totalBytesSent: session.totalBytesSent,
                playbackTime: Math.round(session.playbackTime / 1000), // in seconds
                rangeRequests: Array.from(session.activeRequests.values()).map(req => ({
                    rangeHeader: req.rangeHeader,
                    startOffset: req.startOffset,
                    currentPosition: req.currentPosition,
                    bytesSent: req.bytesSent
                }))
            })),
            mediaViewerCounts: Object.fromEntries(this.mediaViewerCounts)
        };
    }

    formatDuration(seconds) {
        if (!seconds || isNaN(seconds)) return '0s';
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = Math.floor(seconds % 60);
        if (h > 0) return `${h}h ${m}m ${s}s`;
        if (m > 0) return `${m}m ${s}s`;
        return `${s}s`;
    }

    formatBytes(bytes) {
        if (!bytes || isNaN(bytes) || bytes === 0) return '0 B';
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(1024));
        return parseFloat((bytes / Math.pow(1024, i)).toFixed(2)) + ' ' + sizes[i];
    }
}

module.exports = new ActivityTracker();
