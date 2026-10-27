# dsc-mapui: fog of war, trail and map icons (specs 15 and 25 item 2)

## Shipped
- `game/scripts/ui/map_fog.gd` (MapFog): one 2 m-cell fog bitmap per island with a 25 m reveal brush,
  a walked trail (one dot per 8 m, last 200 kept), base64 serialisation, and a land mask so sea cells
  never fog (the coastline stays readable, as in the reference).
- `game/scripts/core/world.gd`: `map_fogs` per island id, `map_fog` for the current island,
  `note_map_walk()` called at 4 Hz from `World._process`, `map_map()` / `load_map_map()`.
- `game/scripts/core/save_game.gd`: new top-level save field
  `"map": {"islands": {id: {id, size, fog, trail}}}`. Builds before the field load it as absent.
  `save_sanitizer.gd` is outside this task's scope regex, so the row is validated where it is read:
  `World.load_map_map()` drops islands over 1 km, fog strings over 200 kB and trail points outside
  ±1 km (a forged row can never allocate a huge bitmap). **Integrator:** if you prefer the shape
  enforced in SaveSanitizer, move that block there; behaviour is identical.
- `game/scripts/ui/map_icons.gd` (MapIcons): house (claim), flame (campfire/bonfire), workshop sign
  (craft/trade facility), anchor (harbour), grey dot (other player), black trail dots.
- `game/scripts/ui/map_screen.gd`: fog texture, trail, claim/campfire/facility icons, other players as
  grey dots, resources and creatures hidden until their cell is revealed, a curated 8-row legend
  (`claim, campfire, facility, harbour, camp, other, wild, tree`), `icon_min_px()`.
- `game/scripts/ui/hunt_hud.gd`: the minimap draws the same fog bitmap (camera-up, cell-accurate
  region), the trail, and flame/anchor symbols.
- Tests/lab: `game/tests/t_mapui.gd`, `game/scripts/dev/mapui_lab.gd`, `game/scenes/dev/mapui_lab.tscn`.

## Before / after (lab, measured from the live scene)
| key | before | after |
|---|---|---|
| fog_start (share of land still grey on a fresh island) | 1.000 | 1.000 |
| revealed_after_walk | 0.000 | 0.603 |
| fog_after_walk | 1.000 | 0.397 |
| trail_dots | 0 | 16 |
| claim_icons / campfire_icons / facility_icons | 0 / 0 / 0 | 1 / 1 / 1 |
| persist_ok | 0 | 1 |
| ui_min_px | — | 64.0 at 844x390, 52.0 at 1600x900 |

The "before" column is what the old atlas had for each key (no fog: grey share 1.0 means nothing was
ever revealed; zero trail dots; zero claim/fire/station icons; nothing persisted).

Before the change there was no fog, no trail and no claim/fire/station icons at all: the atlas drew a
camp dot, a harbour square and resource dots.

## Shots looked at
- `docs/reference/durango-island-map.webp` (reference).
- `/tmp/mapui_shots/map_before_1600x900.png` — first open: island grey except the survivor's brush,
  coastline and legend legible, icons at the camp.
- `/tmp/mapui_shots/map_after_1600x900.png` — after the walk: large soft-edged revealed region with a
  black-dot trail, grey unknown at the rim. Matches the reference's brush idea; the reference's
  watercolour terrain/left info panel are out of this task's scope.
- `/tmp/mapui_shots/minimap_1600x900.png` — minimap: fog rim, revealed band, trail dots, fire/anchor.
- `/tmp/mapui_shots/map_before_844x390.png`, `map_after_844x390.png`, `minimap_844x390.png` — phone:
  icons readable, tap floor 64 px, 8 legend rows fit between header and buttons.

## Owner decisions / assumptions
- Fog is a **new save field** (`map`), backward compatible: an old save loads with a 40 m circle
  around the camp revealed and no trail. A fresh world starts fully grey.
- 25 m reveal radius, 8 m per trail dot, 200 dots kept, 2 m cells — no doc gives these; all marked
  `# ASSUMPTION` in `map_fog.gd`. The task brief supplied the 25 m/~8 m/~200/2 m figures.
- Claim icons use the saved `World.claims_for_current()` rows (one house per plot centre).
- Campfires/bonfires: any placed building whose kind is `bonfire`/`campfire`/`stone_fire_pit` or in the
  `bonfire` group. Facilities: anything with a `station_id` (craft stations) plus the known station
  kinds. Quest givers/trade NPCs do not exist yet; when they do they should join `_icon_marks()`.
- Other players come from `PlayerRegistry.all()` minus the local survivor, so offline the atlas simply
  draws none (no network code was touched).

## What the integrator needs
- `t_ui`, `t_save`, `t_harbour` and smoke pass; `verify_job.sh mapui` (full gate) passes.
- No changes outside the scope regex. No new dependencies, no scene rewrites.
- If the map fog should also cover water, drop the `land_from()` call in `World._ensure_map_fog`.
- `MapFog` is `class_name`d; run `--import` after pulling so `map_fog.gd`/`map_icons.gd` have `.uid`s.
