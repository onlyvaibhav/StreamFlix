/**
 * StreamFlix Frontend Authentication & Storage Service
 * Handles: Device Fingerprinting, IndexedDB session persistence, and API calls.
 */
(function () {
  'use strict';

  const DB_NAME = 'StreamFlixAuthDB';
  const DB_VERSION = 1;
  const STORE_NAME = 'session_store';

  // --- IndexedDB Helper Functions ---
  function openDB() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onupgradeneeded = function (event) {
        const db = event.target.result;
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          db.createObjectStore(STORE_NAME);
        }
      };

      request.onsuccess = function (event) {
        resolve(event.target.result);
      };

      request.onerror = function (event) {
        console.error('IndexedDB open error:', event.target.error);
        reject(event.target.error);
      };
    });
  }

  function getFromDB(key) {
    return openDB().then((db) => {
      return new Promise((resolve, reject) => {
        const transaction = db.transaction(STORE_NAME, 'readonly');
        const store = transaction.objectStore(STORE_NAME);
        const request = store.get(key);

        request.onsuccess = function () {
          resolve(request.result);
        };

        request.onerror = function () {
          reject(request.error);
        };
      });
    });
  }

  function saveToDB(key, val) {
    return openDB().then((db) => {
      return new Promise((resolve, reject) => {
        const transaction = db.transaction(STORE_NAME, 'readwrite');
        const store = transaction.objectStore(STORE_NAME);
        const request = store.put(val, key);

        request.onsuccess = function () {
          resolve(request.result);
        };

        request.onerror = function () {
          reject(request.error);
        };
      });
    });
  }

  function deleteFromDB(key) {
    return openDB().then((db) => {
      return new Promise((resolve, reject) => {
        const transaction = db.transaction(STORE_NAME, 'readwrite');
        const store = transaction.objectStore(STORE_NAME);
        const request = store.delete(key);

        request.onsuccess = function () {
          resolve();
        };

        request.onerror = function () {
          reject(request.error);
        };
      });
    });
  }

  // --- Device Identification (Fingerprinting) ---
  function generateUUID() {
    // Standard crypto UUID generation if available, fallback otherwise
    if (window.crypto && window.crypto.randomUUID) {
      return window.crypto.randomUUID();
    }
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  }

  function getBrowserName(ua) {
    if (ua.includes('Firefox')) return 'Firefox';
    if (ua.includes('SamsungBrowser')) return 'Samsung Browser';
    if (ua.includes('Opera') || ua.includes('OPR')) return 'Opera';
    if (ua.includes('Trident')) return 'Internet Explorer';
    if (ua.includes('Edge') || ua.includes('Edg')) return 'Microsoft Edge';
    if (ua.includes('Chrome')) return 'Google Chrome';
    if (ua.includes('Safari')) return 'Apple Safari';
    return 'Unknown Browser';
  }

  function getOSName(ua, platform) {
    const p = platform || '';
    if (/iPad|iPhone|iPod/.test(ua) || (p === 'MacIntel' && navigator.maxTouchPoints > 1)) return 'iOS';
    if (/Android/.test(ua)) return 'Android';
    if (/Win/.test(p) || /Windows/.test(ua)) return 'Windows';
    if (/Mac/.test(p) || /Macintosh/.test(ua)) return 'macOS';
    if (/Linux/.test(p) || /Linux/.test(ua)) return 'Linux';
    return 'Unknown OS';
  }

  function getDeviceFingerprint() {
    let deviceId = localStorage.getItem('streamflix_device_id');
    if (!deviceId) {
      deviceId = generateUUID();
      localStorage.setItem('streamflix_device_id', deviceId);
    }

    const ua = navigator.userAgent;
    const platform = navigator.platform || navigator.userAgentData?.platform || '';

    return {
      deviceId,
      browser: getBrowserName(ua),
      os: getOSName(ua, platform),
      platform: platform,
      userAgent: ua,
      screenResolution: `${window.screen.width}x${window.screen.height}`,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
      language: navigator.language || 'en'
    };
  }

  // --- Core AuthService Object ---
  const StreamFlixAuth = {
    // Current in-memory session cache
    sessionToken: null,
    user: null,

    /**
     * Initialize Auth state from IndexedDB
     */
    async initialize() {
      try {
        const storedToken = await getFromDB('sessionToken');
        const storedUser = await getFromDB('user');
        
        if (storedToken && storedUser) {
          this.sessionToken = storedToken;
          this.user = storedUser;
          return { sessionToken: storedToken, user: storedUser };
        }
      } catch (err) {
        console.warn('[AuthService] Failed to load session from IndexedDB:', err.message);
      }
      return null;
    },

    /**
     * Check if user is logged in (has local token)
     */
    isLoggedIn() {
      return !!this.sessionToken;
    },

    /**
     * Save session to IndexedDB and memory
     */
    async saveSession(token, user) {
      this.sessionToken = token;
      this.user = user;
      try {
        await saveToDB('sessionToken', token);
        await saveToDB('user', user);
        await saveToDB('authTimestamp', Date.now());
      } catch (err) {
        console.error('[AuthService] IndexedDB save error:', err.message);
      }
    },

    /**
     * Clear session (Logout locally)
     */
    async clearLocalSession() {
      this.sessionToken = null;
      this.user = null;
      try {
        await deleteFromDB('sessionToken');
        await deleteFromDB('user');
        await deleteFromDB('authTimestamp');
      } catch (err) {
        console.error('[AuthService] IndexedDB clear error:', err.message);
      }
    },

    /**
     * Trigger OTP send
     */
    async sendOTP(phoneNumber) {
      const response = await fetch('/api/auth/telegram/send-code', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phoneNumber })
      });

      const result = await response.json();
      if (!response.ok || !result.success) {
        throw new Error(result.error || 'Failed to send verification code.');
      }
      return result; // { success, loginSessionId, isCodeViaApp }
    },

    /**
     * Verify OTP code
     */
    async verifyOTP(loginSessionId, code) {
      const device = getDeviceFingerprint();
      const response = await fetch('/api/auth/telegram/verify-code', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ loginSessionId, code, device })
      });

      const result = await response.json();
      if (!response.ok || !result.success) {
        throw new Error(result.error || 'OTP verification failed.');
      }
      
      if (result.requiresPassword) {
        return { requiresPassword: true };
      }

      // Save the session token locally
      await this.saveSession(result.sessionToken, result.user);

      if (result.requiresMembership) {
        return { success: true, requiresMembership: true, inviteLink: result.inviteLink, user: result.user };
      }

      return { success: true, user: result.user };
    },

    /**
     * Verify 2FA Password
     */
    async verify2FAPassword(loginSessionId, password) {
      const device = getDeviceFingerprint();
      const response = await fetch('/api/auth/telegram/verify-password', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ loginSessionId, password, device })
      });

      const result = await response.json();
      if (!response.ok || !result.success) {
        throw new Error(result.error || 'Password verification failed.');
      }

      // Save the session token locally
      await this.saveSession(result.sessionToken, result.user);

      if (result.requiresMembership) {
        return { success: true, requiresMembership: true, inviteLink: result.inviteLink, user: result.user };
      }

      return { success: true, user: result.user };
    },

    /**
     * Validate active session with backend (check if revoked on Telegram)
     */
    async validateSessionWithBackend() {
      if (!this.sessionToken) return { authorized: false };

      try {
        const response = await fetch('/api/auth/telegram/status', {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${this.sessionToken}`
          }
        });

        const result = await response.json();
        if (response.ok && result.success && result.authorized) {
          // Token is valid. Update cached user just in case details synced/changed
          if (result.user) {
            await this.saveSession(this.sessionToken, result.user);
          }
          return { authorized: true, user: result.user };
        } else if (response.status === 403 || result.error === 'MEMBERSHIP_REQUIRED') {
          // Valid session, but membership required
          return { authorized: false, requiresMembership: true, inviteLink: result.inviteLink, user: result.user || this.user };
        } else {
          // Stale/revoked session
          console.warn('[AuthService] Backend session check failed or unauthorized:', result.error);
          await this.clearLocalSession();
          return { authorized: false, error: result.error || 'Your session has expired.' };
        }
      } catch (err) {
        console.error('[AuthService] Backend session validation failed:', err.message);
        // On network error, keep current local session rather than logging out user aggressively
        return { authorized: true, user: this.user };
      }
    },

    /**
     * Full logout (local + backend)
     */
    async logout(isRevoked = false) {
      const token = this.sessionToken;
      await this.clearLocalSession();

      if (token) {
        try {
          await fetch('/api/auth/telegram/logout', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${token}`,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({ status: isRevoked ? 'revoked' : 'logout' })
          });
        } catch (err) {
          console.error('[AuthService] Backend logout error:', err.message);
        }
      }
      
      // Reload the page to clear any in-memory app state and redirect to login
      window.location.reload();
    }
  };

  // Expose to window
  window.StreamFlixAuth = StreamFlixAuth;
})();
