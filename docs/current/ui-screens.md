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

**`sheet_menu`** — MENU sheet

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

**`craft`** — hand crafting

![craft](screens/craft.webp)

**`camp_bonfire`** — camp labels by the bonfire

![camp_bonfire](screens/camp_bonfire.webp)

**`station_bonfire`** — bonfire station menu

![station_bonfire](screens/station_bonfire.webp)

**`camp_workbench`** — camp labels by the workbench

![camp_workbench](screens/camp_workbench.webp)

**`station_workbench`** — workbench station menu

![station_workbench](screens/station_workbench.webp)

**`build`** — construction menu (Build)

![build](screens/build.webp)


## Skills

**`skills`** — skills sheet

![skills](screens/skills.webp)


## Creatures, pets, combat

**`animals`** — owned-animal roster

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

**`atlas`** — world atlas

![atlas](screens/atlas.webp)

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


## Restyled world screens (UIWORLD, 2026-10-28)

Built to [`../design/ui-redesign-spec.md`](../design/ui-redesign-spec.md) §7 F1 / F3 / E2 / A2 on the
shared `UiWorldSheet` chrome (`game/scripts/ui/uiworld_sheet.gd`: HEADER bar with torn edge, back
arrow, title, GOLD-numbered counter, ✕; GOLD primary and ghost buttons; parchment headers; GOLD
corner brackets). Shots at 1600x900 and 844x390: `docs/orchestration/reports/uiworld/`; lab
`game/scripts/dev/uiworld_lab.gd`; test `game/tests/t_uiworld.gd`.

| Screen | Script | Opened by | What it shows |
|---|---|---|---|
| F1 Domain | `domain_screen.gd` | `HuntHud.open_domain()` | Left icon tabs (Tamed / Civilized / Clan / Outpost locked). No domain: GOLD headline, body, quote, **Declare Domain**, island art. Domain held: 7x7 plot grid (Domain GOLD, can-expand outline, water blue, camp land), Plots used/cap, Pioneer rank, upkeep, plot size, next rank, **Communications Center →** (spec-29 contribution panel), Expand / Build here / Release. Declare and Expand step aside to a Confirm / Cancel card over the ground preview. Footer: the edge-adjacent growth rule. |
| F3 Communication | `comms_ui.gd` | `HuntHud.open_comms()` | Five factions from `data/world/factions.json` with a trust bar each; selected faction's parchment header (name, tone), three offers from its mission pool with Accept, support-crate band, Reroll offers / Contribute → / Track on HUD; header "Active missions 0 / 4 · Free rerolls 3". No mission or trust logic exists: trust is rank 0, Accept/Reroll/Track are disabled and say why. |
| F3 Radio University | `radio_university_ui.gd` | `HuntHud.open_radio_university()` or Communication → Radio University | Dr. Lamar, career guides only (seven from data, +2 SP each), no crates; progress is not tracked yet. Back returns to Communication. |
| E2 Taming Pen | `taming_pen_ui.gd` | tapping a pen (`PlayerActions.pen_interact` → `HuntHud.open_taming_pen(pen)`) | Left: captured animal (species, level, nature, pack n / cap, diet and role tiles, clade line, food and pen time). Right: "Tame it now, or keep it caged?", pen space n / 1, read-only mood slider with the pen time, pen grid (pen occupant + every caged animal in the bag, tap to pick), Store / Tame; once running: "Taming started", live countdown, Feed meat / OK. |
| A2 Island pick | `island_pick.gd` | character creation | Square cards on a sea well, GOLD brackets on the pick, blurb and top scatter kinds, "! Terrain choice is final.", GOLD **Select and move**. |

Not captured: the death/respawn ring and the skill debug overlay (dev only).

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
