# dsc — LIGHTPORT (colour grade + golden hour onto canon)

Worktree `.claude/worktrees/mmo-lightport`, cut from canon `7d537d51` (`claude/mmo-overhaul`).
Source intent: `git show 80c3c3a6 -- game` (branch `claude/aaa-lighting-grade`, written on an older main).
Headless only: the owner reserved the machine (`HEADLESS_ONLY` is set in the job dir), so **no windowed shot was
taken and no visual judgement is claimed here**. The look is unverified by eye and belongs to the owner.

## What shipped

The port lands on canon's one shared lighting builder, not a second environment setup. Every island
(`island_runtime.gd:147` `WorldLighting.install`) and every LabKit lab (`lab_kit.gd:9`) gets it.

`game/scripts/world/world_lighting.gd`
- `_make_env`: the colour grade on the shared `Environment`. AgX tonemap is **kept** (canon's, and the old
  commit's filmic would be a regression); `adjustment_contrast` 1.08 (new profile key `contrast`);
  glow `strength` 0.9, `bloom` 0.04, `hdr_threshold` 1.0, `blend_mode` SOFTLIGHT (new keys `glow_strength`,
  `glow_bloom`, `glow_hdr_threshold`); canon's `saturation` / `saturation_compat` reused untouched (1.25 / 1.2,
  tuned by `lighting_lab`); `fog_sun_scatter` 0.15 already existed, untouched.
- `drive`: the golden hour. A new `golden` ramp (`golden_start` 0.56 → `golden_full` 0.64 in the profile,
  fading out before `NIGHT`) warms the sun colour and energy, and, through `dusk_w = max(warm * sun_up, golden)`,
  the fog and the sky horizon (and the sky-top dusk key). `max`, not sum, so dawn/dusk and the golden hour never
  double up. Night's blue lerp still runs last and still wins.
- `FALLBACK` carries all five new keys, so a missing/`lighting.json`-less run grades the same as the tuned one.

`game/scripts/core/game.gd`
- `--tod=0..1` (the island counterpart of LabKit's flag) parsed into a new `tod_pin`, and `_process` holds the
  clock while it is pinned. This matters: `World`'s save load (`save_game.gd:284`) writes the save's clock after
  `_ready`, and the frame advance would otherwise walk a shot off the ramp before the shutter.

`game/tests/t_lighting.gd` (`t_light.gd` is an alias that extends it)
- Prints both `[t_light] PASS` and `[t_lighting] PASS`. The gate confs use `TEST=t_lighting` **and**
  `RELATED="t_light"`, and the file only ever printed `[t_light]`, so the gate could not see it pass — that was
  the pre-existing stage-1 failure this job started from.
- `_test_environment` now asserts the grade on the live Environment: AgX, adjustment on, contrast in 1.0–1.2,
  glow strength and bloom both on, soft-light blend, threshold ≥ 1.0.
- `_test_golden_hour` (new): measures red-minus-blue of the live sun, fog and sky horizon at tod 0.62 / 0.66 /
  0.70 and requires each to beat **both** noon and night by 0.1 and be amber; at night fog and horizon must be
  blue again; and moving the profile's ramp to 0.40–0.44 must warm tod 0.45, proving the ramp is profile-driven.
- `_test_warm_dawn_dusk`: unchanged except the day-neutral upper bound (0.72 → `GOLDEN_START - 0.02`), because
  the golden hour is deliberately warm at tod 0.70. The 0.30 / 0.52 day core must still be exactly neutral.
- `_test_tod_flag` (new): the flag's value, the pin, and that a save-load write plus a frame cannot move it.

## Before / after numbers

| measure (live scene, headless) | before | after |
|---|---|---|
| `t_lighting` gate    | `VERIFY FAIL` (printed `[t_light] PASS`, gate wanted `[t_lighting] PASS`) | `VERIFY STAGE 1 PASS` |
| Environment grade | AgX, adjustment on, glow 0.3, threshold 1.0, no contrast/strength/bloom/blend | + contrast 1.08, strength 0.9, bloom 0.04, SOFTLIGHT |
| sun R−B, noon (0.5) / golden (0.66) / night (0.02) | 0.14 / 0.14 / 0.58 (no golden hour) | 0.14 / 0.58 / 0.58 |
| fog R−B, noon / golden / night | −0.20 / −0.20 / −0.07 | −0.20 / **+0.22** / −0.07 |
| sky horizon R−B, noon / golden / night | −0.26 / −0.26 / −0.12 | −0.26 / **+0.38** / −0.12 |
| night fog luminance (pixel gate's band, ≤ 0.15) | 0.059 | 0.059 (unchanged; the night lerp still wins) |
| `--tod` on islands | not parsed | 0.66 → `time_of_day=0.660 pin=0.660`, held |

Negative checks were run so the new asserts can fail: golden ramp forced to `0` → 8 FAIL lines; `--tod` parse
removed → `FAIL --tod=0.66 gave time_of_day 0.350`. Both restored afterwards.

## What I looked at
Nothing rendered — headless only, by the task and the owner's machine reservation. There is no PNG path to
report, and the visual verdict (does the grade read as "AAA", is the amber convincing, does the glow bloom the
fire and not the ground) is open for the owner. The pixel gates that do exist (`lighting_lab`: blown pixels
≤ 1 %, ground luminance 0.25–0.55, night ≥ 0.05, shade ratios) were **not** run: they need a window.

## Assumptions (all `# ASSUMPTION`, visual tuning the owner judges)
- contrast 1.08, glow strength 0.9, glow bloom 0.04, soft-light blend, threshold 1.0 — 80c3c3a6's values except
  the threshold, where canon's tuned 1.0 was kept instead of the old 1.3.
- golden ramp 0.56 → 0.64, gone by `NIGHT − 0.01`. 80c3c3a6's ramp peaked around tod 0.62–0.70 with a
  different noon reference; this one starts after noon so the afternoon core stays neutral, which canon's
  existing test (and the owner's earlier "the whole day phase is neutral" decision) required.
- the amber itself is **not** a new constant: it reuses canon's profile `sun_warm_color` [1.0, 0.68, 0.42],
  `fog_dusk_color` [0.74, 0.6, 0.52] and `sky_dusk_horizon` [0.88, 0.66, 0.5], so a climate can tune them in
  `data/world/lighting.json` (out of this job's scope — not edited) with no code change.
- `--tod` pins the clock rather than only seeking it; without the pin a shot drifts off the ramp.

## What the integrator needs
- Run `lighting_lab` windowed at 1600x900 and 844x390 on a compat build and judge the grade and the golden hour
  by eye; the gate's stage 2 is deferred here by `HEADLESS_ONLY`, so **nothing visual is approved**.
- If the owner finds the grade too strong, the knobs are `contrast`, `glow_strength`, `glow_bloom`,
  `glow_hdr_threshold`, `golden_start`, `golden_full` in `game/data/world/lighting.json`'s `default` row — no code
  edit needed (the keys are read with the same defaults as code).
- Touched files: `game/scripts/world/world_lighting.gd`, `game/scripts/core/game.gd`,
  `game/tests/t_lighting.gd`, this report.

## Gate note — `RELATED="t_light t_daynight"` cannot pass
`job_lightport.conf` names `t_daynight`, but `game/tests/t_daynight.gd` **does not exist in any branch** of this
repository; the `[t_daynight] PASS` the old reports quote is printed by `t_daynight_dial.gd`. The unmodified
full gate therefore ends at `VERIFY FAIL: t_daynight printed no PASS line` regardless of the code.
Everything else passes: with a copy of the gate whose only change is `t_daynight` → `t_daynight_dial`
(`$TMPDIR/lightport/gatecopy/verify_job.sh`, log `/tmp/lightport_full2.log`) the run prints
`VERIFY HEADLESS-ONLY: visual lab deferred by owner` then `VERIFY PASS`; `tools/smoke.sh --no-import` prints
`SMOKE PASS`; the scope diff is clean. Integrator: fix `RELATED` to `t_light t_daynight_dial`, or add a
`game/tests/t_daynight.gd` alias (`extends "res://tests/t_daynight_dial.gd"`) in a job whose SCOPE covers
`game/tests/` — I could not, it is outside this job's scope.
