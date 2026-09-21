# Station hex interact menu (instinct task agent)

What shipped: tapping a workstation now opens a hexagonal interact menu floating over the
station instead of jumping straight into the craft sheet. Workbench offers CRAFT, bonfire
offers COOK (plus CAUTERISE while the survivor has bleed/deep_bleed). Any station without a
registry entry falls back to a single CRAFT hex when it has recipes. CRAFT/COOK open the
craft sheet on that station's group; the old StationRadial remains as the no-CraftUI
fallback. Tapping the same station toggles the menu; walking away or opening the craft
sheet dismisses it.

- New: `game/scripts/ui/station_menu.gd` (StationMenu; ACTIONS/HEIGHTS registries are the
  extension points for new station hexes).
- Changed: `game/scripts/items/station_craft.gd` owns the menu (`open_station_menu`,
  `_on_menu_action`), `game/scripts/player/player.gd` `open_station_craft` routes
  menu-first (interact dispatch only; spawn/touch code untouched).
- `craft_lab` shot modes: `--shot=` filenames containing `stmenu`, `stmenu_bonfire`,
  `stmenu_open` render the menu over the bench, over the fire, and the post-CRAFT sheet.
- Context "cook" hex and the interact key now surface the menu over the bonfire first
  (one extra tap vs before; consistent with the tap-the-station flow).

Verification: tools/test.sh PASS, tools/smoke.sh PASS, three craft_lab screenshots at
844x390 (hex over workbench, hex over bonfire, craft sheet after CRAFT). Note: tests in
`game/tests/run_all.gd` cannot compile classes that reference the Data/Game/World
autoloads (autoload identifiers do not resolve in the --script harness), so the menu is
covered by labs/smoke instead of run_all.

Credits spent: 0.
