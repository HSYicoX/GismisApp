-- Migration: 008_create_anime_cache
-- Description: Create anime_cache table for caching aggregated anime data
-- Requirements: 6.1 - Cache results to Supabase database
-- 
-- Purpose:
-- - Store cached anime data from multiple platforms
-- - Reduce API calls to external platforms
-- - Improve response times for frequently accessed data
-- 
-- Access Pattern:
-- - Only Edge Functions (service_role) can access this table
-- - No direct client access (anon/authenticated roles have no access)

-- ============================================================================
-- CREATE ANIME_CACHE TABLE
-- ============================================================================

CREATE TABLE anime_cache (
    -- Primary key: unique cache key (e.g., "anime_list:1:20", "search:keyword:20")
    cache_key TEXT PRIMARY KEY,
    
    -- Cached data stored as JSONB for flexibility
    data JSONB NOT NULL,
    
    -- Expiration timestamp for TTL-based cache invalidation
    expires_at TIMESTAMPTZ NOT NULL,
    
    -- Last update timestamp
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- CREATE INDEXES
-- ============================================================================

-- Index on expires_at for efficient expired cache cleanup
CREATE INDEX idx_anime_cache_expires_at ON anime_cache(expires_at);

-- ============================================================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE anime_cache ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES - SERVICE ROLE ONLY
-- ============================================================================
-- Only service_role can access this table.
-- This ensures cache operations are only performed by Edge Functions.

CREATE POLICY "anime_cache_service_role_all" ON anime_cache
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE anime_cache IS 
    'Cache table for aggregated anime data from multiple platforms';

COMMENT ON COLUMN anime_cache.cache_key IS 
    'Unique cache key (e.g., anime_list:page:pageSize, search:keyword:limit)';

COMMENT ON COLUMN anime_cache.data IS 
    'Cached JSON data (anime list, search results, schedule, etc.)';

COMMENT ON COLUMN anime_cache.expires_at IS 
    'Cache expiration timestamp for TTL-based invalidation';

COMMENT ON COLUMN anime_cache.updated_at IS 
    'Last update timestamp';

COMMENT ON POLICY "anime_cache_service_role_all" ON anime_cache IS 
    'Full access for service_role - used by Edge Functions for cache operations';

-- ============================================================================
-- SECURITY NOTES
-- ============================================================================
-- 
-- 1. This table is only accessible via service_role (Edge Functions)
-- 2. No anon or authenticated role policies - direct client access denied
-- 3. Cache keys should be deterministic and predictable
-- 4. TTL is enforced at application level by checking expires_at
-- 5. Expired cache cleanup should be done periodically by Edge Functions
--
