# Design Map

This file tells Claude Code which design asset to use when building each screen or feature. Pre-filled based on your Stitch survey — verify the mappings, adjust if you notice anything wrong, and keep it up to date as your project evolves.

## How to read this file

- **Design folders** (in `designs/`) are the source of truth for visual design — colors, typography, layout, spacing, and motion. Match them faithfully. Each entry points to a folder (Stitch exports each screen as a self-contained folder containing HTML, CSS, and typically a PNG preview) — read whichever asset inside is most useful for the task.
- **Reference files** (in `designs/references/`) are behavior or interaction examples from other apps. Study the pattern shown in them, but do NOT copy their visual style — that must come from the design folders and the design system.
- **Design system:** `designs/sonic_sanctuary_2/DESIGN.md` is the canonical design system. All colors, typography, spacing, and motion tokens come from there. Extract them into `lib/core/theme/` during Phase 1.
- If a screen listed below has an empty "Design folder" cell, or isn't listed at all, ask the user before improvising the UI. Don't guess.

## Design system

| Component | Folder | Role |
|---|---|---|
| Canonical design system | `designs/sonic_sanctuary_2/` | Source of ALL design tokens. Extract into `lib/core/theme/` in Phase 1. |

## v1 screens (build in phases 1–7)

| Screen / feature | Design folder | Phase | Notes |
|---|---|---|---|
| Home / landing | `designs/lounge_home/` | 2 | Recently played, curated picks, quick access to sections |
| Library — gallery view | `designs/the_gallery_library/` | 2 | Main library browsing |
| Library — singles list | `designs/the_gallery_singles_list/` | 2 | Alternate list view within the gallery |
| Library — bulk select + sort | `designs/the_gallery_bulk_actions_sorting/` | 2 | Long-press to enter, checkboxes, bottom action bar |
| Navigation drawer — base | `designs/navigation_drawer_side_menu/` | 2 | Standard slide-out nav |
| Navigation drawer — expanded with stats | `designs/expanded_navigation_drawer_profile_stats/` | 2 | **Reinterpret as LOCAL listening stats only** (top artists, hours listened, songs played). No accounts, no XP, no Aura. |
| Now Playing (default / classic skin) | `designs/now_playing/` | 3 | Cover, controls, progress, favorite, more menu, lyrics area |
| Queue with gesture interactions | `designs/up_next_queue_gestures/` | 3 | Drag to reorder, swipe to remove, tap to jump |
| Song context menu | `designs/song_context_menu/` | 3 | Long-press / overflow menu — reusable everywhere a song appears |
| Add to playlist bottom sheet | `designs/add_to_playlist/` | 4 | Sheet with playlists + "New playlist" option |
| Playlist creation flow | `designs/playlist_creation_mini_player/` | 4 | Multi-step flow that keeps the mini player visible |
| Favorites, Recently Added, Playlists list, Playlist detail | *(not in Stitch folders — ASK BEFORE BUILDING)* | 4 | Build from sonic_sanctuary_2 tokens matching the visual language of the other screens |
| Liner notes panel | `designs/liner_notes/` | 5 | Extended track info: credits, lyrics context, album details |
| Equalizer | `designs/audio_engine_eq/` | 6 | 5-band graphic EQ + presets |
| Custom EQ presets management | `designs/custom_eq_presets/` | 6 | Save, rename, delete user presets |
| Recommendations "For You" | *(use `designs/nocturnal_frequency_feed/` as VISUAL reference only — content is local recommendations, not curators)* | 6 | Ask before building — confirm the visual pattern is a fit |
| Settings — root | *(not in Stitch folders — ASK BEFORE BUILDING)* | 7 | Standard settings screen with sections |
| Settings — audio customization sub-screen | `designs/navigation_drawer_audio_customization/` | 7 | Audio-related settings entry point |
| Loading / transition state | `designs/frequency_transition_flow/` | 7 | Minimal animated loading indicator, used app-wide |
| Onboarding / first-launch | *(not in Stitch folders — ASK BEFORE BUILDING)* | 7 | Folder picker + permissions + brief tour |
| Empty states | *(build from sonic_sanctuary_2 tokens)* | throughout | Empty library, empty playlist, no lyrics found, no search results |

## v1.5 screens and assets (build in phases 8–9, AFTER v1 ships)

| Screen / feature | Design folder | Phase | Notes |
|---|---|---|---|
| Now Playing — Fluid skin | `designs/now_playing_fluid/` | 8 | Alternate player skin with organic animated background |
| Now Playing — Singularity skin | `designs/singularity_interface/` | 8 | Alternate player skin with WebGL cosmic background |
| Mood-reactive mini player | `designs/mood_reactive_player_bar/` | 8 | Mini player tints based on track mood |
| Mini player with mood toggles | `designs/player_bar_with_mood_toggles/` | 8 | Same mini player with explicit mood controls |
| Background shader — 1 through 13 | `designs/shader_1/` … `designs/shader_13/` | 8 | Selectable animated backgrounds for compatible skins |
| Background shader — Universe | `designs/universe_aura_shader/` | 8 | Additional shader option for the gallery |
| Visualizers gallery | `designs/infinite_visualizers_gallery/` | 9 | Selectable audio-reactive overlays for the Now Playing screen |
| Hi-res audio export | `designs/high_res_audio_export/` | 9 | Format + sample rate + bit depth picker |
| Haptic controls tuning | `designs/interactive_haptic_controls/` | 9 | Per-action haptic toggles + intensity |

## Behavior references

Live in `designs/references/`. Interaction pattern only — do NOT copy visual style.

| Reference | File | Applies to | What to copy |
|---|---|---|---|
| Musixmatch-style lyrics with translation | `designs/references/lyrics-reference.jpg` | Phase 5 — lyrics display on Now Playing | Current line in prominent bold; upcoming words within that line dimmed/faded (word-level progress); translation directly below in a distinct accent color from sonic_sanctuary_2, slightly smaller weight; small "文A" translation toggle button in bottom-left; auto-scroll keeps current line centered. **Visual style comes from `designs/now_playing/`, NOT from this reference.** |

## Explicitly out of scope

The following folders exist in `designs/` but are NOT to be used. They correspond to the Aura gamification system and social features, which are deferred to a possible v2. If Claude Code encounters these while browsing the folder, it should skip them entirely.

Aura gamification (out): `aura_profile_stats`, `interactive_aura_profile`, `aura_levels_stats`, `refined_aura_progression_tiered_view`, `aura_achievements_gallery`, `aura_level_up_transition`, `universe_aura_reveal`, `supernova_milestone_reached`, `aura_discovery_feed`

Social (out): `event_horizon_social_hub`, `social_aura_sharing`, `omniscient_feed`

Aura transition frames (available as generic transitions ONLY if user asks): `aura_transition_electric_1/2/3`, `aura_transition_nocturnal_1/2`, `aura_transition_tranquil_1/2`. If reused, do NOT frame them to the user as "aura" or "mood" transitions — just tasteful screen transitions.

## When adding new designs

1. Drop the folder into `designs/` (or a reference file into `designs/references/`).
2. Add or update the relevant row in the tables above.
3. If the design introduces a new color, typography variant, or spacing value, either fit it to existing tokens in sonic_sanctuary_2 or ask the user before adding a new token.
