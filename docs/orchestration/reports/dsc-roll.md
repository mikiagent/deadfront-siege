# dsc-roll — a roll that carries you clear and dodges a well-timed attack

Owner (verbatim, 2026-10-28): "roll should take you farther away and allow you to dodge an enemy attack
if well timed (invincibility for a small amount of time)". Spec: `docs/design/durango-prompts/07_combat_and_animal_capture.md`
§2 (telegraph + timed Roll, stamina/cooldown, Defense XP only for a real narrow dodge).

## What shipped
- `game/data/combat_tuning.json` → new `"roll"` section, every number `# ASSUMPTION` (spec 07 fixes none;
  I did **not** touch any existing balance number).
- `game/scripts/combat/roll_rules.gd` (new, `class_name RollRules`): the single place the roll's rule
  lives — exponential front-loaded speed curve, distance, the i-frame window (`invulnerable_at`), stamina,
  cooldown, buffer, Defense XP. Player and server both call it.
- `game/scripts/player/player_sim.gd` (`PlayerSim`): dash speed from `RollRules.speed_at(elapsed)`, stamina
  from data, cooldown counted from the press `RollRules.cooldown_s()` and refused with "Roll on cooldown
  (N.Ns).", input buffer kept (a press during a roll waits `buffer_s`; one that finds the cooldown running
  is dropped silently), new `roll_invulnerable()` / `roll_elapsed()` / `roll_cooldown_left()`.
  **Directional (owner rule, same day):** held input rolls that way; **no input rolls backward**, away from
  her facing, and she keeps facing forward (no yaw snap). There is no dedicated back-roll clip in
  `assets/characters/survivor/anim`, so the `roll` clip plays unchanged.
- `game/scripts/combat/creature_attack.gd`: the accuracy roll happens first, then the Player branch checks
  `sim.roll_invulnerable()`; a hit arriving inside the window is dodged before any damage, crit, float,
  camera shake or status.
- `game/scripts/player/player.gd`: `roll_dodge(clip, who, lands)` — no damage, no stagger, a "Dodged"
  line on the HUD (through `Player.notice`; `hunt_hud.gd` is outside this job's scope, so the float
  variant was left for the HUD owner), Defense XP **once per attack** and only when the accuracy roll would have landed
  (`lands`), so pressing Roll never pays. `receive_creature_hit` skips the hit reaction (and its own XP and
  fatigue) for a hit the roll dodged on the same physics frame.
- `game/scripts/combat/telegraph.gd` + `game/scripts/creatures/brains/tyrant_brain.gd`: the yellow ring's
  "she rolled" check and the tyrant's impact no longer treat the *whole* dash as immunity; they go through
  the same window. (Before, `TyrantBrain._impact` returned outright while `player.rolling`.)
- `game/scripts/server/`: new client op `act.roll {ms}` (`CharacterState.roll_ms()` / `roll_press()`), and
  `IntentHandlers.rolls_dodge(ch, at_ms)` = `RollRules.invulnerable_at(at_ms - roll_ms)`. The cooldown is
  judged on the same rule (`not_ready`), and the answer carries `iframes_ms` / `cooldown_ms`.
- `game/tests/t_roll.gd` (new): the acceptance spec, measured on the live scene and on a real
  `CharacterStore`.
- Docs: `docs/current/controls.md` (Roll section), `docs/current/server-contract.md` (op table + window).

## Before / after (measured, not constants)
| | before | after |
|---|---|---|
| distance on open floor | 5.907 m (13 m/s × 0.45 s) | 10.55–10.74 m (≈1.8×) |
| speed curve | constant | 4.64 m (44 %) inside the first 0.16 s of 10.55 m |
| wall 3 m ahead | stopped at 2.149 m | stopped at 2.148 m (unchanged: never rolls through) |
| invulnerability | none (the telegraph ring "dodged" while `rolling`) | 0.32 s window; a bite 0.15 s in deals 0, no stagger, 1 Defense XP |
| same bite after the window | — | 0.55 s in: lands, 70.8–89.1 dmg across runs (crit/dodge rolls vary) |
| cost / cooldown | 12 stamina, no cooldown | 12 stamina, 0.9 s from the press |
| spam (3 rolls, no attack) | — | 0 Defense XP |
| server | no roll op | `act.roll` + `rolls_dodge`, identical at 0/150/250/319/330/500/900 ms |
| direction | no input = forward (same way she faces) | no input = backward, facing kept; input = that way |

## Verified
- `game/tests/t_roll.gd` → `[t_roll] PASS` (direction, distance, front-loaded curve, wall, i-frames and XP
  at 0.15 s and 0.55 s, stamina, cooldown, no spam XP, server agreement, server cooldown).
  Fails on the base code: with the six game files reverted to `HEAD` it exits 1 (curve + `act.roll` rows).
- Related: `t_combat`, `t_player`, `t_srvdom`, `t_controls`, `t_ai` all PASS.
- Headless only (`HEADLESS_ONLY` is set for this job): no render, no screenshots. The roll pose/animation
  was not looked at.

## Assumptions (all in `combat_tuning.json` `roll._about` unless noted)
- Spec 07 says "a small amount" of invulnerability but gives no numbers: 0.56 s dash, 0.32 s window,
  39 m/s decaying to 0.2, 0.9 s cooldown, 12 stamina, 1 Defense XP, 0.2 s buffer are mine, data-tunable.
- Backward roll with no input is the owner's rule; the facing is kept because no back-roll clip exists.
- `act.roll`'s `ms` (0..999) is the client's millisecond inside the op's second; absent = start of second.
  `# ASSUMPTION` in `_roll`.
- Defense XP is paid only when the accuracy roll would have hit (`lands`), which is the narrow reading of
  "narrowly avoiding a real attack"; a hit that would have missed anyway gives nothing.

## What the integrator needs
- Nothing to merge by hand: the change is confined to the SCOPE files; no new autoload, no new asset.
- If creature→player hits ever move to the server, the hit handler must call
  `IntentHandlers.rolls_dodge(ch, hit_ms)` before applying damage — that is the whole hook.
- A dedicated back-roll clip (Blender/anim thread) would let the backward roll read better; the game will
  use it by swapping `PlayerAnim.on_roll()`.
- The HUD Roll hex shows no cooldown yet; `PlayerSim.roll_cooldown_left()` is there to drive a caption
  (`Hunt.tactic_label(3)` already returns "Roll N"). A dedicated "Dodged" float (`HudEventState.add_float`)
  belongs in `hunt_hud.gd`, which is not in this job's scope.
