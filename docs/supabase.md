You are a senior full-stack engineer. Help me integrate a self-hosted Supabase backend into my Flutter app.

Context
- App: Gismis (Flutter) with Riverpod, go_router, dio, hive, flutter_secure_storage.
- Backend: Supabase self-hosted (Postgres + Storage + Edge Functions), but we DO NOT use Supabase Auth.
- Authentication: Custom auth service issues JWT access/refresh tokens. Flutter attaches Authorization: Bearer <access_token> to API calls.
- AI streaming: AI endpoints use SSE (Server-Sent Events) with events: meta, field_start, delta, field_end, done, error.

What you must do (required)
1) Use Supabase MCP to retrieve my self-hosted Supabase configuration:
   - Supabase URL (API base)
   - anon/public key (if used for client reads) and service role key (server-side only)
   - storage bucket names (if any)
   - edge function endpoints (if any)
   - database connection details only if needed for server-side migrations (never expose secrets in client code)

2) Based on the retrieved configuration, generate an integration plan and the exact code changes for Flutter:
   - Create a config layer (dev/staging/prod) that loads SUPABASE_URL and any non-secret public keys via compile-time env or config file.
   - Implement a Supabase-aware API client using Dio that calls:
     - Edge Functions for protected operations (requires custom JWT)
     - Public read endpoints if applicable
   - Add request interceptors:
     - attach Authorization header (custom JWT)
     - handle 401 by refreshing token through my auth service then retry the original request

3) Generate the repository implementations that call Supabase-backed endpoints:
   - AnimeRepository: list, search, trending, todayUpdates
   - ScheduleRepository: weekday schedule, update progress, persist order
   - FavoritesRepository: list, reorder
   - ProfileRepository: get/update profile
   - AIRepository: hot questions + SSE chat streaming

4) Provide a clear security policy:
   - Never put service_role keys in Flutter.
   - All writes and any privileged reads must go through Edge Functions or my custom API layer.
   - If using anon key in Flutter, keep operations read-only and non-sensitive.

Output format (required)
- A step-by-step integration checklist
- Exact file paths and code snippets for each file you create/modify
- Minimal but complete Flutter code for:
  - supabase_config.dart (loads config safely)
  - api_base_urls.dart or env loader
  - dio_client.dart interceptor updates
  - repositories (one by one)
  - a short example of calling one endpoint (e.g., getAnimeList)
- If any config value is missing from MCP, clearly list what is missing and provide safe placeholders.

Do not
- Do not ask me to manually copy secrets into the Flutter app.
- Do not use Supabase Auth.
- Do not skip SSE streaming integration.