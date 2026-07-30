const axios = require('axios');
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
dotenv.config();

const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const ADMIN_CHAT_ID = process.env.TELEGRAM_ADMIN_CHAT_ID;
const LOGS_DIR = path.join(process.cwd(), 'data', 'logs');

// Import local services
const activityTracker = require('../activityTracker');
const supabaseService = require('../supabaseService');
const telegramAuthService = require('../telegramAuthService');
const alertBot = require('./alertBot');

async function sendTelegramMessage(chat_id, text, parse_mode = 'HTML') {
    try {
        await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
            chat_id, text, parse_mode
        });
    } catch (e) {
        console.error('[BotCommands] Failed to send message:', e.message);
    }
}

async function answerCallbackQuery(callback_query_id, text) {
    try {
        await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/answerCallbackQuery`, {
            callback_query_id, text, show_alert: true
        });
    } catch (e) {
        console.error('[BotCommands] Failed to answer callback query:', e.message);
    }
}

async function editMessageReplyMarkup(chat_id, message_id, reply_markup) {
    try {
        await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/editMessageReplyMarkup`, {
            chat_id, message_id, reply_markup
        });
    } catch (e) {
        console.error('[BotCommands] Failed to edit message reply markup:', e.message);
    }
}

async function sendTelegramReply(chat_id, text, reply_to_message_id, parse_mode = 'HTML') {
    try {
        await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
            chat_id, text, parse_mode,
            reply_parameters: { message_id: reply_to_message_id }
        });
    } catch (e) {
        console.error('[BotCommands] Failed to send reply message:', e.message);
    }
}

function parseBotEvents() {
    const eventsPath = path.join(LOGS_DIR, 'bot_events.jsonl');
    if (!fs.existsSync(eventsPath)) return [];
    const lines = fs.readFileSync(eventsPath, 'utf-8').split('\n').filter(Boolean);
    return lines.map(line => {
        try { return JSON.parse(line); } catch (e) { return null; }
    }).filter(Boolean);
}

function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

async function handleCommand(text) {
    const cmd = text.split(' ')[0].toLowerCase();
    
    if (cmd === '/start' || cmd === '/help') {
        const helpText = `🤖 <b>StreamFlix Admin Bot Commands:</b>\n\n` +
                         `📩 <b>/messages</b> - View all received contact messages\n` +
                         `📊 <b>/stats</b> - View logins today & active viewer count\n` +
                         `📺 <b>/activenow</b> - List currently active streaming sessions\n` +
                         `🔐 <b>/recentlogins</b> - Show recent device logins`;
        return sendTelegramMessage(ADMIN_CHAT_ID, helpText);
    }

    if (cmd === '/stats') {
        const events = parseBotEvents();
        const todayStr = new Date().toISOString().split('T')[0];
        const loginsToday = events.filter(e => e.type === 'Login' && e.timestamp.startsWith(todayStr)).length;
        
        const status = activityTracker ? activityTracker.getStatus() : { activeSessions: 0 };
        const activeCount = status.activeSessions || 0;
        
        return sendTelegramMessage(ADMIN_CHAT_ID, `📊 <b>System Stats</b>\nLogins Today: ${loginsToday}\nActive Viewers: ${activeCount}`);
    }
    
    if (cmd === '/activenow') {
        if (!activityTracker) return sendTelegramMessage(ADMIN_CHAT_ID, 'Activity tracker not loaded.');
        const sessions = activityTracker.getActiveSessionsList ? activityTracker.getActiveSessionsList() : [];
        if (sessions.length === 0) return sendTelegramMessage(ADMIN_CHAT_ID, 'No active sessions right now.');
        
        const lines = sessions.map(s => `• ${s.identity} - ${s.title}`);
        return sendTelegramMessage(ADMIN_CHAT_ID, `📺 <b>Active Sessions:</b>\n${lines.join('\n')}`);
    }
    
    if (cmd === '/recentlogins') {
        const events = parseBotEvents();
        const logins = events.filter(e => e.type === 'Login').slice(-5).reverse();
        if (logins.length === 0) return sendTelegramMessage(ADMIN_CHAT_ID, 'No recent logins found.');
        
        const lines = logins.map(l => `• <b>${l.data.user}</b> on ${l.data.os}/${l.data.browser}\n  IP: ${l.data.ip}`);
        return sendTelegramMessage(ADMIN_CHAT_ID, `🔐 <b>Recent Logins:</b>\n${lines.join('\n\n')}`);
    }

    if (cmd === '/messages' || cmd === '/contact' || cmd === '/inquiries') {
        const events = parseBotEvents();
        const contactMsgs = events.filter(e => e.type === 'ContactMessage').reverse();
        
        if (contactMsgs.length === 0) {
            return sendTelegramMessage(ADMIN_CHAT_ID, '📩 <b>No contact messages received yet.</b>');
        }
        
        const count = contactMsgs.length;
        let replyText = `📩 <b>Received Contact Messages (${count})</b>\n\n`;

        contactMsgs.slice(0, 10).forEach((m, i) => {
            const time = m.timestamp ? new Date(m.timestamp).toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }) : 'Unknown time';
            const name = escapeHtml(m.data.name || 'Anonymous');
            const email = escapeHtml(m.data.email || 'N/A');
            const subject = escapeHtml(m.data.subject || 'General Inquiry');
            const msg = escapeHtml(m.data.message || '');
            
            replyText += `<b>#${i + 1} | ${name}</b> (<code>${email}</code>)\n` +
                         `🏷 Topic: <b>${subject}</b>\n` +
                         `🕒 ${time}\n` +
                         `💬 <i>"${msg.length > 150 ? msg.substring(0, 150) + '...' : msg}"</i>\n\n`;
        });

        if (count > 10) {
            replyText += `<i>Showing latest 10 of ${count} messages.</i>`;
        }

        return sendTelegramMessage(ADMIN_CHAT_ID, replyText);
    }
}

async function handleUpdate(update) {
    if (update.message && update.message.text) {
        if (String(update.message.chat.id) !== String(ADMIN_CHAT_ID)) return;
        
        if (update.message.text.startsWith('/')) {
            await handleCommand(update.message.text);
        }
    }
    
    if (update.callback_query) {
        if (String(update.callback_query.message.chat.id) !== String(ADMIN_CHAT_ID)) return;
        
        const data = update.callback_query.data;
        if (data.startsWith('kick_')) {
            const sessionId = data.replace('kick_', '');
            if (supabaseService) {
                try {
                    await supabaseService.markSessionRevoked(sessionId, 'revoked');
                    await answerCallbackQuery(update.callback_query.id, 'Session has been revoked!');
                    
                    // Parse original message to get who/what device
                    const origText = update.callback_query.message.text || '';
                    const lines = origText.split('\n');
                    let userInfo = 'Unknown User';
                    let deviceInfo = 'Unknown Device';
                    let ipInfo = 'Unknown IP';
                    let locInfo = 'Unknown Location';
                    
                    lines.forEach(l => {
                        if (l.startsWith('User:')) userInfo = l.replace('User:', '').trim();
                        if (l.startsWith('Device:')) deviceInfo = l.replace('Device:', '').trim();
                        if (l.startsWith('IP:')) ipInfo = l.replace('IP:', '').trim();
                        if (l.startsWith('Location:')) locInfo = l.replace('Location:', '').trim();
                    });

                    // Remove the button from original message
                    await editMessageReplyMarkup(ADMIN_CHAT_ID, update.callback_query.message.message_id, { inline_keyboard: [] });
                    
                    // Send a detailed reply
                    const replyMsg = `🚫 <b>Session Kicked Successfully</b>\nUser: ${userInfo}\nDevice: ${deviceInfo}\nIP: ${ipInfo}\nLocation: ${locInfo}\nSession ID: <code>${sessionId}</code>`;
                    await sendTelegramReply(ADMIN_CHAT_ID, replyMsg, update.callback_query.message.message_id);
                } catch (e) {
                    await answerCallbackQuery(update.callback_query.id, 'Failed to revoke session: ' + e.message);
                }
            }
        }
    }
}

let polling = false;
let offset = 0;

async function startPolling() {
    if (!BOT_TOKEN || !ADMIN_CHAT_ID) return;
    polling = true;
    
    while (polling) {
        try {
            const res = await axios.get(`https://api.telegram.org/bot${BOT_TOKEN}/getUpdates`, {
                params: { offset, timeout: 30 }
            });
            
            if (res.data && res.data.ok) {
                for (const update of res.data.result) {
                    offset = update.update_id + 1;
                    await handleUpdate(update);
                }
            }
        } catch (error) {
            if (!error.message.includes('timeout')) {
                // Network error, ignore
                await new Promise(r => setTimeout(r, 5000));
            }
        }
    }
}

function stopPolling() {
    polling = false;
}

module.exports = {
    startPolling,
    stopPolling
};
