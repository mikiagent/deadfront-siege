# dsc-butcher — BUTCHER: choose carcass parts instead of a random roll

Spec: `docs/design/durango-prompts/12_remaining_skill_trees.md` §2, `04_loot_material_processing_crafting.md`.
Shipped on `claude/mmo-overhaul` + this job's branch, base `a8a41cb`.

## What shipped

A kill still leaves a `Corpse` with a rolled `loot` bag (unchanged), but the survivor now **chooses what
to cut**. Tapping the corpse opens a part picker instead of the loot chest; each pick starts a timed cut
and hands over only that part.

- `game/scripts/gather/carcass_parts.gd` (new, `CarcassParts`) — the part list per species from
  `game/data/butchering.json` (deduped by item id: a rare row that repeats a base id merges into it),
  `cut_budget(skill) = 1 + floor(skill / 10)`, `reason(part, ctx)` (the one refusal answer), `cut()` (one
  part's stacks + one rare roll), and the save row (`to_row` / `corpse_from_row`).
- `game/scripts/gather/loot_roller.gd` — added `roll_part()` (one data row's stack, the shipped count
  scaling reused from `roll_carcass`) and `part_rare_chance()`. `roll_carcass` untouched.
- `game/scripts/creatures/corpse.gd` — `cuts_budget` / `cuts_left` / `cut_parts` set in `setup()` from the
  killer's Butchering level; `part_options()`, `cut_context()`, `cut_part()`, `apply_cut_state()`; the cut
  in flight (`begin_cut`, `_tick_cut` in `_process`, `cancel_cut`, `cut_progress`, `cut_running`) with the
  shipped `GatherRing.show_for_craft` ring and the same movement / out-of-reach cancel rules;
  `open_picker()` builds the picker on its own `CanvasLayer(95)`; `open_loot()` now opens the picker and
  `open_loot_chest()` keeps the old chest screen (reachable from the picker's "Loot chest" button).
- `game/scripts/core/save_sanitizer.gd`, `save_restore.gd` — a `carcasses` record (species, position,
  cuts left of budget, part ids already cut, units left): sanitized on load and respawned through
  `SaveRestore.carcasses`. **The two call sites live in `game/scripts/core/save_game.gd`, which is
  outside this job's SCOPE regex**, so they ship as
  `docs/orchestration/reports/dsc-butcher-save-hook.patch` (three hunks: build the rows in `save_now`,
  add the `carcasses` payload key, call `SaveRestore.carcasses` in `_apply`). Until that patch is applied
  the record round-trips (tested) but a real save writes no carcasses.
- `game/scripts/ui/butcher_picker.gd` (new, `ButcherPicker`) — minimal picker on the existing UI tokens:
  one 64 px `HexButton` per part with its icon, seconds, units left, its name under it and a red reason
  under any blocked part; "cuts left n of m"; "Loot chest" and "Close" (64 px). The grid fits as many
  cells a row as the width takes (up to 5) inside a scroller whose bar only appears when the parts really
  do not fit, and the panel is clamped to the safe area — so 1600x900 shows five hexes in one row and
  844x390 landscape shows the same row inside the screen.
- `game/tests/t_butcher.gd` (new, 9 groups) — part list from data, one-part-per-cut, budget enforcement,
  knife-tier scaling, rare odds per chosen part, cancelled cut grants nothing, save row round-trip, the
  timed cut through `Corpse`, and the picker (one hex per part, 64 px targets, no overlapping hexes or
  names, blocked reason, a tap starting the cut).
- `game/scripts/dev/gather_lab.gd` — butchers through the picker flow and prints one measured
  `[butcher] RESULT ...` line.

Docs: `docs/current/world-biomes.md` (new "Butchering: choosing what to cut" section above the per-species
drops table) and `docs/current/saves-persistence.md` (`carcasses` row in the payload table).

## Before / after numbers (measured)

| | before | after |
|---|---|---|
| A kill's parts | every rolled row landed in the bag | only the parts the survivor cuts |
| Choice | none (chest: take what is there) | one pick per cut, cut budget `1 + floor(Butchering/10)` |
| Velociraptor, stone knife, Lv1 Butchering | 4 slots taken from the chest | 5 part hexes, 1 cut, `bag_meat=3`, hide / bone / tendon / talon left on the carcass |
| Budget | — | Lv1 1, Lv10 2, Lv30 4, Lv60 7 cuts |
| Meat per cut | stone 2.78 / flint 3.58 units (per-100-cuts average, unchanged scaling) | identical per cut — no balance change |
| Talon per cut | — | 0.150 units at 0.156 odds (rare roll per chosen part) |
| Time per cut | 1.6 s corpse take | 1.6 s, same ring, cancel grants nothing |

Lab `[butcher] RESULT` at both resolutions: `parts=5 hexes=5 hex_px=64 panel_px=652 inside=1 cuts=1
cuts_left=0 cut_seconds=1.6 picker_open=1` (1600x900, fails=0) and the same with `panel_px=660` at
844x390.

## Shots looked at (in `.dsc/NOTES.md` with verdicts)

- `$TMPDIR/butcher/fit_1600x900/picker.png` — desktop, five hexes one row, blocked parts badged with
  "nothing left". Good.
- `$TMPDIR/butcher/fit_844x390/picker.png` — landscape phone, same row, panel inside the screen, footer
  reachable. Good.
- `cutting.png` / `butcher.png` in both sets — the ring over the carcass during the cut and the bag after.

## Assumptions (marked `# ASSUMPTION` in code)

- Cut budget `1 + floor(Butchering level / 10)`; parts not cut are lost when the carcass despawns (the
  task's own rule for the spec's silence).
- A rare-only part (e.g. `raptor_talon`) rolls its odds to exist on that cut; a miss still spends the cut.
- The knife is still required, matching the shipped `Corpse.can_butcher`.
- No drop numbers were tuned: counts still come from `loot_tables.json` with the shipped knife-tier and
  level bonuses.

## What the integrator needs

- **Apply `docs/orchestration/reports/dsc-butcher-save-hook.patch`** to `game/scripts/core/save_game.gd`
  (`git apply`) — the only part of this feature that could not land here, because that file is outside
  the job's SCOPE.

- The old chest screen still exists behind the picker's "Loot chest" button; `Corpse.open_loot` now opens
  the picker, so anything that expected a chest from that call (`t_player`, `main.gd --combat-test`) was
  left working by keeping `open_loot_chest`.
- The picker is deliberately minimal (the task said a Claude agent restyles UI later): tokens and
  `HexButton` only, no custom art.
- `gather_lab` at 844x390 still exits 1 on **pre-existing** phone rare-popup asserts
  ("a phone draws the rare stack over Bush", the rare notice, the motion follow) that fail identically at
  HEAD with this job's lab file reverted — unrelated to butchering, and the gate's stage 2 does not read
  them. Worth a separate look by whoever owns `gather_feedback.gd`.
- No new dependencies, no balance changes, no Meshy credits spent.
