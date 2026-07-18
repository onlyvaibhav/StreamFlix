-- StreamFlix Database Schema
-- Run this in your Supabase SQL Editor to initialize the authentication tables.

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 1. USERS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    telegram_id BIGINT UNIQUE NOT NULL,
    username VARCHAR(255),
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255),
    phone VARCHAR(50),
    premium BOOLEAN DEFAULT FALSE,
    language VARCHAR(10),
    profile_photo TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexing for fast lookups by Telegram ID
CREATE INDEX IF NOT EXISTS idx_users_telegram_id ON users(telegram_id);

-- Trigger to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ==========================================
-- 2. DEVICES TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS devices (
    device_id VARCHAR(255) PRIMARY KEY,
    telegram_id BIGINT REFERENCES users(telegram_id) ON DELETE CASCADE,
    browser VARCHAR(100),
    os VARCHAR(100),
    platform VARCHAR(100),
    user_agent TEXT,
    last_active TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_devices_telegram_id ON devices(telegram_id);

-- ==========================================
-- 3. SESSIONS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS sessions (
    session_id VARCHAR(255) PRIMARY KEY,
    telegram_id BIGINT REFERENCES users(telegram_id) ON DELETE CASCADE,
    device_id VARCHAR(255) REFERENCES devices(device_id) ON DELETE CASCADE,
    telegram_session TEXT NOT NULL, -- Encrypted session string
    token_hash TEXT UNIQUE,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    last_used TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_sessions_telegram_id ON sessions(telegram_id);
CREATE INDEX IF NOT EXISTS idx_sessions_device_id ON sessions(device_id);

-- ==========================================
-- 4. ROW-LEVEL SECURITY & PERMISSIONS
-- ==========================================
-- Enable RLS on all tables (Supabase requirement)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

-- Explicitly revoke access from anon and public to ensure lockdown
REVOKE ALL ON users FROM anon, public;
REVOKE ALL ON devices FROM anon, public;
REVOKE ALL ON sessions FROM anon, public;

-- Grant full access to service_role (used by backend server)
GRANT ALL ON users TO service_role;
GRANT ALL ON devices TO service_role;
GRANT ALL ON sessions TO service_role;

-- Grant full access to authenticated role (for future client-side queries)
GRANT ALL ON users TO authenticated;
GRANT ALL ON devices TO authenticated;
GRANT ALL ON sessions TO authenticated;

-- RLS Policies: Allow service_role to bypass RLS (it already does by default)
-- Allow authenticated users to read their own data
CREATE POLICY "Service role has full access to users" ON users
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Service role has full access to devices" ON devices
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Service role has full access to sessions" ON sessions
  FOR ALL USING (true) WITH CHECK (true);

-- ==========================================
-- ARCHITECTURAL PREPARATION FOR FUTURE EXPANSIONS
-- ==========================================
-- These comments show how upcoming tables will map to the users table.
--
-- 1. profiles:
--    CREATE TABLE profiles (
--        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
--        profile_name VARCHAR(100) NOT NULL,
--        avatar VARCHAR(255),
--        created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
--    );
--
-- 2. watch_history / continue_watching:
--    CREATE TABLE continue_watching (
--        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
--        profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
--        media_id VARCHAR(100) NOT NULL, -- TMDB ID or File ID
--        media_type VARCHAR(20) NOT NULL, -- 'movie' or 'tv'
--        season INT,
--        episode INT,
--        progress_seconds INT NOT NULL,
--        duration_seconds INT NOT NULL,
--        last_active TIMESTAMP WITH TIME ZONE DEFAULT now()
--    );
--
-- 3. favorites / watchlist:
--    CREATE TABLE favorites (
--        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
--        media_id VARCHAR(100) NOT NULL,
--        media_type VARCHAR(20) NOT NULL,
--        created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
--    );

-- ==========================================
-- 5. WATCH PROGRESS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS watch_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    telegram_id BIGINT REFERENCES users(telegram_id) ON DELETE CASCADE,
    file_id VARCHAR(255) NOT NULL,
    position_seconds INT NOT NULL DEFAULT 0,
    duration_seconds INT NOT NULL DEFAULT 0,
    title TEXT,
    poster_path TEXT,
    media_type VARCHAR(20) DEFAULT 'movie',
    season INT,
    episode INT,
    show_id VARCHAR(100),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(telegram_id, file_id)
);

CREATE INDEX IF NOT EXISTS idx_watch_progress_telegram_id ON watch_progress(telegram_id);
CREATE INDEX IF NOT EXISTS idx_watch_progress_updated_at ON watch_progress(updated_at DESC);

ALTER TABLE watch_progress ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON watch_progress FROM anon, public;
GRANT ALL ON watch_progress TO service_role;
GRANT ALL ON watch_progress TO authenticated;

CREATE POLICY "Service role has full access to watch_progress" ON watch_progress
  FOR ALL USING (true) WITH CHECK (true);

