-- Migration: 006_rls_user_tables
-- Description: Enable RLS and create user-level policies for private tables
-- Requirements: Security Checklist
-- 
-- Policy Strategy:
-- - User tables (user_profiles, user_favorites, watch_history, ai_conversations) 
--   are private and require authentication
-- - All read/write operations go through Edge Functions using service_role
-- - Edge Functions validate custom JWT tokens before accessing data
-- - No direct client access to user data (anon role has no access)
-- 
-- IMPORTANT: Since we use custom JWT (not Supabase Auth), we cannot use
-- auth.uid() for RLS. All user operations MUST go through Edge Functions
-- that use service_role to bypass RLS after validating the custom JWT.

-- ============================================================================
-- ENABLE RLS ON USER TABLES
-- ============================================================================

-- Enable RLS on user_profiles table
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Enable RLS on user_favorites table
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;

-- Enable RLS on watch_history table
ALTER TABLE watch_history ENABLE ROW LEVEL SECURITY;

-- Enable RLS on ai_conversations table
ALTER TABLE ai_conversations ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- DENY ALL ACCESS FOR ANON ROLE
-- ============================================================================
-- By default, with RLS enabled and no policies, anon role has no access.
-- We explicitly document this by NOT creating any anon policies.
-- All access must go through Edge Functions with service_role.

-- ============================================================================
-- SERVICE ROLE FULL ACCESS POLICIES
-- ============================================================================
-- service_role bypasses RLS by default, but we add explicit policies
-- for documentation, clarity, and to ensure consistent behavior.

-- User profiles table: Service role full access
CREATE POLICY "user_profiles_service_role_all" ON user_profiles
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- User favorites table: Service role full access
CREATE POLICY "user_favorites_service_role_all" ON user_favorites
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Watch history table: Service role full access
CREATE POLICY "watch_history_service_role_all" ON watch_history
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- AI conversations table: Service role full access
CREATE POLICY "ai_conversations_service_role_all" ON ai_conversations
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- ============================================================================
-- AUTHENTICATED ROLE - NO DIRECT ACCESS
-- ============================================================================
-- Even authenticated users cannot directly access user tables.
-- This is because we use custom JWT, not Supabase Auth.
-- All operations must go through Edge Functions.
-- 
-- If in the future we want to allow direct authenticated access,
-- we would need to:
-- 1. Use Supabase Auth OR
-- 2. Create a custom JWT verification function in PostgreSQL
-- 
-- For now, we explicitly deny all access to authenticated role
-- by not creating any policies for it.

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON POLICY "user_profiles_service_role_all" ON user_profiles IS 
    'Full access for service_role - used by Edge Functions after JWT validation';

COMMENT ON POLICY "user_favorites_service_role_all" ON user_favorites IS 
    'Full access for service_role - used by Edge Functions after JWT validation';

COMMENT ON POLICY "watch_history_service_role_all" ON watch_history IS 
    'Full access for service_role - used by Edge Functions after JWT validation';

COMMENT ON POLICY "ai_conversations_service_role_all" ON ai_conversations IS 
    'Full access for service_role - used by Edge Functions after JWT validation';

-- ============================================================================
-- SECURITY NOTES
-- ============================================================================
-- 
-- 1. NEVER expose service_role key to client applications
-- 2. All user data access must go through Edge Functions
-- 3. Edge Functions must validate custom JWT before any operation
-- 4. Edge Functions use service_role to bypass RLS after validation
-- 5. The user_id column in all tables stores the external user ID from
--    the custom auth system, NOT a Supabase auth.uid()
-- 
-- Access Pattern:
-- 
-- Flutter Client                Edge Function                  PostgreSQL
--      |                             |                              |
--      |-- Custom JWT + Request ---->|                              |
--      |                             |-- Validate JWT               |
--      |                             |-- Extract user_id            |
--      |                             |-- Query with service_role -->|
--      |                             |<-- Results ------------------|
--      |<-- Response ----------------|                              |
--
