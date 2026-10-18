# Tyrant raid phases: stomp, roar, tail

Date: 2026-10-18. Agent: Claude Code acting as the game-code owner (Cursor's lane). Branch
`claude/tyrant-phases`, not merged. Follow-up to `claude-tyrannosaurus-tripo.md`.

## What shipped

- **Clip contract** (`creature_clips.gd`): `tail_swipe` and `sleep` are now in `CONTRACT`, `sleep`
  is in `LOOPING`. New `OPTIONAL` list: a species without these clips gets a silent idle copy
  (no "missing clip" log line), in both `CreatureClips.attach` and `RiggedModel.fill_missing`
  (new `quiet` argument). The AnimationTree in `creature_anim.gd` has states for both.
  On the volcanic island: 0 "missing clip" lines; the tyrannosaurus `tail_swipe` and `sleep` clips
  remap with `missing=0`.
- **Tyrant brain** (`tyrant_brain.gd`): bites, with every third attack a raid phase in turn:
  stomp, roar, tail.
  - Roar: plays `alert`. On impact, the player within 2.5x bite reach (about 9 m) gets
    `deafened`, if the species lists it in `status_applied`. No damage.
  - Tail: plays `tail_swipe`. The boss turns its hips toward the target and sweeps. Hits the
    locked target if it is behind or beside (facing dot <= 0.3) within 2x bite reach (about
    7.3 m): bite damage plus `fracture` (blocked by the raid kit, the same as for bite and stomp).
    Standing at the head, rolling, or leaving the ring avoids it.
  - Telegraph labels: `ROAR - BACK OFF`, `TAIL - ROLL OR GET TO THE HEAD`. The HUD opening label
    shows `ROAR`/`TAIL`.
- **`anim_events.json`**: `tail_swipe.hit_frac` 0.47. Measured: the tail tip (bone `Tail7`) sweeps
  right to left. Its fastest point is 73 m/s at 47.5% of the 1.97 s clip, passing straight
  behind the hips. It swings about 7.7 m out to each side. `alert` keeps the default 0.55 because
  the jaw is fully open (52-58°) from 25% to 70%.
- **IsoCamera**: while the player's hunt target is taller than 4 m, the camera zooms out to
  `height x 3` (24 for the 8 m T. rex, capped at `max_size`). After the hunt it returns to the
  previous size. Pinch and wheel zoom are untouched outside boss hunts.
- **`tyrant_window_probe.gd`**: logs the windup clip, and the scripted player now backs out to
  the telegraph's reach instead of a fixed 4.5 m.

## Verification

- `tools/smoke.sh`: **SMOKE PASS**.
- `--tyrant-window-probe --tyrant-accelerated`: finishes, exit 0. Boss killed at t=674 s; player
  ends at 298/298 HP, 17 staggers. Windups: 171 bite, 29 stomp, 28 roar, 28 tail. Every roar
  deafened the player.
- Before the probe change, the old 4.5 m retreat could not escape the 7.3 m tail. The tail hit
  5 times and the player died at t=141. So the tail is lethal if ignored and avoidable if you
  leave the ring.
- Footage (`docs/orchestration/reports/tyrant-phases/`): `raid_three_phases.mp4` is 34 s of the
  real volcanic raid at 30 fps through the game camera. Stomp windup at about 6 s, roar at about
  13 s, tail at about 19 s. `roar.png` and `stomp_roar_tail_stills.png` show the tail windup
  (middle) and stomp windup (bottom).

## ASSUMPTIONs (PRD is silent)

All are marked in `tyrant_brain.gd`:
1. Phase order and cadence: every third attack, rotating stomp, roar, tail. The PRD says
   "3-phase raid: stomp, roar, tail" but gives no HP thresholds or order.
2. Roar radius 2.5x bite reach; rolling does not avoid a roar.
3. Tail reach 2x bite reach, damage equal to a bite, and it applies Fracture (the PRD status
   table lists "T. rex tail" as a Fracture source).
4. Windup and recovery times: roar 1.0/1.0 s, tail 1.0/1.5 s.

## Not done / for the next agent

- Bite and stomp still apply every `status_applied` token (deafened, fracture, pinned), as
  before. The PRD ties Deafened to the roar, Fracture to the tail and Pinned to "phase 2". If
  wanted, bite and stomp could drop deafened and fracture now that the roar and tail exist. That
  is a balance change, so I left it out.
- `sleep` is wired into the contract but nothing plays it. Only herbivores enter the brain's
  `sleep` state, and the T. rex is never in it.
- Framing: at size 24 the boss fits, but its head can still touch the top HUD bars, because the
  camera centres on the survivor. Centring on the survivor-boss midpoint would fix that.
- Stomp `hit_frac` 0.72 against the visible plant at about 62% is still open (out of scope).
- `face_towards(..., 1.0)` snaps the boss's facing instantly. That was already true for bite and
  stomp; on the tail turn it is a visible snap of up to 180°.

## Credits

0 Meshy, 0 Tripo.
