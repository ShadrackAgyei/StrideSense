
# labapp

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
=======
# StrideSense PHP Backend (Phase 1)

This is a lightweight PHP + MySQL API scaffold for moving the app from mock state to real end-to-end behavior.

## Implemented endpoints

- `GET /v1/health`
- `POST /v1/auth/register`
- `POST /v1/auth/login`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `GET /v1/me`
- `PATCH /v1/me/profile`
- `GET /v1/clubs`
- `POST /v1/clubs`
- `GET /v1/clubs/{clubId}`
- `POST /v1/clubs/{clubId}/join`
- `GET /v1/challenges`
- `POST /v1/challenges/{challengeId}/join`
- `GET /v1/leaderboard`
- `POST /v1/workouts/start`
- `POST /v1/workouts/{workoutId}/pause`
- `POST /v1/workouts/{workoutId}/resume`
- `POST /v1/workouts/{workoutId}/complete`
- `POST /v1/workouts/{workoutId}/samples`
- `GET /v1/workouts/history`
- `GET /v1/workouts/{workoutId}`

## Setup

1. Copy env template:
```bash
cp backend/.env.example backend/.env
```
2. Export env vars (or load via your server config):
```bash
set -a
source backend/.env
set +a
```
3. Create database and run migration:
```bash
mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" "$DB_NAME" < backend/migrations/001_phase1_init.sql
```
4. Run local server:
```bash
php -S localhost:8080 -t backend/public
```

## Notes

- Tokens are opaque random strings hashed in DB.
- Access tokens are short-lived (default 15 min).
- Refresh tokens rotate on refresh.
- Workout lifecycle routes are now included for Phase 2 handoff with mobile tracking.

