# dsc-domaind — Personal Communications Center (spec 29 §4, §10)

## What shipped

A contribution-driven Tamed Island upgrade track. The **Personal Communications Center** is an ordinary
BUILDFLOW building: place it (Build menu → Construction Parts → Personal Communications Center), deposit
the exact parts, work the site down, finish. Once it stands on the home island, the Domain screen's
**CENTER** button opens its contribution panel: hand it the next step's items one unit at a time
(Contribute / Withdraw), then **Complete Upgrade** consumes them once and raises the island's Pioneer
rank. The plot **capacity** follows the documented milestones in `game/data/world/domains.json`.
Nothing is claimed by an upgrade: land still comes only from Domain → Declare/Expand.

| file | what |
|---|---|
| `game/data/world/comm_center.json` (new) | the build blueprint row + the rank steps; all costs are `# ASSUMPTION` |
| `game/scripts/world/comm_center.gd` (new) | data, the saved record, exact-instance deposit/withdraw/complete, `station()`/`built()`, nameboard |
| `game/scripts/world/domain_rules.gd` | `pioneer_rank()` = max(character level, center rank); registers the center's blueprint |
| `game/scripts/ui/comm_center_ui.gd` (new) | the modal contribution panel |
| `game/scripts/ui/domain_screen.gd` | rank in the stats line, a Capacity line, CENTER action, live re-read of rank/cap while open |
| `game/scripts/core/world.gd`, `save_game.gd` | `home_comm_center` record; saved as `home.comm_center` only when it has progress |
| `game/tests/t_domaind.gd` (new) | acceptance test |
| `game/scripts/dev/domaind_lab.gd` + `game/scenes/dev/domaind_lab.tscn` (new) | windowed lab + shots |

## Before / after

- Pioneer rank 1 → 2 (via the center); plot cap **13 → 17** (data, rank 2 milestone).
- Contributions spent: 2 Plank Shape + 8 Stone (the rank-2 step); the rank-6 step (4 plank + 6 strap +
  16 stone) and rank-7 step (6 + 10 + 24) are in data, unspent.
- Cells claimed by the upgrade: **0** (`no_auto_cells=1`, measured over the domain record and `rt.claims`).
- Domain screen, same open session: "Plots 0 / 13 · Pioneer rank 1" → "Plots 0 / 17 · Pioneer rank 2".
- Tap targets: 56 px desktop, 64 px on a landscape phone (844x390).

## Verified

- `Godot --headless --path game --script res://tests/t_domaind.gd` → `[t_domaind] PASS`, no SCRIPT ERROR.
- `verify_job.sh domaind 2` → `VERIFY STAGE 2 PASS` at both resolutions. RESULT line:
  `center_built=1 rank_before=1 rank_after=2 cap_before=13 cap_after=17 contrib_consumed_once=1 no_auto_cells=1 save_roundtrip=1 ui_min_px=56` (1600x900) and `ui_min_px=64` (844x390).
- Full gate (`verify_job.sh domaind`): see the run log; related tests `t_claims2`, `t_buildflow`, `t_save`,
  smoke and the scope check.

## Shots looked at

- `domaind_02_center_built` 1600x900 — Domain card reads "Plots 0 / 13 · Pioneer rank 1" with the
  "Capacity Pioneer rank 1 -> 17 plots at rank 2" line and the CENTER button.
- `domaind_03_contributions` 1600x900 / 844x390 — the modal panel, opaque, part rows with live bag counts.
- `domaind_04_ready` 844x390 — both rows full (2/2, 8/8), footer at 64 px on the phone.
- `domaind_05_after_upgrade` 1600x900 — rank 2, "Plots 0 / 17", rank-6 step listed empty.
- `domaind_06_domain_after` 1600x900 — the Domain card back with "Plots 0 / 17 · Pioneer rank 2".

## Assumptions (owner to confirm or tune)

1. **Contribution costs** (`game/data/world/comm_center.json`, all `# ASSUMPTION`): rank 2 = 2 Plank Shape
   + 8 Stone; rank 6 = 4 Plank Shape + 6 Strap + 16 Stone; rank 7 = 6 Plank Shape + 10 Strap + 24 Stone.
   Spec 29 says the intervening ranks and costs are not established, so only the documented ranks have a
   step and no intermediate table was invented.
2. The center's build gate reuses the Basic Workbench's (Construction 20 + the Workbench skill node), a
   1x1→2x1 workbench footprint and 20 s of work (`# ASSUMPTION`: spec 29 gives no build timer).
3. The finished center is a **workbench-kind** CraftStation carrying the `comm_center` tag: `comm_center`
   on its own has no `props_manifest` row and no kit, so a reload would refund it instead of rebuilding it.
   It therefore gets the workbench model plus a `Label3D` nameboard, and the HUD's station pill still names
   it "Workbench" (`hud_pills.gd` names a node by its kind — outside this job's files).
4. Rank = max(character Pioneer level, center rank), so a leveled survivor never loses capacity and the
   center can raise an under-leveled one. The record's `max_cells` stays a floor, as CLAIMS2 wrote it.
5. No record is written for an island that never used the center, so old saves re-save unchanged.

## For the integrator

- `data/blueprints.json` is outside this job's SCOPE, so the center's blueprint row lives in
  `data/world/comm_center.json` and `CommCenter.register_blueprint()` folds it into `Blueprints.all()`.
  Moving the row into `blueprints.json` is a straight cleanup (then delete the hook).
- A world tap on the center still opens the generic station/craft menu (`player_actions.gd:680`, outside
  SCOPE). Routing a tap on a `comm_center`-tagged station to `CommCenterUI` is one branch there.
- A dedicated center model/icon is art work: `data/props_manifest.json` needs a `comm_center` row with a
  `glb` if one is ever made; the tag-based lookup keeps working either way.
- `t_save`'s goldens are untouched (`home.comm_center` is absent when there is no progress).
