-- Migration: 003_create_schedule_table
-- Description: Create anime airing schedule table
-- Requirements: 4.1

-- ============================================================================
-- SCHEDULE 时间表
-- ============================================================================
CREATE TABLE IF NOT EXISTS schedule (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    anime_id UUID NOT NULL REFERENCES anime(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    air_time TIME NOT NULL,
    timezone TEXT NOT NULL DEFAULT 'Asia/Shanghai',
    season_id UUID REFERENCES anime_seasons(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (anime_id, day_of_week, air_time)
);

-- Indexes for schedule table
CREATE INDEX IF NOT EXISTS idx_schedule_anime_id ON schedule (anime_id);
CREATE INDEX IF NOT EXISTS idx_schedule_day_of_week ON schedule (day_of_week);
CREATE INDEX IF NOT EXISTS idx_schedule_air_time ON schedule (air_time);
CREATE INDEX IF NOT EXISTS idx_schedule_is_active ON schedule (is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_schedule_day_time ON schedule (day_of_week, air_time) WHERE is_active = TRUE;

-- ============================================================================
-- TRIGGERS for updated_at
-- ============================================================================
CREATE TRIGGER update_schedule_updated_at
    BEFORE UPDATE ON schedule
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE schedule IS 'Anime airing schedule by day of week';
COMMENT ON COLUMN schedule.day_of_week IS 'Day of week: 0=Sunday, 1=Monday, ..., 6=Saturday';
COMMENT ON COLUMN schedule.air_time IS 'Time of day when anime airs';
COMMENT ON COLUMN schedule.timezone IS 'Timezone for the air_time (e.g., Asia/Shanghai, Asia/Tokyo)';
COMMENT ON COLUMN schedule.is_active IS 'Whether this schedule entry is currently active';
