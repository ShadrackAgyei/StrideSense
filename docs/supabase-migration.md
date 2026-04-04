# Supabase migration plan for StrideSense

The current backend is a custom PHP API backed by MySQL and custom access and refresh token tables. Supabase changes two core things:

1. Auth moves to Supabase Auth.
2. The data store moves from MySQL to Postgres with row-level security.

This repo now includes a baseline schema in [`/Users/shaddy/Documents/GitHub/StrideSense/supabase/migrations/20260404_initial_schema.sql`](/Users/shaddy/Documents/GitHub/StrideSense/supabase/migrations/20260404_initial_schema.sql).

## What maps cleanly

- `users` -> `auth.users` plus `public.profiles` and `public.private_user_data`
- `user_profiles` -> `public.profiles`
- `clubs`, `club_members`, `challenges`, `challenge_participants`, `workouts`, `workout_events`, `workout_samples` -> same logical tables in `public`
- avatar uploads -> Supabase Storage bucket `avatars`
- leaderboard summary -> `public.leaderboard_distance(period text)`
- current user totals -> `public.current_user_dashboard()`

## What does not map 1:1

- `auth_access_tokens` and `auth_refresh_tokens` should be removed. Supabase owns session issuance and refresh.
- PHP routes such as `/v1/auth/register` and `/v1/auth/login` disappear if the Flutter app talks to Supabase directly.
- user IDs become `uuid` values from Supabase Auth. The app already treats workout, club, and challenge IDs as integers, which is still fine. Only `user_id` changes shape.

## Recommended cutover

Use a direct-to-Supabase Flutter client and retire the PHP backend.

That is the cleaner option because the current Flutter app already owns most of the session state and sync behavior. Keeping the PHP server as a compatibility layer would just recreate auth and policy logic that Supabase already gives you.

## Endpoint replacement guide

- `POST /auth/register`
  Replace with `supabase.auth.signUp(email:, password:, data:)`
- `POST /auth/login`
  Replace with `supabase.auth.signInWithPassword(email:, password:)`
- `POST /auth/refresh`
  Remove. Supabase handles token refresh.
- `POST /auth/logout`
  Replace with `supabase.auth.signOut()`
- `GET /me`
  Replace with:
  - `from('profiles').select()`
  - `from('private_user_data').select()`
  - `rpc('current_user_dashboard')`
- `PATCH /me/profile`
  Replace with updates against `profiles` and `private_user_data`
- `POST /me/avatar`
  Replace with:
  - `storage.from('avatars').upload('${user.id}/filename', ...)`
  - `from('profiles').update({'avatar_url': publicUrl})`
- `GET /clubs`
  Replace with `from('clubs')` plus `club_members` join state
- `POST /clubs`
  Replace with `from('clubs').insert(...)`
- `POST /clubs/{id}/join`
  Replace with `from('club_members').insert(...)`
- `POST /clubs/{id}/leave`
  Replace with delete from `club_members`
- `GET /challenges`
  Replace with `from('challenges')`
- `GET /challenges/{id}`
  Replace with `from('challenges').select(...)`
- `POST /challenges/{id}/join`
  Replace with `from('challenge_participants').insert(...)`
- `GET /leaderboard`
  Replace with `rpc('leaderboard_distance', params: {'period': ...})`
- workout lifecycle routes
  Replace with direct inserts and updates on `workouts`, `workout_events`, and `workout_samples`

## Flutter code that must change

The current client is tightly bound to the old REST contract in [`/Users/shaddy/Documents/GitHub/StrideSense/lib/session/session.dart`](/Users/shaddy/Documents/GitHub/StrideSense/lib/session/session.dart).

The main refactor points are:

- `BackendApiClient`
  Replace `Dio` route calls with a `SupabaseClient`-backed implementation
- `AuthTokens`
  Replace custom token persistence with the Supabase session
- `_withAuthRetry(...)`
  Remove manual refresh token flow
- `uploadAvatar(...)`
  Change multipart upload to Supabase Storage
- `_profileFromServer(...)`
  Read from joined `profiles` and `private_user_data` rows instead of `/me`

## Suggested implementation order

1. Create a Supabase project.
2. Apply the SQL migration in this repo.
3. Add the Flutter dependency `supabase_flutter`.
4. Add `SUPABASE_URL` and `SUPABASE_ANON_KEY` as Dart defines or platform config.
5. Replace auth calls first.
6. Replace profile read and write flows.
7. Replace workout writes and history reads.
8. Replace clubs, challenges, and leaderboard.
9. Remove the PHP backend once the mobile app is stable.

## Data migration notes

If you need to preserve existing MySQL data:

- export `users`, `user_profiles`, `clubs`, `club_members`, `challenges`, `challenge_participants`, `workouts`, `workout_events`, and `workout_samples`
- create Supabase users first, or map existing users to newly created Supabase auth IDs
- load profile and domain tables after you know the final auth UUID for each user

The hardest part is user identity mapping, not the tables themselves.

## Important gaps to resolve before full cutover

- The app currently uses a hard-coded backend base URL in [`/Users/shaddy/Documents/GitHub/StrideSense/lib/session/session.dart`](/Users/shaddy/Documents/GitHub/StrideSense/lib/session/session.dart). That needs to be removed.
- The current data model for self profile includes email and phone. Those are private and should stay in `private_user_data`, not in a world-readable profile table.
- If you want admin-only club and challenge management, add stricter RLS or RPC functions before exposing creation flows widely.
