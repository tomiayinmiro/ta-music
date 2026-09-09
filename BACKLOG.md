# TA MUSIC — Future Features Backlog

## Purpose

Features and improvements discussed, agreed upon, but explicitly deferred to a later time. Not bugs — bugs are fixed in the moment. This is the "we'll do this later" list, so nothing gets lost across sessions.

Each item includes: what it is, why deferred, current workaround (if any), rough scope estimate.

## Deferred Features

### Per-song lyrics offset adjustment
- **What**: Allow user to shift the lyrics timeline for a specific song forward or backward in small increments (e.g., +/- 0.5s buttons) to compensate for LRCLIB timestamps that don't perfectly match the audio.
- **Why deferred**: Not critical — most synced lyrics are close enough. Feature is for power users who care about precise alignment.
- **Current workaround**: Users can manually add lyrics via the manual editor if the auto-fetched ones are unusable.
- **Scope**: Small. Add UI (+/- buttons in lyrics view), persist offset per-song in lyrics_cache table, apply offset when displaying timestamps. ~1 session.

### Word-level lyrics dimming
- **What**: Within the current line, individual words dim/highlight as the singer progresses through them (like Musixmatch reference image, Apple Music). Original design goal for Phase 5, deferred to line-level for v1.
- **Why deferred**: LRCLIB provides line-level timestamps only, not word-level. Estimating word timing from line duration is possible but approximate and adds complexity. v1 line-level is good enough.
- **Current workaround**: N/A — line-level highlight is functional.
- **Scope**: Medium. Requires per-word timing estimation, UI updates. ~2-3 sessions.

### Language i18n (internationalization)
- **What**: Full app translation to non-English languages. Add localization framework + at least one non-English language.
- **Why deferred**: UI still stabilizing through Phase 5-7. Translating a moving target wastes effort.
- **Current workaround**: N/A — English only for now.
- **Scope**: Medium. Framework setup + string extraction + one translation. Land in Phase 6 or 7 after UI stabilizes.

### RTL (right-to-left) language support in lyrics translation
- **What**: Detect when a translation target language uses RTL script (Arabic, Hebrew, Persian, Urdu, etc.) and wrap the translated Text widget in a Directionality widget with textDirection: TextDirection.rtl. Also set textAlign appropriately.
- **Why deferred**: Center-alignment currently masks most visible issues for RTL. Nigerian-focused v1 user base is very unlikely to translate to RTL languages. Polish work not blocking v1 release.
- **Current workaround**: RTL characters render correctly (BiDi algorithm handles character shaping); minor polish issues in punctuation placement and multi-line wrapping.
- **Scope**: Small. ~half session of work.

### Bundled font fallback for non-Latin scripts on Windows
- **What**: Bundle Noto Sans (or similar broad-coverage font) as a fallback for translations that use scripts not covered by system fonts. Especially matters for Sinhala, Khmer, Lao, Tibetan, Mongolian, and other less-common scripts on Windows installations without optional language packs.
- **Why deferred**: Most common script languages (CJK, Cyrillic, Arabic, Latin, Devanagari) work via system-font fallback on both Android and modern Windows. Only rare scripts on stripped-down Windows installs may show tofu boxes. Font bundling adds significant app size.
- **Current workaround**: Users select from ~110 languages; a small subset may not render on some Windows installs. No error, just visible tofu boxes.
- **Scope**: Medium. Font selection, licensing check, bundling, fallback configuration.

### Notification/lockscreen control customization
- **What**: Setting to hide specific media notification controls (e.g., "hide Previous button because I always tap it by accident"). Default (all controls shown) works for most users, but customization is a real power-user request.
- **Why deferred**: Basic controls already work via audio_service defaults. Customization is polish, not core.
- **Scope**: Small. ~half session.

### Custom themes / color schemes
- **What**: Beyond light/dark toggle, let users pick accent colors or fully custom themes. Also where the *real* Light theme palette itself belongs — the Settings-expansion pass (2026-09-08) shipped the Light/Dark/System default setting and its persistence, but `AppTheme.light` is currently a stub that resolves identically to `AppTheme.dark` (see `theme_data.dart`); designing an actual inverted sonic_sanctuary_2 light palette (lighter surfaces, darker text/accents, same visual language) is real UX work that belongs here, not guessed at inline.
- **Why deferred**: v1.5 territory. Base light/dark is enough for launch — and until the real light palette exists, Light and System-on-a-light-device both just look like Dark.
- **Scope**: Medium. Requires designing multiple theme variants + theme editor UI (plus, at minimum, the one real light palette above).

### Reset stats options  
- **What**: Setting buttons to reset play counts, listening history, Aura stats. Useful for users who want to "start fresh" or for testing.
- **Why deferred**: Backup/restore covers most of this use case (backup, then start fresh manually via reinstall). Explicit reset buttons are nice-to-have.
- **Scope**: Small. ~half session.

### Advanced audio settings
- **What**: Bit rate preferences, output device selection, sample rate control
- **Why deferred**: Most users won't touch these. Only relevant for audiophile use cases.
- **Scope**: Medium. Requires deeper audio pipeline configuration.

### Manual translation entry in lyrics editor
- **What**: Extend the manual lyrics editor so users can optionally enter their own translations for one or more target languages, per line or full-lyrics. Manual translations always override auto-translation for that line + target language.
- **Why deferred**: Auto-translation quality is generally acceptable for common use. Manual translation entry adds UI complexity (partial translations mixing with auto, showing origin of each translation, deletion/editing) that's not justified for v1 pain level. Most users tolerate imperfect translations more than they tolerate manually fixing them.
- **Current workaround**: Users just accept imperfect translations, or turn translation off if it's more distracting than helpful.
- **Scope**: Medium. New UI fields, storage schema addition, precedence logic (manual > auto). ~1-2 sessions.

### Gapless playback
- **What**: Zero-gap transitions between tracks for concept albums, live recordings, DJ mixes
- **Why deferred**: v1 implementation broke auto-advance functionality as a side effect. Rebuilding it properly requires careful separation of "auto-advance logic" (always on) from "gapless preload logic" (opt-in feature). Not worth the risk for v1.
- **Current workaround**: Songs play with the small natural gap Flutter's audio pipeline produces (~100-500ms). Acceptable for the vast majority of music.
- **Scope**: Medium. Requires refactoring audio pipeline so gapless is additive to auto-advance, not replacement of it.

## v1.5 Features (post-v1 release)

Surveyed in the Stitch designs but explicitly held for v1.5 release after v1 ships.

### Player skins
- Now Playing Fluid skin (`designs/now_playing_fluid/`)
- Now Playing Singularity skin (`designs/singularity_interface/`)
- User can pick between skins in Settings

### Visual effects layer
- 13 background shaders (`designs/shader_1/` through `shader_13/`)
- Universe Aura shader (`designs/universe_aura_shader/`)
- Mood-reactive mini player (`designs/mood_reactive_player_bar/`, `designs/player_bar_with_mood_toggles/`)
- Infinite visualizers gallery (`designs/infinite_visualizers_gallery/`)

### High-res audio export
- Format + sample rate + bit depth picker (`designs/high_res_audio_export/`)

### Interactive haptic controls
- Per-action haptic toggles + intensity (`designs/interactive_haptic_controls/`)

## Explicit v2 (or "may never build") items

Discussed and explicitly deferred beyond v1.5 — may never be built depending on where the project goes.

### Social layer
- Event horizon social hub (real-time presence)
- Social aura sharing (shareable aura cards)
- Omniscient feed (curator/community feed)
- Would require accounts + backend, which v1/v1.5 explicitly does not have.

## How to use this file

- **Adding a new deferred item**: give it its own subheading, describe in the same format, include "why deferred" so future-you understands the reasoning.
- **Building an item off this list**: remove it from BACKLOG.md in the same commit that ships the feature.
- **If an item stays here for a year without being touched**: consider whether it's actually going to happen or should be moved to a "won't do" section.
