# TA MUSIC — Project Brief

This file is the source of truth for every future task on this project. Reference it before making architectural decisions. If a task conflicts with this brief, ask before changing direction.

## Project identity
- Working name: TA MUSIC
- Owner/user: solo developer (me), personal use to start, intended for public release later
- Target platforms: Android (my phone) and Windows (my laptop)
- Not building for iOS, macOS, Linux, or web at this stage

## What the app does
An offline-first personal music player with a distinctive, polished UI based on the Stitch designs in `designs/`. Playback is always local — the app doesn't touch online music sources.

Core capabilities:
- Play my personal music library offline (formats: MP3, FLAC, AAC, M4A, OGG, WAV)
- Full-screen "Now Playing" experience with on-screen lyrics
- Automatic translation of lyrics when the song is in a foreign language
- Favorites collection sorted by play count (most-played first), also manually addable — songs with 0 plays are excluded
- "Recently Added" collection showing anything added in the last 14 days
- User-created playlists (create, rename, delete, add/remove songs, reorder)
- Local recommendations based on my most-played songs
- Background playback with lockscreen and notification controls (Android), system media controls (Windows)
- Equalizer (5-band graphic EQ + presets, plus user-saved custom presets)
- Shuffle, repeat (off/one/all), play-next, add-to-queue with gesture support
- Standard settings: theme, folders to scan, folders to exclude, cache size, about screen
- Listening stats surfaced in the navigation drawer (top artists, hours listened, songs played — LOCAL ONLY, no accounts)

## Explicit non-goals for v1 and v1.5
- No user accounts or authentication anywhere
- No backend server, no cloud storage, no cloud sync of anything except device-to-device local sync
- No streaming services — playback is always local. Do NOT integrate any online music sources (no yt-dlp, no Spotify, no YouTube, no SoundCloud). The app is intended for public release, so anything with legal/licensing exposure is off the table.
- No social features (no activity feeds, no shared playlists, no listener presence, no sharing to external social networks from within the app)
- No gamification (no XP, no levels, no ranks, no achievements/badges, no "Aura" system). The `designs/aura_*` and `designs/*_milestone_*` folders contain designs for a gamification system that we are NOT building. Ignore them, or use their transition animations ONLY as generic tasteful screen transitions if I explicitly ask.
- Do NOT include voice recordings/memos from my phone. Detect and exclude by:
  (a) folder location (skip Android's `Recordings/`, `Voice Recorder/`, `Call Recordings/`, and any subfolder containing "recording" in the name)
  (b) file duration under 60 seconds AND no artist tag AND no album tag (heuristic for voice memos)
  (c) user-configurable "excluded folders" list they can add to

## Design source of truth
- **Canonical design system:** `designs/sonic_sanctuary_2/DESIGN.md`. Extract all design tokens (colors, typography, spacing, radius, elevation, motion) from this file into `lib/core/theme/` during Phase 1. Every widget references these tokens — zero hardcoded values elsewhere.
- **Screen designs:** live in per-screen subfolders under `designs/`. See `DESIGN_MAP.md` at the project root for which folder maps to which screen. Read that file before starting any UI task.
- **Behavior references:** live in `designs/references/`. Interaction patterns only — do not copy their visual style.

## Tech stack (chosen — don't propose alternatives without asking)
- Framework: Flutter (latest stable channel)
- Language: Dart, with strong typing everywhere, avoid `dynamic`
- State management: Riverpod (with code generation via `riverpod_generator`)
- Immutable models: `freezed` + `json_serializable`
- Database: `sqflite` (SQLite for Flutter) with `sqflite_common_ffi` for Windows
- Audio playback: `just_audio` (playback engine) + `audio_service` (background/lockscreen)
- Audio metadata: `audiotags` package (reads ID3, Vorbis comments, MP4 tags)
- File system access: `path_provider`, `file_picker`, `permission_handler`
- HTTP client: `dio`
- Lyrics: parse local `.lrc` files first, fall back to `lyrics.ovh` (free API)
- Translation: LibreTranslate self-hosted or free public instance (paid Google Translate optional later)
- Animation: `flutter_animate` for entry animations, tasteful transitions, and micro-interactions
- Local networking (for device-to-device sync): `shelf` + `multicast_dns`
- Logging: `logger` package
- Testing: `flutter_test` for widgets, `mocktail` for mocks

## Architecture principles
- Feature-first folder structure (not layer-first)
- Repository pattern: UI → Providers → Repositories → Data Sources (DB, files, network)
- No direct database or file access from widgets — always through providers
- Every model is immutable (`freezed`)
- All async operations return `AsyncValue` via Riverpod
- Errors surface as typed exceptions, never silent failures
- Every feature has its own folder with its own models, providers, screens, widgets
- Shared code lives in `core/` or `shared/`

## Target folder structure
```
lib/
  main.dart
  app.dart                     # App root widget, routing, theme
  core/
    constants/
    theme/                     # Design tokens extracted from sonic_sanctuary_2
      colors.dart
      typography.dart
      spacing.dart
      radius.dart
      elevation.dart
      motion.dart
      theme_data.dart          # Assembled ThemeData
    utils/
    errors/
  data/
    database/
      database.dart            # DB init, migrations
      daos/                    # song_dao.dart, playlist_dao.dart, etc.
    models/                    # freezed models
    repositories/
    services/
      library_scanner.dart
      audio_service.dart
      lyrics_service.dart
      translation_service.dart
      stats_service.dart       # local listening stats aggregation
  features/
    library/                   # Home, gallery views, artist/album detail
    now_playing/               # Full-screen player + mini-player + queue
    search/                    # Local library search
    favorites/
    playlists/
    recently_added/
    recommendations/
    settings/
    equalizer/
    stats/                     # Local listening stats surfaced in nav drawer
  shared/
    widgets/                   # Reusable UI (song tile, empty state, sheet, etc.)
    extensions/
assets/
  images/
  fonts/
designs/                       # Stitch designs — see DESIGN_MAP.md
test/
```

## Coding standards
- Format with `dart format` (line length 100)
- Lint with `flutter_lints` + `custom_lint` — zero warnings
- Every public API has a doc comment (`///`)
- Every complex function has a brief comment explaining WHY (not what)
- Widget files under 300 lines — split when they grow past that
- No `print()` — use the `logger` package
- No hardcoded strings in UI — put them in a constants file (I'll add i18n later)
- No hardcoded colors, sizes, or fonts in widgets — reference the tokens in `lib/core/theme/`

## Feature roadmap
- **v1 (build now, phases 1–7):** the shipping product. Complete offline music player with everything listed in "Core capabilities" above.
- **v1.5 (build after v1 is stable in daily use, phases 8–9):** player skins (alternate now-playing variants, background shader gallery), mood-reactive player bar, visualizers gallery, hi-res audio export, haptic controls.
- **v2 (deferred, may never build):** Aura gamification, social hub, backend + accounts. Do not touch v2 features unless I explicitly reopen that decision.

## How I want you to work with me
- Before any non-trivial change, tell me your plan in a few bullets and wait for me to confirm
- After implementing a feature, tell me exactly how to test it (what to tap, what I should see)
- If you hit an ambiguous decision (data model shape, UI variant, package choice), ask me — don't guess
- If you write code that assumes something not in this brief, flag it explicitly
- Prefer small, focused commits I can review and roll back if needed
- After each phase completes, update CLAUDE.md with anything I've decided that isn't in this brief yet
- Read DESIGN_MAP.md before any UI task, and use ONLY the folders listed there — ignore folders not in the map
