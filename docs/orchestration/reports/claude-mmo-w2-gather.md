# W2-GATHER report (claude/mmo-w2-gather)

## What shipped
- `game/data/loot_tables.json`: rare gather finds per node role/family, each row gated by the climates whose materials list it (below). Rows: resin on trees (tundra), flint (temperate) and obsidian-pick-gated copper_ore (desert) on rock, berry_seed on bushes and spice_herb on plants (grassland, temperate), flax_seed on ground (savannah, temperate), pearl on coral (blue_tropical), copper-pick-gated silver_ore on black iron (snowfield). Tool tier raises the odds, with a cap; Gathering level does not (spec 12 s1). Butcher part gates by knife tier, butcher count/rare scaling.
- `game/data/gather_rules.json`: role tool affinity (axe on trees, pick on rock, knife on bushes and plants), bare hands 1.35x slower, rare XP bonuses.
- `game/scripts/gather/`: `LootTables` (data), `LootRoller` (pure roll math, injected RNG, usable by the server), `GatherService` (effective tool, seconds and yield per unit, after_unit: rare roll into a free slot only, "+n Item" popup, announcement, XP), `ButcherLoot` (carcass from butchering.json: counts scale with knife tier and Butchering level, scutes/dense bone/venom need a better knife, "rare" rows roll their `chance`), `GatherFeedback` (2D "+n Item" stack on CanvasLayer 60: above pet plates (58), under the radial (64) and ring (65); gold rare line on top; placed above the ring, else right or left of it, off world pills, HUD zones, plates and the radial; when HUD text moves onto it later it moves off, held still, or hides; not drawn when nothing within 120 px is free, and only then does the HUD notice "Rare find: x" announce the find), `GatherXp` (W2-SKILLS sink).
- `game/tests/t_gather.gd`, plus `--lab=gather_lab` (`game/scenes/dev/gather_lab.tscn`, `game/scripts/dev/gather_lab.gd`).

## Hooks patch (integrator applies at merge)
`docs/orchestration/reports/claude-mmo-w2-gather-hooks.patch`: `player_actions.gd` (`_scaled_gather_seconds` -> `GatherService.unit_seconds`, `_gather_yield_multiplier` -> `GatherService.yield_multiplier`, `GatherService.after_unit(...)` after `gt.consume_unit()`) and `corpse.gd` (`_roll_loot()` -> `ButcherLoot.roll_into(self, _owner)`). Both files on the branch equal claude/mmo-overhaul 34b6d459; `git apply --check` on it is clean.

Lab registration: there is no lab list. `main.gd` loads `res://scenes/dev/<name>.tscn` for `--lab=<name>`, so `game/scenes/dev/gather_lab.tscn` is the registration (`[boot] lab=gather_lab` in the run log). `tools/labs.txt` from the old report does not exist. `run_all.gd` needs nothing: the t_*.gd sweep picks up `t_gather.gd`.

## Gather rules against the specs
- GAUNTLET.md:83 "Gathering is from reach without teleport; movement cancels; progress appears above the node." gather_lab checks each pass: survivor within 3.2 m of the node when the first unit lands, largest frame step under 1 m (walked), the ring (or picked radial hex) drawn above the node's base, and a move input mid-pass stops the cycle with no later unit.
- GAUNTLET.md:73 "Starter-island dinos and gatherables are level 1." The lab's nodes now take climate and level from the island (`rt.material_level`, home `level_override: 1`) instead of a hard-coded 1; every gathered stack is checked at level 1.
- GAUNTLET.md:89 "Gathering UI stays above pet plates." Popup layer 60 > plates 58; the lab summons a pet and checks the stack's rect against plates, pills, HUD zones and the radial.
- Spec 12:38 "Resource nodes with species, biome, node level, finite parts/charges, respawn rules, and material drop tables." Rare rows are now per biome (climate).
- Spec 12:42 "never silently grant rare material traits purely for reaching a high level". `skill_bonus_per_level` 0; t_gather checks Lv60 and Lv1 roll the same.
- Spec 12:45 "say exactly what is missing". Logs refuse bare hands with "need tool axe".
- Spec 04:6 (individual instances per harvested unit): the finds are added as ItemStack with level; per-instance uids arrive with W2-INV (no stacking), and the sync step adapts then.

## Vision fix: climate materials
`docs/design/world-design.md:66` Grassland (home): "fibre_stalk, branch, stone, herb_leaf, berries, clay"; `:68` Temperate lists flint; `:71` Desert lists copper_ore. The doc says it, so the fix went in: every rare row lists `climates`, `LootRoller.roll_gather_rares` takes the node's climate (set from the island data by `IslandScatter.plant_at` into `yield_attributes.climate`) and skips rows that do not list it. A home-grassland rock never yields flint or copper now; the only home finds are berry_seed (bush) and spice_herb (plant). gather_lab's rare demo moved from rock flint to a bush berry seed for that reason.
Test: t_gather "a home-grassland rock never yields flint/copper_ore" (20 000 obsidian-pick rolls each), "copper_ore (desert) never rolls on a temperate rock", "the home grassland still has a find", and every row lists real climates. Mutation (filter removed): `[t_gather] FAIL a home-grassland rock never yields flint (rate 0.0756)`.

## This run (2026-10-20 night, resumed)
- Base: merged claude/mmo-overhaul at cbba0333 (6e9655d6) and again at 34b6d459 (40955e19, docs only). The hooks patch is `git apply --check` clean on 34b6d459; `player_actions.gd` and `corpse.gd` on the branch equal the base.
- Fix found by the phone shot (aa356931): at 844x390 the gold "RARE Berry Seed" stack sat on the HUD's "Rare find: Berry Seed" notice (gather_lab: `FAIL popup ["RARE  Berry Seed", "+2 Fibre Stalk"] at [P: (454.8858, 226.4473) ...] clear of [P: (392.5, 226.4474), S: (197.0, 30.0)]`). The stack was placed once; the HUD re-places its notices every frame and a level-up banner had moved the notice onto it. Now the stack checks each frame and moves off (held still) or hides. The HUD notice is the fallback only: the desktop rare shot used to say one find four times (toast, notice, gold line, yield line). gather_lab checks both ways: a drawn rare stack is not repeated by a HUD notice; a skipped one is announced (`popup skipped over Bush (no room by the node); HUD toast true, rare notice true` at 844x390 with the radial open).
- gather_lab on a phone: when the gather radial is open, nothing within 120 px of the node is free and the stack is skipped by design; the lab then requires the HUD toast (and for a find, the notice) instead of failing. On desktop it still requires the stack.

## Gate lines (scratch tree = aa356931 + hooks patch; 40955e19 adds only docs)
- `--import` (mkscratch, same game/ tree): 0 `SCRIPT ERROR` / `Failed to compile` lines in `.import.log`.
- Every `game/tests/t_*.gd` rc=0: t_ai, t_build, t_canim, t_combat, t_gather, t_harbour (`[t_harbour] PASS islands=15`), t_iconart, t_items, t_light, t_lighting, t_occlude, t_player, t_save (`[t_save] PASS`, the 5 deliberate SCRIPT ERRORs), t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons, t_web, each `[t_x] PASS` with 0 SCRIPT ERROR.
- `--script res://tests/run_all.gd`: `[tests] PASS`.
- `tools/smoke.sh --no-import`: `SMOKE PASS`.
- `--lab=gather_lab` headless: `[gather_lab] PASS`, 0 SCRIPT ERROR; windowed gl_compatibility 1600x900, Forward+ 1600x900 and gl_compatibility 844x390: each `[gather_lab] PASS`, 0 SCRIPT ERROR.
- 0 "couldn't resolve track" in any gate log; no new `~/Library/Logs/DiagnosticReports/Godot-*.ips`.

## Screenshots looked at (scratchpad `w2g2/shots3` and `w2g2/shots4`, not in the repo)
- 1600x900 gl_compatibility and Forward+, `-rare`: gold "RARE  Berry Seed" over cream "+1 Fibre Stalk" left of the ring hex (7/12), clear of the Bush pill, the raptor's plate and the ring; HUD toasts "+1 Berry Seed", "+1 Fibre Stalk" top centre; no red notice. `-rare_radial` (Forward+): the stack above the bush, under the toasts. `-hands` / `-tools`: "+4 Branch", "+1 Log" right of the ring, readable.
- 844x390 gl_compatibility, `-rare`: gold "RARE  Berry Seed" / "+3 Fibre Stalk" right of the bush, below the level-up banner, clear of the ring, the plate and the notice band. `-rare_radial`: stack skipped (radial filled the space), the fallback "Rare find: Berry Seed" notice under the nameplate and the toasts on the left say it.
- Not this package, seen in the shots (for W1-UI / INVUI): at 844x390 the raptor's plate bar sits on the Bush pill and the ring hex covers that pill's text; `-loot_screen` (both sizes) draws world pills, the pet plate, the level-up text and the HUD notice over the open bag/loot screen; the HUD toast "+n Item" top centre repeats the node's "+n" line (kept: on a phone the toast is the fallback).

## Assumptions
- Rare odds and bonuses are illustrative values in loot_tables.json; the PRDs give none.
- Rare climates: berry_seed and spice_herb follow berries/herb_leaf (grassland, temperate); flax_seed follows the flax craters (savannah, temperate, world-design s4 crater column). silver_ore is a snowfield material but black iron nodes only grow on volcanic islands, so that row never rolls until a snowfield black-iron node exists; resin (tundra) no longer drops from home trees.
- Bare hands are 1.35x slower than the role's tool.
- The carcass rolls when the animal dies, for the local survivor's best knife and Butchering level (single player; W3 should roll for the credited killer).
- Knife tier stands in for the Butchering part nodes until W2-BUTCHER adds them.
- A rare find only rolls into a free bag slot, so no item is ever minted and lost.
- In gather_lab the starter tools are handed over, and the seed is picked so the next fibre unit rolls a find (the odds are proven in t_gather).

## What is left
1. W2-BUTCHER / W2-SKILLS: per-part Butchering nodes (Leather I, Bone I/II, Teeth, Horn), per-part take refusal in the chest screen, Slaughter/Mining/Plant Gathering ability, flawless and mistake results, techniques per part (spec 12 s1-2).
2. W3-SRVACT: the server gather handler should call LootRoller with its own RNG and the node's climate (intent_handlers does not roll rares yet).
3. Yield popups for corpse takes (the HUD toasts already show them).
4. W2-DATA: once rarity moves into items.json, review the rare items picked here (resin and flint are marked common in item_rarity.json).
5. Not done: no web export check; the 844x390 shots are gl_compatibility only.
6. W2-INV: once gathered items are instances (no stacking), `after_unit` should mint each find with a uid (it adds an ItemStack today).
