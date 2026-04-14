# StrideSense — 8-Minute Presentation Script

> **Total time: 8 minutes**
> Speaker notes are written to be spoken naturally. Each section has a target duration.
> Slide numbers refer to the PowerPoint deck: `StrideSense_Presentation.pptx`

---

## SLIDE 1 — Title  `[0:00 – 0:20]`  *(20 seconds)*

> *Advance to slide. Pause one beat. Then speak.*

"Good [morning / afternoon / evening], everyone.

Today we're presenting **StrideSense** — a GPS-powered fitness tracking mobile application we built using Flutter, backed by Supabase, and deployed on both Android and iOS.

Over the next eight minutes we'll walk you through why we built it, what it does, how we designed and built it, and how you'd actually use it.

Let's get into it."

---

## SLIDE 2 — Agenda  `[0:20 – 0:35]`  *(15 seconds)*

> *Quick orientation — don't read every item.*

"Here's our roadmap for today. We'll cover eight sections — starting with the case study that motivated the app, through requirements, design, the technical architecture, our database, the tech stack, deployment, and finally a walkthrough of how the app works.

Each section is tight, so let's move."

---

## SLIDE 3 — The Case Study  `[0:35 – 1:35]`  *(60 seconds)*

> *This is your story. Speak it naturally, like you're describing something you observed.*

"So — why did we build this?

Picture a group of university student athletes. They run regularly — early mornings, evenings, on weekends. But they have no way to measure how far they ran, how fast they were going, or how they compared to anyone else. They're training, but in the dark.

Affordable fitness trackers — things like Garmin or Apple Watch — were simply out of reach for most of them. And the generic apps available either lacked community features entirely, or weren't designed for the kind of group training culture these students actually had.

Without structure, without data, without anyone else to compete with — motivation dropped off. People would start a training routine and abandon it within weeks.

That was the gap. And from that gap, we identified four specific things the app needed to do:

First — **real-time GPS tracking**: distance, pace and route, recorded live during a run.

Second — a **progress dashboard**: so users could actually see their totals, their history, and how their week compared to the last.

Third — a **social and community layer**: leaderboards, clubs and time-limited challenges that give people something to train *toward*.

And fourth — it had to **work offline**. These users aren't always on a strong network. The app had to cache data locally so it never broke during a run.

StrideSense was designed specifically to meet all four of those needs."

---

## SLIDE 4 — Requirements  `[1:35 – 2:05]`  *(30 seconds)*

> *Don't read every bullet. Hit the key ones and move.*

"From that case study, we derived our requirements.

On the functional side, the seven core things the app had to do — user registration and login, live GPS tracking with a timer, a fallback to a simulated route when GPS is unavailable, workout history, profile editing with photo upload, clubs and challenges, and a leaderboard.

On the non-functional side — the app had to work offline first, store auth tokens encrypted on the device, respond in under 300 milliseconds for local operations, enforce location permission correctly, and apply Row Level Security to every database table so users can only access their own data.

These requirements drove every design and implementation decision we made."

---

## SLIDE 5 — Wireframes  `[2:05 – 2:35]`  *(30 seconds)*

> *Reference the image on screen. Keep it visual.*

"Before we wrote a single line of Flutter, we designed all ten screens in Figma.

You can see them here — starting from the Splash screen and Sign Up, through Login, the Home dashboard, the Record tab with its GPS controls, the Community section with leaderboards and challenges, the Profile view, Settings, and the Edit Profile and Personal Info screens.

The design process helped us settle on the key UX decisions early — a bottom navigation bar for instant access to all four core areas, card-based layouts throughout, and a dark navy brand with electric blue accents.

These wireframes were the direct blueprint for the Flutter implementation."

---

## SLIDE 6 — Physical Resources  `[2:35 – 3:10]`  *(35 seconds)*

> *Explain what hardware the app actually uses. Be specific — this is the 'physical resources' section.*

"The app relies on six physical and platform-level resources on the device.

**GPS** — the device's location sensor, accessed through the `geolocator` package, using `ACCESS_FINE_LOCATION` on Android. This is what powers the live distance and route tracking during a run.

**Camera and Photo Library** — used by `image_picker` with the `CAMERA` and `READ_MEDIA_IMAGES` permissions to let users capture or select their profile avatar.

**Network** — the device's WiFi or mobile data connection, used for all Supabase API calls and for loading OpenStreetMap tiles in the route map.

**Secure device storage** — the platform's Keystore on Android and Secure Enclave on iOS, accessed through `flutter_secure_storage`, to hold encrypted auth tokens.

**Local key-value storage** — SharedPreferences, used by the `shared_preferences` package to cache the dashboard, profile, and sync queue for offline use.

And **map tile rendering** — the GPU and screen, driven by `flutter_map`, to display the workout route preview."

---

## SLIDE 7 — Architecture & Module Assignments  `[3:10 – 4:10]`  *(60 seconds)*

> *Walk through the layer stack first, then the table.*

"The app is built on a five-layer architecture — and it's worth understanding each layer before we go into who built what.

At the bottom, **Layer 5** is the backend — Supabase, which gives us PostgreSQL, authentication, file storage, and database functions. This is what the app talks to.

**Layer 4** is the data access layer — this is where `BackendApiClient` lives, along with the local stores and the sync worker. It's the boundary between the app and the outside world.

**Layer 3** is session and state — a custom `SessionController` that extends Flutter's `ChangeNotifier` and a `SessionScope` inherited widget. This drives all UI rebuilds — auth state, profile data, dashboard content, workout lifecycle, everything.

**Layer 2** is navigation — route constants, typed route arguments, and auth-guarded routing that redirects unauthenticated users to login.

**Layer 1** at the top is the presentation layer — every Flutter widget and screen, built with Material 3 and our deep navy theme.

Now for the team —

**Shadrack Agyei Nti** was responsible for the entire Flutter application — authentication, home dashboard, workout recording, community screens, profile and settings, the session and state layer, navigation, and the Supabase database schema.

**Ismail** built the PHP backend — the REST API scaffold in `src/` and `public/`, which mirrors the domain model and provides an alternate backend path documented in the repository."

---

## SLIDE 8 — ERD  `[4:10 – 5:00]`  *(50 seconds)*

> *Walk through the diagram in groups — don't enumerate every field.*

"Here's our entity relationship diagram.

At the center is **`auth.users`** — Supabase's built-in auth table. Every other table in the system is connected to it.

From `auth.users` we get two user-facing tables — **`profiles`**, which holds public-facing information like name, username, bio and avatar URL, and **`private_user_data`**, which holds sensitive fields like email and phone number behind a stricter Row Level Security policy.

The **`workouts`** table records every run — activity type, status, distance in metres, duration in seconds, average pace, and calories. Each workout links to **`workout_events`** — start, pause, resume, complete — and to **`workout_samples`**, which stores the GPS coordinates, heart rate, and step data captured during the run.

On the social side, **`clubs`** connect to **`club_members`**, and **`challenges`** connect to **`challenge_participants`**. Challenges can optionally be tied to a specific club.

Finally, **`idempotency_keys`** prevents duplicate API operations if a request is retried.

Two database functions power key screens: `current_user_dashboard()` returns the logged-in user's total distance and workout count, and `leaderboard_distance(period)` returns ranked user stats for the weekly or monthly leaderboard."

---

## SLIDE 9 — Tech Stack  `[5:00 – 5:45]`  *(45 seconds)*

> *Group the technologies — don't read every card.*

"Our tech stack, grouped by layer.

The **language** is Dart. The **framework** is Flutter at SDK version 3.10.7.

The **backend** is entirely Supabase — PostgreSQL as the database, Supabase Auth for session management, Supabase Storage for avatars, and PostgREST for our API calls. We use the `supabase_flutter` package, version 2.8, as the Dart SDK for all of this.

For **device features** — `geolocator` for GPS, `flutter_map` and `latlong2` for the route map, and `image_picker` for the camera.

For **local persistence** — `flutter_secure_storage` for encrypted tokens and `shared_preferences` for the local cache.

And `dio` for HTTP error handling and `uuid` for generating unique file paths when uploading avatars.

That's the complete stack — no PHP or MySQL in the active mobile application."

---

## SLIDE 10 — Deployment  `[5:45 – 6:30]`  *(45 seconds)*

> *Walk through both columns — terminal left, targets right.*

"Deploying the app has two parts — the Supabase backend and the Flutter mobile build.

For Supabase: create a project, run the SQL migration file in `supabase/migrations/`, which sets up all ten tables, the RLS policies, the triggers, and the storage bucket automatically. Then copy the project URL and anonymous key.

For the Flutter app, you inject those credentials at compile time using `--dart-define` flags — so they're never hardcoded in source.

Running `flutter run` with those flags gives you the development build. `flutter build apk --release` gives you the Android APK for sideloading or Play Store distribution. `flutter build ios --release` targets TestFlight or the App Store.

The five Android permissions the app declares are: `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` for GPS, `INTERNET` for network access, `READ_MEDIA_IMAGES` for the photo picker, and `CAMERA` for the in-app photo capture."

---

## SLIDE 11 — Operational Guide  `[6:30 – 7:30]`  *(60 seconds)*

> *Walk through the six flows. Keep each one to two sentences.*

"Finally — how you actually use the app.

**Sign up** — tap Get Started, fill in your email, password, first name, last name and phone. Supabase creates your profile row automatically via a database trigger, and you land on the Home dashboard.

**Log in** — enter email and password. The session is stored securely on the device, and your profile and dashboard load from the local cache instantly while a background sync fetches fresh data.

**Record a workout** — open the Record tab, tap Start, and grant location permission. The GPS begins tracking distance and time live. Tap Pause to pause, Start again to resume, and Stop when you're done. You choose a category on the log screen and tap Save — the workout is stored locally and synced to Supabase.

**View progress** — the Home tab shows your total distance and weekly pace. The Profile tab shows a weekly distance bar chart. Tapping any workout in your history opens a route map and full summary.

**Community** — the Leaderboard ranks all users by weekly or monthly distance. The Challenges section lists active challenges you can browse and join with one tap. Clubs lets you browse or create running groups.

**Edit profile** — Edit Profile updates your public display information. Personal Info handles your private email and phone. Change Photo lets you take a new photo or pick one from your gallery. All changes are saved locally first and automatically synced to Supabase in the background."

---

## CLOSING  `[7:30 – 8:00]`  *(30 seconds)*

> *Bring it back to the case study. End with confidence.*

"So — StrideSense started from a real observation: student athletes running without data, without feedback, and without community.

We built an app that addresses all three — live GPS tracking, a personal progress dashboard, and a full social layer with leaderboards, clubs and challenges — all in one Flutter application backed by Supabase, with offline support built in from the ground up.

Thank you. We're happy to take any questions."

---

## TIMING SUMMARY

| Slide | Topic | Target Time | Cumulative |
|-------|-------|-------------|------------|
| 1 | Title | 0:20 | 0:20 |
| 2 | Agenda | 0:15 | 0:35 |
| 3 | Case Study | 1:00 | 1:35 |
| 4 | Requirements | 0:30 | 2:05 |
| 5 | Wireframes | 0:30 | 2:35 |
| 6 | Physical Resources | 0:35 | 3:10 |
| 7 | Architecture | 1:00 | 4:10 |
| 8 | ERD | 0:50 | 5:00 |
| 9 | Tech Stack | 0:45 | 5:45 |
| 10 | Deployment | 0:45 | 6:30 |
| 11 | User Guide | 1:00 | 7:30 |
| — | Closing | 0:30 | 8:00 |

---

## SPEAKER TIPS

- **Slides 3 and 7** are your longest — they carry the most content. Don't rush them.
- **Slide 8 (ERD)** is visually dense. Point to the groups on screen rather than reading field names.
- **Slide 9** — do not read every card. Group them and move.
- If you run ahead of time, expand slightly on the case study (Slide 3) or the architecture walk-through (Slide 7).
- If you're running behind, condense the requirements (Slide 4) to three points each and cut the closing to one sentence.
