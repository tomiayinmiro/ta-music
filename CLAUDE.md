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

## Decisions made during Phase 1 (not in the original brief)

- **Riverpod/Freezed pinned to 2.x, not latest**: `audiotags` caps `freezed_annotation` below `3.0.0`, and this Dart SDK's `analyzer` requirements made the newest Riverpod/Freezed line incompatible with it. Exact pinned versions are commented in `pubspec.yaml`. Don't bump these to "latest" without re-checking this conflict.
- **`json_serializable` dropped entirely** (no version bridges its `source_gen` requirement with the analyzer version this SDK needs). JSON for the lyrics.ovh/LibreTranslate responses will be hand-written `fromJson`/`toJson`, not generated.
- **Fonts are self-hosted, not `google_fonts`**: Sora and Hanken Grotesk are bundled as variable-weight TTFs under `assets/fonts/` (downloaded once from Google's open-source font repo), declared in `pubspec.yaml`, weights selected via `TextStyle.fontVariations`. Keeps the app fully offline from first launch, consistent with the offline-first brief — no runtime font fetching.
- **Android `compileSdk` forced to 37 for all subprojects** (root `android/build.gradle.kts`, via `afterEvaluate`): `permission_handler_android` needs 37, and `audiotags` 1.4.5 bundles its own Android module hardcoded to `compileSdk 31`, which fails AAR metadata checks against newer transitive androidx deps. Forcing it at the root avoids patching the third-party plugin.
- **Windows build needs a one-time manual step after a fresh `flutter pub get`**: run `tool/fix_audiotags_windows.ps1`. `audiotags` extracts a bundled DLL archive into its own source directory during CMake configure, but Flutter builds Windows plugins through a symlink, and that extraction fails through a symlink (a libarchive safeguard). The script pre-extracts it directly in the real pub-cache path once, which the plugin's own build script then detects and skips re-extracting. This lives outside the repo (global pub cache), so it doesn't survive a `flutter pub cache repair` or a different machine's first setup — rerun the script if the Windows build ever fails with "Cannot extract through symlink" again.
- **`_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` defined globally in `windows/CMakeLists.txt`**: `audio_service_win` and `permission_handler_windows` use `<experimental/coroutine>`, which this MSVC toolchain (VS 2026) escalated from a deprecation warning to a hard error.

## Decisions made during Phase 3 (not in the original brief)

- **`audio_session` and `rxdart` added as explicit dependencies**: both were already transitive (via `just_audio`/`audio_service`), but `AudioPlayerHandler` calls their APIs directly (`AudioSession.instance` for interruption/becoming-noisy handling; `Rx.combineLatestN` to build `PlaybackSnapshot`), so they're declared directly rather than relying on another package's transitive pin.
- **App settings persisted in a new sqflite `settings` key-value table** (migration v3), not `shared_preferences`. Approved 2026-08-18 — keeps storage entirely on sqflite rather than adding a second persistence mechanism, and gives Phase 7's full Settings screen a home to grow into. Currently holds one key: whether to resume playback after an audio-focus interruption ends (default off).
- **`PlaybackHandler` interface extracted** (`lib/data/services/playback/playback_handler.dart`): `PlaybackService` depends on this interface, not the concrete `AudioPlayerHandler`, so widget tests can construct it with a lightweight fake instead of the real handler — the real one talks to `audio_session`/`just_audio` platform channels immediately in its constructor, which aren't available in `flutter_test`'s host-VM environment. See `test/fakes/fake_playback_handler.dart`.
- **Play-count/history rule**: a play is recorded once per listen, at whichever comes first of the 50%-played mark or the track naturally finishing. If counted at 50% and the same listen later actually finishes, the existing `play_history` row is flipped to `completed: true` rather than inserting a second row (`PlayHistoryDao.markCompleted`). A large backward position jump (manual rewind, or a repeat-one loop restarting) starts fresh tracking for that item.
- **Song context menu substitutes two mockup actions**: `designs/song_context_menu/` includes "Share Aura" (the gamification system CLAUDE.md excludes outright) and "Download Lossless" (not applicable — files are already local). Both are replaced with the actual 8 actions this brief lists. "Add to Playlist" is present but stubbed with a snackbar — the real bottom sheet is Phase 4 scope per `DESIGN_MAP.md`.
- **"Song info" is a minimal undesigned dialog** (plain metadata: title/artist/album/genre/year/duration/format/bitrate/sample rate/file size/play count/path), approved 2026-08-18 rather than waiting for Phase 5's Liner Notes panel, which may later replace or absorb it.
- **Known pre-existing issue (not introduced by Phase 3, not fixed)**: `test/widget_test.dart`'s `pumpAndSettle()` never converges — confirmed present before Phase 3 by stashing these changes and re-running. Something in the widget tree schedules frames indefinitely; root cause not yet identified. Worked around with a bounded `pump()` loop so the test suite runs; worth investigating separately.
- **Any screen reached via `Navigator.push` must use `AppScaffold` (`lib/shared/widgets/app_scaffold.dart`), not a bare `Scaffold`.** `AppShell` (the bottom-nav-tab root) renders the mini player as a sibling of its `IndexedStack`, which only covers the 3 tab screens living inside it — anything pushed as a new route sits on the same root `Navigator` and gets its own full-screen `Scaffold`, covering the mini player regardless of which screen it was pushed from. Album detail, Artist detail, Settings, and Recently Added all silently lost the mini player this way before `AppScaffold` existed; a guard test (`test/features/library/mini_player_presence_test.dart`) now checks Album/Artist detail specifically, but any new pushed screen still needs to opt in by construction. The one deliberate exception is `NowPlayingScreen`, which keeps a bare `Scaffold` — it's the expanded player and shouldn't show a mini player of its own.
- **Don't trust `just_audio`'s own internal, native-fed derived state (`AudioPlayer.hasNext`/`hasPrevious`/`shuffleIndices`) — compute from state the app already owns synchronously instead.** Hit the same underlying mistake in three different corners of the same problem across this phase: `_player.hasPrevious` went stale on Windows (a `just_audio_windows` event-channel threading bug), then `_player.shuffleIndices` went stale whenever shuffle was left on (fed via `sequenceStateStream`, not updated synchronously by `ShuffleOrder.insert()`, so it could keep holding a previous, differently-sized queue's indices indefinitely). The fix that stuck: `AudioPlayerHandler` now keeps its own `NextAwareShuffleOrder` instance (`_activeShuffleOrder`, mutated in plain synchronous Dart) and never reads `_player`'s own derived sequence/shuffle state for this. The algorithm itself is pulled out as a pure function, `relativeQueueIndex` (`lib/data/services/playback/relative_queue_index.dart`), unit-tested directly against plain values (`test/data/services/playback/relative_queue_index_test.dart`) instead of needing a real `AudioPlayer` to exercise. Separately: a button whose gating condition doesn't match what its action can actually do is its own bug — the Previous button was disabled outright whenever `hasPrevious` was false, even though `skipToPrevious()` always has a "restart the current track" fallback that needs no previous track to exist at all. It's unconditionally enabled now whenever a song is loaded.
- **Tap-to-play was never actually duplicated across list screens** — Singles, Album detail, Artist detail, Favorites, and Recently Added all already called the one shared `PlaybackService.playFromSong` → `AudioPlayerHandler.playFromSong`, confirmed by writing regression tests against each (`test/features/library/song_tap_regression_test.dart`) before touching any fix code, and watching them pass against the *existing* code. If a "tap plays the wrong song" bug recurs, look downstream of that shared method (the native platform plugin, as it turned out twice) before assuming the queue-construction logic itself needs fixing again.

## Decisions made during Phase 4 (not in the original brief)

- **Favorites' 0-play exclusion wins over a manual add** — confirmed 2026-08-20. A song favorited manually with 0 plays stays hidden from the Favorites list until it's actually been played once; this was already how `FavoriteDao.getAllSortedByPlayCount()` worked since Phase 2, just not yet explicitly signed off. Not revisited.
- **Playlist creation's song picker replaces the `playlist_creation_mini_player` mockup's curated "Suggested Tracks" bento grid with a real searchable list of the library** — approved 2026-08-20. The mockup's grid assumes a recommendation engine, which is Phase 6 scope; the name/description entry step and glass-panel visual language are kept, everything downstream of it is a plain `SongListTile`-style list with an add toggle.
- **Mini player gained a favorite-toggle heart** alongside Now Playing and the context menu — approved 2026-08-20, placed left of the transport controls (before Previous), `VisualDensity.compact` like the other three icon buttons there.
- **`AlphabetFastScroller` (`lib/shared/widgets/alphabet_fast_scroller.dart`) is presentation- and gesture-only — it does no scrolling itself.** It has no idea whether the caller is a `ListView` or a `GridView`, fixed or variable row height, so `onLetterSelected` is the caller's own scroll-offset math. Retrofitted onto Singles, Favorites, Recently Added, and Playlist detail (`itemExtent`-based `ListView`s, exact jump math) and onto the Albums/Artists grids (`GridView` with `SliverGridDelegateWithMaxCrossAxisExtent`, jump math replicated from the delegate's own `getLayout` — see `_gridRowMetrics` in `library_gallery_screen.dart` — correct crossAxisCount, approximate beyond that since row heights aren't otherwise measured). Playlist detail and Favorites jump into a variable-height header block using an eyeballed fixed offset, so those two land near — not pixel-exact at — the target letter.
- **A drag-reorder handle must be its own tappable region, never wrap a whole row that also has `onLongPress`.** `PlaylistDetailScreen` first tried `ReorderableDelayedDragStartListener` around the entire row (matching the row's existing tap-to-play / long-press-for-context-menu), which puts a delayed-long-press recognizer in the same gesture arena as `onLongPress` — whichever wins starves the other. Fixed the same way `QueueScreen` already did it: a dedicated trailing `Icons.drag_handle_rounded` icon wrapped in `ReorderableDragStartListener`, row's own tap/long-press left alone.
- **Playlist reorder (`PlaylistDao.reorderSongs`) takes an already-adjusted `newIndex`**, matching `SliverReorderableList.onReorderItem` (not the deprecated `onReorder`) and the existing `AudioPlayerHandler.reorderQueue` convention — no manual off-by-one correction in the caller.
- **The add-to-playlist bottom sheet (`shared/widgets/add_to_playlist_sheet.dart`) is shared between the song context menu (single song, full add/remove toggle diffed against current membership) and the library gallery's bulk-select bar (multiple songs, add-only — there's no single well-defined "already in" state to diff against a mixed selection).** Wired up the gallery's previously-stubbed "Add to Playlist" bulk action to it at the same time, since it was the same underlying gap.
- **Home's quick-access row grew a third tile (Playlists)** and switched from an icon-beside-label `Row` layout to icon-above-label `Column` per tile — three equal-width columns made the existing `Row` layout (no `maxLines`/`overflow` on the label) prone to wrapping "Recently Added" as the tightest label. All three tiles' visuals changed together for consistency, not just the new one.
- **No automated tests added for the new playlist DAO/repository logic or screens** — the existing suite (regression tests, `database_test.dart`, `relative_queue_index_test.dart`) still passes untouched, but reorder/add/remove-membership logic and the new screens are so far only verified by `flutter analyze` (clean) and that existing suite — not yet exercised on a real device. Worth adding guard tests if this area sees more churn.

## Feature roadmap
- **v1 (build now, phases 1–7):** the shipping product. Complete offline music player with everything listed in "Core capabilities" above.
  - Phase 1 (foundation), Phase 2 (library scanner/browsing), and Phase 3 (playback engine + background service) are **complete** as of 2026-08-19, verified on both Android (Tecno BF6) and Windows.
  - **Phase 4 (Playlists) is built, not yet device-tested** as of 2026-08-20 — Favorites (upgraded from its Phase 2 stub), Recently Added (extended), Playlists list, Playlist detail, the playlist creation flow, and the add-to-playlist bottom sheet are all in place per `DESIGN_MAP.md`, plus the reusable `AlphabetFastScroller` and the context menu's "Go to Favorites" entry from the same pass. Mark complete once verified on Android + Windows, matching how Phases 1–3 closed out.
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
