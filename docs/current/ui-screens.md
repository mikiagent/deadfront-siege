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


## Island Market

Menu -> Island Market (`HuntHud.open_market(tab)`, or `MarketScreen.open_for(host, tab, uid)` for any
nav menu). Scripts: `game/scripts/ui/market/` (`market_screen.gd` chrome, rail, offline card;
`market_buy.gd`, `market_mine.gd`, `market_sell.gd`; `market_row.gd` one row = one instance;
`market_confirm.gd`). §8 chrome: HEADER bar with ‹ and the island name, the T-stones pill, ✕, torn
edge; left rail Buy / My Market / Sell (GOLD brackets on the active tab). The market lives on the
game server only: in the single-player build every tab shows an **Island Market offline** card and
sends nothing (owner 2026-10-20). Screens with listings come from the local test server
(`scripts/dev/market_harness.gd`, labelled "Local test server, not the live market" on the rail).
Test: `game/tests/t_uimarket.gd`. Shots (1600x900 and 844x390): `docs/orchestration/reports/uimarket/`.

- **Buy**: category column (View All, Tools, Weapons, Food, Wood, Stone, Fibre, Bone, Hide, Animals),
  search field, Level / Durability / Price sort headers (active one GOLD), one row per listed instance
  (icon in its natural tint, gold name, type line, Lv., cur/max durability, coin + price). A row opens
  the confirm: parchment header, trait chips, seller, price, tradable T-stones, **Buy for n** (one unit).
- **My Market**: Active (tap to cancel) / Sold / Expired / History, "n waiting" and **Receive All**
  (withdraws everything in market storage into the server bag, one rid per item).
- **Sell**: the server character's bag and bonded animals (equipped gear left out, locked rows greyed),
  price field, duration (12/24/48/72 h, default 24), fee / tax-when-sold / you-receive preview from
  `market_rules.json`, GOLD **List on market** (deposit + list exactly one unit).

![market offline](../orchestration/reports/uimarket/market_offline_1600x900.png)
![market buy](../orchestration/reports/uimarket/market_buy_1600x900.png)

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
