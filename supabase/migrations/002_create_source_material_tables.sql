-- Migration: 002_create_source_material_tables
-- Description: Create source material tables (novels, manga, etc.)
-- Requirements: 3.1

-- ============================================================================
-- SOURCE_MATERIALS 原著信息表
-- ============================================================================
CREATE TABLE IF NOT EXISTS source_materials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    anime_id UUID NOT NULL REFERENCES anime(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('novel', 'manga', 'game', 'original', 'light_novel', 'web_novel')),
    title TEXT,
    author TEXT,
    platform TEXT,
    platform_url TEXT,
    cover_url TEXT,
    synopsis TEXT,
    total_chapters INTEGER,
    latest_chapter INTEGER,
    latest_chapter_title TEXT,
    update_status TEXT DEFAULT 'ongoing' CHECK (update_status IN ('ongoing', 'completed', 'hiatus')),
    last_updated TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for source_materials table
CREATE INDEX IF NOT EXISTS idx_source_materials_anime_id ON source_materials (anime_id);
CREATE INDEX IF NOT EXISTS idx_source_materials_type ON source_materials (type);
CREATE INDEX IF NOT EXISTS idx_source_materials_platform ON source_materials (platform);
CREATE INDEX IF NOT EXISTS idx_source_materials_update_status ON source_materials (update_status);

-- ============================================================================
-- CHAPTERS 章节表
-- ============================================================================
CREATE TABLE IF NOT EXISTS chapters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_material_id UUID NOT NULL REFERENCES source_materials(id) ON DELETE CASCADE,
    chapter_number INTEGER NOT NULL CHECK (chapter_number > 0),
    title TEXT,
    word_count INTEGER,
    publish_date DATE,
    is_paid BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (source_material_id, chapter_number)
);

-- Indexes for chapters table
CREATE INDEX IF NOT EXISTS idx_chapters_source_material_id ON chapters (source_material_id);
CREATE INDEX IF NOT EXISTS idx_chapters_publish_date ON chapters (publish_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_chapters_is_paid ON chapters (is_paid);

-- ============================================================================
-- TRIGGERS for updated_at
-- ============================================================================
CREATE TRIGGER update_source_materials_updated_at
    BEFORE UPDATE ON source_materials
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE source_materials IS 'Original source material information (novels, manga, etc.)';
COMMENT ON TABLE chapters IS 'Individual chapters of source materials';
COMMENT ON COLUMN source_materials.type IS 'Type of source material: novel, manga, game, original, light_novel, web_novel';
COMMENT ON COLUMN source_materials.platform IS 'Platform where source material is published (e.g., qidian, fanqie)';
COMMENT ON COLUMN chapters.is_paid IS 'Whether the chapter requires payment to read';
