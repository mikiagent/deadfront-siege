# UI screens — what every screen looks like today

Every screen the build opens, captured from the real home island in the landscape phone layout
(844x390 logical canvas, drawn at 2x = 1688x780). Regenerate after any UI change:
`tools/ui_screens.sh` (runs `game/scripts/dev/ui_screens_lab.gd` windowed; full PNGs go flat to
`~/Documents/deadfront-ui-screens/`, WebP copies to `docs/current/screens/`). The lab walks the UI
gate lab's screens (`ui_real_capture_lab.gd`) with its checks off, then the ones it does not open.

## HUD

**`hud`** — idle HUD: vitals, fatigue belt, quest card, minimap, day/night dial, hex rail

![hud](screens/hud.webp)

**`hud_daynight`** — day/night dial label open

![hud_daynight](screens/hud_daynight.webp)

**`radial`** — gather radial on a resource

![radial](screens/radial.webp)

**`levelup`** — level-up banner

![levelup](screens/levelup.webp)

**`busy`** — pickup toasts and notices over the HUD

![busy](screens/busy.webp)

**`busy_levelup`** — toasts and notices over a level-up

![busy_levelup](screens/busy_levelup.webp)

**`fatigue`** — "what is tiring you" panel (tap the fatigue gauge)

![fatigue](screens/fatigue.webp)

**`sheet_menu`** — MENU nav menu (B3, `nav_menu.gd`): two columns of entries over the live world,
header with the debug gear and T-stone balance, CLOSE where MENU sits. The WebP below predates it
(old row sheet); current captures at both sizes: `docs/orchestration/reports/uinav/b3_nav_menu_*.png`.

![sheet_menu](screens/sheet_menu.webp)

**`sheet_build`** — BUILD sheet

![sheet_build](screens/sheet_build.webp)


## Bag & items

**`bag`** — bag and equipment

![bag](screens/bag.webp)

**`bag_food_inspect`** — food inspector (Grilled Meat selected)

![bag_food_inspect](screens/bag_food_inspect.webp)

**`bag_bag_inspect`** — bag inspector (Basic Bag selected)

![bag_bag_inspect](screens/bag_bag_inspect.webp)


## Crafting, stations, building

**`craft`** — Craft / Build (UICRAFT, spec §7 D1 / D3; `craft_ui.gd`, `craft_place.gd`)

![craft](screens/craft.webp)

Full-screen sheet: HEADER bar with torn edge, Back, "Craft / Build", the station hint (desktop),
Build and ✕. Left: station chooser (By hand / Workbench n m / Bonfire n m ..., scrolls sideways;
the chosen one gold-rimmed) over a 2-column category grid (All + the six recipe `skill` values; gold
brackets on the chosen tile). Middle: search over the recipe list grouped by what it makes (tool
class, else the output's first category), two cells a row, gold brackets + wash on the selection.
Right: parchment header, level · time · count, Max Level / Related Skill / Station / Time · Success ·
Flawless, the skill lock line, the Materials bar with ✓/✕ have / need rows, the CRAFTFEEL stake lines
and bag preview, and Craft (GOLD) / Craft ×5 pinned under the scroll. "Materials · Place materials"
opens **place materials** (D3): completion %, one chevron per slot (OK_GREEN once placed), the
slot's candidates (level, rarity pips, gold order badges), a parchment focus card with trait chips,
the expected result (traits from slot 1 only), a 1-10 stepper, the success rate, then Place
material → Craft; the placed instances lead their slots (`StationCraft.begin(..., uids)`).
Shots: `docs/orchestration/reports/uicraft/`. Every tap target is 64 px or more at 1600x900 and
844x390 (`game/tests/t_uicraft.gd`).

**`camp_bonfire`** — camp labels by the bonfire

![camp_bonfire](screens/camp_bonfire.webp)

**`station_bonfire`** — bonfire station menu

![station_bonfire](screens/station_bonfire.webp)

**`camp_workbench`** — camp labels by the workbench

![camp_workbench](screens/camp_workbench.webp)

**`station_workbench`** — workbench station menu

![station_workbench](screens/station_workbench.webp)

**`build`** — build mode drawer (UICRAFT, spec §7 D2; `build_ui.gd`)

![build](screens/build.webp)

Opened by the BUILD rail hex, MENU › Build or Craft / Build's Build button. An opaque drawer down
the left edge (494 px desktop, 312 phone): "Build", Move buildings, ✕; tier tabs Thatch Lv. 1 /
Wood Constr. 5 / Stone Constr. 20 / Metal Constr. 35 (`structures.json`; GOLD underline on the
chosen tier, red level when locked); flat-top hex tiles under Parts (the tier's pieces, cost
under the name), Stations (kits in the bag) and Blueprints (construction sites); the tier's materials
in the bag and the Construction level along the bottom. A tile starts the ghost and the drawer stays
open: "Pick a building spot" over the world, the cost bar at the bottom (in the drawer's bottom line
on a phone), and the HUD's ROTATE / SAVE / CANCEL row beside the ghost, kept off the drawer. A
construction site's sheet (slots, Work / Withdraw / Cancel site / Finish) opens in the same drawer.
The old BUILD bottom sheet (`sheet_build`) is still reachable from code but no control opens it.


## Skills

**`skills`** — skills sheet

![skills](screens/skills.webp)


## Creatures, pets, combat

**`animals`** — E1 Animals (UIANIMALS rebuild, `animal_screen.gd`; spec §7 E1). Sheet chrome
(`sheet_chrome.gd`: blurred world + SCREEN_DIM, HEADER with torn edge, back icon -> MENU, ✕ -> HUD,
tabs Pack / Taming Pen (disabled: no E2 screen yet), counter "Bonded n / cap (grows to 7)").
Left: pack slots = the bonded roster (spec 09 cap 3-7), one card per pet (swatch, name, NatureChip
directly under it, "Species · Lv. n · grade", status Out / Resting / Down / hungry), empty slots up to
the cap, one "n – 7 · locked" row, then "Waiting to bond" (captured / tamed animal items in the bag and
occupied taming pens). Centre: name, NatureChip, species · diet, grade box, the pet's live 3D model
(`animal_stage.gd`, drag to turn), growth XP bar, role and potential chips. Right: stats (with the
genetics tier), needs (fullness, health), Feed (GOLD) / Ride / Summon-Dismiss / Release (disabled: no
bond-breaking exists). Open: `HuntHud.open_animals(rec = null)`. The wiki shot below predates the
rebuild; current shots: `../orchestration/reports/uianimals/e1-animals-*.png`.

![animals](screens/animals.webp)

**`pet_out`** — HUD with a bonded pet out (SIC / HEEL / GUARD)

![pet_out](screens/pet_out.webp)

**`plate`** — creature plate, idle

![plate](screens/plate.webp)

**`plate_front`** — creature plate in front of the survivor

![plate_front](screens/plate_front.webp)

**`plate_zoom`** — creature plate, cropped close

![plate_zoom](screens/plate_zoom.webp)

**`combat`** — combat layer in a hunt

![combat](screens/combat.webp)


## Map, land, island

**`atlas`** — F2 World Atlas (UIANIMALS rebuild, `map_screen.gd`; spec §7 F2). Left column: "World
Atlas", "You X · Y · Lv. · T-stones", one card per catalogue island (current first, GOLD brackets on the
selected; level · climate · Tamed/Unstable, resources, species, status: You are here / Harbour route ·
n T-stones / Needs Survival n), foot: Island time, Islands visited, GOLD "Back to camp" on an unstable
island. Centre: the north-up map on its own sea colour. Right: compass + ✕, legend panel, Harbour
routes (+ Warp home away from home) and zoom − / +. Open: `HuntHud.open_atlas()` (opens) or
`open_map()` (toggles). Current shots: `../orchestration/reports/uianimals/f2-world-atlas-*.png`.

![atlas](screens/atlas.webp)

**`claim`** — CLAIM confirm panel (B4 restyle: parchment header, Cancel outlined, GOLD Expand;
current captures `docs/orchestration/reports/uinav/b4_claim_*.png`)
**`harbour`** — Harbour (`world_ui.gd show_harbour()`; owner §11 rebuilt the stretched "Sail ..." rows):
sheet chrome "Harbour" with "Survival n · T-stones n", then a 4-column (phone: 3) grid of route cards:
island, level · climate, the requirement line (red when short), and a Sail button (GOLD when it can
go, `route_id` meta, disabled with the reason on the card). Away from home: Free return home and
Return to camp cards first. Back returns to the atlas. Shots:
`../orchestration/reports/uianimals/f2-harbour-*.png`.

**`claim`** — CLAIM confirm panel

![claim](screens/claim.webp)

**`domain`** — Domain screen (Menu -> Domain)

![domain](screens/domain.webp)

**`comm_center`** — Communications Center contribution panel

![comm_center](screens/comm_center.webp)


## New character

**`charcreate`** — character creation (spec 19): Gender/Profession, Create Character (height, portrait
pattern/background, Colour tab), Name (1-20 chars), then the Tamed Island pick. The shot predates the
CHARCREATE restyle; recapture it.

![charcreate](screens/charcreate.webp)

**`island_pick`** — Tamed Island terrain pick

![island_pick](screens/island_pick.webp)


B4 toasts, radials and dialogs (UINAV, `game/scripts/dev/uinav_lab.gd`, desktop 1600x900 and phone
844x390 in `docs/orchestration/reports/uinav/`): warnings on dark red with a warning glyph and green
ok notices, the station radial (main action gold-rimmed, 96 px hexes on desktop), eating as a hex
pie with seconds left and the food's energy, the pet respawn ring (dark red disc, LIFE arc,
"seconds"), the fatigue panel and the death card.

Not captured by `tools/ui_screens.sh`: the death card, the respawn ring and the skill debug overlay (dev only).

## Tokens available for restyled sheets (not yet applied)

`game/scripts/ui/ui_tokens.gd` carries the token set and chrome helpers of
[`../design/ui-redesign-spec.md`](../design/ui-redesign-spec.md) §2/§8; no sheet uses them yet.

- Palette: `HUD_FILL`, `HUD_RIM`, `HEADER`, `SCREEN_DIM`, `PANEL`, `GOLD`, `GOLD_DIM`, `CTA_INK`,
  `PARCHMENT_TOP` / `PARCHMENT_BOTTOM` / `PARCHMENT_INK`, `OK_GREEN`, `LIFE`, `ENERGY`, `XP`, `MUTED`;
  existing `INK` / `TEAL` / `DIVIDER` unchanged.
- Chrome: `header_style()` (the HEADER bar) with `draw_torn_edge()` under it, `draw_brackets()` for a
  selection (four 18 px GOLD corners), `trait_chip_style(polarity)` / `trait_chip_prefix()` for the
  grey / yellow / green trait chips, and `ui_font(400|700)` / `ui_face()` for Roboto Condensed (the TTF
  is not in this branch yet; these return null and the engine fallback there).
- `HexButton` (also used by the sheets) has `flat_top`, `rim_color` / `rim_width`, `fill_ratio`,
  `icon_grey` and `key_hint`; a hex that sets `rim_color` selects in GOLD instead of TEAL. Defaults
  keep the shipped look; the one global change is that default hexes are flat-top (`HEX_FLAT_TOP`).
