# NOBOXES: no species ever shows up as placeholder boxes in normal play

Branch `claude/mmo-noboxes` (from `origin/claude/mmo-stegofix`, with `origin/claude/mmo-overhaul` merged in). Not merged to canon. No credits spent.

Owner rule (Milan, 2026-10-30): "remove the blocky stegosaurus and never show me that again", applied to every species.

## Species and models
A model is `res://assets/creatures/<id>/<id>.glb` and it must load (`CreatureDef.has_model`).

| Species | Model |
|---|---|
| coelophysis, compsognathus, deinonychus, gallimimus, megaloceros, pachycephalosaurus, protoceratops, stegosaurus, styracosaurus, tyrannosaurus, utahraptor, velociraptor, zebraceratops | yes (13) |
| allosaurus, ankylosaurus, brachiosaurus, dilophosaurus, smilodon, tarbosaurus, triceratops | **no** (7) |

The other JSON files in `game/data/creatures/` (`ai`, `anim_events`, `natures`, `ragdoll`) are not species.
The seven model-less species stay in data, the wiki, the codex, butchering and loot tables. Nothing about them was deleted.

## What changed
- `CreatureDef` (`scripts/creatures/creature_def.gd`) holds the one shared check:
  - `has_model(id)`: the GLB exists, or the id is in the test-only `fake_models`.
  - `eligible(want, table, pool)`: returns `want` if it has a model. Otherwise it returns the next species after it in the same table that has one (wrapping), then the first species with a model in `pool`, then `&""` (no spawn).
  - `allow_placeholder` (static, default false): the only way to get boxes.
- `CreatureView.setup`: with no model (or a model that fails to load), the boxes are built only when `allow_placeholder` is set. Otherwise the view stays empty and logs a warning.
- `IslandSpawns.spawn_all` (all roster islands, home and unstable isles, since isles copy their template's tables) runs every fixed row and ring row through `eligible`.
  - The table is the row's own list: the island's `creatures`, or that ring's rows.
  - The pool is every species on the island.
  - When a row is substituted, the row's `tier_offset` goes on the Spawner as meta, because the Spawner's own lookup keys on the old species name.
- Tutorial wild zones (`tutorial.gd _wild_zones`) do the same over the `wild_zones` table.
- `Spawner.spawn_now` is the last guard. It spawns nothing for a model-less species unless `allow_placeholder` is set. That covers alphas (rolled inside the Spawner) and zone wakes.
- `PlayerPets.summon` refuses a model-less pet with a notice instead of summoning an empty body. Only an old save could hold one, since captures come from wild spawns.
- Town pens (zebraceratops and compsognathus only), taming pen occupants and the animal stage all go through `CreatureView`, so they cannot draw boxes either.
- These labs set `allow_placeholder = true` in `_ready`: `capture_lab`, `combat_rules_lab`, `creature_lab`, `stationstate_lab`, `wild_ai_sweep_lab`.
  `LabSpawnPanel.spawn` also sets it, since t_labspawn drops an allosaurus.
- These tests opt in explicitly, because they measure a model-less body:
  - `t_stationstate`: the ankylosaurus overhanging its pen.
  - `t_petfollow`: the triceratops as the big follower.

Once a species' GLB lands, it is eligible everywhere with no table edits.

## Test: `game/tests/t_noboxes.gd`
- It prints the species and model list.
- It unit-checks `eligible`:
  - the next species in the table is picked, and the table wraps;
  - an all-model-less table falls back to the pool;
  - nothing eligible means no spawn;
  - a faked model makes a species eligible.
- `Spawner` refuses a model-less species.
- It builds all 15 roster islands, then the tutorial island (with 4 zones woken), then 3 rolled unstable isles.
  - Each one has creatures.
  - Every creature draws its GLB.
  - No `CreatureView` in the tree has a box body.
- Per-island creature counts: home 8, savannah_15 24, temperate_20 19, temperate_25 24, tropical_25 17, tundra_30 14, desert_35 17, temperate_35 15, tropical_40 12, savannah_45 16, temperate_45 12, desert_50 14, swamp_55 19, tundra_55 14, volcanic_60 6; drift isles 17, 11 and 19.

## Gates
All gates were run on the merged head (with `origin/claude/mmo-overhaul` at a2c5acbf), each test headless with its own HOME:
- PASS: `t_noboxes`, `t_islandgen`, `t_unstable_isles`, `t_tame`, `t_combat`, `run_all.gd` (`[tests] PASS`), `tools/smoke.sh --no-import` (SMOKE PASS).
- Also PASS, re-run because they touch model-less species:
  - before the merge: t_ai, t_alphas, t_boneparts, t_canim, t_data, t_eyetrails, t_fieldhud, t_gather, t_genetics, t_movepriority, t_natures, t_player, t_rest, t_roll, t_styraco, t_targetui, t_tentsleep, t_turnrate;
  - after the merge: t_butcher, t_capture09, t_labspawn, t_lootradial, t_pen_claim, t_pen_offline, t_petfollow, t_stationstate.
- **t_tutorial FAILS on the merged head (TEST_TIMEOUT 1200), and it fails the same way on plain `origin/claude/mmo-overhaul`.** The failures are "the town is batched: 262 MultiMeshes" (the test's ceiling is 220) and "ground cover 88813 > 80000". Both are town and ground-cover budgets that came in from canon, not from this branch. t_tutorial PASSED on stegofix + NOBOXES before the merge.
- t_playerturn fails ("tap_walk_away_target_gone: no position jitter") on plain `origin/claude/mmo-stegofix` as well; this branch did not cause it.

## Assumptions and notes
- # ASSUMPTION: the fallback widens from the row's table to the whole island's species. No global fallback was added:
  every island today has at least one species with a model, and `t_noboxes` fails if one ever does not.
- A model-less view that a normal-play path still reaches (only an old save's pen occupant or a market preview) stays empty instead of drawing boxes.
