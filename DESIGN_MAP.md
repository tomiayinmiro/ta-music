# Design Map

This file tells Claude Code which design asset to use when building each screen or feature. Pre-filled based on your Stitch survey — verify the mappings, adjust if you notice anything wrong, and keep it up to date as your project evolves.

## How to read this file

* **Design folders** (in `designs/`) are the source of truth for visual design — colors, typography, layout, spacing, and motion. Match them faithfully. Each entry points to a folder (Stitch exports each screen as a self-contained folder containing HTML, CSS, and typically a PNG preview) — read whichever asset inside is most useful for the task.
* **Reference files** (in `designs/references/`) are behavior or interaction examples from other apps. Study the pattern shown in them, but do NOT copy their visual style — that must come from the design folders and the design system.
* **Design system:** `designs/sonic\_sanctuary\_2/DESIGN.md` is the canonical design system. All colors, typography, spacing, and motion tokens come from there. Extract them into `lib/core/theme/` during Phase 1.
* If a screen listed below has an empty "Design folder" cell, or isn't listed at all, ask the user before improvising the UI. Don't guess.
* **Aura gamification specifically:** `designs/aura/` is the ONLY source of truth. Any reference to the old `aura\_*` folders (e.g. `aura\_profile\_stats`, `aura\_levels\_stats`) elsewhere in this file or the codebase is stale — those designs are discarded, see "Explicitly out of scope" below.

## Design system

|Component|Folder|Role|
|-|-|-|
|Canonical design system|`designs/sonic\_sanctuary\_2/`|Source of ALL design tokens. Extract into `lib/core/theme/` in Phase 1.|

## v1 screens (build in phases 1–7)

|Screen / feature|Design folder|Phase|Notes|
|-|-|-|-|
|Home / landing|`designs/lounge\_home/`|2|Recently played, curated picks, quick access to sections|
|Library — gallery view|`designs/the\_gallery\_library/`|2|Main library browsing|
|Library — singles list|`designs/the\_gallery\_singles\_list/`|2|Alternate list view within the gallery|
|Library — bulk select + sort|`designs/the\_gallery\_bulk\_actions\_sorting/`|2|Long-press to enter, checkboxes, bottom action bar|
|Navigation drawer — base|`designs/navigation\_drawer\_side\_menu/`|2|Standard slide-out nav|
|Navigation drawer — expanded with stats|`designs/expanded\_navigation\_drawer\_profile\_stats/`|2|**Reinterpret as LOCAL listening stats only** (top artists, hours listened, songs played). No accounts, no XP, no Aura.|
|Now Playing (default / classic skin)|`designs/now\_playing/`|3|Cover, controls, progress, favorite, more menu, lyrics area|
|Queue with gesture interactions|`designs/up\_next\_queue\_gestures/`|3|Drag to reorder, swipe to remove, tap to jump|
|Song context menu|`designs/song\_context\_menu/`|3|Long-press / overflow menu — reusable everywhere a song appears|
|Add to playlist bottom sheet|`designs/add\_to\_playlist/`|4|Sheet with playlists + "New playlist" option|
|Playlist creation flow|`designs/playlist\_creation\_mini\_player/`|4|Multi-step flow that keeps the mini player visible|
|Favorites, Recently Added, Playlists list, Playlist detail|*(not in Stitch folders — ASK BEFORE BUILDING)*|4|Build from sonic\_sanctuary\_2 tokens matching the visual language of the other screens|
|Liner notes panel|`designs/liner\_notes/`|5|Extended track info: credits, lyrics context, album details|
|Equalizer|`designs/audio\_engine\_eq/`|6|5-band graphic EQ + presets|
|Custom EQ presets management|`designs/custom\_eq\_presets/`|6|Save, rename, delete user presets|
|Recommendations "For You"|*(use `designs/nocturnal\_frequency\_feed/` as VISUAL reference only — content is local recommendations, not curators)*|6|Ask before building — confirm the visual pattern is a fit|
|Settings — root|*(not in Stitch folders — ASK BEFORE BUILDING)*|7|Standard settings screen with sections|
|Feedback & Help|*(not in Stitch folders — built from sonic\_sanctuary\_2 tokens, approved 2026-09-07)*|pre-7|Nav drawer entry after Settings. Help tab: expandable FAQ list (`ExpansionTile`, same glass-card treatment as elsewhere). Feedback tab: form (type/subject/message/optional email) posting to Web3Forms, matching the manual lyrics editor's field styling.|
|Settings — audio customization sub-screen|`designs/navigation\_drawer\_audio\_customization/`|7|Audio-related settings entry point|
|Loading / transition state|`designs/frequency\_transition\_flow/`|7|Minimal animated loading indicator, used app-wide|
|Onboarding / first-launch|*(not in Stitch folders — ASK BEFORE BUILDING)*|7|Folder picker + permissions + brief tour|
|Empty states|*(build from sonic\_sanctuary\_2 tokens)*|throughout|Empty library, empty playlist, no lyrics found, no search results|

## v1.5 screens and assets (build in phases 8–9, AFTER v1 ships)

|Screen / feature|Design folder|Phase|Notes|
|-|-|-|-|
|Now Playing — Fluid skin|`designs/now\_playing\_fluid/`|8|Alternate player skin with organic animated background|
|Now Playing — Singularity skin|`designs/singularity\_interface/`|8|Alternate player skin with WebGL cosmic background|
|Mood-reactive mini player|`designs/mood\_reactive\_player\_bar/`|8|Mini player tints based on track mood|
|Mini player with mood toggles|`designs/player\_bar\_with\_mood\_toggles/`|8|Same mini player with explicit mood controls|
|Background shader — 1 through 13|`designs/shader\_1/` … `designs/shader\_13/`|8|Selectable animated backgrounds for compatible skins|
|Background shader — Universe|`designs/universe\_aura\_shader/`|8|Additional shader option for the gallery|
|Visualizers gallery|`designs/infinite\_visualizers\_gallery/`|9|Selectable audio-reactive overlays for the Now Playing screen|
|Hi-res audio export|`designs/high\_res\_audio\_export/`|9|Format + sample rate + bit depth picker|
|Haptic controls tuning|`designs/interactive\_haptic\_controls/`|9|Per-action haptic toggles + intensity|

## Aura gamification (Phase 4.5)

|Screen / feature|Design folder|Phase|Notes|
|-|-|-|-|
|Aura page (main stats view)|`designs/aura/local\_stats/`|4.5|Full Aura page: profile, level card, stats card, local insights|
|Level: Atmosphere (0-1400 mins)|`designs/aura/level\_atmosphere/`|4.5|Level 1 image + info|
|Level: Aurora (1401-3000)|`designs/aura/level\_aurora/`|4.5|Level 2|
|Level: Solar Flare (3001-4200)|`designs/aura/level\_solar\_flare/`|4.5|Level 3|
|Level: Eclipse (4201-7000)|`designs/aura/level\_eclipse/`|4.5|Level 4|
|Level: Starlight Novice (7001-10000)|`designs/aura/level\_starlight\_novice/`|4.5|Level 5|
|Level: Nebula Master (10001-14700)|`designs/aura/level\_nebula\_master/`|4.5|Level 6|
|Level: Galactic Voyager (14701-19999)|`designs/aura/level\_galactic\_voyager/`|4.5|Level 7|
|Level: Supernova (20000+)|`designs/aura/level\_supernova/`|4.5|Level 8|
|Level list reference|`designs/aura/level\_list/`|reference|Design reference for level system — NOT a user-facing screen|
|Level-up transition animation|`designs/aura/level\_up\_transition/`|4.5|Transition sequence played when user crosses a level threshold|

## Behavior references

Live in `designs/references/`. Interaction pattern only — do NOT copy visual style.

|Reference|File|Applies to|What to copy|
|-|-|-|-|
|Musixmatch-style lyrics with translation|`designs/references/lyrics-reference.jpg`|Phase 5 — lyrics display on Now Playing|Current line in prominent bold; upcoming words within that line dimmed/faded (word-level progress); translation directly below in a distinct accent color from sonic\_sanctuary\_2, slightly smaller weight; small "文A" translation toggle button in bottom-left; auto-scroll keeps current line centered. **Visual style comes from `designs/now\_playing/`, NOT from this reference.**|

## Explicitly out of scope

The following folders exist in `designs/` but are NOT to be used. If Claude Code encounters these while browsing the folder, it should skip them entirely.

Aura gamification (DISCARDED — superseded by `designs/aura/`, do not reference): `aura\_profile\_stats`, `interactive\_aura\_profile`, `aura\_levels\_stats`, `refined\_aura\_progression\_tiered\_view`, `aura\_achievements\_gallery`, `aura\_level\_up\_transition`, `universe\_aura\_reveal`, `supernova\_milestone\_reached`, `aura\_discovery\_feed`

Social (out, deferred to a possible v2): `event\_horizon\_social\_hub`, `social\_aura\_sharing`, `omniscient\_feed`

Aura transition frames (available as generic transitions ONLY if user asks): `aura\_transition\_electric\_1/2/3`, `aura\_transition\_nocturnal\_1/2`, `aura\_transition\_tranquil\_1/2`. If reused, do NOT frame them to the user as "aura" or "mood" transitions — just tasteful screen transitions.

## When adding new designs

1. Drop the folder into `designs/` (or a reference file into `designs/references/`).
2. Add or update the relevant row in the tables above.
3. If the design introduces a new color, typography variant, or spacing value, either fit it to existing tokens in sonic\_sanctuary\_2 or ask the user before adding a new token.

