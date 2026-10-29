# dsc — CHASESPRINT: auto-sprint when a chased enemy pulls away

Owner (verbatim): "when chasing a fleeing enemy, when it leaves a certain radius around the player,
toggle sprint to chase it".

## What shipped

- `game/scripts/player/player.gd`
  - `Player.chase_sprint` — a flag of its own, never written into `sprint_toggled`, so the player's
    own SPRINT latch is never turned off from here (and chase-sprint turning off leaves it on).
  - `Player.chase_sprint_tick()` — called from `Player._physics_process` before the movement tick.
    Sprints once the hunt target is farther than `CHASE_SPRINT_ON_M` (7 m), drops back to a walk
    inside `CHASE_SPRINT_OFF_M` (4 m) — a hysteresis band — and clears when the chase ends (target
    dead or cleared, a ground-tap move order, or her death). A winded survivor is never forced to
    sprint; the forced sprint resumes at `CHASE_SPRINT_RESUME_FRAC` (0.25) of the stamina bar.
    Mounted, the mount's own pool decides.
- `game/scripts/player/player_sim.gd` — `wants_sprint()` also reads `chase_sprint`.
- `game/scripts/player/player_pets.gd` — `wants_mount_sprint()` also reads `chase_sprint`, so a
  fleeing target makes the mount run on its own energy.
- `game/tests/t_chasesprint.gd` — new: 9 m turns it on; 5 m keeps it on (hysteresis); 3 m turns it
  off; 6 m alone does not start it; a manual latch survives in both directions; a winded survivor
  walks; the chase ending clears it; mounted, the rider asks the mount to run and a winded mount
  walks. Prints `[t_chasesprint] PASS`.
- Docs: `docs/current/controls.md` § "Chase sprint (auto-sprint after a fleeing target)";
  `docs/vision/WildLandsMMO_Open_Questions.md` § 2026-10-29 CS1-CS4 (both radii and the resume
  fraction, each an ASSUMPTION).

## Assumptions taken (all `# ASSUMPTION` in code)

| Knob | Default | Why |
| --- | --- | --- |
| `CHASE_SPRINT_ON_M` | 7 m | The task names ~7 m. |
| `CHASE_SPRINT_OFF_M` | 4 m | The task names ~4 m; the gap is the hysteresis. |
| `CHASE_SPRINT_RESUME_FRAC` | 0.25 | Not in the task: without it an empty bar would re-arm the forced sprint every frame. |

## Verified

`bash .../dsc/verify_chasesprint.sh` → VERIFY PASS: `t_chasesprint`, `t_controls`, `t_combat`,
`t_movepriority`, `tests/run_all.gd`, `tools/smoke.sh --no-import`.

Headless only: every run used `--headless --path game --script res://tests/<t>.gd`; no windowed Godot
was started and no Meshy credits were spent.

## Notes for the next agent

- Chase sprint is a flag, not a HUD state: the SPRINT hex stays unlit while it is on. Logged as CS4.
- The radii live on `Player`, so tuning is one constant each; `docs/current/controls.md` and the
  Open Questions register carry the same numbers and must move together.
- Sprint costs 9 stamina/s (`PlayerSim._walk`), so a long chase can still empty the bar and she then
  walks on her own — the intended interaction with the winded gate.
