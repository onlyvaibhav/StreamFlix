-- Migration: Add token_hash and status to sessions table

ALTER TABLE sessions 
ADD COLUMN IF NOT EXISTS token_hash TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';

-- Any existing sessions will have a null token_hash, which invalidates them 
-- as per the new authentication logic requiring a matching hash.
