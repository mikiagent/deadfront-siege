# dsc — capture09 (spec 09 §1: capture when stunned at any HP, or at <= 30 % HP)

Owner rule: a wild animal is capturable when it is **stunned/collapsed at ANY HP**, **or** its HP is
**at or below 30 %**. The code required **both** (knockdown AND `< 30 %`). Stun = the existing
`knockdown` status (`game/data/statuses.json`); no new status, no second capture system.

## What shipped

One rule, one place: `game/scripts/pets/field_tame.gd`

- `FieldTame.capture_window(creature) -> bool` — not dead, `def.tameable`, not `is_pet`, and
  (`statuses.has(&"knockdown")` **or** `health.fraction() <= CAPTURE_HEALTH_FRAC`).
- `FieldTame.window_open(hp, hp_max, stunned)` — the same rule for callers holding numbers (server
  intents, lab fixtures).
- `FieldTame.health_allows_capture(fraction)` — now the health half only, and **`<=`** (was `<`).
- `FieldTame.can_attempt()` (feeding) delegates to `capture_window()`; the cooldown / technique / roster
  checks are unchanged.

Every old site now goes through it:

| file | what changed |
|---|---|
| `pets/capture_system.gd` | `attempt()` gates on `capture_window` (was `capturable()` + `health_allows_capture`); new `chance_for(creature, net_tier)` = `clamp(base[tier] * (1.5 - hp_fraction), 0.05, 0.90)` on the **actual** HP — same formula and numbers as before. Refusal print now says "stun it or weaken it to 30 %". |
| `combat/hunt.gd` | `_net_health_ok()` = `FieldTame.capture_window(target)`; Net tactic label and `use_net()` share it; refusal is `"Stun it or weaken it to 30% health to capture it."`; new 50 % tutorial hint. |
| `combat/status_effects.gd` | the DoT guard skips `bleeding_target` / `poisoned_target` when `FieldTame.capture_window(cr)` — never force damage onto a capturable animal. |
| `creatures/creature.gd` | the groggy -> `knockdown` collapse uses `health_allows_capture()` (`<=`). |
| `server/intent_handlers.gd` | `act.tame` / `act.capture` gate on `FieldTame.window_open(hp, hp_max, knocked)` and refuse with `"Stun it or weaken it to 30% health to capture it."`; net tier / technique / range checks untouched. |
| `ui/hunt_hud.gd` | the Net hex is enabled by `hunt._net_health_ok()` (the same window) instead of `capturable()`. |

Tutorial hint (`hunt.gd`): once per creature, when the hunted creature is a tameable, non-pet, living
animal at `<= 50 %` HP and not stunned: `"Stun the dinosaur to capture it safely."` via `say()` ->
`player.notice()`; state is `_stun_hinted` keyed by instance id (a second animal gets its own hint).
No new UI widget.

## Before / after

| case | before | after |
|---|---|---|
| stunned, 80 % HP | refused (net, tame, server) | capturable; net chance 0.24 (tier 1) |
| unstunned, exactly 30 % | refused (`<`) | capturable |
| unstunned, 31 % | refused | still refused |
| unstunned, 20 % | capturable | capturable |
| chance at 80 % vs 20 % (tier 2) | 0.32 vs 0.59 (unchanged formula) | 0.32 vs 0.59 |
| bleed on a stunned 80 % animal | ticks (can kill it) | skipped |
| hunt refusal text | "Weaken it below 30% health before netting it." | "Stun it or weaken it to 30% health to capture it." |
| 50 % HP, unstunned, hunted | nothing | one "Stun the dinosaur to capture it safely." |

## Tests

- New `game/tests/t_capture09.gd`: window (stun@80 % true, 30 % true, 31 % false, dead / pet /
  non-tameable / null false), feeding opens at 80 % stunned, chance ordering per tier with the formula
  pinned, `attempt()` nets a stunned 80 % animal, DoT guard on a stunned 80 % animal, the 50 % hint
  fires exactly once and not above 50 %. **Fails 6 asserts on the old rule** (verified by temporarily
  restoring `knockdown AND < 30 %`), passes now.
- `game/tests/t_tame.gd` `_test_rules` updated (never deleted): unstunned 50 % refused, **stunned 50 %
  netted**, unstunned 25 % netted; the technique-lock asserts are untouched.
- t_tame, t_combat, t_srvdom, t_capture09: PASS.

## What the integrator must do

1. **`game/tests/run_all.gd` lines 548-550 still encode the old boundary** (outside this job's SCOPE):
   ```gdscript
   _expect(bool(script.call("health_allows_capture", 0.299)), "capture opens below 30 percent health")
   _expect(not bool(script.call("health_allows_capture", 0.30)), "capture stays closed at 30 percent health")
   _expect(not bool(script.call("health_allows_capture", 0.50)), "capture stays closed above threshold")
   ```
   Flip the middle line to expect **true** at 0.30 and add `0.301` as the false case. The third line
   (0.50 false) is still correct — an unstunned 50 % animal is only capturable via `capture_window`.
2. `docs/current/` and the GAUNTLET line already say the new rule; no doc edit needed there.

## Assumptions

- `# ASSUMPTION` in `creature.gd`: the groggy -> knockdown **collapse** still needs `<= 30 %`. Widening
  it would collapse every tackled animal at full HP — a balance change spec 09 does not ask for. The
  spec's "stunned at any HP" is satisfied because any `knockdown` (tackle finish, raptor pounce, lab)
  now opens capture at any HP.
- The 50 % hint fires from the hunt process loop, so it needs a live hunt on the creature (the player is
  fighting it), which is what the spec says. It is throttled only by "once per creature", not by time.
- No balance numbers were tuned: chance bases, 30 % threshold, 50 % hint point all as they were / as the
  spec names them.

## Shots

See `.dsc/NOTES.md` for the capture_lab PNG paths and the one-line verdicts.
