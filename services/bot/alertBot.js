const axios = require('axios');
const dotenv = require('dotenv');
const fs = require('fs').promises;
const path = require('path');
dotenv.config();

const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const ADMIN_CHAT_ID = process.env.TELEGRAM_ADMIN_CHAT_ID;
const LOGS_DIR = path.join(process.cwd(), 'data', 'logs');

async function logEvent(type, data) {
    try {
        await fs.mkdir(LOGS_DIR, { recursive: true });
        const logEntry = JSON.stringify({
            timestamp: new Date().toISOString(),
            type,
            data
        }) + '\n';
        await fs.appendFile(path.join(LOGS_DIR, 'bot_events.jsonl'), logEntry, 'utf-8');
    } catch (err) {
        console.error('[AlertBot] Failed to write event to log:', err.message);
    }
}

async function fetchGeoData(ip) {
    if (!ip || ip === 'Unknown' || ip === '127.0.0.1' || ip === '::1' || ip.startsWith('192.168.') || ip.startsWith('10.')) return null;
    try {
        const res = await axios.get(`http://ip-api.com/json/${ip}?fields=status,country,regionName`);
        if (res.data.status === 'success') {
            return `${res.data.regionName}, ${res.data.country}`;
        }
    } catch (e) {
        // Ignore API failures quietly so we don't break login flows
    }
    return null;
}

const BATCH_WINDOW_MS = 5000;
let batchQueue = [];
let batchTimeout = null;

async function _sendWithRetry(chat_id, text, reply_markup = undefined, parse_mode = 'HTML', retries = 3) {
    if (!BOT_TOKEN || !chat_id) return;
    const url = `https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`;
    
    for (let attempt = 1; attempt <= retries; attempt++) {
        try {
            await axios.post(url, { chat_id, text, parse_mode, reply_markup });
            return;
        } catch (error) {
            console.error(`[AlertBot] Send failed (attempt ${attempt}/${retries}): ${error.message}`);
            if (attempt === retries) {
                console.error('[AlertBot] Max retries reached. Message dropped.');
                return;
            }
            await new Promise(r => setTimeout(r, 1000 * Math.pow(2, attempt - 1)));
        }
    }
}

async function flushBatch() {
    batchTimeout = null;
    if (batchQueue.length === 0) return;
    
    const grouped = {};
    for (const item of batchQueue) {
        if (!grouped[item.type]) grouped[item.type] = [];
        grouped[item.type].push(item);
    }
    
    batchQueue = []; // clear
    
    for (const [type, items] of Object.entries(grouped)) {
        if (items.length >= 3) {
            const digest = `⚡ <b>Burst Alert</b>\n<b>${items.length}</b> new <code>${type}</code> events occurred in the last few seconds.`;
            await _sendWithRetry(ADMIN_CHAT_ID, digest);
        } else {
            for (const item of items) {
                await _sendWithRetry(ADMIN_CHAT_ID, item.message, item.reply_markup);
            }
        }
    }
}

async function enqueueAlert(type, message, immediate = false, reply_markup = undefined) {
    if (immediate) {
        return _sendWithRetry(ADMIN_CHAT_ID, message, reply_markup);
    }
    
    batchQueue.push({ type, message, reply_markup });
    
    if (!batchTimeout) {
        batchTimeout = setTimeout(() => flushBatch(), BATCH_WINDOW_MS);
    }
}

async function sendAlert(message, type = 'Alert', immediate = false, reply_markup = undefined) {
    return enqueueAlert(type, message, immediate, reply_markup);
}

async function notifyLogin(user, device) {
    const name = user.firstName || user.username || 'Unknown User';
    const os = device.os || 'Unknown OS';
    const browser = device.browser || 'Unknown Browser';
    const ip = device.ip || 'Unknown';
    const geo = await fetchGeoData(ip);
    const locStr = geo ? `\nLocation: ${geo}` : '';
    const msg = `🔐 <b>New Login</b>\nUser: ${name}\nDevice: ${os} / ${browser}\nIP: ${ip}${locStr}`;
    logEvent('Login', { user: name, os, browser, ip, geo });
    
    // Add inline button to kick session if sessionToken provided
    const reply_markup = device.sessionId ? {
        inline_keyboard: [[
            { text: "🛑 Kick this session", callback_data: `kick_${device.sessionId}` }
        ]]
    } : undefined;

    return sendAlert(msg, 'Login', false, reply_markup);
}

async function notifyOtpRequest(phone, ip) {
    const geo = await fetchGeoData(ip);
    const locStr = geo ? `\nLocation: ${geo}` : '';
    const msg = `📱 <b>OTP Request</b>\nPhone: <code>${phone}</code>\nIP: ${ip || 'Unknown'}${locStr}`;
    logEvent('OtpRequest', { phone, ip: ip || 'Unknown', geo });
    return sendAlert(msg, 'OtpRequest');
}

async function notifyNonMemberLogin(user, device) {
    const name = user.firstName || user.username || 'Unknown User';
    const id = user.telegramId || user.id || 'Unknown ID';
    const os = device.os || 'Unknown OS';
    const browser = device.browser || 'Unknown Browser';
    const ip = device.ip || 'Unknown';
    const geo = await fetchGeoData(ip);
    const locStr = geo ? `\nLocation: ${geo}` : '';
    const msg = `🚫 <b>Non-Member Login Attempt</b>\nUser: ${name} (ID: ${id})\nDevice: ${os} / ${browser}\nIP: ${ip}${locStr}`;
    logEvent('NonMemberLogin', { user: name, id, os, browser, ip, geo });
    return sendAlert(msg, 'NonMemberLogin');
}

function notifyPreLoginCleanup(deviceId, revokedCount) {
    const msg = `🧹 <b>Pre-Login Session Cleanup</b>\nDevice: <code>${deviceId}</code>\nSessions Revoked: ${revokedCount}`;
    logEvent('PreLoginCleanup', { deviceId, revokedCount });
    return sendAlert(msg, 'PreLoginCleanup');
}

function notifyWatchStart(session) {
    const name = session.identity || 'Anonymous';
    const ip = session.ip || 'Unknown';
    const msg = `▶️ <b>Started Watching</b>\nUser: ${name}\nTitle: ${session.title}\nFile ID: ${session.fileId}\nIP: ${ip}`;
    logEvent('WatchStart', { user: name, title: session.title, fileId: session.fileId, ip });
    return sendAlert(msg, 'WatchStart');
}

function notifyLogout(user, actionType, deviceId) {
    if (!user) return;
    const name = user.first_name || user.firstName || user.username || 'Unknown User';
    const id = user.telegram_id || user.telegramId || 'Unknown ID';
    const msg = `🚪 <b>${actionType}</b>\nUser: ${name} (ID: ${id})\nDevice: <code>${deviceId || 'Unknown'}</code>`;
    logEvent('Logout', { user: name, id, actionType, deviceId: deviceId || 'Unknown' });
    return sendAlert(msg, 'Logout');
}

function formatDuration(ms) {
    if (ms < 1000) return '0s';
    const totalSeconds = Math.round(ms / 1000);
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    
    let parts = [];
    if (hours > 0) parts.push(`${hours}h`);
    if (minutes > 0) parts.push(`${minutes}m`);
    if (seconds > 0 || parts.length === 0) parts.push(`${seconds}s`);
    
    return parts.join(' ');
}

function notifyWatchEnd(session, durationMs) {
    const name = session.identity || 'Anonymous';
    const duration = formatDuration(durationMs);
    const ip = session.ip || 'Unknown';
    const msg = `🛑 <b>Stopped Watching</b>\nUser: ${name}\nTitle: ${session.title}\nDuration: ${duration}\nIP: ${ip}`;
    logEvent('WatchEnd', { user: name, title: session.title, durationMs, ip });
    return sendAlert(msg, 'WatchEnd');
}

function notifyError(user, errorMsg, context = '') {
    const name = user ? (user.first_name || user.firstName || user.username || 'Unknown User') : 'System/Anonymous';
    const msg = `⚠️ <b>Error Alert</b>\nUser: ${name}\nContext: ${context}\nError: <code>${errorMsg}</code>`;
    logEvent('Error', { user: name, errorMsg, context });
    return sendAlert(msg, 'Error', true);
}

// Schedule Daily Digest
setInterval(() => {
    const now = new Date();
    // Run roughly at midnight UTC (check every minute)
    if (now.getUTCHours() === 0 && now.getUTCMinutes() === 0) {
        sendDailyDigest();
    }
}, 60000);

async function sendDailyDigest() {
    try {
        const eventsPath = path.join(LOGS_DIR, 'bot_events.jsonl');
        const raw = await fs.promises.readFile(eventsPath, 'utf-8');
        const events = raw.split('\n').filter(Boolean).map(l => {
            try { return JSON.parse(l); } catch(e) { return null; }
        }).filter(Boolean);
        
        const yesterday = new Date();
        yesterday.setUTCDate(yesterday.getUTCDate() - 1);
        const yesterdayStr = yesterday.toISOString().split('T')[0];
        
        const dailyEvents = events.filter(e => e.timestamp.startsWith(yesterdayStr));
        
        let totalDurationMs = 0;
        const uniqueTitles = new Set();
        const uniqueViewers = new Set();
        
        dailyEvents.forEach(e => {
            if (e.type === 'WatchEnd' && e.data.durationMs) {
                totalDurationMs += e.data.durationMs;
            }
            if (e.type === 'WatchStart' && e.data.title) {
                uniqueTitles.add(e.data.title);
            }
            if (e.data.user && e.type !== 'Error') {
                uniqueViewers.add(e.data.user);
            }
        });
        
        if (totalDurationMs > 0 || uniqueViewers.size > 0) {
            const digest = `📅 <b>Daily Digest (${yesterdayStr})</b>\n\n` +
                           `⏱ Total Watch Time: <b>${formatDuration(totalDurationMs)}</b>\n` +
                           `👥 Unique Viewers: <b>${uniqueViewers.size}</b>\n` +
                           `🎬 Unique Titles Watched: <b>${uniqueTitles.size}</b>`;
            await sendAlert(digest, 'Digest');
        }
    } catch (e) {
        console.error('[AlertBot] Failed to send daily digest:', e.message);
    }
}

module.exports = {
    sendAlert,
    sendDailyDigest,
    notifyLogin,
    notifyWatchStart,
    notifyLogout,
    notifyWatchEnd,
    notifyError,
    notifyOtpRequest,
    notifyNonMemberLogin,
    notifyPreLoginCleanup
};
