const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

let supabase = null;

// In-Memory Fallback Stores (used if Supabase tables don't exist or DB calls fail)
const memoryUsers = new Map();
const memoryDevices = new Map();
const memorySessions = new Map();

if (!supabaseUrl) {
  console.warn('⚠️ SUPABASE_URL not configured in .env. Database synchronization will be disabled.');
} else if (!supabaseServiceKey) {
  console.warn('⚠️ SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY not configured in .env. Database synchronization will be disabled.');
} else {
  try {
    supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false
      }
    });
    console.log('✅ Supabase Client initialized successfully.');
  } catch (err) {
    console.error('❌ Failed to initialize Supabase client:', err.message);
  }
}

/**
 * Helper to check if Supabase is enabled
 */
function isEnabled() {
  return supabase !== null;
}

/**
 * Upsert user profile info into the users table.
 */
async function syncUser(userData) {
  // Always update in-memory cache as fallback
  const telegramId = parseInt(userData.telegramId);
  memoryUsers.set(telegramId, {
    telegram_id: telegramId,
    username: userData.username || null,
    first_name: userData.firstName || 'Telegram User',
    last_name: userData.lastName || null,
    phone: userData.phone || null,
    premium: !!userData.premium,
    language: userData.language || null,
    profile_photo: userData.profilePhoto || null,
    updated_at: new Date().toISOString()
  });

  if (!isEnabled()) {
    return memoryUsers.get(telegramId);
  }

  try {
    const payload = {
      telegram_id: telegramId,
      username: userData.username || null,
      first_name: userData.firstName || 'Telegram User',
      last_name: userData.lastName || null,
      phone: userData.phone || null,
      premium: !!userData.premium,
      language: userData.language || null,
      profile_photo: userData.profilePhoto || null,
      updated_at: new Date().toISOString()
    };

    const { data, error } = await supabase
      .from('users')
      .upsert(payload, { onConflict: 'telegram_id' })
      .select()
      .single();

    if (error) {
      console.error('❌ Supabase syncUser error (falling back to memory):', error.message, error.details);
      return memoryUsers.get(telegramId);
    }
    return data;
  } catch (err) {
    console.error('❌ Failed to sync user in Supabase (falling back to memory):', err.message);
    return memoryUsers.get(telegramId);
  }
}

/**
 * Upsert device info into the devices table.
 */
async function syncDevice(deviceData) {
  const telegramId = parseInt(deviceData.telegramId);
  memoryDevices.set(deviceData.deviceId, {
    device_id: deviceData.deviceId,
    telegram_id: telegramId,
    browser: deviceData.browser || null,
    os: deviceData.os || null,
    platform: deviceData.platform || null,
    user_agent: deviceData.userAgent || null,
    last_active: new Date().toISOString()
  });

  if (!isEnabled()) {
    return memoryDevices.get(deviceData.deviceId);
  }

  try {
    const payload = {
      device_id: deviceData.deviceId,
      telegram_id: telegramId,
      browser: deviceData.browser || null,
      os: deviceData.os || null,
      platform: deviceData.platform || null,
      user_agent: deviceData.userAgent || null,
      last_active: new Date().toISOString()
    };

    const { data, error } = await supabase
      .from('devices')
      .upsert(payload, { onConflict: 'device_id' })
      .select()
      .single();

    if (error) {
      console.error('❌ Supabase syncDevice error (falling back to memory):', error.message);
      return memoryDevices.get(deviceData.deviceId);
    }
    return data;
  } catch (err) {
    console.error('❌ Failed to sync device in Supabase (falling back to memory):', err.message);
    return memoryDevices.get(deviceData.deviceId);
  }
}

/**
 * Upsert session info (encrypted session string) into the sessions table.
 */
async function syncSession(sessionData) {
  const telegramId = parseInt(sessionData.telegramId);
  memorySessions.set(sessionData.sessionId, {
    session_id: sessionData.sessionId,
    telegram_id: telegramId,
    device_id: sessionData.deviceId,
    telegram_session: sessionData.telegramSession,
    created_at: new Date().toISOString(),
    last_used: new Date().toISOString(),
    expires_at: sessionData.expiresAt ? new Date(sessionData.expiresAt).toISOString() : null
  });

  if (!isEnabled()) {
    return memorySessions.get(sessionData.sessionId);
  }

  try {
    const payload = {
      session_id: sessionData.sessionId,
      telegram_id: telegramId,
      device_id: sessionData.deviceId,
      telegram_session: sessionData.telegramSession, // Encrypted session string
      last_used: new Date().toISOString(),
      expires_at: sessionData.expiresAt ? new Date(sessionData.expiresAt).toISOString() : null
    };

    const { data, error } = await supabase
      .from('sessions')
      .upsert(payload, { onConflict: 'session_id' })
      .select()
      .single();

    if (error) {
      console.error('❌ Supabase syncSession error (falling back to memory):', error.message);
      return memorySessions.get(sessionData.sessionId);
    }
    return data;
  } catch (err) {
    console.error('❌ Failed to sync session in Supabase (falling back to memory):', err.message);
    return memorySessions.get(sessionData.sessionId);
  }
}

/**
 * Retrieve session by ID.
 */
async function getSession(sessionId) {
  let dbData = null;
  
  if (isEnabled()) {
    try {
      const { data, error } = await supabase
        .from('sessions')
        .select('*, users(*)')
        .eq('session_id', sessionId)
        .maybeSingle();

      if (error) {
        console.error('❌ Supabase getSession error (checking in-memory):', error.message);
      } else {
        dbData = data;
      }
    } catch (err) {
      console.error('❌ Failed to retrieve session from Supabase (checking in-memory):', err.message);
    }
  }

  if (dbData) {
    return dbData;
  }

  // Fallback to memory
  const memSession = memorySessions.get(sessionId);
  if (!memSession) {
    return null;
  }

  const memUser = memoryUsers.get(memSession.telegram_id);
  return {
    session_id: memSession.session_id,
    telegram_id: memSession.telegram_id,
    device_id: memSession.device_id,
    telegram_session: memSession.telegram_session,
    created_at: memSession.created_at,
    last_used: memSession.last_used,
    expires_at: memSession.expires_at,
    users: memUser || {
      telegram_id: memSession.telegram_id,
      first_name: 'Telegram User'
    }
  };
}

/**
 * Delete session by ID (revocation).
 */
async function deleteSession(sessionId) {
  memorySessions.delete(sessionId);

  if (!isEnabled()) return true;

  try {
    const { error } = await supabase
      .from('sessions')
      .delete()
      .eq('session_id', sessionId);

    if (error) {
      console.error('❌ Supabase deleteSession error:', error.message);
      return false;
    }
    return true;
  } catch (err) {
    console.error('❌ Failed to delete session in Supabase:', err.message);
    return false;
  }
}

module.exports = {
  isEnabled,
  syncUser,
  syncDevice,
  syncSession,
  getSession,
  deleteSession
};
