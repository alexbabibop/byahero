# ByaHero 🚀 — Ikaw ang bida sa byahe mo.

Pinoy-centric Smart Commute Analytics, Anti-Tamper Delay Verification, at Community Traffic App.

## Features (MVP)
- **Smart Route & Journey Tracker** — Start / Pause (Meeting/Errand) / Resume / End, Vehicle Selector (Lakad/Jeep/Bus/Private/Nakapila/Paused) with color-coded routes, Idle auto-detect (speed < 1km/h for 3min + reverse geocode), Geofenced destination auto-detect (100m radius).
- **Anti-Daya Security** — Fake GPS / Mock Location blocker, Live-only Camera (no gallery), Watermark (GPS + timestamp + weather stub + device hash), EXIF/SHA256 hash validation.
- **PDF Delay Report** — One-click A4 PDF: name/employee/company, map summary, time breakdown, watermarked photo, signature + hash.
- **Community Feed** — Traffic posts, upvote/downvote, live-stream placeholder.
- **Low-end optimized** — Target Android 8.0 / 2GB RAM, Lite tiles flag when RAM < 400MB, adaptive GPS polling (10m moving / 30-50m idle), SQLite offline cache + auto-sync.
- **Telemetry & Bug Reports** — Device brand/model, OS/API, RAM/storage, battery auto-attached.

## Tech
Flutter + Dart + Firebase (Auth/Firestore/Storage) + Google Maps + Geolocator + PDF Engine.

## Quick start
Buong Tagalog tutorial: tingnan ang `SETUP_GUIDE_TAGALOG.md`.

```bash
flutter pub get
flutter run
flutter build apk --release
```

APK via cloud (no local install needed): push sa GitHub → Actions tab → `Build APK` → download artifact `byahero-apk`.

## Firebase structure
- `users/{uid}` — profile + company/employeeId
- `journeys/{journeyId}` — route points, time breakdown, hash
- `posts/{postId}` — community feed + votes
- `bug_reports/{id}` — telemetry + stacktrace group hash

Rules: tingnan `firestore.rules` at `storage.rules`.

## Author
**alexbabibop** — jamiestun@gmail.com
