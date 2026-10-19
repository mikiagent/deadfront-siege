# W1-QA: gates that can fail and a green release soak

Branch `claude/mmo-w1-qa` (cut from `claude/mmo-overhaul`). Not pushed, merged or deployed.
Spec: `docs/orchestration/mmo/plan-register.md` section "#### W1-QA".

## What shipped

- `tools/test.sh`: runs `run_all.gd` and every `game/tests/t_*.gd`. A file passes only with exit 0,
  its own `[tag] PASS` line and no `SCRIPT ERROR` / `Parse Error` line. Strict expected failures
  (`XFAIL`): `t_rules` until W1-TAME lands the 180 s cooldown; an XPASS fails the gate. Each run gets
  a throwaway HOME.
- `tools/smoke.sh`: the `--smoke` main-scene boot, plus a second boot of `island_lab` that builds
  the real temperate_25 island and needs `[island] PASS mm= nodes= creatures= gathered=` with
  non-zero counts. Either run failing on a script error, a missing line or a non-zero exit fails it.
- `game/scripts/dev/lab_result.gd` (`LabResult`): `expect()` / `finish()` (exit 0/1), `deadline()`,
  `headless()`, `exposure()` (luma stats for stills), `capture_path()` (user://, not shared /tmp).
- `tools/labs.sh` + `tools/labs.txt`: one table row per lab, timeout per row, fresh HOME per row,
  NOISE column (ERROR/WARNING count). Flags: `shot`, `window` (silent windowed run, 1600x900),
  `xfail:<PKG>` and `shotxfail:<PKG>` (both strict: crash still fails, XPASS fails).
  `tools/labs.sh --shots DIR` takes web-renderer (gl_compatibility) stills of the `shot` rows and
  runs `game/scripts/dev/shot_check.gd` (black / flat / blown-out frames fail).
- Labs that never exited now quit headless with a verdict: `creature_lab` (survivor cannot die;
  six spawn, AI moves, survivor alive), `raptor_scale_lab`, `harvest_lab` (renamed from
  `foundation_lab`, script + scene). Other owned labs and probes use LabResult and exit 1 on FAIL.
- `counter_matchup_probe`: correct kit must win in 90 s; wrong kit fails if it still wins.
  `tyrant_window_probe`: capped at 200 s game time; PARTIAL (boss alive) and FAIL (survivor dead)
  exit 1. `bot_survivor --bot-gate`: exit 1 on PARTIAL/FAIL; a rung cut by the session budget reads
  TIMEOUT instead of a fake gameplay reason.
- `web_soak.gd`: prints `[soak] stamp`, seeds Survival to the route level (the hang on
  "Needs Survival 20"), every await has a timeout plus a 180 s watchdog, native runs click the bench
  themselves and exit 0/1.
- `tools/production_soak.mjs`: fails when the in-game stamp differs from `--expect-stamp=` /
  `EXPECTED_STAMP` or is missing; records requestAnimationFrame p50/p95/max from the first checkpoint
  and fails above `RAF_P95_MS` (default 100 ms).
- `perf_budget_lab` (+ scene): real temperate_25 island, 300 sampled frames, prints
  `[perf] physics_ms= frame_ms= process_ms= prims_visible= draws= ...`, fails above budgets.
- `game/tests/t_rules.gd`: GAUNTLET literals (pet cooldown 180 s, 3 active pets, capture below 30 %).
- `game/tests/t_qa.gd`: unit checks for LabResult and the exposure maths.
- `.github/workflows/ci.yml`: Godot 4.7.1, push on `main` and `claude/**` plus PRs; payload guard,
  test, smoke, lab table (under xvfb), web-renderer stills, uploads `artifacts/` (PNGs + lab logs).
  Not run: nothing is pushed.

## Acceptance checklist

| Item | Result | Exact line seen |
|---|---|---|
| Scratch t_crash.gd (method on null) makes test.sh exit 1; deleted after | done | `[test] FAIL t_crash (exit 142; SCRIPT ERROR: Cannot call method 'call' on a null value.)` then `[tests] FAIL 1/4 files`, exit 1 |
| Real suite exits 0 | done | `[test] PASS run_all`, `[test] PASS t_qa`, `[test] XFAIL t_rules ([t_rules] FAIL pet death cooldown 60 s, GAUNTLET says 180 s)`, `[tests] PASS files=3` |
| labs.sh prints a row per lab and exits 0 | done | 22 rows, `[labs] PASS rows=22`, exit 0 (table below) |
| Flipping one expectation makes labs.sh exit 1 | done | skills_lab with `xfail:DEMO`: `skills_lab XPASS 1 1 passes now: drop xfail:DEMO from labs.txt`, `[labs] FAIL 1/1 rows`, exit 1 |
| creature_lab, raptor_scale_lab, harvest_lab exit headless within 30 s with a verdict | done | `[creature_lab] PASS creatures=6 moved=3 hp=100` (9 s), `[raptor_scale] PASS heights=1.20/2.40/3.60` (1 s), `[harvest] PASS temperate=2 tropical=2 thicket=1` (1 s) |
| Desktop --web-soak prints every checkpoint through travel and `[soak] PASS` | done | windowed run: 11 checkpoints `world-entered` ... `travelled`, `returned-home`, `[soak] PASS`, exit 0; labs row `web_soak PASS 14 1 [soak] PASS` |
| production_soak.mjs against a local export prints PASS | done | local export `7199a9a5d/a99c143c84` on 127.0.0.1: `[perf] raf_frames=526 raf_p50_ms=16.7 raf_p95_ms=16.8 raf_max_ms=4666.6 budget_p95_ms=100`, `SOAK PASS (11 checkpoints, stamp 7199a9a5d/a99c143c84 as expected)` |
| ... and fails when the expected stamp differs | done | `SOAK FAIL: stamp 7199a9a5d/a99c143c84 is not the expected 000000000/0000000000`, exit 1 |
| --counter-matchup-probe exits 1 on a wrong verdict | done (see assumption 1) | correct kit: `[matchup] PASS species=velociraptor correct=true win=true time=20.8`; wrong kit: `[matchup] PASS species=velociraptor correct=false win=false time=90.0` exit 0 because the wrong kit lost; it exits 1 when the wrong kit wins or the correct kit does not |
| --bot --bot-gate exits 1 on PARTIAL | done | `bot_gate XFAIL 45 3 W2-DATA owns it: exit 1; [bot] PARTIAL 10/12 rungs reached` |
| CI uses 4.7.1, triggers on claude/**, log shows `[tests] PASS`, `SMOKE PASS`, lab table | written, not run | ci.yml pins `version: 4.7.1`, `branches: [main, 'claude/**']`; runs only after the program is pushed |
| t_rules asserts GAUNTLET literals, passes once W1-TAME merges | done (XFAIL now) | `[t_rules] FAIL pet death cooldown 60 s, GAUNTLET says 180 s`; remove `t_rules` from `XFAIL` in tools/test.sh when W1-TAME lands (the gate goes red with XPASS until then) |
| perf_budget_lab prints `[perf] physics_ms=... frame_ms=... prims_visible=...` and fails above thresholds | done, provisional budgets | `[perf_budget] PASS physics_ms=5.44 frame_ms=11.71 prims_visible=0` (headless: prims not gated) |
| smoke | done | `[island] PASS mm=2 nodes=378 creatures=24 gathered=1`, `SMOKE PASS` |

Final lab table (`tools/labs.sh`, exit 0):

```
island_lab               PASS      16     2  [island] PASS mm=2 nodes=378 creatures=24 gathered=1
creature_lab             PASS       9     1  [creature_lab] PASS creatures=6 moved=3 hp=100
raptor_scale_lab         PASS       1     1  [raptor_scale] PASS heights=1.20/2.40/3.60
harvest_lab              PASS       1     1  [harvest] PASS temperate=2 tropical=2 thicket=1
skills_lab               PASS       1     1  [skills] PASS construction=20 gathering=1 sp=215
sleep_lab                PASS      25     2  [sleeplab] PASS tent sleeps_left=5
plain_bush_lab           PASS       7     1  [plainbush] PASS ...
berry_state_lab          PASS       9     1  [berrylab] PASS ...
layout_perf_lab          PASS       3     1  [perf] PASS functional drag_p95=10542us rebuild=230us
pet_passthrough_lab      PASS       1     1  [passthrough] PASS pets pass through, wild creatures block
perf_budget_lab          PASS       7     1  [perf_budget] PASS physics_ms=5.44 frame_ms=11.71 prims_visible=0
camp_travel              PASS      11     1  [camptravel] PASS done failures0 ...
cargo_capacity           PASS       4     1  [cargocapacity] PASS failures0 ...
bot_rest                 PASS       6     1  [restprobe] PASS fatigue=0.0 energy=66.8 elapsed=29.4 ...
earned_training          PASS     104     7  [bot] PASS all attempted rungs reached
counter_raptor           PASS       3     1  [matchup] PASS species=velociraptor correct=true win=true time=20.8
counter_protoceratops    PASS       3     1  [matchup] PASS species=protoceratops correct=true win=true time=25.9
tyrant_window            XFAIL     25     2  W1-COMBAT owns it: exit 1; [raidwindows] PARTIAL boss alive at the 200 s cap ...
bot_gate                 XFAIL     45     3  W2-DATA owns it: exit 1; [bot] PARTIAL 10/12 rungs reached
web_soak                 PASS      14     1  [soak] PASS
ai_validation_lab        PASS      13     1  [aival] PASS
resource_visibility_lab  PASS       1     1  [resource_visibility] PASS ...
[labs] PASS rows=22
```

Stills (`tools/labs.sh --shots`, exit 0): `[shot] PASS shots=2` (island_lab, perf_budget_lab), and
`[shot] XFAIL creature_lab.png W1-LIGHT owns it: ... blown out (86 % clipped)`, same for
raptor_scale_lab (89 %) and harvest_lab (90 %).

## Screenshots inspected

Under `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/qa/`:
- `soak-pass/checkpoint-02.png`: craft menu open over the Workbench in the web export.
- `shots/island_lab.png`: real island, tree with labels, HUD; normal exposure.
- `shots/creature_lab.png`: survivor alive at 100/100 among raptors; ground and boxes washed out
  pale yellow (blown out, the qa-render-01 problem W1-LIGHT owns).
- `shots/harvest_lab.png`: same blown-out LabKit ground.

## Assumptions

1. `counter_matchup_probe.gd`: "exits 1 on correct=false" read as "exits 1 when the counter did not
   decide the fight": `--correct-kit` must win, the wrong kit must not. A literal "every
   correct=false run exits 1" would make the wrong-kit control unpassable. Reviewer call.
2. `perf_budget_lab.gd`: provisional budgets (physics p95 8 ms, frame p95 33.4 ms, 3 M prims
   windowed) from this machine, with headroom. Re-record after W1-AI and W1-WEB merge.
3. `shot_check.gd`: gross-failure exposure bounds (mean >= 0.04, spread >= 0.015, clipped <= 35 %),
   not a colour sign-off.
4. `layout_perf_lab.gd`: a layout drag must keep a 60 Hz frame on the dev machine.
5. `raptor_scale_lab.gd`: a model may stand 35 % off its data height.
6. `web_soak.gd`: Survival is seeded to the route level (as camp_travel_probe does); the soak proves
   the release, not earned progression.
7. production_soak rAF budget 100 ms p95: catches stalls and a stuck renderer, not a 60 fps target.

## Integrator hooks

None. `main.gd` already dispatches `--web-soak`, `--bot`, the probes and `--lab=<name>`.

## Labs to register

- `perf_budget_lab` (new): `game/scripts/dev/perf_budget_lab.gd` + `game/scenes/dev/perf_budget_lab.tscn`.
- `harvest_lab` (renamed from `foundation_lab`): anything that launched `--lab=foundation_lab` must
  use `--lab=harvest_lab`.
- New labs from other packages: append one line each to `tools/labs.txt` at merge.

## What failed or is left

- `tyrant_window` is red: boss at ~96-108 k HP after the 200 s cap with 6 stagger windows. Marked
  `xfail:W1-COMBAT`.
- `bot_gate` is red: PARTIAL (tame rung runs out of food, route grind ends at Survival 9 of 10, so
  sail/away are blocked). Marked `xfail:W2-DATA` (test-01). Rung counts vary run to run (12/16, 10/12).
- `t_rules` is red until W1-TAME (60 s cooldown vs 180 s). XFAIL in test.sh.
- LabKit stills are blown out under gl_compatibility: `shotxfail:W1-LIGHT`.
- `web_soak` must run windowed: in a headless run the desktop click never opened the station ring.
  The row is flagged `window`, so CI runs the lab table under xvfb.
- CI has not run (nothing pushed). xvfb + mesa on ubuntu-latest for gl_compatibility is untested.
- A crashed SceneTree test hangs until test.sh's 120 s alarm (exit 142) before it is reported.
- Noise is counted (NOISE column), not gated.
- Commits on this branch include `.uid` files for owned scripts only; `.uid` churn for other
  packages' probes was untracked again in `64bccee`.
- `shot_check.gd` is a new file in `game/scripts/dev/` that the Owns list does not name; labs.sh needs it.
