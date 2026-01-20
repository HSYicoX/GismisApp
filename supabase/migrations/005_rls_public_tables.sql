-- Migration: 005_rls_public_tables
-- Description: Enable RLS and create public read-only policies for anime-related tables
-- Requirements: Security Checklist
-- 
-- Policy Strategy:
-- - Public tables (anime, anime_seasons, episodes, schedule, etc.) are read-only for anon role
-- - Only service_role can perform write operations (INSERT, UPDATE, DELETE)
-- - This ensures data integrity while allowing public read access

-- ============================================================================
-- ENABLE RLS ON PUBLIC TABLES
-- ============================================================================

-- Enable RLS on anime table
ALTER TABLE anime ENABLE ROW LEVEL SECURITY;

-- Enable RLS on anime_seasons table
ALTER TABLE anime_seasons ENABLE ROW LEVEL SECURITY;

-- Enable RLS on episodes table
ALTER TABLE episodes ENABLE ROW LEVEL SECURITY;

-- Enable RLS on schedule table
ALTER TABLE schedule ENABLE ROW LEVEL SECURITY;

-- Enable RLS on anime_platform_links table
ALTER TABLE anime_platform_links ENABLE ROW LEVEL SECURITY;

-- Enable RLS on episode_platform_links table
ALTER TABLE episode_platform_links ENABLE ROW LEVEL SECURITY;

-- Enable RLS on source_materials table
ALTER TABLE source_materials ENABLE ROW LEVEL SECURITY;

-- Enable RLS on chapters table
ALTER TABLE chapters ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PUBLIC READ POLICIES (SELECT for anon and authenticated)
-- ============================================================================

-- Anime table: Public read access
CREATE POLICY "anime_public_read" ON anime
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Anime seasons table: Public read access
CREATE POLICY "anime_seasons_public_read" ON anime_seasons
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Episodes table: Public read access
CREATE POLICY "episodes_public_read" ON episodes
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Schedule table: Public read access (only active schedules)
CREATE POLICY "schedule_public_read" ON schedule
    FOR SELECT
    TO anon, authenticated
    USING (is_active = true);

-- Anime platform links table: Public read access
CREATE POLICY "anime_platform_links_public_read" ON anime_platform_links
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Episode platform links table: Public read access
CREATE POLICY "episode_platform_links_public_read" ON episode_platform_links
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Source materials table: Public read access
CREATE POLICY "source_materials_public_read" ON source_materials
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Chapters table: Public read access
CREATE POLICY "chapters_public_read" ON chapters
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- ============================================================================
-- SERVICE ROLE WRITE POLICIES (Full access for backend operations)
-- ============================================================================
-- Note: service_role bypasses RLS by default, but we add explicit policies
-- for documentation and clarity

-- Anime table: Service role full access
CREATE POLICY "anime_service_role_all" ON anime
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Anime seasons table: Service role full access
CREATE POLICY "anime_seasons_service_role_all" ON anime_seasons
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Episodes table: Service role full access
CREATE POLICY "episodes_service_role_all" ON episodes
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Schedule table: Service role full access
CREATE POLICY "schedule_service_role_all" ON schedule
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Anime platform links table: Service role full access
CREATE POLICY "anime_platform_links_service_role_all" ON anime_platform_links
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Episode platform links table: Service role full access
CREATE POLICY "episode_platform_links_service_role_all" ON episode_platform_links
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Source materials table: Service role full access
CREATE POLICY "source_materials_service_role_all" ON source_materials
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Chapters table: Service role full access
CREATE POLICY "chapters_service_role_all" ON chapters
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON POLICY "anime_public_read" ON anime IS 'Allow public read access to anime metadata';
COMMENT ON POLICY "anime_seasons_public_read" ON anime_seasons IS 'Allow public read access to anime seasons';
COMMENT ON POLICY "episodes_public_read" ON episodes IS 'Allow public read access to episodes';
COMMENT ON POLICY "schedule_public_read" ON schedule IS 'Allow public read access to active schedules only';
COMMENT ON POLICY "anime_platform_links_public_read" ON anime_platform_links IS 'Allow public read access to platform links';
COMMENT ON POLICY "episode_platform_links_public_read" ON episode_platform_links IS 'Allow public read access to episode platform links';
COMMENT ON POLICY "source_materials_public_read" ON source_materials IS 'Allow public read access to source materials';
COMMENT ON POLICY "chapters_public_read" ON chapters IS 'Allow public read access to chapters';
