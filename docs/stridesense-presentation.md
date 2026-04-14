# StrideSense — Project Presentation

---

## Slide 1: Title

**StrideSense**
A GPS-powered running and fitness tracking mobile application

> Built with Flutter · Powered by Supabase · Deployed on Android & iOS

---

## Slide 2: The Case Study — The Story Behind StrideSense

Running is one of the most accessible forms of exercise, yet most runners in Ghana and similar markets face a fragmented experience: no affordable wearable, no unified platform to track progress, join clubs, or compete with peers in a structured way.

The story begins with a simple observation: **people run alone, improve slowly, and stay unmotivated because they have no feedback loop and no community.**

StrideSense was conceived as the answer to that problem — a mobile-first fitness companion designed specifically for everyday runners who want to:

- **Track their runs** with live GPS and real metrics (distance, pace, duration)
- **See their progress** through dashboards and personal history
- **Compete and connect** through leaderboards, clubs, and challenges
- **Stay consistent** through gamified targets and a social feed

The case study target was a university student athlete community — members who run regularly but lack structured tools, coaching data, or peer accountability. The app needed to work on affordable Android devices with intermittent internet, support group training clubs, and surface competitive leaderboards to drive motivation.

---

## Slide 3: Requirements Derived from the Case Study

### Functional Requirements

| # | Requirement |
|---|-------------|
| FR-01 | Users must be able to register and log in with email and password |
| FR-02 | Users must be able to record a run with live GPS distance and timer |
| FR-03 | The app must fall back to a simulated route when GPS is unavailable |
| FR-04 | Users must be able to view their full workout history |
| FR-05 | Users must be able to view and edit their profile and personal information |
| FR-06 | Users must be able to upload a profile avatar |
| FR-07 | Users must be able to browse and join running clubs |
| FR-08 | Users must be able to view, join, and track fitness challenges |
| FR-09 | A leaderboard must rank users by weekly or monthly distance |
| FR-10 | Users must be able to log out securely |

### Non-Functional Requirements

| # | Requirement |
|---|-------------|
| NFR-01 | App must work offline with local-first caching and background sync |
| NFR-02 | Auth tokens must be stored securely (encrypted local storage) |
| NFR-03 | UI must respond in under 300ms for local operations |
| NFR-04 | Location data must only be accessed with explicit user permission |
| NFR-05 | All database access must be protected by Row Level Security (RLS) |
| NFR-06 | App must support Android (API 21+) and iOS (14+) |
| NFR-07 | Avatar uploads must be namespaced per user to prevent overwrite collisions |

---

## Slide 4: Local Resources Used

### Application Source Files

| Resource | Path | Role |
|----------|------|------|
| App entry point | `lib/main.dart` | Bootstrap, Supabase init, root widget composition |
| Navigation & routing | `lib/navigation/app_core.dart`, `app_routes.dart` | Route constants, auth-guarded navigation |
| Session & state layer | `lib/session/session.dart` | SessionController, BackendApiClient, local stores, sync worker |
| Shared widgets | `lib/widgets/shared.dart` | Reusable UI components and form validators |
| Auth screens | `lib/features/auth/auth_screens.dart` | Onboarding, signup, login, password reset |
| Shell & main tabs | `lib/features/shell/`, `lib/features/tabs/` | Bottom nav shell, Home, Record, Community, Profile tabs |
| Detail screens | `lib/features/details/detail_screens.dart` | Workout summary, challenge detail, club detail, leaderboard, profile settings |
| App icon source | `assets/images/welcome_runner.png` | Launcher icon and onboarding illustration |

### Local Persistence Keys

| Store Class | Key | Contents |
|-------------|-----|----------|
| `AuthTokenStore` | `auth_tokens_v1` | Encrypted access + refresh tokens |
| `LocalDashboardStore` | `dashboard_summary_v1` | Cached total distance and workout count |
| `LocalProfileStore` | `profile_data_v1` | Cached user profile (name, bio, avatar URL) |
| `SyncQueueStore` | `sync_queue_v1` | Pending profile edits awaiting upload |

### Environment Variables (injected at build time)

| Variable | Purpose |
|----------|---------|
| `SUPABASE_URL` | Points the Flutter client to the Supabase project |
| `SUPABASE_ANON_KEY` | Grants public anonymous/authenticated access |

### Database Schema File

`supabase/migrations/20260404_initial_schema.sql` — full Postgres schema, triggers, RLS policies, and storage bucket setup.

---

## Slide 5: UI/Figma — Initial Wireframe Process

> **[Insert figma.jpeg here — file at `docs/figma.jpeg`]**

The wireframe process covered four primary connection points:

```
┌─────────────────────────────────────────────────────────────┐
│  ONBOARDING                                                  │
│  Welcome screen → Login / Sign Up → Dashboard               │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────▼────────────────┐
         │        MAIN SHELL (Bottom Nav) │
         │  Home | Record | Community | Profile │
         └───────┬────────────────────────┘
                 │
    ┌────────────┼──────────────┬──────────────┐
    ▼            ▼              ▼              ▼
  HOME        RECORD        COMMUNITY      PROFILE
  ─────       ─────         ─────────      ─────────
  Dashboard   GPS tracking  Leaderboard    Stats
  Progress    Timer/Pause   Challenges     Edit Profile
  History     Route map     Clubs          Personal Info
```

**Key wireframe decisions:**
- Bottom navigation for immediate access to all four core areas
- Card-based layouts for workout history and leaderboard entries
- Map preview embedded in the workout log screen
- Edit Profile separated from Personal Info to isolate public vs private data

---

## Slide 6: Key Modules, Layers, and Team Assignments

### Five-Layer Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Layer 1: Presentation                                    │
│  Flutter widgets, screens, and Material 3 theme           │
├──────────────────────────────────────────────────────────┤
│  Layer 2: Navigation                                      │
│  Route constants, typed arguments, auth guard             │
├──────────────────────────────────────────────────────────┤
│  Layer 3: Session & State                                 │
│  SessionController (ChangeNotifier), SessionScope         │
├──────────────────────────────────────────────────────────┤
│  Layer 4: Data Access                                     │
│  BackendApiClient, LocalStores, SyncWorker                │
├──────────────────────────────────────────────────────────┤
│  Layer 5: Backend / Data                                  │
│  Supabase (Auth + Postgres + Storage) · PHP/MySQL scaffold│
└──────────────────────────────────────────────────────────┘
```

### Module Assignments

| Module | Files | Assigned Member |
|--------|-------|-----------------|
| Authentication & Onboarding | `lib/features/auth/auth_screens.dart` | _[Member Name]_ |
| Home Dashboard | `lib/features/tabs/home_tab.dart` | _[Member Name]_ |
| Workout Recording (GPS + Timer) | `lib/features/tabs/` (Record tab) | _[Member Name]_ |
| Community (Leaderboard, Challenges, Clubs) | `lib/features/tabs/community_tab.dart`, `lib/features/details/` | _[Member Name]_ |
| Profile & Settings | `lib/features/tabs/profile_tab.dart`, `lib/features/details/` | _[Member Name]_ |
| Session / State / Data Layer | `lib/session/session.dart` | _[Member Name]_ |
| Navigation & Routing | `lib/navigation/` | _[Member Name]_ |
| Database Schema & Backend (PHP + Supabase) | `supabase/migrations/`, `src/`, `public/` | _[Member Name]_ |
| UI Components / Shared Widgets | `lib/widgets/shared.dart` | _[Member Name]_ |

> _Fill in team member names per your Activity One assignment log._

---

## Slide 7: Entity Relationship Diagram

```
┌──────────────┐         ┌─────────────────────┐
│  auth.users  │────┬───▶│     profiles         │
│  (Supabase)  │    │    │ ─────────────────── │
│  id (uuid)   │    │    │ id (uuid) PK → FK   │
│  email       │    │    │ username             │
│  password    │    │    │ first_name           │
└──────────────┘    │    │ last_name            │
                    │    │ bio, avatar_url       │
                    │    │ city, privacy_level  │
                    │    └─────────────────────┘
                    │
                    │    ┌─────────────────────┐
                    ├───▶│  private_user_data   │
                    │    │ ─────────────────── │
                    │    │ user_id (uuid) PK FK│
                    │    │ email, phone         │
                    │    └─────────────────────┘
                    │
                    │    ┌─────────────────────┐
                    ├───▶│      workouts        │
                    │    │ ─────────────────── │
                    │    │ id (bigint) PK       │
                    │    │ user_id (uuid) FK    │
                    │    │ challenge_id FK      │
                    │    │ activity_type        │
                    │    │ status               │
                    │    │ started_at, ended_at │
                    │    │ distance_m           │
                    │    │ duration_sec         │
                    │    │ avg_pace_sec_per_km  │
                    │    │ calories_kcal        │
                    │    └────────┬────────────┘
                    │             │
                    │    ┌────────▼────────────┐
                    │    │   workout_events     │
                    │    │ id, workout_id FK    │
                    │    │ event_type           │
                    │    │ event_at             │
                    │    └─────────────────────┘
                    │             │
                    │    ┌────────▼────────────┐
                    │    │   workout_samples    │
                    │    │ id, workout_id FK    │
                    │    │ lat, lng, altitude   │
                    │    │ distance_m, pace     │
                    │    │ heart_rate, steps    │
                    │    │ calories_kcal        │
                    │    └─────────────────────┘
                    │
                    │    ┌─────────────────────┐
                    ├───▶│       clubs          │
                    │    │ id (bigint) PK       │
                    │    │ name, description    │
                    │    │ created_by (uuid) FK │
                    │    └────────┬────────────┘
                    │             │
                    │    ┌────────▼────────────┐
                    │    │    club_members      │
                    │    │ id, club_id FK       │
                    │    │ user_id (uuid) FK    │
                    │    │ role (owner/admin/   │
                    │    │        member)       │
                    │    └─────────────────────┘
                    │
                    │    ┌─────────────────────┐
                    ├───▶│     challenges       │
                    │    │ id (bigint) PK       │
                    │    │ club_id FK (opt)     │
                    │    │ title, description   │
                    │    │ type (distance/count/│
                    │    │        time)         │
                    │    │ target_value         │
                    │    │ start_at, end_at     │
                    │    │ status               │
                    │    │ created_by FK        │
                    │    └────────┬────────────┘
                    │             │
                    │    ┌────────▼────────────┐
                    │    │challenge_participants│
                    │    │ id, challenge_id FK  │
                    │    │ user_id (uuid) FK    │
                    │    │ joined_at            │
                    │    └─────────────────────┘
                    │
                    └───▶┌─────────────────────┐
                         │  idempotency_keys    │
                         │ id, key_value        │
                         │ user_id FK           │
                         │ endpoint             │
                         │ response_code/body   │
                         │ expires_at           │
                         └─────────────────────┘
```

**Database Functions:**
- `current_user_dashboard()` — returns total distance and workout count for the logged-in user
- `leaderboard_distance(period)` — ranks all users by distance for weekly or monthly window

**RLS Policies Summary:**
- Profiles: readable by all authenticated users; editable only by owner
- Private user data: accessible only by the owning user
- Workouts / events / samples: owned and visible only by the recording user
- Clubs & challenges: readable by all authenticated; creatable by authenticated users

---

## Slide 8: Tools, Libraries, Frameworks, APIs, Languages & Database

### Programming Languages

| Language | Where Used |
|----------|-----------|
| **Dart** | Flutter mobile app — all UI, state, and data logic |
| **SQL (PostgreSQL)** | Supabase database schema, triggers, RLS policies, stored functions |
| **PHP** | Alternate REST API backend scaffold (`src/`, `public/`) |

### Framework

| Framework | Version | Role |
|-----------|---------|------|
| **Flutter** | SDK ^3.10.7 | Cross-platform mobile UI framework (Android + iOS) |
| **Material 3** | (via Flutter) | Design system — navy theme `#0D1A63`, rounded cards, typography |

### Flutter Packages (Dependencies)

| Package | Version | Purpose |
|---------|---------|---------|
| `supabase_flutter` | ^2.8.0 | Auth, Postgres CRUD, RPC calls, file storage |
| `geolocator` | ^11.1.0 | Live GPS stream, distance calculation, permission checks |
| `flutter_map` | ^6.1.0 | Interactive route map rendering in workout log screen |
| `latlong2` | ^0.9.1 | Coordinate data structures for `flutter_map` |
| `image_picker` | ^1.1.2 | Camera and gallery access for profile avatar upload |
| `shared_preferences` | ^2.3.2 | Lightweight local cache (dashboard, profile, sync queue) |
| `flutter_secure_storage` | ^9.2.2 | Encrypted token storage |
| `uuid` | ^4.5.1 | Unique file path generation for avatar uploads |
| `dio` | ^5.7.0 | HTTP error type handling and offline fallback logic |
| `cupertino_icons` | ^1.0.8 | iOS-style icon support |
| `flutter_launcher_icons` | ^0.14.3 | Launcher icon generation from `welcome_runner.png` |

### Backend / Database

| Component | Technology | Role |
|-----------|-----------|------|
| **Database** | PostgreSQL (via Supabase) | Primary relational data store |
| **Auth** | Supabase Auth (JWT) | User registration, login, session management, token refresh |
| **File Storage** | Supabase Storage (`avatars` bucket) | Profile avatar file hosting |
| **RPC Functions** | PostgreSQL stored functions | `current_user_dashboard()`, `leaderboard_distance()` |
| **Row Level Security** | PostgreSQL RLS | Per-user data isolation and access control |
| **Alt Backend** | PHP + MySQL | REST API scaffold (not active in production mobile flow) |

### APIs

| API | Type | Usage |
|-----|------|-------|
| Supabase Auth API | REST / SDK | Sign up, login, logout, session |
| Supabase PostgREST API | REST / SDK | All CRUD operations on app tables |
| Supabase Storage API | REST / SDK | Avatar image upload and URL generation |
| Device Location API | Platform (geolocator) | GPS coordinates stream while recording |
| Device Camera / Gallery | Platform (image_picker) | Avatar photo selection |

---

## Slide 9: Deployment

### Build & Run

The app is deployed as a native mobile APK (Android) and IPA (iOS) built via Flutter.

```bash
# Run in development (with Supabase config injected)
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY

# Build release APK
flutter build apk \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY

# Build iOS
flutter build ios \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

### Supabase Backend Setup

1. Create a Supabase project at supabase.com
2. Apply the schema:
   `supabase/migrations/20260404_initial_schema.sql`
3. Enable the `avatars` storage bucket (created by the migration script)
4. Copy the project URL and anon key into your build command

### Deployment Targets

| Target | Method | Notes |
|--------|--------|-------|
| Android | APK sideload or Play Store | `flutter build apk --release` |
| iOS | TestFlight or App Store | `flutter build ios --release` |
| macOS (dev) | Desktop runner | `flutter run -d macos` |
| Supabase backend | Hosted (Supabase cloud) | No self-hosting required |

### Android Permissions Required

Declared in `AndroidManifest.xml`:
- `ACCESS_FINE_LOCATION` — live GPS during workout recording
- `ACCESS_COARSE_LOCATION` — fallback approximate location
- `INTERNET` — Supabase API and storage calls
- `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE` — image picker for avatar upload
- `CAMERA` — in-app photo capture

---

## Slide 10: Operational Guide

### First-Time Setup

1. Ensure Flutter SDK is installed (`flutter --version`)
2. Create a Supabase project and apply the migration SQL
3. Run the app with Supabase credentials injected via `--dart-define`

### User Flows

**Sign Up**
1. Launch app → tap **Get Started** or **Create Account**
2. Enter email, password, first name, last name, phone
3. App registers via Supabase Auth → profile row created automatically
4. User lands on Home dashboard

**Log In**
1. Enter email and password
2. Session stored securely; profile and dashboard data loaded from cache then synced

**Record a Workout**
1. Open **Record** tab → tap **Start**
2. Grant location permission when prompted
3. Live distance and duration update in real time
4. Tap **Pause** to pause, **Start** again to resume, **Stop** to finish
5. Choose category and add optional notes on the log screen
6. Tap **Save Workout** — saved locally and synced to Supabase
7. _(If GPS unavailable: app auto-switches to simulated route so the flow still completes)_

**View Progress**
- **Home** → total distance, weekly pace, recent workouts
- **Profile** → personal stats, weekly distance bar chart
- Tap any workout entry for route map + summary

**Community**
- **Leaderboard** → weekly/monthly rankings by distance
- **Challenges** → browse active challenges, tap to join
- **Clubs** → browse clubs, join or create a club

**Edit Profile / Personal Info**
1. Open **Profile** → **Edit Profile** (display name, bio, city)
2. **Personal Info** for private fields (email, phone)
3. **Change Photo** → camera or gallery → uploads to Supabase Storage
4. Changes saved locally first, then background-synced

**Log Out**
- Tap logout icon on Home, or **Settings → Log Out**

### Offline Behaviour
- Dashboard and profile load from local cache when offline
- Profile edits are queued and synced automatically when connectivity returns
- Auth session persists via secure local token storage

---

_Document generated from project source: StrideSense · Branch: shadrack_
