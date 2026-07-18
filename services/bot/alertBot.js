const axios = require('axios');
const dotenv = require('dotenv');
dotenv.config();

const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const ADMIN_CHAT_ID = process.env.TELEGRAM_ADMIN_CHAT_ID;

async function sendAlert(message) {
    if (!BOT_TOKEN || !ADMIN_CHAT_ID) return;
    
    try {
        const url = `https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`;
        await axios.post(url, {
            chat_id: ADMIN_CHAT_ID,
            text: message,
            parse_mode: 'HTML'
        });
    } catch (error) {
        console.error('[AlertBot] Failed to send alert:', error.message);
    }
}

function notifyLogin(user, device) {
    const name = user.firstName || user.username || 'Unknown User';
    const os = device.os || 'Unknown OS';
    const browser = device.browser || 'Unknown Browser';
    const msg = `🔐 <b>New Login</b>\nUser: ${name}\nDevice: ${os} / ${browser}`;
    return sendAlert(msg);
}

function notifyOtpRequest(phone, ip) {
    const msg = `📱 <b>OTP Request</b>\nPhone: <code>${phone}</code>\nIP: ${ip || 'Unknown'}`;
    return sendAlert(msg);
}

function notifyNonMemberLogin(user, device) {
    const name = user.firstName || user.username || 'Unknown User';
    const id = user.telegramId || user.id || 'Unknown ID';
    const os = device.os || 'Unknown OS';
    const browser = device.browser || 'Unknown Browser';
    const msg = `🚫 <b>Non-Member Login Attempt</b>\nUser: ${name} (ID: ${id})\nDevice: ${os} / ${browser}`;
    return sendAlert(msg);
}

function notifyWatchStart(session) {
    const name = session.identity || 'Anonymous';
    const msg = `▶️ <b>Started Watching</b>\nUser: ${name}\nTitle: ${session.title}\nFile ID: ${session.fileId}`;
    return sendAlert(msg);
}

function notifyLogout(user, actionType, deviceId) {
    if (!user) return;
    const name = user.first_name || user.firstName || user.username || 'Unknown User';
    const id = user.telegram_id || user.telegramId || 'Unknown ID';
    const msg = `🚪 <b>${actionType}</b>\nUser: ${name} (ID: ${id})\nDevice: <code>${deviceId || 'Unknown'}</code>`;
    return sendAlert(msg);
}

function notifyWatchEnd(session, durationMs) {
    const name = session.identity || 'Anonymous';
    const minutes = Math.round(durationMs / 60000);
    const msg = `🛑 <b>Stopped Watching</b>\nUser: ${name}\nTitle: ${session.title}\nDuration: ${minutes} min`;
    return sendAlert(msg);
}

function notifyError(user, errorMsg, context = '') {
    const name = user ? (user.first_name || user.firstName || user.username || 'Unknown User') : 'System/Anonymous';
    const msg = `⚠️ <b>Error Alert</b>\nUser: ${name}\nContext: ${context}\nError: <code>${errorMsg}</code>`;
    return sendAlert(msg);
}

module.exports = {
    sendAlert,
    notifyLogin,
    notifyWatchStart,
    notifyLogout,
    notifyWatchEnd,
    notifyError,
    notifyOtpRequest,
    notifyNonMemberLogin
};
