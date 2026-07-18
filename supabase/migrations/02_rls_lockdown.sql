-- Phase E: RLS Lockdown Validation
-- This script ensures that no data can be accessed via the anonymous (anon) role
-- or public role, since the backend uses the service_role key for all operations.

-- 1. Ensure RLS is enabled on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE watch_progress ENABLE ROW LEVEL SECURITY;

-- 2. Revoke any accidental grants to anon and public roles
REVOKE ALL ON users FROM anon, public;
REVOKE ALL ON devices FROM anon, public;
REVOKE ALL ON sessions FROM anon, public;
REVOKE ALL ON watch_progress FROM anon, public;

-- 3. Ensure service_role and authenticated roles retain access
GRANT ALL ON users TO service_role, authenticated;
GRANT ALL ON devices TO service_role, authenticated;
GRANT ALL ON sessions TO service_role, authenticated;
GRANT ALL ON watch_progress TO service_role, authenticated;

-- Note: The service_role bypasses RLS by default, so we don't strictly need 
-- "USING (true)" policies for it, but keeping them is fine.
-- There are currently NO policies created for the 'anon' role, meaning
-- default-deny is active for any request using the anon key.
