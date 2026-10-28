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

**`bag`** — bag (its Character tab now opens the Character sheet above)

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


## Character, Skills, Orders (UICHAR, spec §7 C1/C3/C4)

Full-screen sheets with the §8 chrome (`uichar_chrome.gd`: dimmed world, HEADER bar with "‹ Title"
and torn edge, ✕, PANEL boxes, parchment detail headers, GOLD primary button, gold corner brackets).
‹ reopens the MENU; ✕ / Esc returns to the HUD. Captures:
`docs/orchestration/reports/uichar/*_1600x900.png` and `*_844x390.png` (`--lab=uichar_lab`).

- **Character** (`character_sheet.gd`, hosted by the bag's `InventoryUI`; open with
  `HuntHud.open_character()` / `InventoryUI.open_character()` / the bag's Character tab). Tabs
  Equipment / Titles / Appearance (Appearance: "No decorative gear yet"). Left: name, level, occupation
  and title on parchment, then the stats list (Life, Energy, Attack, Defense, Accuracy, Critical chance,
  Held tool power, Heat / Cold resistance, the three Powers, Carry, Skill points). Centre: the figure
  (the survivor's portrait) with Head, Body, Arms, Legs left, Weapon, Tool, Ring, Bag right and Food 1,
  Food 2 under it; the selected slot's bar (name · Lv. · Attack · durability, Unequip, Open bag ›).
  Gear sets 1-4 sit in the header. Right: Survival (Exhaustion meter; Food, Thirst, Hygiene as status
  states, since the build has no hunger, thirst or hygiene meters) and a status footer. On 844x390
  the slot labels move inside empty slots.
- **Skills** (`skills_sheet.gd`; `HuntHud.open_skills(tree)`). A 4-column grid of the 12 skills (name,
  gold unread dot when a node is buyable now, white symbol, thin XP bar, Lv., "FULL · n XP" when XP is
  banked at the cap); right, the selected skill: parchment name + Lv., Skill XP, SP spent here, what
  levels it, the unlock list (Unlock / Refund / lock reason per node, auto-learned line, not-in-game
  rows) and the GOLD "Spend n SP on <next node>". F7 `skill_debug.gd` is unchanged.
- **Orders** (`orders_sheet.gd`; `HuntHud.open_orders()`). The standing orders of
  `data/world/objectives.json`: numbered rows (check when done, gold ring on the running one), title,
  hint, progress; right, the parchment title, how-to line, reward chips (+XP, +T-stones) and
  "Track on HUD" / "Tracking on HUD" / "Done".

**`skills`** — skills sheet (pre-UICHAR capture; recapture with `tools/ui_screens.sh`)

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
