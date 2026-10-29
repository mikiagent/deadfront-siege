# EYESDEATH: eye glow scales with threat, death without the 0-HP limbo

Branch `claude/mmo-eyesdeath` (from `origin/claude/mmo-overhaul`). Not pushed or merged. Credits: 0.

Owner: "compsagnathus looks very intimidating with the eye trails but it's not that powerful. Also could be
a bug: am still alive at 0 health for a while before You died shows up".

## 1. Eye glow and trails scale with threat

Rule (ASSUMPTION, numbers in `game/data/world/eye_glow.json` `_threat`):
`threat = clamp((tier - 10) / (60 - 10), 0, 1)` from the species tier (its level). A species can set
`eyes.threat` (0..1) in its JSON to override. At threat t:

| what | scale |
|---|---|
| trail length (default, before per-species `trail` knobs) | lerp(0.05, 1, t) |
| trail energy (default) | lerp(0.25, 1, t) |
| bloom/halo/core radius | lerp(0.6, 1, t) |
| dot material + rim light glow | lerp(0.45, 1, t) |

Measured (t_eyetrails `_test_threat`, length x energy):

| species | tier | threat | trail strength | dot glow |
|---|---|---|---|---|
| compsognathus | 15 | 0.10 | 0.20 (0.28 m x 0.72) | 0.51 |
| deinonychus | 35 | 0.50 | 1.39 (1.01 m x 1.38) | 0.73 |
| T. rex | 60 | 1.00 | 13.20 (6.00 m x 2.20) | 1.00 |

Alphas still get eye_glow_mult (2.5x) on top of their species: `set_glow` now builds the material at
`glow * threat_glow`, and `EyeTrail.boost` is relative as before. The test checks the trail and dot ratio
is exactly 2.5. Explicit per-species `trail` knobs (energy, max_length_m) still win over the scaled defaults.
Facing rule and the daytime glow-but-no-trail rule are untouched.

Files: `game/scripts/creatures/creature_eyes.gd` (`threat_of`, `threat`, `threat_glow`),
`game/scripts/creatures/eye_trail.gd` (`setup` scales defaults), `game/data/world/eye_glow.json`.

Shots: `docs/orchestration/reports/eyesdeath/` (compsognathus vs T. rex, night, run frames).

## 2. Death delay

Cause: `Vitals.take_damage` already set `dead` and emitted `died` in the same frame at 0 HP. The bug was
the display. The HUD wrote HP as `"%.0f"`, so a survivor left at under 0.5 HP by a fractional hit (mitigated
bite damage is not whole) read "0 / 100" and fought on until the next bite, or regen after the 6 s lock.
The death card then faded in at 0.8/s, so it took 1.25 s to show fully and looked faint for most of the
first second.

Fix:
- `HuntHud.hp_label(v)` rounds HP up (ceil), so 0 shows only when she is dead. The character sheet's Life row uses it too.
- The death card fades in at 2.0/s (full in 0.5 s, measured 0.51 s).
- Nonlethal ticks (starving, poison) still stop at 1 HP (status_effects.gd, unchanged).

Test: new `game/tests/t_death.gd`. At 0.4 HP the label reads 1. A hit from 5 HP fires `died` in the hit's
frame, she shows 0 and is dead, the card is fully up within 1.2 s, and she does not regenerate or move.

## Verification

t_eyetrails (the per-frame 2 ms budget flaked once at 2.04 ms on a machine running 74 Godot processes; it passed when rerun alone),
t_eyeglow, t_combat, t_player, t_starving, t_death, run_all `[tests] PASS`, smoke `SMOKE PASS`.

## Next agent

- To have a mid-tier species glow like an apex, set `"threat": 1.0` in its `eyes` block.
- t_death is not in run_all. Run it standalone like the other t_* suites.
