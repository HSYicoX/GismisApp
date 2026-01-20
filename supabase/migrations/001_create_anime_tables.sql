-- Migration: 001_create_anime_tables
-- Description: Create core anime tables (anime, anime_seasons, episodes, platform links)
-- Requirements: 3.1

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- ANIME 主表
-- ============================================================================
CREATE TABLE IF NOT EXISTS anime (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    title_ja TEXT,
    synopsis TEXT,
    cover_url TEXT,
    banner_url TEXT,
    genres TEXT[] DEFAULT '{}',
    rating DECIMAL(3, 1) CHECK (rating >= 0 AND rating <= 10),
    status TEXT NOT NULL DEFAULT 'upcoming' CHECK (status IN ('airing', 'completed', 'upcoming')),
    start_date DATE,
    end_date DATE,
    season_count INTEGER DEFAULT 1,
    current_season INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for anime table
CREATE INDEX IF NOT EXISTS idx_anime_title ON anime USING GIN (to_tsvector('simple', title));
CREATE INDEX IF NOT EXISTS idx_anime_title_ja ON anime USING GIN (to_tsvector('simple', COALESCE(title_ja, '')));
CREATE INDEX IF NOT EXISTS idx_anime_status ON anime (status);
CREATE INDEX IF NOT EXISTS idx_anime_genres ON anime USING GIN (genres);
CREATE INDEX IF NOT EXISTS idx_anime_rating ON anime (rating DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_anime_start_date ON anime (start_date DESC NULLS LAST);

-- ============================================================================
-- ANIME_SEASONS 季表
-- ============================================================================
CREATE TABLE IF NOT EXISTS anime_seasons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    anime_id UUID NOT NULL REFERENCES anime(id) ON DELETE CASCADE,
    season_number INTEGER NOT NULL CHECK (season_number > 0),
    title TEXT,
    episode_count INTEGER DEFAULT 0,
    latest_episode INTEGER,
    status TEXT NOT NULL DEFAULT 'upcoming' CHECK (status IN ('airing', 'completed', 'upcoming')),
    start_date DATE,
    end_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (anime_id, season_number)
);

-- Indexes for anime_seasons table
CREATE INDEX IF NOT EXISTS idx_anime_seasons_anime_id ON anime_seasons (anime_id);
CREATE INDEX IF NOT EXISTS idx_anime_seasons_status ON anime_seasons (status);


-- ============================================================================
-- EPISODES 集表
-- ============================================================================
CREATE TABLE IF NOT EXISTS episodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    season_id UUID NOT NULL REFERENCES anime_seasons(id) ON DELETE CASCADE,
    episode_number INTEGER NOT NULL CHECK (episode_number > 0),
    title TEXT,
    synopsis TEXT,
    duration_seconds INTEGER,
    air_date DATE,
    thumbnail_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (season_id, episode_number)
);

-- Indexes for episodes table
CREATE INDEX IF NOT EXISTS idx_episodes_season_id ON episodes (season_id);
CREATE INDEX IF NOT EXISTS idx_episodes_air_date ON episodes (air_date DESC NULLS LAST);

-- ============================================================================
-- ANIME_PLATFORM_LINKS 动漫平台链接表
-- ============================================================================
CREATE TABLE IF NOT EXISTS anime_platform_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    anime_id UUID NOT NULL REFERENCES anime(id) ON DELETE CASCADE,
    platform TEXT NOT NULL CHECK (platform IN ('iqiyi', 'tencent', 'youku', 'bilibili', 'mgtv', 'other')),
    url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (anime_id, platform)
);

-- Indexes for anime_platform_links table
CREATE INDEX IF NOT EXISTS idx_anime_platform_links_anime_id ON anime_platform_links (anime_id);
CREATE INDEX IF NOT EXISTS idx_anime_platform_links_platform ON anime_platform_links (platform);

-- ============================================================================
-- EPISODE_PLATFORM_LINKS 集平台链接表
-- ============================================================================
CREATE TABLE IF NOT EXISTS episode_platform_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    episode_id UUID NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
    platform TEXT NOT NULL CHECK (platform IN ('iqiyi', 'tencent', 'youku', 'bilibili', 'mgtv', 'other')),
    url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (episode_id, platform)
);

-- Indexes for episode_platform_links table
CREATE INDEX IF NOT EXISTS idx_episode_platform_links_episode_id ON episode_platform_links (episode_id);
CREATE INDEX IF NOT EXISTS idx_episode_platform_links_platform ON episode_platform_links (platform);

-- ============================================================================
-- TRIGGERS for updated_at
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_anime_updated_at
    BEFORE UPDATE ON anime
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_anime_seasons_updated_at
    BEFORE UPDATE ON anime_seasons
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_episodes_updated_at
    BEFORE UPDATE ON episodes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE anime IS 'Main anime metadata table';
COMMENT ON TABLE anime_seasons IS 'Anime seasons/cours information';
COMMENT ON TABLE episodes IS 'Individual episode information';
COMMENT ON TABLE anime_platform_links IS 'Links to streaming platforms for anime';
COMMENT ON TABLE episode_platform_links IS 'Links to streaming platforms for individual episodes';
