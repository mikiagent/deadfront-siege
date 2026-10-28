# dsc — FIREPITS: permanent firepit vs temporary fire

Task: owner rules of 2026-10-28 — "for the permanent firepit (bonfire with rocks in a circle) don't show
wood unless wood is loaded into the bonfire. For temporary fire bonfire show fire and wood and it burns
out eventually, and loses durability over time (especially if it's outside of a domain)".

## What shipped

| Rule | Where |
|---|---|
| The permanent `stone_fire_pit` never decays, hides its wood until wood is loaded, burns while the fuel lasts, goes cold (wood and flame gone, rocks stay) at 0 fuel | `game/scripts/world/bonfire.gd` (`is_permanent`, `load_wood`, `tick`, `_build_fire_nodes`, `WoodPile`, `Flame`) |
| `bonfire` and `campfire` show wood + flame from placement, burn out after their fuel time, wear over time, wear 2× outside a Domain, are removed at burn-out or 0 durability | same file (`tick`, `_in_domain`) + `structures.json` `placed_kinds` |
| Cooking only while the fire burns | `Bonfire.can_cook` / `cook_block_reason`, `StationMenu.filter_actions` (drops the COOK hex), `StationMenu._on_pressed` (refuses the press on a cold fire) |
| Loading wood is an action | `LOAD WOOD` hex in `StationMenu.actions_for`, handled in `StationMenu._on_pressed` → `Bonfire.load_wood`, which keeps the menu open so its fuel line updates |
| Info/inspect text: fuel left, plus durability for temporary fires | `Bonfire.info_lines()` / `info_text()`, shown by the hex menu's new `info_label` |
| Save/load keeps fuel, burning and durability; old rows load sane | `Bonfire.to_dict` / `from_dict`, `SaveSanitizer.BUILDING_ROW` |
| Acceptance test | `game/tests/t_firepits.gd` |
| Visual lab (the gate's kitchen_lab) | `game/scripts/world/firepits_lab.gd` |
| Docs | `docs/current/building.md` ("Fires"), `docs/current/recipes.md` ("Fires and cooking") |

## Before / after numbers

| | Before | After |
|---|---|---|
| `stone_fire_pit` | permanent object, but its model always showed wood + a spit, and it cooked with no fuel at all | permanent, wood/flame only while fuelled; one branch = 120 s, cap 600 s; cannot cook when cold |
| `campfire` | 120 s lifetime, no durability, no fuel concept | 120 s of fuel, durability 200 wearing 1/min (2/min outside a Domain), removed at burn-out or 0 |
| `bonfire` | permanent, no fuel, no durability | 600 s fuel, durability 300 wearing 1/min (2/min outside), removed at burn-out or 0 |
| Cooking at a dead fire | always allowed | refused, with a reason |
| Fire state on screen | none | `Fuel 4:12 · Burning · Durability 288/300` under the hex ring |
| Fire save row | `seconds_left` only (campfire) | `fuel_seconds` + `durability` for all three kinds; old rows still load |

Measured in the windowed lab (`[firepits] RESULT ... all_ok=1` at 1600x900 and 844x390):
`wear_inside=1.000` / `wear_outside=2.000` durability per minute on live nodes (ratio 2.000),
`cold_pit_cook=0`, `hot_fire_cook=1`, `pit_wood_empty=0`, `pit_wood_loaded=1`, `pit_wood_after=0`,
`pit_alive_after=1`, `save_fuel=1`, `save_durability=1`.

## Shots looked at

- `/tmp/firepits_shots/firepits_pit_empty_1600x900.png`, `..._pit_loaded_...`, `..._temporary_...`,
  `..._pit_out_...` (1600x900) and the 844x390 set under `/tmp/firepits_shots_phone/`. Verdicts are in
  `.dsc/IMAGES.md`. First phone pass failed on the loaded pit (the wood hid under the flame); the wood
  pile was redrawn as four light crossed logs on an ash bed and the flame lowered, and the rerun reads
  at phone size.

## Assumptions (all `# ASSUMPTION`, none in the owner's docs)

- Docs 10, 30 and 08 give no fire/fuel/burn/durability numbers, so every number is data in
  `structures.json` → `placed_kinds`: bonfire 600 s fuel, campfire 120 s (its old lifetime), wear
  1 durability/min, ×2 outside a Domain, one branch = 120 s, pit cap 600 s. Max durability stays the
  existing 300 / 200 / 700.
- "Outside a Domain" = the same claim check placement uses (`IslandRuntime.is_claimed` on the fire's
  cell; the home island counts as inside).
- A temporary fire at burn-out or 0 durability is **removed**, not left as ash: no ash state exists
  anywhere in the game.
- Wood is `branch` only; charcoal and peat carry a `fuel` category but are not accepted yet.
- A bonfire (a plain kit) still packs up; a lit campfire does not (pack + place would reset its fuel);
  a lit pit refuses pack-up.
- The pit hides its baked model and draws a procedural stone ring, because the GLB in
  `tools/blender/structures/structures.py` bakes the wood and a spit into the mesh.

## What the integrator needs

- Merge order: this branch only touches `game/scripts/world/bonfire.gd`, the new
  `game/scripts/world/firepits_lab.gd`, `game/scripts/ui/station_menu.gd`,
  `game/data/structures.json`, `game/scripts/core/save_sanitizer.gd`,
  `game/tests/t_firepits.gd` and two docs. `game/scripts/items/station_craft.gd` is **not** touched: it
  sits outside this job's scope regex, so the cook gate and LOAD WOOD dispatch live inside
  `station_menu.gd` (`filter_actions`, `show_for`, `_on_pressed`), which every fire menu already goes
  through.
- `t_save` passes unchanged: the frozen goldens carry no fire fuel/durability fields and the campfire's
  `seconds_left` still round-trips, so no golden rewrite is needed.
- The windowed lab probe self-installs from `Bonfire._ready` only when `--lab=kitchen_lab` is run with
  `--shot-dir=`; headless runs and other labs never load it. If kitchen_lab ever gains its own firepit
  section, move the probe into the lab scene.
- Not done (out of scope): a HUD fuel bar on the world chip (`ProcessStation.label_text` style), fuel
  from charcoal/peat, fire damage to nearby creatures, and rain putting a fire out.
