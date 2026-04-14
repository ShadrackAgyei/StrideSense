# StrideSense Application Documentation

## 1. Purpose and Scope

StrideSense is a Flutter-based fitness tracking app focused on running and workout logging. The current codebase provides:

- user onboarding, sign up, and login
- dashboard and profile views
- workout recording with live GPS or simulated fallback tracking
- workout history and workout summaries
- community features such as clubs, challenges, and leaderboards
- profile editing with avatar upload
- local persistence and background sync support

The repository also contains two backend/data layers:

- an active Flutter-to-Supabase integration used by the mobile app
- a PHP/MySQL REST API scaffold that documents an alternate backend path and mirrors much of the same domain model

Important implementation note:
The current Flutter application uses `supabase_flutter` directly for authentication, storage, and data operations. The PHP backend exists in the repo, but it is not the primary runtime backend used by the Flutter client at this stage.

## 2. Local Resources Used

### 2.1 Project Resources

The main local resources in the repository are:

- [`lib/main.dart`](/Users/shaddy/Documents/GitHub/StrideSense/lib/main.dart): application entry point and root composition file
- [`lib/navigation/`](/Users/shaddy/Documents/GitHub/StrideSense/lib/navigation): route constants, navigation arguments, app shell wiring
- [`lib/session/session.dart`](/Users/shaddy/Documents/GitHub/StrideSense/lib/session/session.dart): session management, models, Supabase API client, local stores, sync queue
- [`lib/features/auth/`](/Users/shaddy/Documents/GitHub/StrideSense/lib/features/auth): onboarding, signup, login, password reset flows
- [`lib/features/tabs/`](/Users/shaddy/Documents/GitHub/StrideSense/lib/features/tabs): main tab views for Home, Record, Community, and Profile
- [`lib/features/details/`](/Users/shaddy/Documents/GitHub/StrideSense/lib/features/details): secondary screens such as leaderboard, workout summary, challenge detail, club detail, and profile settings
- [`lib/widgets/shared.dart`](/Users/shaddy/Documents/GitHub/StrideSense/lib/widgets/shared.dart): reusable UI building blocks and validators
- [`assets/images/welcome_runner.png`](/Users/shaddy/Documents/GitHub/StrideSense/assets/images/welcome_runner.png): onboarding illustration and launcher icon source

### 2.2 Local Persistence Resources

The app stores state locally using `SharedPreferences` and `FlutterSecureStorage`.

Stored local resources include:

- auth token payload under `auth_tokens_v1`
- cached dashboard summary under `dashboard_summary_v1`
- cached profile data under `profile_data_v1`
- queued sync operations under `sync_queue_v1`

These are managed in [`lib/session/session.dart`](/Users/shaddy/Documents/GitHub/StrideSense/lib/session/session.dart) by:

- `AuthTokenStore`
- `LocalDashboardStore`
- `LocalProfileStore`
- `SyncQueueStore`

### 2.3 Environment and Schema Resources

- Supabase connection is injected at runtime through `--dart-define`
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
- Supabase schema and SQL functions are defined in [`supabase/migrations/20260404_initial_schema.sql`](/Users/shaddy/Documents/GitHub/StrideSense/supabase/migrations/20260404_initial_schema.sql)
- PHP/MySQL backend bootstrap and env loading are defined in:
  - [`public/index.php`](/Users/shaddy/Documents/GitHub/StrideSense/public/index.php)
  - [`src/Env.php`](/Users/shaddy/Documents/GitHub/StrideSense/src/Env.php)
  - [`src/Database.php`](/Users/shaddy/Documents/GitHub/StrideSense/src/Database.php)

## 3. Packages and Libraries Used

The app dependencies are declared in [`pubspec.yaml`](/Users/shaddy/Documents/GitHub/StrideSense/pubspec.yaml).

### 3.1 Core Flutter Packages

- `flutter`: UI framework for the mobile app
- `cupertino_icons`: iOS-style icon support

### 3.2 Functional Packages

- `supabase_flutter`: primary backend SDK
  - used for authentication
  - used for database CRUD
  - used for RPC calls
  - used for file upload to avatar storage
- `geolocator`: live location tracking and distance computation
  - used in the Record tab for GPS stream subscriptions and permission checks
- `flutter_map`: route preview map rendering
  - used in workout logging screens to visualize the recorded route
- `latlong2`: coordinate data structures for map rendering
  - used with `flutter_map`
- `image_picker`: profile photo capture or gallery selection
  - used in the Edit Profile screen
- `shared_preferences`: lightweight local cache and sync queue persistence
  - used for dashboard, profile, and sync state
- `flutter_secure_storage`: secure token storage
  - used for auth token persistence when available
- `uuid`: unique path generation for uploaded avatars
  - used in `BackendApiClient.uploadAvatar`
- `dio`: imported for structured network error handling
  - currently used mainly for `DioException` handling and offline fallback logic

### 3.3 Development Packages

- `flutter_test`: widget testing support
- `flutter_lints`: linting rules
- `flutter_launcher_icons`: launcher icon generation from the welcome image

## 4. How the Main Dart File Enables Full Functionality

The main entry point is [`lib/main.dart`](/Users/shaddy/Documents/GitHub/StrideSense/lib/main.dart).

Its responsibilities are:

1. initialize Flutter bindings with `WidgetsFlutterBinding.ensureInitialized()`
2. read `SUPABASE_URL` and `SUPABASE_ANON_KEY` from compile-time environment variables
3. fail early if Supabase configuration is missing
4. initialize the Supabase SDK
5. launch the root widget `StrideSenseApp`

The file also acts as a central composition root by using Dart `part` directives to assemble the app from multiple feature files:

- navigation
- session/state
- shared widgets
- auth screens
- shell and tabs
- detail screens

This makes `main.dart` the single bootstrap point while allowing the app to remain modular in feature files.

## 5. System and App Architecture Overview

### 5.1 High-Level Architecture

The current architecture can be understood in five layers:

1. Presentation layer
   - Flutter widgets and screens
2. Navigation layer
   - route constants, typed route arguments, guarded routing
3. Session and state layer
   - `SessionController` and `SessionScope`
4. Data access layer
   - `BackendApiClient`, local stores, sync worker
5. Backend/data layer
   - Supabase as the active mobile backend
   - PHP/MySQL scaffold as an additional backend resource in the repo

### 5.2 Frontend Structure

The frontend is organized around:

- `StrideSenseApp`
  - root `MaterialApp`
  - route generation
  - auth-aware route protection
- `MainShell`
  - bottom navigation container
  - tab preservation through `IndexedStack`

Primary user-facing areas:

- onboarding and authentication
- Home
- Record
- Community
- Profile

### 5.3 State Management

State is managed with a lightweight custom pattern:

- `SessionController extends ChangeNotifier`
- `SessionScope extends InheritedNotifier`

This controls:

- auth state
- current profile data
- dashboard summary
- error messages
- pending post-login navigation
- workout lifecycle actions
- profile sync behavior

This avoids extra state libraries like Provider, Riverpod, or Bloc while still keeping shared app state centralized.

### 5.4 Data Flow

The active runtime data flow is:

1. user signs up or logs in through Supabase Auth
2. tokens are stored locally
3. profile and dashboard data are fetched from Supabase
4. local cache is updated
5. UI rebuilds from `SessionController`
6. profile edits are stored locally first, then synced through the sync worker
7. workouts are recorded locally and then persisted to Supabase tables

### 5.5 Backend and Database Structure

The active Supabase schema includes:

- `profiles`
- `private_user_data`
- `clubs`
- `club_members`
- `challenges`
- `challenge_participants`
- `workouts`
- `workout_events`
- `workout_samples`
- `idempotency_keys`

Database-side functions include:

- `current_user_dashboard()`
- `leaderboard_distance(period text)`
- auth triggers to keep profile and private user data aligned with `auth.users`

The PHP backend exposes parallel REST endpoints for:

- auth
- user profile
- clubs
- challenges
- leaderboard
- workout lifecycle

That backend is routed from [`public/index.php`](/Users/shaddy/Documents/GitHub/StrideSense/public/index.php) and implemented mainly through [`src/ApiController.php`](/Users/shaddy/Documents/GitHub/StrideSense/src/ApiController.php) and [`src/AuthService.php`](/Users/shaddy/Documents/GitHub/StrideSense/src/AuthService.php).

## 6. Frontend and Backend Integration

### 6.1 Current Active Integration

The Flutter app currently integrates directly with Supabase through `BackendApiClient`.

Implemented client operations include:

- `register`
- `login`
- `refresh`
- `logout`
- `getMe`
- `patchProfile`
- `uploadAvatar`
- `startWorkout`
- `pauseWorkout`
- `resumeWorkout`
- `uploadWorkoutSamples`
- `completeWorkout`
- `getWorkoutHistory`
- `getLeaderboard`
- `getChallenges`
- `joinChallenge`
- `getChallengeDetail`
- `getClubs`
- `joinClub`
- `getClubDetail`
- `createClub`

### 6.2 Sync Integration

Profile updates follow an offline-tolerant flow:

1. user edits profile data
2. data is saved locally through `LocalProfileStore`
3. a sync operation is enqueued in `SyncQueueStore`
4. `SyncWorker` runs on a timer
5. `BackendSyncApiClient` pushes changes upstream
6. successful sync clears the dirty flag

This supports resilience for temporary connection loss.

### 6.3 Workout Integration

Workout integration spans UI, sensors, local models, and backend writes:

- `geolocator` provides location stream data
- the Record tab computes distance from consecutive positions
- route points are kept in memory during a workout
- the Log Workout screen shows a route preview using `flutter_map`
- the workout is cached locally
- samples and workout summary are written to Supabase if a cloud workout ID exists

### 6.4 PHP Backend Status

The PHP backend is functional as a scaffold and mirrors many mobile domain operations, but the current Flutter mobile flow does not call it directly. If the app later migrates to the PHP API, the domain model and endpoint coverage are already partially prepared in the repository.

## 7. UI/UX Structure

### 7.1 Design Direction

The UI is built with Material 3 and a consistent visual language:

- primary brand color: deep navy `0xFF0D1A63`
- white or light-blue surfaces
- rounded cards and chips
- strong typography for section titles
- bottom navigation for the main app shell

### 7.2 Navigation Experience

Navigation is route-based using `MaterialApp.onGenerateRoute`.

Main route groups:

- auth routes
- tab shell routes
- detail routes
- profile/settings routes

Protected routes are gated by `_requireAuth`, which redirects unauthenticated users to login and preserves their pending destination.

### 7.3 Screen-by-Screen UX Structure

- Onboarding
  - welcome branding
  - illustration
  - direct actions to login or create account
- Signup/Login
  - simple validated forms
  - clear primary CTA buttons
  - snackbar feedback on failure
- Home
  - welcome header
  - date strip
  - progress cards
  - recent activity list
- Record
  - start, pause, stop controls
  - live metrics for distance and duration
  - recent records and workout access
- Community
  - leaderboard and challenges entry points
  - challenge highlights
  - club overview
- Profile
  - personal identity section
  - progress cards
  - weekly performance chart
- Detail screens
  - leaderboard filters
  - challenge/club join actions
  - workout map preview and summary
  - editable profile and personal information forms

### 7.4 UX Resilience Features

The app includes several fallback behaviors:

- offline/local auth fallback in non-production builds
- simulated route generation when GPS is unavailable
- local-first profile saving before sync
- cached dashboard and profile reload on bootstrap

These improve demo readiness and reduce hard failure points during development.

## 8. Operational Guide: How to Use the App

### 8.1 Setup and Run

1. ensure Flutter is installed
2. create or configure a Supabase project
3. apply the schema in [`supabase/migrations/20260404_initial_schema.sql`](/Users/shaddy/Documents/GitHub/StrideSense/supabase/migrations/20260404_initial_schema.sql)
4. run the Flutter app with the required defines

Example:

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

### 8.2 First-Time User Flow

1. launch the app
2. tap `Get Started` or `Create account`
3. create an account with email, password, first name, last name, and phone
4. after successful authentication, continue into the main app

### 8.3 Logging In

1. open the login screen
2. enter email and password
3. submit the form
4. the app stores the session and loads profile/dashboard data

### 8.4 Recording a Workout

1. open the `Record` tab
2. tap `Start`
3. allow location access if prompted
4. the app begins tracking distance and elapsed time
5. tap `Pause` to pause
6. tap `Start` again to resume
7. tap `Stop` to end the workout
8. on the log screen, choose a workout category and optionally add notes
9. tap `Save Workout`

If GPS is unavailable, the app automatically switches to a simulated route so the flow still works.

### 8.5 Viewing Progress

- use `Home` to view overall distance, weekly pace, and recent workouts
- use `Profile` to view personal stats and the weekly distance chart
- open a workout entry to see the workout summary

### 8.6 Using Community Features

- open `Community`
- tap `Leaderboard` to view rankings
- tap `Challenges` to browse challenge content
- open a challenge and tap `Join Challenge`
- open a club and tap `Join Club`

### 8.7 Editing Profile and Personal Information

1. open `Profile`
2. tap `Edit Profile` to change display-facing information
3. tap `Personal Info` to update personal account details
4. use `Change Photo` to upload an avatar from camera or gallery
5. save changes
6. the app writes locally and then syncs upstream

### 8.8 Logging Out

- use the logout icon from Home, or
- go to Settings and tap `Log Out`

## 9. Practical Architecture Summary

In practical terms, StrideSense currently works as:

- a Flutter mobile frontend
- a custom in-app session/state layer
- a direct Supabase-integrated backend client
- a local caching and deferred sync system
- a partially prepared PHP/MySQL backend for alternate or future API deployment

This makes the current app suitable for end-to-end usage around auth, profile management, workout tracking, and community interaction while still leaving room for backend evolution.

## 10. Key Files for Maintenance

- App bootstrap: [`lib/main.dart`](/Users/shaddy/Documents/GitHub/StrideSense/lib/main.dart)
- Routing and app shell: [`lib/navigation/app_core.dart`](/Users/shaddy/Documents/GitHub/StrideSense/lib/navigation/app_core.dart)
- Session/state/data access: [`lib/session/session.dart`](/Users/shaddy/Documents/GitHub/StrideSense/lib/session/session.dart)
- Shared widgets: [`lib/widgets/shared.dart`](/Users/shaddy/Documents/GitHub/StrideSense/lib/widgets/shared.dart)
- Auth screens: [`lib/features/auth/auth_screens.dart`](/Users/shaddy/Documents/GitHub/StrideSense/lib/features/auth/auth_screens.dart)
- Tabs: [`lib/features/tabs/`](/Users/shaddy/Documents/GitHub/StrideSense/lib/features/tabs)
- Detail screens: [`lib/features/details/detail_screens.dart`](/Users/shaddy/Documents/GitHub/StrideSense/lib/features/details/detail_screens.dart)
- Supabase schema: [`supabase/migrations/20260404_initial_schema.sql`](/Users/shaddy/Documents/GitHub/StrideSense/supabase/migrations/20260404_initial_schema.sql)
- PHP API entrypoint: [`public/index.php`](/Users/shaddy/Documents/GitHub/StrideSense/public/index.php)
- PHP API controller: [`src/ApiController.php`](/Users/shaddy/Documents/GitHub/StrideSense/src/ApiController.php)
