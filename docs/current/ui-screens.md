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

**`charcreate`** — character creation

![charcreate](screens/charcreate.webp)

**`island_pick`** — Tamed Island terrain pick

![island_pick](screens/island_pick.webp)


Not captured: the death/respawn ring and the skill debug overlay (dev only).
