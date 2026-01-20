-- Migration: 007_create_storage_buckets
-- Description: Create storage buckets for anime covers, banners, and user avatars
-- Requirements: 8.1, 8.2
-- 
-- Bucket Strategy:
-- - anime-covers: Public bucket for anime cover images (public read)
-- - anime-banners: Public bucket for anime banner images (public read)
-- - user-avatars: Private bucket for user profile avatars (authenticated access via Edge Functions)
--
-- Security Model:
-- - Public buckets allow anonymous read access
-- - Private buckets require authentication (handled via Edge Functions with service_role)
-- - All uploads to private buckets go through Edge Functions for validation

-- ============================================================================
-- CREATE STORAGE BUCKETS
-- ============================================================================

-- Create anime-covers bucket (public)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'anime-covers',
    'anime-covers',
    true,  -- Public bucket
    5242880,  -- 5MB file size limit
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Create anime-banners bucket (public)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'anime-banners',
    'anime-banners',
    true,  -- Public bucket
    10485760,  -- 10MB file size limit (banners are larger)
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Create user-avatars bucket (private)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'user-avatars',
    'user-avatars',
    false,  -- Private bucket
    2097152,  -- 2MB file size limit
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ============================================================================
-- STORAGE POLICIES FOR PUBLIC BUCKETS (anime-covers)
-- ============================================================================

-- Allow public read access to anime-covers
CREATE POLICY "anime_covers_public_read" ON storage.objects
    FOR SELECT
    TO anon, authenticated
    USING (bucket_id = 'anime-covers');

-- Allow service_role to manage anime-covers (for backend uploads)
CREATE POLICY "anime_covers_service_role_all" ON storage.objects
    FOR ALL
    TO service_role
    USING (bucket_id = 'anime-covers')
    WITH CHECK (bucket_id = 'anime-covers');

-- ============================================================================
-- STORAGE POLICIES FOR PUBLIC BUCKETS (anime-banners)
-- ============================================================================

-- Allow public read access to anime-banners
CREATE POLICY "anime_banners_public_read" ON storage.objects
    FOR SELECT
    TO anon, authenticated
    USING (bucket_id = 'anime-banners');

-- Allow service_role to manage anime-banners (for backend uploads)
CREATE POLICY "anime_banners_service_role_all" ON storage.objects
    FOR ALL
    TO service_role
    USING (bucket_id = 'anime-banners')
    WITH CHECK (bucket_id = 'anime-banners');

-- ============================================================================
-- STORAGE POLICIES FOR PRIVATE BUCKET (user-avatars)
-- ============================================================================

-- No public read access for user-avatars (private bucket)
-- All access goes through Edge Functions with service_role

-- Allow service_role full access to user-avatars (for Edge Function operations)
CREATE POLICY "user_avatars_service_role_all" ON storage.objects
    FOR ALL
    TO service_role
    USING (bucket_id = 'user-avatars')
    WITH CHECK (bucket_id = 'user-avatars');

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON POLICY "anime_covers_public_read" ON storage.objects IS 
    'Allow public read access to anime cover images';

COMMENT ON POLICY "anime_covers_service_role_all" ON storage.objects IS 
    'Allow service_role full access for backend anime cover management';

COMMENT ON POLICY "anime_banners_public_read" ON storage.objects IS 
    'Allow public read access to anime banner images';

COMMENT ON POLICY "anime_banners_service_role_all" ON storage.objects IS 
    'Allow service_role full access for backend anime banner management';

COMMENT ON POLICY "user_avatars_service_role_all" ON storage.objects IS 
    'Allow service_role full access for user avatar management via Edge Functions';

-- ============================================================================
-- SECURITY NOTES
-- ============================================================================
-- 
-- Storage Access Patterns:
-- 
-- 1. Public Buckets (anime-covers, anime-banners):
--    - Read: Direct URL access (no authentication required)
--    - Write: Backend only via service_role (data pipeline)
--    - URL format: {storage_url}/object/public/{bucket}/{path}
-- 
-- 2. Private Bucket (user-avatars):
--    - Read: Via signed URLs generated by Edge Functions
--    - Write: Via Edge Functions (upload-avatar) with JWT validation
--    - URL format: {storage_url}/object/sign/{bucket}/{path}?token=...
-- 
-- Flutter Client Access:
-- 
-- Public images:
--   final url = supabaseStorage.getPublicUrl('anime-covers', 'cover.jpg');
-- 
-- Private images (user avatars):
--   final signedUrl = await supabaseStorage.getSignedUrl(
--     functionName: 'get-signed-url',
--     accessToken: token,
--     bucket: 'user-avatars',
--     path: 'user123/avatar.jpg',
--   );
-- 
-- Avatar upload:
--   final url = await supabaseStorage.uploadViaFunction(
--     functionName: 'upload-avatar',
--     accessToken: token,
--     fileName: 'avatar.jpg',
--     bytes: imageBytes,
--     contentType: 'image/jpeg',
--   );
--
