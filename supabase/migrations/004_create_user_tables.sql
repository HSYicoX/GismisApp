-- Migration: 004_create_user_tables
-- Description: Create user-related tables (profiles, favorites, watch history, AI conversations)
-- Requirements: 5.1, 6.1, 7.4

-- ============================================================================
-- USER_PROFILES 用户资料表
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL UNIQUE,
    nickname TEXT,
    avatar_url TEXT,
    bio TEXT,
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add preferences column if table exists but column doesn't (idempotent fix)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' AND column_name = 'preferences'
    ) THEN
        ALTER TABLE user_profiles ADD COLUMN preferences JSONB DEFAULT '{}';
    END IF;
END $$;

-- Indexes for user_profiles table
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles (user_id);

-- ============================================================================
-- USER_FAVORITES 收藏表
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    anime_id UUID NOT NULL REFERENCES anime(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    sort_order INTEGER,
    UNIQUE (user_id, anime_id)
);

-- Indexes for user_favorites table
CREATE INDEX IF NOT EXISTS idx_user_favorites_user_id ON user_favorites (user_id);
CREATE INDEX IF NOT EXISTS idx_user_favorites_anime_id ON user_favorites (anime_id);
CREATE INDEX IF NOT EXISTS idx_user_favorites_added_at ON user_favorites (user_id, added_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_favorites_sort_order ON user_favorites (user_id, sort_order);

-- ============================================================================
-- WATCH_HISTORY 观看历史表
-- ============================================================================
CREATE TABLE IF NOT EXISTS watch_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    episode_id UUID NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
    progress INTEGER DEFAULT 0 CHECK (progress >= 0),
    duration INTEGER,
    watched_at TIMESTAMPTZ DEFAULT NOW(),
    completed BOOLEAN DEFAULT FALSE,
    UNIQUE (user_id, episode_id)
);

-- Indexes for watch_history table
CREATE INDEX IF NOT EXISTS idx_watch_history_user_id ON watch_history (user_id);
CREATE INDEX IF NOT EXISTS idx_watch_history_episode_id ON watch_history (episode_id);
CREATE INDEX IF NOT EXISTS idx_watch_history_watched_at ON watch_history (user_id, watched_at DESC);
CREATE INDEX IF NOT EXISTS idx_watch_history_completed ON watch_history (user_id, completed);


-- ============================================================================
-- AI_CONVERSATIONS AI 对话表
-- ============================================================================
CREATE TABLE IF NOT EXISTS ai_conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    conversation_id TEXT NOT NULL UNIQUE,
    title TEXT,
    messages JSONB DEFAULT '[]',
    model TEXT DEFAULT 'deepseek-chat',
    tokens_used INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for ai_conversations table
CREATE INDEX IF NOT EXISTS idx_ai_conversations_user_id ON ai_conversations (user_id);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_conversation_id ON ai_conversations (conversation_id);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_created_at ON ai_conversations (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_updated_at ON ai_conversations (user_id, updated_at DESC);

-- ============================================================================
-- TRIGGERS for updated_at
-- ============================================================================
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ai_conversations_updated_at
    BEFORE UPDATE ON ai_conversations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE user_profiles IS 'User profile information';
COMMENT ON TABLE user_favorites IS 'User favorite anime list';
COMMENT ON TABLE watch_history IS 'User watch history with progress tracking';
COMMENT ON TABLE ai_conversations IS 'AI assistant conversation history';

COMMENT ON COLUMN user_profiles.user_id IS 'External user ID from custom auth system';
COMMENT ON COLUMN user_profiles.preferences IS 'User preferences as JSON (theme, notifications, etc.)';
COMMENT ON COLUMN user_favorites.sort_order IS 'Custom sort order for favorites list';
COMMENT ON COLUMN watch_history.progress IS 'Watch progress in seconds';
COMMENT ON COLUMN watch_history.duration IS 'Total duration of episode in seconds';
COMMENT ON COLUMN ai_conversations.messages IS 'Array of chat messages as JSON';
COMMENT ON COLUMN ai_conversations.model IS 'AI model used (deepseek-chat or deepseek-reasoner)';
COMMENT ON COLUMN ai_conversations.tokens_used IS 'Total tokens consumed in this conversation';
