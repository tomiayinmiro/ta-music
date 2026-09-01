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
