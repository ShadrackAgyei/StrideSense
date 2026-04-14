# StrideSense — Complete System Explanation

> A detailed reference document covering every slide in the presentation and the full technical architecture of the StrideSense Flutter application.

---

## PART 1 — SLIDE-BY-SLIDE EXPLANATIONS

---

### Slide 1 — Title

**StrideSense** is the name of the project. The subtitle — *GPS-Powered Fitness Tracking · Flutter Mobile App* — summarises the two things that define it: what it does (GPS fitness tracking) and how it was built (Flutter).

The three tag lines at the bottom — *Built with Flutter*, *Powered by Supabase*, *Android & iOS* — are not marketing. They represent three concrete technical decisions:

1. **Flutter** was chosen so the same Dart codebase compiles to both Android and iOS without duplication.
2. **Supabase** was chosen as a managed backend — it provides authentication, a PostgreSQL database, file storage, and database functions without requiring a custom server.
3. **Android & iOS** indicates that the app was tested and deployed on both platforms using a single codebase.

---

### Slide 2 — Presentation Roadmap

The agenda slide maps the eight sections to approximate time allocations within the eight-minute window. The sections follow a logical build-up:

- Why (case study) → What (requirements) → How it looks (wireframes) → What it uses physically (resources) → How it is built (architecture, ERD, tech stack) → How to run and use it (deployment, guide)

This ordering mirrors standard software documentation: problem → specification → design → implementation → operation.

---

### Slide 3 — The Case Study

#### Context

The case study describes the real-world scenario that motivated the application. It is presented as a narrative rather than a list of bullet points because a narrative communicates *why the problem matters*, not just *what the problem is*.

#### The Situation

University student athletes in a community setting ran regularly but lacked access to:

- **Measurement tools**: No GPS-enabled device to track distance, pace, or route. Without measurement, progress is invisible and training plateaus are invisible too.
- **Affordable wearables**: Consumer fitness trackers (Garmin, Apple Watch, Fitbit) cost significantly more than the target demographic could justify. These devices are also locked to proprietary ecosystems.
- **Community infrastructure**: Generic fitness apps (Strava, Nike Run Club) are designed for individual performance and have limited or paywalled community features. They do not support the club-and-challenge culture of student athletics.
- **Accountability mechanisms**: Without visible leaderboards, shared challenges, or club membership, there is no social pressure or incentive to maintain consistency.

#### The Result

Without data, structure, or peer accountability, motivation degraded over weeks. Users started strong and abandoned the habit because there was no feedback loop to sustain it.

#### The Four Identified Needs

These were not assumed — they were derived from observing the behaviour and constraints of the target users:

| Need | Reasoning |
|------|-----------|
| Real-time GPS tracking | Without measurement, training has no baseline and no visible progress |
| Progress dashboard | Data needs to be surfaced to be motivating — raw numbers in a database are useless |
| Social / community layer | Peer accountability is one of the most reliable predictors of sustained behaviour change |
| Offline-first operation | Student athletes run in parks, tracks, and areas with variable network coverage |

#### Why the Framing Matters

The slide does not say "the problem was that there was no app." It says the *situation* was a specific group of people with a specific gap. This matters because it defines the scope: StrideSense was not trying to compete with Strava globally — it was designed for a community of student runners with a specific set of constraints.

---

### Slide 4 — Requirements

Requirements were derived directly from the case study. Every item on the list maps back to one of the four identified needs.

#### Functional Requirements — Detailed

| # | Requirement | Maps to need |
|---|-------------|-------------|
| 1 | User registration & login with email/password | Foundation — all other features require identity |
| 2 | Live GPS tracking — distance, pace, route | Real-time GPS tracking |
| 3 | GPS fallback to simulated route | Real-time GPS tracking (resilience) |
| 4 | Workout history with map preview | Progress dashboard |
| 5 | Profile editing including avatar upload | Progress dashboard (personal identity) |
| 6 | Browse and join clubs; view and join challenges | Social / community layer |
| 7 | Leaderboard ranked by weekly or monthly distance | Social / community layer |

#### Non-Functional Requirements — Detailed

| # | Requirement | Technical reason |
|---|-------------|-----------------|
| 1 | Offline-first with local cache and background sync | Users run in areas with no network; app must not crash or lose data |
| 2 | Encrypted auth token storage | Sessions persist across restarts — tokens must be protected on-device |
| 3 | Sub-300 ms local operations | UI must feel instantaneous for cached data; no spinner for things already on-device |
| 4 | Location access requires user permission | Android and iOS both gate GPS behind explicit user consent; the app must handle denial gracefully |
| 5 | Row Level Security on all database tables | Users must never be able to read or write another user's workouts or private data |
| 6 | Android API 21+ and iOS 14+ | Ensures compatibility with the widest range of affordable Android devices |

---

### Slide 5 — Wireframes

#### The Design Process

All ten screens were designed in Figma before any Flutter code was written. This is called a *design-first* workflow: the wireframes serve as a shared reference that aligns the team on navigation, layout, and data requirements before implementation begins.

#### The Ten Screens

| Screen | Purpose |
|--------|---------|
| Splash | Branding entry point — logo, tagline, Get Started / Login CTAs |
| Sign Up | Account creation form — email, password, first name, last name, phone |
| Login | Authentication form — email, password, forgot password link |
| Home | Dashboard — welcome header, date strip, total distance, weekly pace, recent workouts |
| Record | Workout recording — start/pause/stop controls, live distance, elapsed time, recent history |
| Community | Social hub — leaderboard entry, challenge highlights, club overview |
| Profile | Personal stats — name, avatar, total distance, weekly bar chart |
| Settings | App settings — notifications, privacy, logout |
| Edit Profile | Public profile editing — name, bio, city, avatar upload |
| Personal Info | Private account info — email, phone |

#### Key UX Decisions Made During Wireframing

- **Bottom navigation bar** (not a drawer): puts all four core areas — Home, Record, Community, Profile — one tap away from anywhere in the app.
- **Card-based layouts**: consistent across workout history, leaderboard entries, challenges, and clubs.
- **Inline map preview**: the workout log screen shows a route map rendered with `flutter_map` rather than a static thumbnail, because route visualisation is part of the value the app provides.
- **Edit Profile vs. Personal Info split**: public display data (name, bio, city, avatar) is separated from private data (email, phone) to make the privacy boundary explicit to users.

---

### Slide 6 — Physical & Local Resources

This section covers the hardware sensors, platform APIs, and on-device storage systems the app uses. These are distinct from software libraries — they are the physical and OS-level capabilities the device must provide.

#### 1. GPS / Location Sensor

- **Hardware**: The device's GPS chip and/or network-assisted location module.
- **Android permission**: `ACCESS_FINE_LOCATION` (high-accuracy GPS), `ACCESS_COARSE_LOCATION` (fallback).
- **iOS permission**: `NSLocationWhenInUseUsageDescription` in `Info.plist`.
- **Flutter package**: `geolocator ^11.1.0`.
- **How it is used**: The Record tab subscribes to a stream of `Position` objects from `geolocator`. Each position has a latitude, longitude, accuracy, and timestamp. The app computes the cumulative distance by summing the Haversine distance between consecutive position updates. GPS coordinates are stored in `workout_samples` in the Supabase database.
- **Fallback**: If GPS is unavailable (device denied permission or GPS signal lost), the app generates a simulated route using interpolated coordinates. This allows the full workout recording flow to complete in a demo or low-signal environment.

#### 2. Camera & Photo Library

- **Hardware**: The device's camera module and internal/external media storage.
- **Android permissions**: `CAMERA` (for live capture), `READ_MEDIA_IMAGES` (for gallery access on API 33+), `READ_EXTERNAL_STORAGE` (for API < 33).
- **iOS**: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` in `Info.plist`.
- **Flutter package**: `image_picker ^1.1.2`.
- **How it is used**: The Edit Profile screen calls `ImagePicker().pickImage(source: ImageSource.camera)` or `ImageSource.gallery`. The selected image is then uploaded to Supabase Storage using `BackendApiClient.uploadAvatar`, which places the file at `{user_id}/{uuid}.jpg` in the `avatars` bucket and writes the resulting public URL back to the `profiles.avatar_url` column.

#### 3. Network / Internet

- **Hardware**: WiFi network interface card (NIC) or mobile modem (4G/5G).
- **Android permission**: `INTERNET`.
- **iOS**: No explicit permission required for outbound network access, but ATS (App Transport Security) rules apply.
- **Flutter packages**: `supabase_flutter` (for all backend calls), `dio` (for error handling), `flutter_map` (for tile HTTP requests).
- **How it is used**:
  - All Supabase operations (auth, database reads/writes, RPC calls, storage uploads) go over HTTPS to the Supabase project URL.
  - `flutter_map` fetches map tile images from OpenStreetMap tile servers over HTTP/HTTPS to render the route preview.
  - `dio` wraps outbound calls in retry and error-classification logic to distinguish network errors from API errors.

#### 4. Secure Device Storage

- **Hardware**: The device's hardware-backed secure enclave.
- **Android**: Android Keystore System — cryptographic keys are stored in hardware and never exposed to user space.
- **iOS**: Apple Keychain and Secure Enclave — the OS manages key storage independent of the app sandbox.
- **Flutter package**: `flutter_secure_storage ^9.2.2`.
- **How it is used**: The `AuthTokenStore` class in `session.dart` persists the user's access and refresh tokens under the key `auth_tokens_v1`. Tokens are AES-encrypted at rest using a key managed by the platform. This means that even if someone extracts the device's filesystem, the tokens cannot be read without the device's hardware security credentials.

#### 5. Local Key-Value Storage

- **Hardware**: The device's on-device flash storage (not hardware-secured).
- **Platform mechanism**: `SharedPreferences` on Android (XML-backed key-value store) and `NSUserDefaults` on iOS.
- **Flutter package**: `shared_preferences ^2.3.2`.
- **How it is used**: Three store classes in `session.dart` manage different cached resources:
  - `LocalDashboardStore` → key `dashboard_summary_v1`: stores the user's total distance and workout count for instant Home tab display.
  - `LocalProfileStore` → key `profile_data_v1`: stores the full profile object for instant Profile tab display.
  - `SyncQueueStore` → key `sync_queue_v1`: stores queued profile edit operations that have not yet been pushed to Supabase.

#### 6. Map Tile Rendering

- **Hardware**: The device GPU and screen display.
- **Flutter packages**: `flutter_map ^6.1.0` (map widget), `latlong2 ^0.9.1` (coordinate model).
- **Network dependency**: `flutter_map` fetches tile images from OpenStreetMap servers (requires `INTERNET` permission).
- **How it is used**: The workout log screen renders a `FlutterMap` widget with a `TileLayer` (OpenStreetMap) and a `PolylineLayer` drawn from the list of `LatLng` coordinate pairs collected during the recorded workout. The map widget handles zoom, pan, and tile caching internally.

---

### Slide 7 — Architecture & Module Assignments

#### The Five-Layer Architecture

StrideSense follows a layered architecture where each layer has a single responsibility and communicates only with the layer directly below it.

---

**Layer 1 — Presentation**

Files: `lib/features/auth/auth_screens.dart`, `lib/features/tabs/`, `lib/features/details/detail_screens.dart`, `lib/widgets/shared.dart`, `lib/features/shell/main_shell.dart`

This is everything the user sees. Every screen is a Flutter `StatelessWidget` or `StatefulWidget`. The Presentation layer reads state from `SessionScope` (Layer 3) and calls actions on `SessionController`. It never calls Supabase directly. It never writes to local storage directly.

The design system is Material 3 with a consistent visual language:
- Primary colour: deep navy `#0D1A63`
- Accent: electric blue `#2563EB`
- Surface: white and light gray `#F8FAFC`
- Typography: system fonts with bold headings and regular body text

---

**Layer 2 — Navigation**

Files: `lib/navigation/app_routes.dart`, `lib/navigation/app_core.dart`

The Navigation layer defines:
- **Route constants** in `app_routes.dart` — all route strings as typed constants so they can never be mistyped.
- **Route generation** in `app_core.dart` — `MaterialApp.onGenerateRoute` switches on route names and constructs the correct screen with typed arguments.
- **Auth guard** — the `_requireAuth` function checks `SessionController.isAuthenticated` before building protected routes. Unauthenticated access redirects to login and stores the pending destination for post-login navigation.

---

**Layer 3 — Session & State**

File: `lib/session/session.dart` (partial)

`SessionController extends ChangeNotifier` is the single source of truth for the entire app's runtime state. It holds:

| Field | Purpose |
|-------|---------|
| `isAuthenticated` | Whether the user has a valid session |
| `profile` | The loaded `UserProfile` object |
| `dashboardSummary` | Cached distance and workout count |
| `errorMessage` | Current error to display in the UI |
| `pendingRoute` | Route to navigate to after login |
| `workoutState` | Live workout recording state |

`SessionScope extends InheritedNotifier<SessionController>` wraps the widget tree so any descendant can call `SessionScope.of(context)` to read state without passing the controller manually through constructors.

This design deliberately avoids third-party state management libraries (Provider, Riverpod, Bloc) to keep the dependency surface small and the state logic fully within the team's control.

---

**Layer 4 — Data Access**

File: `lib/session/session.dart` (partial)

Three classes form the data access layer:

**`BackendApiClient`** — wraps all Supabase operations. Every method is async and returns a typed result or throws a classified error. Operations include:
- Auth: `register`, `login`, `refresh`, `logout`
- Profile: `getMe`, `patchProfile`, `uploadAvatar`
- Workouts: `startWorkout`, `pauseWorkout`, `resumeWorkout`, `completeWorkout`, `uploadWorkoutSamples`, `getWorkoutHistory`
- Leaderboard: `getLeaderboard`
- Challenges: `getChallenges`, `joinChallenge`, `getChallengeDetail`
- Clubs: `getClubs`, `joinClub`, `getClubDetail`, `createClub`

**Local store classes** — `AuthTokenStore`, `LocalDashboardStore`, `LocalProfileStore`, `SyncQueueStore`. Each store has typed read and write methods that abstract away the `SharedPreferences` or `FlutterSecureStorage` key names.

**`SyncWorker`** — runs on a timer. On each tick it reads from `SyncQueueStore`, calls `BackendSyncApiClient` to push each pending operation, and clears operations that succeed. This gives the app its offline-tolerant profile editing behaviour.

---

**Layer 5 — Backend / Data**

Supabase project + `supabase/migrations/20260404_initial_schema.sql`

The Flutter app communicates with Supabase via three interfaces:
1. **Supabase Auth** — sign up, login, session refresh, logout, and auth state change events.
2. **PostgREST** (via `supabase_flutter`) — typed CRUD operations against all public tables.
3. **Supabase Storage** — multipart file upload to the `avatars` bucket.

The PHP backend in `src/` and `public/` is an additional resource in the repository. It was built by Ismail as a REST API scaffold that mirrors the same domain operations. It is not called by the Flutter app at runtime — the Flutter app talks directly to Supabase — but it documents an alternate backend path and remains available for future migration.

---

#### Module Assignments

| Module | File(s) | Member | Description |
|--------|---------|--------|-------------|
| Auth & Onboarding | `auth_screens.dart` | Shadrack Agyei Nti | Onboarding screen, sign up form, login form, password reset, all auth state wiring |
| Home Dashboard | `home_tab.dart` | Shadrack Agyei Nti | Welcome header, date strip, progress cards, recent workout list |
| Workout Recording | `home_tab.dart` (Record section) | Shadrack Agyei Nti | GPS stream subscription, live distance/timer UI, pause/stop controls, workout log screen |
| Community Features | `community_tab.dart` | Shadrack Agyei Nti | Leaderboard display, challenge highlights, club overview cards |
| Profile & Settings | `profile_tab.dart` | Shadrack Agyei Nti | Personal stats, weekly chart, Edit Profile, Personal Info, Change Photo |
| Session / State / Data | `session.dart` | Shadrack Agyei Nti | `SessionController`, `BackendApiClient`, all local stores, sync worker |
| Navigation & Routing | `lib/navigation/` | Shadrack Agyei Nti | Route constants, `onGenerateRoute`, auth guard |
| PHP Backend / REST API | `src/`, `public/`, `migrations/` | Ismail | REST endpoint definitions, auth service, database controller, PHP environment |
| Database Schema (SQL) | `supabase/migrations/` | Shadrack Agyei Nti | Full Postgres schema, RLS policies, triggers, stored functions, storage bucket config |

---

### Slide 8 — Entity Relationship Diagram

The database schema defines ten tables across four logical groups.

#### Group 1 — Identity (Purple / Blue)

**`auth.users`** (Supabase-managed)
The root identity record. Created by Supabase Auth on sign-up. Every other table references this via a foreign key on `id (uuid)`. The app never writes to this table directly — Supabase Auth manages it.

**`profiles`** (public-facing)
Stores information the user controls and that other users can see: username, first name, last name, bio, avatar URL, city, and privacy level. Created automatically by the `handle_auth_user_created()` trigger when a new auth user is inserted.

**`private_user_data`** (private)
Stores sensitive information — email and phone. Protected by a stricter RLS policy: only the owning user can read or update their own row. Email is kept in sync with `auth.users.email` via the `handle_auth_user_updated()` trigger.

---

#### Group 2 — Workout Activity (Green)

**`workouts`**
The central activity record. One row per recorded workout session. Key fields:
- `activity_type`: enum — `run`, `walk`, `cycle`, `workout`
- `status`: enum — `running`, `paused`, `completed`, `abandoned`
- `distance_m`: metres as a decimal
- `duration_sec`: elapsed time in integer seconds
- `avg_pace_sec_per_km`: average pace as decimal seconds per kilometre
- `calories_kcal`: estimated calories
- `source`: enum — `mobile`, `gps`, `healthkit`, `health_connect`, `manual`

**`workout_events`**
An audit log of lifecycle state changes for a workout. One row per event: `start`, `pause`, `resume`, `complete`. Used to reconstruct the exact history of a session and to calculate total active time (excluding paused periods).

**`workout_samples`**
Time-series GPS and biometric data captured during a workout. Each sample has a timestamp, latitude, longitude, altitude, instantaneous pace, heart rate, step count, and calorie estimate. This table powers the route map — the `PolylineLayer` in `flutter_map` is drawn from the sequence of `(latitude, longitude)` pairs in this table.

---

#### Group 3 — Social / Community (Orange)

**`clubs`**
A running club. Has a name, description, and a `created_by` foreign key to the user who created it. Any authenticated user can create a club.

**`club_members`**
Join table between `clubs` and `auth.users`. Each membership has a `role` (owner, admin, or member) and a `joined_at` timestamp. Unique constraint on `(club_id, user_id)` prevents double-joining.

**`challenges`**
A time-limited fitness challenge. Has a type (`distance`, `count`, or `time`), a `target_value`, a start and end timestamp, and a `status` (upcoming, active, completed, cancelled). Optionally linked to a specific club.

**`challenge_participants`**
Join table between `challenges` and `auth.users`. Records when a user joined a specific challenge.

---

#### Group 4 — System (Gray)

**`idempotency_keys`**
Prevents duplicate operations if a network request is retried. The Flutter client generates a UUID key before making a mutating API call. If the call succeeds, the key and response are stored here with an expiry. If the same key is submitted again before expiry, the stored response is returned immediately without re-executing the operation. This protects against double-starting or double-completing a workout on poor network connections.

---

#### Database Functions

**`current_user_dashboard()`**
Returns a single row with `total_distance_m` and `workouts_count` for the currently authenticated user (`auth.uid()`). Called on app startup and after each workout completes to populate the Home tab's progress cards.

**`leaderboard_distance(period text)`**
Returns a ranked list of users with their total distance, average pace, and active days for the past 7 days (weekly) or 30 days (monthly). Called by the Leaderboard screen with the selected filter.

---

#### Row Level Security Summary

Every table has RLS enabled. The policies are:

| Table | Read | Write |
|-------|------|-------|
| `profiles` | Any authenticated user | Own row only |
| `private_user_data` | Own row only | Own row only |
| `workouts` | Own rows only | Own rows only |
| `workout_events` | Own workouts only | Own workouts only |
| `workout_samples` | Own workouts only | Own workouts only |
| `clubs` | Any authenticated user | Creator can insert |
| `club_members` | Any authenticated user | Own memberships only |
| `challenges` | Any authenticated user | Creator can insert |
| `challenge_participants` | Any authenticated user | Own participations only |
| `idempotency_keys` | Own keys only | Own keys only |

---

### Slide 9 — Tech Stack

#### Languages

**Dart** is the only programming language used in the Flutter application. It is a strongly typed, AOT-compiled language developed by Google. The AOT compilation to native ARM code is what gives Flutter apps their near-native performance on both Android and iOS.

#### Frameworks

**Flutter (SDK ^3.10.7)** is Google's UI toolkit for building natively compiled applications for mobile (Android, iOS), desktop (macOS, Windows, Linux), and web from a single codebase. In StrideSense it is used exclusively for mobile.

Flutter's widget system is fully reactive — every UI element is a widget, and rebuilding a widget is cheap because Flutter uses a virtual DOM-like reconciliation mechanism (the element tree and render tree). State changes in `SessionController` call `notifyListeners()`, which triggers `SessionScope` to rebuild its subtree, which causes only the affected widgets to re-render.

#### Backend

**Supabase** is an open-source Firebase alternative built on top of PostgreSQL. It provides:
- **Authentication**: JWT-based auth with email/password, OAuth providers, magic links. Handles token issuance, rotation, and invalidation.
- **PostgREST**: An auto-generated REST API layer over the PostgreSQL schema. Any table with RLS enabled is instantly accessible via HTTP with typed query parameters.
- **Storage**: S3-compatible object storage with bucket-level and path-level access policies.
- **Database functions**: Custom SQL functions callable as RPC endpoints via `supabase.rpc('function_name', params: {...})`.

#### Package-by-Package Explanation

| Package | Version | Detailed explanation |
|---------|---------|---------------------|
| `supabase_flutter` | ^2.8.0 | The official Supabase client for Flutter. Wraps the Supabase REST API, Auth API, and Storage API into typed Dart methods. Manages the Supabase session internally and exposes `Supabase.instance.client` as a global access point. |
| `geolocator` | ^11.1.0 | Provides a `Stream<Position>` of location updates. Abstracts platform differences between Android's `FusedLocationProviderClient` and iOS's `CLLocationManager`. Handles permission request flow natively. |
| `flutter_map` | ^6.1.0 | A Leaflet.js-inspired map widget for Flutter. Renders tile layers (OpenStreetMap), polyline layers, and marker layers. Used on the workout log screen to show the recorded route. |
| `latlong2` | ^0.9.1 | Provides the `LatLng` data class used by `flutter_map` for coordinate representation. |
| `image_picker` | ^1.1.2 | Bridges Flutter to the device camera and photo gallery via platform channel calls. Returns an `XFile` which can be read as bytes for upload. |
| `flutter_secure_storage` | ^9.2.2 | Reads and writes key-value pairs using the platform's hardware-backed keystore. Android: uses the Android Keystore API. iOS: uses the iOS Keychain. |
| `shared_preferences` | ^2.3.2 | Reads and writes key-value pairs to the platform's standard preference storage. Android: XML files in the app's data directory. iOS: NSUserDefaults. Not hardware-secured — used only for non-sensitive cached data. |
| `dio` | ^5.7.0 | A powerful HTTP client for Dart. Used in StrideSense primarily for its exception model (`DioException`) which allows the app to distinguish network errors, timeout errors, and HTTP status code errors programmatically. |
| `uuid` | ^4.5.1 | Generates version 4 (random) UUIDs. Used in `BackendApiClient.uploadAvatar` to generate a unique filename (`{user_id}/{uuid}.jpg`) for each avatar upload, preventing overwrite collisions. |

---

### Slide 10 — Deployment

#### Supabase Backend Deployment

The backend is deployed by applying the SQL migration file to a Supabase project. The migration file at `supabase/migrations/20260404_initial_schema.sql` is idempotent — it uses `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, and `DROP POLICY IF EXISTS ... CREATE POLICY` patterns so it can be applied multiple times safely.

The migration creates:
1. All ten tables with correct types, constraints, and indexes
2. The `set_updated_at()` trigger function and triggers on `profiles`, `private_user_data`, and `workouts`
3. The `handle_auth_user_created()` and `handle_auth_user_updated()` trigger functions and the corresponding triggers on `auth.users`
4. The `current_user_dashboard()` and `leaderboard_distance(period)` RPC functions
5. RLS policies on all tables
6. The `avatars` storage bucket with public read and per-user write policies

#### Flutter App Build

The Flutter app requires two environment variables at build time:
- `SUPABASE_URL`: the base URL of the Supabase project (e.g. `https://xxxx.supabase.co`)
- `SUPABASE_ANON_KEY`: the project's anonymous public key

These are injected via Dart's `--dart-define` mechanism:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

At runtime, `main.dart` reads these with `const String.fromEnvironment('SUPABASE_URL')` and fails fast if they are missing. This means the credentials are compiled into the binary at build time and never exist in source code.

**Android APK build**:
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```
Produces `build/app/outputs/flutter-apk/app-release.apk` for sideloading or Play Store upload.

**iOS build**:
```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```
Produces an `.ipa` archive for TestFlight or App Store distribution via Xcode.

#### Android Permissions Declared

| Permission | Why it is needed |
|------------|-----------------|
| `ACCESS_FINE_LOCATION` | High-accuracy GPS for route tracking |
| `ACCESS_COARSE_LOCATION` | Fallback approximate location |
| `INTERNET` | Supabase API, map tile downloads |
| `READ_MEDIA_IMAGES` | Photo gallery access for avatar picker (API 33+) |
| `CAMERA` | In-app camera capture for avatar photo |

---

### Slide 11 — Operational Guide

#### Sign Up Flow

1. User launches the app and sees the Onboarding screen with the StrideSense logo and a welcome runner illustration.
2. User taps **Get Started** or **Create Account**.
3. The Sign Up form collects: email, password, first name, last name, phone.
4. On submission, `BackendApiClient.register()` calls `supabase.auth.signUp(email:, password:, data: {first_name, last_name, phone})`.
5. Supabase creates the `auth.users` row and fires the `on_auth_user_created` trigger, which automatically inserts rows into `profiles` and `private_user_data`.
6. `SessionController` is updated with the new auth state and the user is navigated to the main shell.

#### Login Flow

1. User enters email and password.
2. `BackendApiClient.login()` calls `supabase.auth.signInWithPassword(email:, password:)`.
3. On success, `AuthTokenStore` persists the session tokens under `auth_tokens_v1`.
4. `SessionController` fetches the profile from Supabase and updates `LocalProfileStore` and `LocalDashboardStore`.
5. The main shell is mounted with the Home tab selected.

On subsequent launches, `SessionController.bootstrap()` reads tokens from `AuthTokenStore`, restores the Supabase session, and loads cached profile and dashboard data from `SharedPreferences` instantly — so the Home tab is visible with content before any network call completes.

#### Workout Recording Flow

1. User opens the Record tab.
2. Taps **Start** — `SessionController.startWorkout()` calls `BackendApiClient.startWorkout()` which inserts a `workouts` row with `status = 'running'` and records the cloud workout ID.
3. `geolocator.getPositionStream()` begins emitting positions. Each position updates the live distance display and appends a point to the in-memory route list.
4. User taps **Pause** — `pauseWorkout()` calls the Supabase update and inserts a `workout_events` row with `event_type = 'pause'`.
5. User taps **Start** again — `resumeWorkout()` inserts a `resume` event.
6. User taps **Stop** — the Record tab shows the workout log screen.
7. User selects a category and optionally adds notes, then taps **Save Workout**.
8. `completeWorkout()` updates the `workouts` row with final distance, duration, pace, and calories, then calls `uploadWorkoutSamples()` to bulk-insert the GPS coordinate list into `workout_samples`.

If GPS was unavailable at step 3, the app substitutes a simulated route — a sequence of interpolated coordinates that produce a realistic-looking path — so the rest of the flow completes normally.

#### Profile Sync Flow

1. User opens Edit Profile or Personal Info and makes changes.
2. Changes are written to `LocalProfileStore` immediately so the UI reflects them instantly.
3. A sync operation is enqueued in `SyncQueueStore`.
4. `SyncWorker` fires on a timer (default: every 30 seconds).
5. For each queued operation, `BackendSyncApiClient` calls the corresponding Supabase `update` operation.
6. If the call succeeds, the operation is removed from the queue and the `dirty` flag is cleared.
7. If the call fails (no network), the operation remains in the queue and will be retried on the next timer tick.

---

## PART 2 — THE ENTIRE SYSTEM

---

### System Overview

StrideSense is a client-server application where the client is a Flutter mobile app and the server is Supabase (a hosted PostgreSQL + API platform). There is no custom server process that the team operates — all backend logic runs as SQL functions, triggers, and RLS policies inside the Supabase project.

```
┌─────────────────────────────────┐
│     Flutter Mobile App          │
│  (Dart, runs on Android / iOS)  │
│                                 │
│  Presentation Layer             │
│       ↕                         │
│  Navigation Layer               │
│       ↕                         │
│  Session & State Layer          │
│       ↕                         │
│  Data Access Layer              │
│   ┌──────────┐  ┌────────────┐  │
│   │Supabase  │  │Local Store │  │
│   │API Client│  │(device)    │  │
│   └────┬─────┘  └────────────┘  │
└────────┼────────────────────────┘
         │ HTTPS
         ▼
┌────────────────────────────────────────┐
│              Supabase                   │
│                                        │
│  ┌──────────┐  ┌────────────────────┐  │
│  │Auth API  │  │PostgREST (REST API) │  │
│  └──────────┘  └────────────────────┘  │
│  ┌──────────┐  ┌────────────────────┐  │
│  │Storage   │  │PostgreSQL Database  │  │
│  │(avatars) │  │(RLS + triggers +   │  │
│  └──────────┘  │ stored functions)  │  │
│               └────────────────────┘  │
└────────────────────────────────────────┘
```

---

### Data Flow — End to End

#### First Launch

```
App starts
  → main.dart reads SUPABASE_URL + SUPABASE_ANON_KEY from --dart-define
  → Supabase.initialize() called
  → SessionController.bootstrap() called
    → AuthTokenStore.read() — checks for stored tokens
    → If no tokens → show Onboarding screen
    → If tokens found → restore Supabase session
      → load profile from LocalProfileStore (instant, no network)
      → load dashboard from LocalDashboardStore (instant, no network)
      → navigate to main shell (Home tab)
      → background: fetch fresh profile + dashboard from Supabase
      → update local stores with fresh data
      → UI rebuilds with fresh data
```

#### Subsequent App Opens (Authenticated)

The user sees the Home dashboard populated with cached data within milliseconds of app launch, even with no network. The background sync then overwrites the cache with fresh data from Supabase, and the UI rebuilds transparently.

#### Workout Recording

```
Start tap
  → BackendApiClient.startWorkout()
    → supabase.from('workouts').insert({user_id, started_at, status:'running'})
    → returns cloud workout id
  → geolocator.getPositionStream() starts
  → Each GPS position →
    → update live distance display
    → append LatLng to in-memory route list

Stop tap
  → show workout log screen
  → user selects category + notes
  → Save tap:
    → BackendApiClient.completeWorkout()
      → update workouts row (distance, duration, pace, calories, status:'completed')
    → BackendApiClient.uploadWorkoutSamples()
      → bulk insert GPS points into workout_samples
    → SessionController refreshes dashboard summary
    → navigate back to Record tab
```

#### Community Data Flow

```
Community tab opens
  → BackendApiClient.getLeaderboard('weekly')
    → supabase.rpc('leaderboard_distance', params: {'period': 'weekly'})
    → returns ranked list of users with distance + active days
  → BackendApiClient.getChallenges()
    → supabase.from('challenges').select('*, challenge_participants(user_id)')
    → returns challenges with participant count and whether current user has joined
  → BackendApiClient.getClubs()
    → supabase.from('clubs').select('*, club_members(user_id)')
    → returns clubs with member count and join status
```

---

### Security Model

**Authentication**: Supabase Auth issues short-lived JWT access tokens (default 1 hour) and long-lived refresh tokens. The Flutter app stores both in the device's hardware-backed secure storage. The Supabase SDK automatically refreshes the access token using the refresh token before expiry.

**Authorisation**: Row Level Security enforces that every database operation is scoped to the authenticated user. The `auth.uid()` function in RLS policies returns the UUID of the currently authenticated user from the JWT. This means that even if a bug in the app tried to read another user's workouts, the Supabase database would return zero rows.

**Data isolation**: `profiles` is readable by any authenticated user (to support leaderboards and club member lists). `private_user_data` is readable only by the owning user. `workouts`, `workout_events`, and `workout_samples` are readable only by the owning user — training data is entirely private.

**Storage security**: The `avatars` bucket is publicly readable (so avatar URLs can be embedded in `img` tags without authentication). Write access is restricted to paths that begin with the authenticated user's UUID (`{auth.uid()}/filename`), preventing users from overwriting each other's avatars.

---

### Offline Resilience Architecture

StrideSense uses a *local-first* approach: every read operation loads from the local cache first and updates from Supabase in the background. Every write operation updates the local cache immediately and enqueues a background sync to Supabase.

This means:
- The app always feels fast — no loading spinners for data the user has already seen.
- The app always works — if there is no network, the user can still see their profile, their dashboard, and their workout history.
- Data consistency is eventual, not immediate — there is a window between a profile edit and its appearance in the Supabase database. This is acceptable for non-critical data like profile bios and display names.

The one exception is workout recording — if the network is available, the workout is started and completed in Supabase in real time so the leaderboard and challenge tracking are accurate. If the network is not available when a workout is saved, the local record exists but the Supabase write fails silently (this is a known limitation in the current implementation).

---

### Repository Structure

```
StrideSense/
├── lib/
│   ├── main.dart                          # App entry point, Supabase init
│   ├── navigation/
│   │   ├── app_routes.dart                # Route name constants
│   │   └── app_core.dart                  # MaterialApp, onGenerateRoute, auth guard
│   ├── session/
│   │   └── session.dart                   # SessionController, BackendApiClient,
│   │                                      # local stores, sync worker
│   ├── features/
│   │   ├── auth/
│   │   │   └── auth_screens.dart          # Onboarding, SignUp, Login, PasswordReset
│   │   ├── shell/
│   │   │   └── main_shell.dart            # BottomNavigationBar, IndexedStack
│   │   ├── tabs/
│   │   │   ├── home_tab.dart              # Home dashboard + Record tab
│   │   │   ├── community_tab.dart         # Leaderboard, Challenges, Clubs
│   │   │   ├── challenges_tab.dart        # Challenge list
│   │   │   └── profile_tab.dart           # Profile stats + settings
│   │   └── details/
│   │       └── detail_screens.dart        # WorkoutSummary, ChallengeDetail,
│   │                                      # ClubDetail, Leaderboard, EditProfile,
│   │                                      # PersonalInfo
│   └── widgets/
│       └── shared.dart                    # Reusable widgets, form validators
├── assets/
│   └── images/
│       └── welcome_runner.png             # App icon source + onboarding illustration
├── supabase/
│   └── migrations/
│       └── 20260404_initial_schema.sql    # Full Postgres schema, RLS, triggers
├── public/                                # PHP backend entry point
├── src/                                   # PHP backend controllers
├── migrations/                            # MySQL migration files (PHP backend)
└── docs/
    ├── stridesense-app-documentation.md   # Technical reference
    ├── supabase-migration.md              # Supabase migration guide
    ├── figma.jpeg                          # Wireframe screenshot
    ├── StrideSense_Presentation.pptx      # Slide deck
    ├── presentation-script.md             # This script
    └── system-explanation.md              # This document
```

---

*Document generated from StrideSense source — branch: shadrack*
