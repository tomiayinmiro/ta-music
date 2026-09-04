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
- Aura: a local listening-minutes leveling system (8 tiers, own stats page, level-up transition) — LOCAL ONLY, no accounts, no social sharing (Phase 4.5, see roadmap)

## Explicit non-goals for v1 and v1.5
- No user accounts or authentication anywhere
- No backend server, no cloud storage, no cloud sync of anything except device-to-device local sync
- No streaming services — playback is always local. Do NOT integrate any online music sources (no yt-dlp, no Spotify, no YouTube, no SoundCloud). The app is intended for public release, so anything with legal/licensing exposure is off the table.
- No social features (no activity feeds, no shared playlists, no listener presence, no sharing to external social networks from within the app)
- No achievement badges, ranks/leaderboards, or social sharing of progress. **Exception (reopened 2026-08-21): the Aura local-stats leveling system is in scope for Phase 4.5** — a listening-minutes-based level track (8 tiers) with its own stats page and level-up transition, sourced ONLY from `designs/aura/`. The old `designs/aura_*` folders (`aura_profile_stats`, `interactive_aura_profile`, `aura_levels_stats`, `refined_aura_progression_tiered_view`, `aura_achievements_gallery`, `aura_level_up_transition`, `universe_aura_reveal`, `supernova_milestone_reached`, `aura_discovery_feed`) are DISCARDED — do not reference them, see `DESIGN_MAP.md`.
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
- Translation: MyMemory free public API, called directly over the app's shared `dio` client (no signup; an email param raises the daily quota from 5,000 to 50,000 characters) — see Phase 5 batch 2 decisions below for why this isn't LibreTranslate or the `mymemory_translate` pub.dev package
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
- **Aura gamification reopened for Phase 4.5** (approved 2026-08-21) — previously a v2-deferred non-goal (see original "Explicit non-goals" wording, now updated above); now scoped narrowly to the local listening-minutes leveling system (main stats page + 8 level tiers + level-up transition) sourced from `designs/aura/`. Achievements/badges, ranks/leaderboards, and social sharing remain out of scope — this is a stats/leveling feature only. See `DESIGN_MAP.md`'s "Aura gamification (Phase 4.5)" table for the screen list and the discarded `aura_*` folders it supersedes.

## Decisions made during Phase 5 batch 1 (not in the original brief)

- **Lyrics fetch reworked to a 3-layer fallback chain mid-batch** (approved 2026-08-23) — batch 1 originally shipped with lyrics.ovh as the sole source; device testing showed it had essentially no coverage for Afrobeats/Nigerian music, the primary listening genre. Now: **LRCLIB** (`/api/get`, falling back to `/api/search` on a 404) primary — MIT-licensed, no API key, wide Afrobeats/international coverage, and returns real `[mm:ss.xx]` synced timing — then lyrics.ovh, then a local `.lrc` sidecar file next to the audio file. A layer's network error doesn't stop the chain (the next layer still runs); only if every layer that could have answered errors out does the lookup report a retryable fetch error instead of caching a false "not found". See `LyricsRepository`.
- **Local `.lrc` sidecar reads are best-effort on Android, reliable on Windows** — the app deliberately doesn't request `MANAGE_EXTERNAL_STORAGE` (see `AndroidManifest.xml`, avoids extra Play Store scrutiny), and `READ_MEDIA_AUDIO` doesn't cover a plain-text file that isn't part of any MediaStore collection. `LocalLrcFileReader` catches the resulting permission error on scoped-storage Android and treats it as a miss rather than surfacing it — this layer is a Windows-first power-user fallback in practice, not a guaranteed-everywhere feature.
- **Background lyrics prefetch hooks into `AudioPlayerHandler._onIndexChanged`** (the event that updates the lockscreen `mediaItem`), **not** the 50%-played `recordPlay` call — the spec's "hook into the same event that already triggers play_history" was factually off; `_onIndexChanged` is what actually fires the instant a new track loads. Debounced (~1.5s, real `Timer`) so rapid skipping only fetches the song the user settles on, with an in-flight fetch cancelled via `CancelToken` the moment the song changes again. Fires on any network connection, not Wi-Fi-only (approved 2026-08-23) — LRCLIB responses are small text and this is already low-priority background work. See `LyricsPrefetchService`.
- **An in-memory (not persisted) 1-hour "don't retry" gate lives in `LyricsPrefetchService`, separate from the DB cache's TTL** — keyed per (artist, title), it stops the automatic background path from re-hitting the network on every replay of a song within one listening session, including for transient network errors (which `LyricsRepository` deliberately never caches — see its doc — so a manual Retry tap from the lyrics panel always bypasses this and tries again immediately; the gate applies only to the automatic prefetch path). Resets on app restart by design.
- **`lyrics_cache` gained `source`/`has_synced_timing`/`synced_lyrics_lrc`/`plain_lyrics` columns (migration v8), wiping existing rows** rather than migrating them in place (approved 2026-08-23) — batch 1 only ever shipped to the developer's own devices, and the existing cache was entirely poisoned lyrics.ovh "not found" nulls from the coverage bug above, not data worth preserving.
- **Now Playing's lyrics view shows a small "Synced"/"Estimated" badge** (top-right of the lyrics area) so it's clear when a song is using LRCLIB/local-`.lrc` real per-line timestamps versus the original equal-time-slot approximation, which still drifts on longer or unevenly-paced songs. See `currentSyncedLyricLineIndex` in `lyrics_line_sync.dart`.
- **A temporary "Lyrics cache" debug screen lives under Settings → Diagnostics**, not a hidden gesture (approved 2026-08-23) — shows total cache rows, a breakdown by source, confirmed-miss count, and the oldest entry. Marked with a `TODO(Phase 5 batch 1)` for removal before release, same as the diagnostic logging threaded through the fetch chain and prefetch path.

## Decisions made during Phase 5 batch 2 (not in the original brief)

- **Translation talks to MyMemory directly over the shared `dio` client, not the `mymemory_translate` pub.dev package** originally pre-approved for this batch — approved 2026-09-02. That package's own documented language table is missing Yoruba and Igbo despite the live MyMemory API supporting both fine via plain ISO 639-1 codes (confirmed directly), and it bundles its own `http` client as a second HTTP stack alongside `dio`, the only one used everywhere else in the app. `TranslationClient` (`lib/data/services/translation/translation_client.dart`) is a thin wrapper mirroring `LrclibClient`'s existing pattern.
- **`translations_cache` (migration v12, `is_same_language` column added in v13)** is keyed on `(source_text, target_lang)`, not per-song — indefinite TTL, since a translation never goes stale. A repeated line (a chorus, or the same line across two songs) only needs translating once per target language.
- **The lyrics-panel translate toggle lives in a session-scoped Riverpod provider (`translationEnabledProvider`), not local widget `State`** the way `now_playing_screen.dart`'s `_showLyrics` toggle does. Found via testing: `LyricsPanel` tears down and rebuilds its lyrics widget subtree from scratch whenever a newly-selected song's lyrics aren't already resolved (its `FutureProvider.family` starts at `AsyncLoading`) — which is true on essentially every real song change — so local `State` would silently reset back to "off" on almost every skip. A provider survives that teardown; `test/features/now_playing/lyrics_panel_translation_test.dart` guards this specifically.
- **The detected-source-language badge is shown in the Now Playing lyrics panel itself** (next to the Synced/Estimated badge), not in Settings as originally spec'd — Settings has no other live/dynamic-playback-state readouts, so a badge reflecting whatever song is actually open fits the lyrics panel better architecturally.
- **A line already in the target language is detected by comparing MyMemory's returned text against the source line (normalized: trimmed, lowercased), never by trusting MyMemory's `autodetect` source-language guess** — confirmed unreliable for short lines, slang, or code-switched lyrics (it misclassified some of Asake's English lyrics, on a Yoruba/English mixed track, as Igbo). `TranslationClient` also recognizes MyMemory's literal `"PLEASE SELECT TWO DISTINCT LANGUAGES"` error (returned when source and target resolve to the same language) and echoes the source text back instead of letting that raw string render in the lyrics panel as if it were a real translation — both paths converge on the same source/target equality check in `TranslationRepository`, so there's one code path for "nothing to translate" rather than two. A same-language line always still displays (highlights, syncs, everything) — just without a translation row underneath it, exactly like any other line.
- **The translation-language picker's list (`lib/data/services/translation/mymemory_languages.dart`) is a hand-curated ~110-language ISO 639-1 table**, not sourced from any package or a live MyMemory endpoint — MyMemory has no dedicated supported-languages endpoint. A handful of codes (Yoruba, Igbo among them) were verified directly against the live API rather than trusted from any single source's docs.
- **Settings → Lyrics gained a "Translation" section**: the language picker, cache stats by target language, "Clear translation cache", and a collapsed-by-default "About translation quality" disclaimer. The disclaimer's first draft claimed the manual lyrics editor could be used to fix a bad translation — it can't, it only edits original lyrics, there's no translation-entry feature (see the "Manual translation entry in lyrics editor" item in `BACKLOG.md`) — caught and corrected before this was marked verified.

## Decisions made during Phase 6 batch 1 (not in the original brief)

- **Skip detection needed a schema addition `play_history` couldn't support**: investigation found a skip (playing a song under 30s and under 50% of its duration before moving on) leaves zero trace in `play_history` — a row is only ever inserted at the 50%-or-completion mark (Phase 3's rule) — and `listening_segments`' wall-clock chunks don't map cleanly to one listen either (periodic 30s flushes + pause/resume can split a single listen across several rows). Approved 2026-09-02: two denormalized counters on `songs` instead — `skip_count` (lifetime) and `consecutive_skips` (streak since the last real play, reset in `SongDao.incrementPlayCount`) — read for free off the same row scan the recommendation scorer already does over every candidate, no extra query, no unbounded event-log table. The threshold check itself is a pure function, `isSkip()` (`lib/data/services/playback/skip_detection.dart`), reusing `_lastPosition`/`_trackedIndex` that `AudioPlayerHandler._onPosition`'s existing 50%-or-completion tracking already maintains.
- **Recommendation scoring is pure and DB-free** (`lib/data/services/recommendations/recommendation_service.dart`, mirroring `relative_queue_index.dart`'s pattern) — weights per the original spec (same artist 3.0 incl. feat/collab via the existing `feature_tag_parser.dart`, same album 2.5, same folder 2.0, co-occurrence 4.0, play-count similarity 0.5), with two approved-2026-09-02 refinements: the skip penalty only kicks in once a candidate has 5+ plays AND 3+ skips (not skipped enough yet isn't evidence of dislike), and the first 2 skips past that trigger are free (subtract 2.0 per skip beyond that). Hard exclusion at 3+ consecutive skips with no completion since.
- **Co-occurrence ("played within 30 min of a seed play") scales with the seed's own play count, not library size**: `PlayHistoryDao.coOccurringPlayCounts` runs one indexed `played_at`-range query per seed timestamp (deduped by `play_history.id` so overlapping windows don't double-count), rather than one query per candidate song — needed `idx_play_history_played_at` (migration v14), the existing song_id-only index didn't help range scans.
- **The Home "Similar to X" seed-selection gate is 2 distinct songs played, not 5** — lowered 2026-09-04 after a live investigation on a freshly-reset Android install: the seed-quality fallback chain (3+ plays in 24h → favorited → most-played in 7 days) already degrades gracefully for thin history on its own; a separate stricter gate in front of it was blocking that chain from ever running for a new/reset install, keeping the section invisible longer than the seed logic itself required. See `RecommendationRepository._kMinDistinctPlayedSongsForHome`.
- **`homeRecommendationSeedProvider`/`homeRecommendationsProvider` must be reactive `StreamProvider`s (via `watchQuery`), not one-shot `FutureProvider`s** — same underlying mistake as `albumByIdProvider` below, hit twice in the same batch. `AppShell`'s `IndexedStack` keeps the Home tab's widget subtree alive for the app's whole life, so a plain `FutureProvider` here resolves once and stays cached regardless of new `play_history` rows arriving afterward — reproduced live: two songs played after Home had already resolved a `null` seed never surfaced the section at all, because nothing re-ran the provider. Watches `{'play_history', 'songs', 'favorites', 'recommendation_seed_cache'}`.
- **Cover art investigation (2026-09-04) found two independent bugs, not one**: (1) most song-row call sites (Singles, Recently Added, Artist detail, Home's cards) simply never passed a resolved `coverArtPath` to `CoverArt` at all, always showing the placeholder — fixed by making `SongListTile` a `ConsumerWidget` that self-resolves from `song.albumId` via `albumByIdProvider` when no explicit override is given, rather than requiring every caller to remember to resolve it. (2) `albumByIdProvider` itself was a one-shot `FutureProvider.family` — fine for a session where an album's cover never changes after first load, but wrong the moment `covers/{id}.jpg` gets regenerated later (e.g. after a migration nulls `cover_art_path` to force a resize-bound regeneration): whichever widget read it first would cache the stale value for the rest of the session. Converted to `StreamProvider.family` via `watchQuery({'albums'}, ...)`.
- **A single song's cover-art write failure must not abort the whole library scan**: reproduced on Windows — `covers/{id}.jpg`'s write can transiently collide with the running app's own `CoverArt` widget holding a read handle on that exact file (Windows' file locking is stricter about concurrent access than the platforms this app mostly targets), surfacing as `PathAccessException`/"Access is denied". This was uncaught, propagating out of `_ensureCoverArt` to the scan's top-level `catch`, aborting the entire scan and leaving every other album's cover unresolved too. Fixed in `library_scanner.dart`: a per-song try/catch makes cover-art failures non-fatal (that song just goes without art for this pass, retried next scan), and the actual file write retries up to 3 times with a short delay first, so this specific kind of transient lock usually self-heals within one scan.
- **A migration that invalidates derived state (like nulling `cover_art_path` to force regeneration) doesn't repair itself** — nothing auto-triggers a rescan afterward; the user has to manually rescan once. Worth remembering for any future migration in the same shape (clearing a column so it gets recomputed "next scan").

## Feature roadmap
- **v1 (build now, phases 1–7):** the shipping product. Complete offline music player with everything listed in "Core capabilities" above.
  - Phase 1 (foundation), Phase 2 (library scanner/browsing), and Phase 3 (playback engine + background service) are **complete** as of 2026-08-19, verified on both Android (Tecno BF6) and Windows.
  - **Phase 4 (Playlists) is built, not yet device-tested** as of 2026-08-20 — Favorites (upgraded from its Phase 2 stub), Recently Added (extended), Playlists list, Playlist detail, the playlist creation flow, and the add-to-playlist bottom sheet are all in place per `DESIGN_MAP.md`, plus the reusable `AlphabetFastScroller` and the context menu's "Go to Favorites" entry from the same pass. Mark complete once verified on Android + Windows, matching how Phases 1–3 closed out.
- **Phase 4.5 (Aura gamification, reopened 2026-08-21, build after Phase 4):** local listening-minutes leveling system — main Aura stats page (profile, level card, stats card, local insights), 8 level tiers (Atmosphere through Supernova), and a level-up transition animation. Sourced entirely from `designs/aura/`; the old `aura_*` folders are discarded (see `DESIGN_MAP.md`). Local only — no accounts, no social sharing, no achievements/badges.
  - **Phase 5 batch 1 (lyrics fetch + display) complete** as of 2026-08-23, verified on both Android (Tecno BF6) and Windows — the 3-layer LRCLIB/lyrics.ovh/local-`.lrc` fallback chain, background prefetch on song start, real synced timing where available, and the Now Playing lyrics view are all in place per the decisions above.
  - **Phase 5 batch 2 (on-demand lyrics translation) complete** as of 2026-09-02, verified on both Android (Tecno BF6) and Windows — MyMemory-backed per-line translation with a per-line cache, the language picker and cache management in Settings → Lyrics, and graceful same-language handling (including the Asake "Gratitude" mixed-language repro) are all in place per the decisions above. **Phase 5 is now complete.**
  - **Phase 6 batch 1 (local recommendations) complete** as of 2026-09-05, verified on both Android (Tecno BF6) and Windows — Home's "Similar to X" section, the song context menu's "More like this" screen, skip-aware scoring (same artist/album/folder/co-occurrence/play-count-similarity signals), Settings → Recommendations, and the seed's 1-hour cache are all in place per the decisions above. Phase 6 batch 2 (Equalizer) is next.
- **v1.5 (build after v1 is stable in daily use, phases 8–9):** player skins (alternate now-playing variants, background shader gallery), mood-reactive player bar, visualizers gallery, hi-res audio export, haptic controls.
- **v2 (deferred, may never build):** social hub, backend + accounts. Do not touch v2 features unless I explicitly reopen that decision.

## How I want you to work with me
- Before any non-trivial change, tell me your plan in a few bullets and wait for me to confirm
- After implementing a feature, tell me exactly how to test it (what to tap, what I should see)
- If you hit an ambiguous decision (data model shape, UI variant, package choice), ask me — don't guess
- If you write code that assumes something not in this brief, flag it explicitly
- Prefer small, focused commits I can review and roll back if needed
- After each phase completes, update CLAUDE.md with anything I've decided that isn't in this brief yet
- Read DESIGN_MAP.md before any UI task, and use ONLY the folders listed there — ignore folders not in the map
