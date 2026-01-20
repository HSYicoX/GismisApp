# Gismis

An artistic anime tracking application with magazine-like aesthetic, powered by Flutter and Supabase.

## Features

- 📺 Browse and search anime library
- 📅 Weekly airing schedule
- ❤️ Favorites with cloud sync
- 👤 User profiles with avatar upload
- 🤖 AI assistant for anime recommendations
- 📊 Watch history tracking
- 🔄 Offline-first with background sync

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                               │
├─────────────────────────────────────────────────────────────────┤
│  Features Layer                                                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │  Anime   │ │ Schedule │ │Favorites │ │    AI    │           │
│  │Repository│ │Repository│ │Repository│ │Repository│           │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │
│       │            │            │            │                   │
│   PostgREST    PostgREST    Functions    Functions              │
│   (公开读)     (公开读)     (私有读写)   (SSE流式)              │
├─────────────────────────────────────────────────────────────────┤
│  Core Layer                                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  SupabaseClient (专用 Dio，不污染全局)                    │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌────────────┐          │   │
│  │  │ PostgREST   │ │   Storage   │ │    SSE     │          │   │
│  │  │   Client    │ │   Service   │ │   Client   │          │   │
│  │  └─────────────┘ └─────────────┘ └────────────┘          │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Getting Started

### Prerequisites

- Flutter SDK ^3.9.2
- Dart SDK ^3.9.2
- Self-hosted Supabase instance (or Supabase Cloud)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/HSYicoX/GismisApp.git
cd gismis
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure environment variables (see [Supabase Configuration](#supabase-configuration))

4. Run the app:
```bash
flutter run
```

## Supabase Configuration

### Environment Variables

The app uses compile-time environment variables for Supabase configuration. Set these when building:

```bash
# Development
flutter run \
  --dart-define=SUPABASE_URL=你的URL \
  --dart-define=SUPABASE_ANON_KEY=your-local-anon-key

# Production
flutter run --release \
  --dart-define=SUPABASE_URL=你的URL \
  --dart-define=SUPABASE_ANON_KEY=your-production-anon-key
```

### Environment Variables Reference

| Variable | Description | Default |
|----------|-------------|---------|
| `SUPABASE_URL` | Base URL for Supabase services | `你的URL` |
| `SUPABASE_ANON_KEY` | Anonymous key for public operations | (required) |
| `SUPABASE_STAGING_URL` | Staging environment URL | `你的URL` |
| `SUPABASE_STAGING_ANON_KEY` | Staging anonymous key | (optional) |

### Configuration Classes

The app provides multiple configuration options:

```dart
// Standard Kong gateway deployment (recommended)
final config = SupabaseConfig.standard(
  baseUrl: '你的URL',
  anonKey: 'your-anon-key',
);

// Custom paths for non-standard deployments
final config = SupabaseConfig.custom(
  restUrl: 'https://db.example.com/v1',
  storageUrl: 'https://storage.example.com/v1',
  functionsUrl: 'https://functions.example.com/v1',
  realtimeUrl: 'wss://realtime.example.com/v1',
  anonKey: 'your-anon-key',
);

// Development (localhost)
final config = SupabaseConfig.dev(anonKey: 'local-key');

// Production (from environment variables)
final config = SupabaseConfig.prod();
```

### Service URLs

For standard Kong gateway deployment:

| Service | URL Pattern |
|---------|-------------|
| PostgREST | `{baseUrl}/rest/v1` |
| Storage | `{baseUrl}/storage/v1` |
| Edge Functions | `{baseUrl}/functions/v1` |
| Realtime | `wss://{host}/realtime/v1` |


## Database Setup

### Running Migrations

The database schema is defined in SQL migration files located in `supabase/migrations/`. Apply them in order:

```bash
# Navigate to supabase directory
cd ../supabase

# Apply migrations using Supabase CLI
supabase db push

# Or apply manually in order:
# 1. 001_create_anime_tables.sql - Core anime tables
# 2. 002_create_source_material_tables.sql - Source material tables
# 3. 003_create_schedule_table.sql - Schedule table
# 4. 004_create_user_tables.sql - User data tables
# 5. 005_rls_public_tables.sql - RLS for public tables
# 6. 006_rls_user_tables.sql - RLS for user tables
# 7. 007_create_storage_buckets.sql - Storage buckets
```

### Migration Files

| File | Description |
|------|-------------|
| `001_create_anime_tables.sql` | `anime`, `anime_seasons`, `episodes`, platform links |
| `002_create_source_material_tables.sql` | `source_materials`, `chapters` |
| `003_create_schedule_table.sql` | `schedule` table |
| `004_create_user_tables.sql` | `user_profiles`, `user_favorites`, `watch_history`, `ai_conversations` |
| `005_rls_public_tables.sql` | RLS policies for public read access |
| `006_rls_user_tables.sql` | RLS policies for user data (service_role only) |
| `007_create_storage_buckets.sql` | Storage buckets configuration |

### Database Tables

#### Public Tables (PostgREST direct access)
- `anime` - Anime metadata
- `anime_seasons` - Season information
- `episodes` - Episode data
- `schedule` - Airing schedule
- `source_materials` - Original source info
- `chapters` - Source material chapters

#### User Tables (Edge Functions only)
- `user_profiles` - User profile data
- `user_favorites` - User favorites
- `watch_history` - Watch progress
- `ai_conversations` - AI chat history

### Storage Buckets

| Bucket | Access | Description |
|--------|--------|-------------|
| `anime-covers` | Public | Anime cover images |
| `anime-banners` | Public | Anime banner images |
| `user-avatars` | Private | User profile avatars |

## Edge Functions Deployment

### Prerequisites

- Supabase CLI installed
- Access to your Supabase project

### Deploying Functions

```bash
# Navigate to supabase directory
cd ../supabase

# Deploy all functions
supabase functions deploy

# Or deploy individual functions:
supabase functions deploy ai-chat
supabase functions deploy ai-hot-questions
supabase functions deploy get-favorites
supabase functions deploy sync-favorites
supabase functions deploy get-profile
supabase functions deploy update-profile
supabase functions deploy upload-avatar
supabase functions deploy get-signed-url
supabase functions deploy get-watch-history
supabase functions deploy update-watch-progress
```

### Edge Functions Reference

| Function | Method | Description |
|----------|--------|-------------|
| `ai-chat` | POST (SSE) | AI assistant streaming chat |
| `ai-hot-questions` | POST | Get hot questions for AI |
| `get-favorites` | POST | Get user favorites |
| `sync-favorites` | POST | Sync favorites (add/remove) |
| `get-profile` | POST | Get user profile |
| `update-profile` | POST | Update user profile |
| `upload-avatar` | POST | Upload user avatar |
| `get-signed-url` | POST | Get signed URL for private files |
| `get-watch-history` | POST | Get watch history |
| `update-watch-progress` | POST | Update watch progress |

### Environment Variables for Edge Functions

Set these in your Supabase project settings:

```bash
# Required
SUPABASE_URL=你的URL
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# For AI functions
DEEPSEEK_API_KEY=your-deepseek-api-key
DEEPSEEK_BASE_URL=https://api.deepseek.com
```

## Security Model

### Authentication Boundary

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter Client                            │
├─────────────────────────────────────────────────────────────────┤
│  Public Data (anonKey)           │  Private Data (JWT)          │
│  ─────────────────────           │  ──────────────────          │
│  • anime table                   │  • user_favorites            │
│  • schedule table                │  • user_profiles             │
│  • Public Storage buckets        │  • watch_history             │
│                                  │  • ai_conversations          │
│  ↓                               │  ↓                           │
│  PostgREST + RLS                 │  Edge Functions              │
│  (public read allowed)           │  (service_role + JWT verify) │
└─────────────────────────────────────────────────────────────────┘
```

### Key Security Constraints

1. **anonKey only in client** - Never include `service_role` key in Flutter code
2. **RLS enabled** - All tables have Row Level Security policies
3. **Edge Functions for writes** - All user data writes go through Edge Functions
4. **JWT validation** - Edge Functions validate custom JWT tokens
5. **Signed URLs** - Private storage access requires signed URLs

## Testing

### Running Tests

```bash
# All tests
flutter test

# Unit tests only
flutter test test/unit/

# Property-based tests only
flutter test test/property/

# Integration tests only
flutter test test/integration/

# Specific test file
flutter test test/integration/supabase_integration_test.dart
```

### Test Structure

```
test/
├── core/
│   └── supabase/
│       └── supabase_config_test.dart
├── integration/
│   └── supabase_integration_test.dart
├── property/
│   ├── supabase_range_header_properties_test.dart
│   ├── supabase_error_mapping_properties_test.dart
│   ├── storage_url_properties_test.dart
│   └── ... (other property tests)
└── unit/
    └── supabase_config_test.dart
```

## Project Structure

```
lib/
├── app/                    # App configuration, routing, theme
├── core/
│   ├── network/           # Dio client, SSE client, API exceptions
│   ├── storage/           # Hive cache, secure storage
│   └── supabase/          # Supabase client, config, providers
├── features/
│   ├── ai_assistant/      # AI chat feature
│   ├── anime_detail/      # Anime detail pages
│   ├── anime_library/     # Anime browsing
│   ├── auth/              # Authentication
│   ├── favorites/         # Favorites management
│   ├── home/              # Home screen
│   ├── profile/           # User profile
│   ├── schedule/          # Airing schedule
│   └── watch_history/     # Watch history
└── shared/
    ├── models/            # Shared data models
    └── widgets/           # Shared UI components
```

## Dependencies

### Core Dependencies

- `flutter_riverpod` - State management
- `go_router` - Navigation
- `dio` - HTTP client
- `hive` / `hive_flutter` - Local storage
- `flutter_secure_storage` - Secure token storage
- `cached_network_image` - Image caching

### Dev Dependencies

- `flutter_lints` - Linting
- `glados` - Property-based testing
- `build_runner` / `hive_generator` - Code generation

## License

This project is proprietary software. All rights reserved.
