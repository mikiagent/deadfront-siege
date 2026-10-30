# FOODFIX — land FOODTORPOR on the new canon (dsc)

Branch `claude/mmo-foodtorpor`, merge of `origin/claude/mmo-overhaul` in, unpushed. Date 2026-10-30.

## What shipped
1. **Merge** (commit 9aa7013b): `origin/claude/mmo-overhaul` (ISLANDSHAPES + WIKI-STEWARD + TUTPERF)
   merged into this branch. Two conflicts, resolved as the brief required:
   - `game/tests/t_buildspeed.gd` → canon's ISLANDSHAPES block, then the three island-build digests
     re-recorded on the merged tree.
   - `docs/vision/WildLandsMMO_Open_Questions.md` → both sections kept (FOODTORPOR + ISLANDSHAPES).
2. **Digest provenance proof**: with `narcoberry_bush` count temporarily 0 in
   `game/scripts/world/island_scatter.gd`, the merged tree built exactly canon's digests
   `ee9810de… / 3baa8c61… / d7f9bb52…`; count restored to 2; the merged tree now builds
   `f04996a5… / 84bf66db… / c3029c63…`, recorded in `game/tests/t_buildspeed.gd` with the comment
   updated. The change is provably the bushes and nothing else.
3. **Narcoberry vs topography**: the bushes cannot land on ISLANDSHAPES cliff/outcrop tiles.
   Read the path: `_spawn_special_family` accepts only GRASS/DRY tiles and requires
   `spawn_ok(pos,false)` — `is_dry` reads `dry_walk`, which is 0 on every CLIFF tile
   (island_terrain.gd walk mask) — plus the harbour/camp keep-outs. Turned into a permanent check:
   `t_islandgen._check_islandshapes` now verifies each narcoberry bush's tile is not CLIFF, is dry +
   spawn_ok, and stays off the dock approach, on all 16 islands (tutorial_isle added to the roster
   with its expected 0 bushes).
4. **Tutorial dock**: t_islandgen's southern-most-dock assertions now skip islands with
   `dock_rule: hint` (the tutorial keeps its hand-tuned dock per ISLANDSHAPES S4) — the tutorial
   isle would otherwise fail the check it was never meant to meet.
5. Gate `verify_foodfix.sh`: **VERIFY PASS** (t_foodtorpor, t_buildspeed, t_islandgen,
   t_capture09, t_tame, t_tutorial, run_all, smoke all green).

## What failed / notes
- t_buildspeed's **timing** gate flakes under this box's load (load average 8-9.5, eight other agent
  Godot jobs; home best 3472-3877 ms vs the 2500 ms budget set on an idle box). The digest
  assertions — the merge's real acceptance — pass every run. claude-islandshapes.md records the
  same flake: canon itself measured 3229 ms home under load ~8.7 and passed only when run alone.
  perf_budget.json was NOT touched (weakening the budget to go green is not allowed here); the
  re-run of the full gate passed when load dipped.
- Credits spent: none.

## What the next agent needs
- The merge is local and unpushed; the branch tip after this task carries FOODTORPOR + canon.
- If t_buildspeed times out again on a loaded box, re-run it alone before debugging anything: the
  digest line in the log is the source of truth.
- `t_islandgen` now covers 16 islands (tutorial_isle included) and takes ~2-3 min headless.
