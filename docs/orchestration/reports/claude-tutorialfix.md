# claude-tutorialfix: TUTORIAL ISLAND safe on canon

Branch `claude/mmo-tutorialfix` (local, not pushed): `claude/mmo-integ-tutorial` (023c5981) + merge of
`origin/claude/mmo-overhaul` 5b4bf4ad (clean) + this fix. Canon's hit-interrupt rule and combat numbers are unchanged.

## What shipped

- `game/data/islands/tutorial_isle.json`: two island-def knobs.
  - `no_alphas: true`: `Spawner.spawn_now` drops the alpha roll when the loaded island def sets it (any island can use it).
  - `town_safe_m: 100`: `Tutorial._wild_zones` pushes every wild-zone row out to at least 100 m from the town,
    and `_dry_near` never picks a spot inside that ring.
  - Wild zone rows: the compsognathus pair moved 55 -> 160 m, and one single compy's angle went 230 -> 265 degrees.
    After the clamp the three single compys sat on one 100 m ring about 50 m apart, so the first hunt often fought
    two of them at once and the stone knife broke before butchering (seen once, 122 s hunt, 43 bites).
- `game/tests/t_tutorial.gd`: the town checks now say that every wild zone lies outside `town_safe_m`, that there
  are 2 or more compsognathus zones and no alphas. The streaming check stands at the nearest compy zone first
  (no compys are awake from the dock any more).
- Docs: Open Questions TU9 (no alphas) and TU10 (safe ring); `docs/current/tutorial.md` wild-lands note.

## Results

- `t_tutorial`, final code:
  - 5/5 PASS in a separate batch (5 parallel runs, each with its own HOME).
  - 7/7 PASS in diagnostic runs on the same data.
  - 4/5 PASS in a sequential loop that shared one HOME.
  - The 1 failure was `step 10 tut_axe: could not reach the workbench (4 m short)`, with 0 compy bites. It is the
    same path-stuck failure seen once before the zone spread, not a compy problem. It did not reproduce in 12
    fresh-HOME runs, and I did not find its cause (see Next).
- Compy bites now come only from the hunt step on (around 5-24 per run). Steps 1-11 have none. Before, about 20
  bites landed during the gather orders.
- `t_islandgen`: PASS (islands=15).
- `bash tools/all_tests.sh` (JOBS 4, shared HOME): 114 pass, 7 fail (t_alphas, t_controls, t_gather,
  t_invscreens, t_save, t_uimarket, t_uiicons). Rerun alone on this branch, all 7 pass. The same four that I
  checked on a canon 5b4bf4ad worktree pass there too. They are parallel-load and shared user:// flakes, not
  regressions.
- `bash tools/smoke.sh --no-import`: SMOKE PASS.

## Assumptions (marked `# ASSUMPTION:` in code and data)

1. TU9: no alphas on the tutorial island (`no_alphas`).
2. TU10: the town has a safe ring of 100 m (`town_safe_m`). The single compys sit at 200, 265 and 310 degrees
   and the compy pair at 160 m. The first hunt walks about 100 m out.

## Credits

None spent.

## Next

- Workbench path-stuck flake: after the reload at (-47.5, 70.4), the bot sometimes stops 4 m short of the town
  workbench, with repeated "abandoned route to 48,160 after 5.0s stuck". It looks like nav or physics at the
  bench approach, and it may depend on leftover user:// state. Not investigated further.
- all_tests.sh with JOBS > 1 shares one user:// dir; giving each test its own HOME would remove the suite flakes.

## Re-merge onto canon cc79a457 (2026-10-29)

- Conflicts resolved:
  - `spawner.gd`: kept canon's `force_alpha` and applied `no_alphas` on top. A forced alpha (labs and tests)
    still wins; only rolled alphas are blocked.
  - Open Questions: kept both sides (TU9-TU10 and canon's new ZEBRAAI section).
- New flake after the merge, and its fix: canon's retaliation can switch the hunt to a second compy and kill
  that one first. The bot kept waiting on its original target until the carcass despawned ("no carcass" at
  butcher, 1 of 3 runs). `tutorial_bot._hunt_weak` now counts any carcass as the hunt's result, which is test
  bot code only.
- Results: `t_tutorial` 3/3 PASS (each run with its own HOME), `t_islandgen` PASS, `t_alphas` PASS,
  `t_genetics` PASS, `smoke.sh --no-import` SMOKE PASS.
- Note: on cc79a457 the tutorial hunt takes 122-136 s, against about 33 s on 5b4bf4ad. The cause is not
  investigated. Each run fought several compys (retaliation).
- Canon moved on to 2c446449 (FIREFUEL) during the work. That merge was clean. One more flake appeared: retaliating
  compys kept biting her, which cancelled every butcher cut (1 of 3 runs). Fix: `tutorial_bot._fight_off_attackers`
  now fights off anything within 10 m whose target is her before it cuts the carcass, as a player would. This is
  test-bot code only; game rules are unchanged.
- Final results on this head: `t_tutorial` 4/4 PASS (own HOME each; hunt 136-175 s, butcher 8-9 s), `t_islandgen`,
  `t_alphas`, `t_genetics` PASS, SMOKE PASS.
