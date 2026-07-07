const { TelegramClient, Api } = require('telegram');
const { StringSession } = require('telegram/sessions');
const { computeCheck } = require('telegram/Password');
const crypto = require('crypto');
const config = require('../config/telegram');
const telegramService = require('./telegramService');

// In-memory pool for active auth clients during the multi-step flow
// Key: loginSessionId (uuid) -> Value: { client, phoneNumber, phoneCodeHash, createdAt }
const pendingClients = new Map();

/**
 * Check if a Telegram user is a member of the configured channel.
 */
async function checkChannelMembership(telegramId) {
  if (!telegramId) return false;
  if (!config.channelId) {
    console.warn('[TelegramAuth] No channel ID configured, skipping membership check.');
    return true;
  }

  const masterClient = telegramService.getClient();
  if (!masterClient) {
    console.warn('[TelegramAuth] Master client not initialized, skipping membership check.');
    return true;
  }

  try {
    const rawChannelId = config.channelId;
    let channelPeer;
    try {
      channelPeer = await masterClient.getInputEntity(rawChannelId);
    } catch (err) {
      channelPeer = rawChannelId;
    }

    await masterClient.invoke(
      new Api.channels.GetParticipant({
        channel: channelPeer,
        participant: parseInt(telegramId)
      })
    );
    return true;
  } catch (error) {
    const errorMsg = error.message || String(error);
    if (errorMsg.includes('USER_NOT_PARTICIPANT')) {
      console.log(`[TelegramAuth] User ${telegramId} is not in channel ${config.channelId}`);
      return false;
    }
    console.error(`[TelegramAuth] Membership check error for ${telegramId}:`, errorMsg);
    return false;
  }
}

/**
 * Dynamically resolves the channel invite link or username link.
 */
async function getChannelInviteLink() {
  if (!config.channelId) return null;
  const masterClient = telegramService.getClient();
  if (!masterClient) return null;

  try {
    const rawChannelId = config.channelId;
    const channelPeer = await masterClient.getInputEntity(rawChannelId);
    const fullChannel = await masterClient.invoke(
      new Api.channels.GetFullChannel({
        channel: channelPeer
      })
    );

    if (fullChannel.chats && fullChannel.chats[0] && fullChannel.chats[0].username) {
      return `https://t.me/${fullChannel.chats[0].username}`;
    }
    if (fullChannel.fullChat && fullChannel.fullChat.exportedInvite) {
      return fullChannel.fullChat.exportedInvite.link;
    }
    return null;
  } catch (err) {
    console.error('[TelegramAuth] Failed to resolve channel invite link:', err.message);
    return null;
  }
}

// Eviction interval to clean up stale authentication clients (e.g. older than 10 minutes)
setInterval(() => {
  const now = Date.now();
  for (const [id, session] of pendingClients.entries()) {
    if (now - session.createdAt > 10 * 60 * 1000) { // 10 minutes timeout
      console.log(`[TelegramAuth] Evicting stale login session: ${id}`);
      try {
        session.client.disconnect();
      } catch (err) {
        // Silent catch
      }
      pendingClients.delete(id);
    }
  }
}, 60 * 1000);

/**
 * Step 1: Initiate auth by sending OTP code to user's Telegram app/number
 */
async function sendCode(phoneNumber) {
  if (!phoneNumber) {
    throw new Error('Phone number is required');
  }

  // Format phone number (ensure it has country code, trim spaces/plus signs)
  const cleanPhone = phoneNumber.replace(/[\s\(\)\-\+]/g, '');

  const loginSessionId = crypto.randomUUID();
  const client = new TelegramClient(
    new StringSession(''),
    config.apiId,
    config.apiHash,
    {
      connectionRetries: 3,
      requestRetries: 2,
      useWSS: true,
      deviceModel: 'StreamFlix Web',
      systemVersion: 'Web SPA',
      appVersion: '1.0.0'
    }
  );

  console.log(`[TelegramAuth] Initiating client connection for ${cleanPhone}...`);
  await client.connect();

  console.log(`[TelegramAuth] Requesting Telegram login code for ${cleanPhone}...`);
  const result = await client.sendCode(
    {
      apiId: config.apiId,
      apiHash: config.apiHash
    },
    cleanPhone
  );

  pendingClients.set(loginSessionId, {
    client,
    phoneNumber: cleanPhone,
    phoneCodeHash: result.phoneCodeHash,
    isCodeViaApp: result.isCodeViaApp,
    createdAt: Date.now()
  });

  return {
    loginSessionId,
    phoneCodeHash: result.phoneCodeHash,
    isCodeViaApp: result.isCodeViaApp
  };
}

/**
 * Step 2: Verify the OTP code sent to Telegram
 */
async function verifyCode(loginSessionId, code) {
  const session = pendingClients.get(loginSessionId);
  if (!session) {
    throw new Error('Verification session has expired or is invalid. Please restart login.');
  }

  const { client, phoneNumber, phoneCodeHash } = session;

  try {
    console.log(`[TelegramAuth] Verifying code for login session ${loginSessionId}...`);
    
    // Invoke raw sign-in
    const result = await client.invoke(
      new Api.auth.SignIn({
        phoneNumber,
        phoneCodeHash,
        phoneCode: code
      })
    );

    // If result is AuthorizationSignUpRequired, user doesn't have an account
    if (result instanceof Api.auth.AuthorizationSignUpRequired) {
      throw new Error('SIGNUP_REQUIRED: Account registration is not supported through StreamFlix. Please register via official Telegram app first.');
    }

    // Success! Get User info and Session String
    const me = result.user || await client.getMe();
    const sessionString = client.session.save();

    // Cleanup resources
    await client.disconnect();
    pendingClients.delete(loginSessionId);

    return {
      sessionString,
      user: normalizeTelegramUser(me)
    };
  } catch (error) {
    if (error.message && error.message.includes('SESSION_PASSWORD_NEEDED')) {
      console.log(`[TelegramAuth] 2FA required for login session ${loginSessionId}`);
      return {
        requiresPassword: true
      };
    }
    throw error;
  }
}

/**
 * Step 3: Verify 2FA password (if enabled)
 */
async function verifyPassword(loginSessionId, password) {
  const session = pendingClients.get(loginSessionId);
  if (!session) {
    throw new Error('Verification session has expired or is invalid. Please restart login.');
  }

  const { client } = session;

  try {
    console.log(`[TelegramAuth] Verifying 2FA password for login session ${loginSessionId}...`);
    
    // Get SRP params
    const passwordSrpResult = await client.invoke(new Api.account.GetPassword());
    
    // Compute SRP check hash
    const passwordSrpCheck = await computeCheck(passwordSrpResult, password);
    
    // Sign in using the password hash
    const result = await client.invoke(
      new Api.auth.CheckPassword({
        password: passwordSrpCheck
      })
    );

    const me = result.user || await client.getMe();
    const sessionString = client.session.save();

    // Cleanup resources
    await client.disconnect();
    pendingClients.delete(loginSessionId);

    return {
      sessionString,
      user: normalizeTelegramUser(me)
    };
  } catch (error) {
    throw error;
  }
}

/**
 * Validate session string validity
 */
async function validateSession(sessionString) {
  if (!sessionString) return false;

  const client = new TelegramClient(
    new StringSession(sessionString),
    config.apiId,
    config.apiHash,
    {
      connectionRetries: 1,
      requestRetries: 1,
      useWSS: true,
      receiveUpdates: false // Disable updates completely to prevent update loop timeouts!
    }
  );

  try {
    await client.connect();
    const isAuthorized = await client.checkAuthorization();
    await client.disconnect();
    return isAuthorized;
  } catch (err) {
    console.error('[TelegramAuth] Session validation error:', err.message);
    try {
      await client.disconnect();
    } catch (_) {}
    return false;
  }
}

/**
 * Terminate/Log out Telegram Session
 */
async function logoutSession(sessionString) {
  if (!sessionString) return true;

  const client = new TelegramClient(
    new StringSession(sessionString),
    config.apiId,
    config.apiHash,
    {
      connectionRetries: 1,
      requestRetries: 1,
      useWSS: true,
      receiveUpdates: false // Disable updates completely to prevent update loop timeouts!
    }
  );

  try {
    await client.connect();
    // Log out standard session from Telegram servers
    await client.logOut();
    await client.disconnect();
    return true;
  } catch (err) {
    console.error('[TelegramAuth] Session logout error:', err.message);
    try {
      await client.disconnect();
    } catch (_) {}
    return false;
  }
}

/**
 * Normalize the Telegram user object attributes
 */
function normalizeTelegramUser(rawUser) {
  if (!rawUser) return null;
  return {
    telegramId: rawUser.id.toString(),
    username: rawUser.username || '',
    firstName: rawUser.firstName || '',
    lastName: rawUser.lastName || '',
    phone: rawUser.phone || '',
    premium: !!rawUser.premium,
    language: rawUser.langCode || 'en',
    profilePhoto: rawUser.photo ? 'has_photo' : null, // Indicate presence, client can resolve avatar
    bot: !!rawUser.bot,
    verified: !!rawUser.verified,
    scam: !!rawUser.scam,
    fake: !!rawUser.fake
  };
}

module.exports = {
  sendCode,
  verifyCode,
  verifyPassword,
  validateSession,
  logoutSession,
  checkChannelMembership,
  getChannelInviteLink
};
