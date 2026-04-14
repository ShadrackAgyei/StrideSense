# StrideSense

StrideSense is a Flutter fitness tracking app for running and workout logging. It includes authentication, workout recording, route tracking, profile management, leaderboards, clubs, challenges, and local-first caching with Supabase-backed sync.

## Stack

- Flutter
- Supabase Auth, Database, RPC, and Storage
- `geolocator` for live route tracking
- `flutter_map` for route previews
- `image_picker` for profile photos
- `shared_preferences` and `flutter_secure_storage` for local persistence

## Current Architecture

The active mobile app talks directly to Supabase.

Key app areas:
- onboarding, signup, login
- Home dashboard
- Record tab with GPS or simulated fallback route
- Community features: clubs, challenges, leaderboard
- Profile editing and avatar upload

The repo also contains a PHP/MySQL backend scaffold under `public/` and `src/`, but that is not the primary backend currently used by the Flutter app.

## Requirements

- Flutter SDK
- A Supabase project
- Supabase URL and anon key

## Supabase Setup

Apply the schema in:

- [supabase/migrations/20260404_initial_schema.sql](/Users/shaddy/Documents/GitHub/StrideSense/supabase/migrations/20260404_initial_schema.sql)

This migration creates the app tables, RPC functions, auth triggers, and the public `avatars` storage bucket used for profile photo uploads.

Minimum objects expected after migration:

- `profiles`
- `private_user_data`
- `workouts`
- `workout_events`
- `workout_samples`
- `clubs`
- `club_members`
- `challenges`
- `challenge_participants`
- `current_user_dashboard()`
- `leaderboard_distance(period)`
- storage bucket `avatars`

## Run the App

Use compile-time Supabase config:

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Example:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Build APK

```bash
flutter build apk \
  --release \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

APK output:

- `build/app/outputs/flutter-apk/app-release.apk`

## Common Development Commands

Install packages:

```bash
flutter pub get
```

Analyze:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Regenerate launcher icons:

```bash
dart run flutter_launcher_icons
```

## Permissions

The app uses:

- location permission for live workout tracking
- camera and photo library access for profile image selection

If permissions are denied, the app may fall back to a simulated workout route or block photo selection until access is granted in system settings.

## Project Structure

- [lib/main.dart](/Users/shaddy/Documents/GitHub/StrideSense/lib/main.dart): app bootstrap and Supabase initialization
- [lib/navigation/](/Users/shaddy/Documents/GitHub/StrideSense/lib/navigation): routing and app shell
- [lib/session/session.dart](/Users/shaddy/Documents/GitHub/StrideSense/lib/session/session.dart): session state, local stores, Supabase API client, sync worker
- [lib/features/auth/](/Users/shaddy/Documents/GitHub/StrideSense/lib/features/auth): onboarding and auth screens
- [lib/features/tabs/](/Users/shaddy/Documents/GitHub/StrideSense/lib/features/tabs): Home, Record, Community, Profile
- [lib/features/details/](/Users/shaddy/Documents/GitHub/StrideSense/lib/features/details): leaderboard, challenge, club, profile, and workout detail screens
- [assets/images/welcome_runner.png](/Users/shaddy/Documents/GitHub/StrideSense/assets/images/welcome_runner.png): onboarding art and launcher icon source
- [supabase/migrations/](/Users/shaddy/Documents/GitHub/StrideSense/supabase/migrations): database and storage schema
- [docs/](/Users/shaddy/Documents/GitHub/StrideSense/docs): supporting project documentation and presentation materials

## Documentation

For deeper project documentation, see:

- [docs/stridesense-app-documentation.md](/Users/shaddy/Documents/GitHub/StrideSense/docs/stridesense-app-documentation.md)
- [docs/system-explanation.md](/Users/shaddy/Documents/GitHub/StrideSense/docs/system-explanation.md)
- [docs/supabase-migration.md](/Users/shaddy/Documents/GitHub/StrideSense/docs/supabase-migration.md)

## Notes

- Because Supabase config is read through `String.fromEnvironment`, changing the URL or anon key requires a fresh run/build with `--dart-define`; hot reload is not enough.
- If signup/login succeeds but profile loading fails, the issue is usually missing or stale Supabase schema, not authentication itself.
- If avatar upload fails, verify that the `avatars` bucket and its storage policies were created from the migration.
