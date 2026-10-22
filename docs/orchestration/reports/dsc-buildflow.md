# dsc: BUILDFLOW — construction components, blueprint → site → Workbench, station jobs

**Task:** BUILDFLOW (dsc, 2026-10-21), spec 30 phases 1-3. Branch `claude/mmo-buildflow`, worktree `mmo-buildflow`.
Nothing pushed, merged or deployed. No Meshy credits spent.

## Outcome

The whole spec 30 §18 sequence now runs through the real systems on the home island: components from logs and
strap materials, the Craft/Build menu with exact prerequisites, a placement that makes a **construction site**
(never a station), exact-instance escrow, timed work, an atomic finish into one **leveled Workbench**, its tag/level
gated recipes, a queued processing job collected exactly once, and save/reload of every part.

- `game/tests/t_buildflow.gd` → `[t_buildflow] PASS` (61 checks), no SCRIPT ERROR.
- `game/scripts/dev/buildflow_lab.gd` (scene `scenes/dev/buildflow_lab.tscn`) plays §18 and prints
  `[buildflow] RESULT steps_total=11 steps_ok=11 site_not_station=1 dup_items=0 lost_items=0 collected_once=1
  save_roundtrip=1 wrong_tag_refused=1 low_station_refused=1 ui_min_px=56` at 1600x900 and `ui_min_px=64` at 844x390.
- `t_process`, `t_build`, `t_save` still pass; `tools/smoke.sh` prints `SMOKE PASS` (full verify).

## M0: the two `t_process` failures on the merged base

Both were about W2-INV's one-instance-per-slot inventory landing after W2-PROCESS was written.

1. *forged 1e9 × lv 5e6 output loaded as a real stack.* `process_station.gd::_clean_stacks` bounded nothing but
   the def id and duplicates. The bag path (SaveSanitizer._stack) already clamps count to `legacy_stack_max` and level
   to `MAX_LEVEL`; the process row never got that boundary. Fixed in the code (clamp `count` to `def.stack_max`, level
   to `SaveSanitizer.MAX_LEVEL`), not the assert.
2. *destroyed rack handed the wrong meat back.* Not a loss bug. W2-INV changed `Crafting._plan`'s default pick to the
   least valuable instance, so a bag of [lv12 meat, raw hide, plain raw meat] drying one meat picks the plain one. The
   test comment said "the meat done" but assumed the first added instance. Fixed the test's input selection (explicit
   pick of the lv12 instance), same intent and same expectations.

## What shipped

### Data (all numbers from spec 30 or marked `# ASSUMPTION`)

- `game/data/blueprints.json` — `basic_workbench`: Construction Lv. 20, skill node `workbench`, footprint 2x1,
  8 s work (`# ASSUMPTION: spec 30 gives no build timer`), level 1..60, station tags `[workbench]`.
  Slots: Plank Shape ×2 (min 10, contributing), Pillar Shape ×2 (min 10, contributing), Strap ×6 (min 1, support:
  support slots never contribute to the level, so they must not gate it either).
- `game/data/items.json` — `plank_shape`, `pillar_shape`, `strap`, `trimmed_plank`, `fine_plank`;
  `strap_material` tag on reed, root, fibre_stalk, bark_strip, vine, palm_frond.
- `game/data/recipes.json` — `plank_shape` (log ×1), `pillar_shape` (log ×2), `strap` (strap_material ×1); all by hand,
  so the vertical slice is playable with no station (spec 30 §5: no circular dependency). `trimmed_plank` and
  `fine_plank` are workbench queued jobs; `fine_plank` requires Workbench ≥ 2.
- `game/data/processing.json` — a `workbench` row (1 job slot + 1 queued) for those two recipes.

### Code

- `scripts/items/blueprints.gd` (Blueprints): load, `unmet()` (exact prerequisite strings, level first),
  `fits()` (accepted tags from the item's categories + min_level), `result_level()` (floor of the contributing
  levels, clamped to the blueprint's min/max, then capped by Construction), `footprint()`.
- `scripts/world/construction_site.gd` (ConstructionSite, StaticBody3D): per-slot escrow of the **real** instances,
  `deposit/withdraw` (all checks before anything moves), the contributor recorded both in `deposited_by` and on the
  instance (`creator`), a work timer, `cancel()` (all-or-nothing by bag space), `salvage_contents()`, `progress()`,
  `to_dict()/from_dict()` — `from_dict` restores the escrow itself, so `SaveRestore.spawn` returns a node that already
  holds its deposits. Deliberately not a CraftStation and with no ProcessStation child.
- `scripts/items/build_flow.gd` (BuildFlow): `place_reason/place_site` (blueprint gate first, then the existing
  BuildGrid claims/water/slope/overlap/reach — no second claimant), `complete()` (refuses until materials + work are
  done, consumes the escrow once, computes the level, swaps the site for exactly one CraftStation with
  `station_tags`/`station_level`, pays Construction XP once), `menu_rows()`.
- `scripts/world/craft_station.gd`: `station_tags`/`station_level` (a kit-placed workbench is level 1), both saved;
  `station_gate()` reads a recipe's `station_tags`/`station_level`.
- `scripts/world/process_station.gd`: `refuse_reason` uses `station_gate`, so a low-level workbench refuses
  `fine_plank` by name.
- `scripts/ui/build_ui.gd` + `scenes/ui/build.tscn` (BuildUI): blueprint list grouped by the spec's categories, details
  with every unmet prerequisite and a "placeable here now" line, Place (the real `BuildFlow.place_site`), and the site
  sheet: slot rows with the deposited instances' levels, Deposit (tap a slot), Withdraw, Work, Cancel site, Finish.
  Created lazily by `BuildUI.ensure(player)` because `scripts/core/main.gd` is outside this task's file scope.
- `scripts/ui/craft_ui.gd`: a "Build" row at the top of the station list, the station tag/level reason on a recipe
  row, and a process station's queue in its header ("1/2 jobs running · 0:12").
- `scripts/ui/hunt_hud.gd`: the menu sheet has a Build row.
- `scripts/player/player_input.gd`, `scripts/player/player_actions.gd`: a tap on a construction site opens the site
  sheet.
- `scripts/core/save_restore.gd`: `construction_site` rows spawn through `ConstructionSite.from_dict`.

## What the shots show (paths and verdicts in `.dsc/NOTES.md` / `.dsc/IMAGES.md`)

At 1600x900 and 844x390: the Build menu with the Basic Workbench details, the site sheet with 2/2 + 2/2 + 6/6 exact
instances at their levels, the finished Workbench in the world with its plate, and the Craft·Workbench screen showing
the running trimmed-plank job. Fixes made from looking: full-canvas anchors for the runtime-created BuildUI, hide it
before the world shots, the 64 px phone tap floor, the site sheet forced to the detail pane on a compact canvas.

## Assumptions and deviations the integrator should know

- The learned-skill gate is the **existing** `workbench` construction node (Lv 5, 6 SP, behind Bonfire) plus
  Construction 20 from the blueprint data. `game/data/skills/trees.json` is outside this task's file scope, so the
  spec's separate "Basic Workbench" node was not added; a 3 SP tutorial node would be a data change in trees.json.
- Support slots use min_level 1: straps add nothing to the level, so gating on their level would be arbitrary.
- The site reserves the station kind's footprint on the BuildGrid, so a Workbench can never be placed on an unfinished
  site and vice versa.
- Completion pays 25 Construction XP (`# ASSUMPTION`, the blueprint's `xp`) once; work ticks, cancel and reopen pay none.
- The lab hands over the logs and reeds instead of gathering (the gather system has its own tests); every step from the
  hand craft onward is the real system.

## What phases 4-5 need

- More blueprints (shelter, storage, comfort) are pure data in `blueprints.json`; the UI already groups by category.
- Storage capacity / Comfort / Antibiotic / Durability bonuses (§17 19) are not wired: the blueprint schema has no
  fields for them yet.
- A `Basic Workbench` skill node in trees.json if the owner wants the spec's own tutorial gate rather than the existing
  Workbench node.
- The station sheet (BuildUI) is new UI: it has no `t_ui` layout gate yet; adding it there would lock the 64 px floor
  and the phone pane rules in CI.
