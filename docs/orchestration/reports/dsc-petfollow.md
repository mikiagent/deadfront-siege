# dsc-petfollow — tames follow in a radius, not on top of the player

Owner (2026-10-28): "tames should follow within a certain radius of the player, not directly on top of
the player". Headless-only job (owner's `HEADLESS_ONLY` marker): no visual lab was run or claimed.

## What shipped
- `game/data/creatures/ai.json`: new `"follow"` block (every number an `# ASSUMPTION`):
  `slot_m` 3.0, `slot_size_mult` 1.0, `slot_arc_deg` 50, `inner_m` 2.0, `outer_m` 4.5,
  `heel_mult` 0.7, `clearance_margin_m` 0.3, `step_aside_m` 0.8, plus an `_about` explaining them.
- `game/scripts/creatures/brains/pet_brain.gd`:
  - `follow_slot(player)` / `slot_distance()`: a per-pet SLOT behind/beside the survivor, fanned by
    summon order (0 right, 1 left, 2 behind, further pets to the rear by `slot_arc_deg`), distance
    `(slot_m + slot_size_mult * body_radius) * follow_dist_mult * (heel_mult on HEEL)` — a big tame
    hangs back further, a Loyal pet stands closer, HEEL pulls it in.
  - `follow_inner()` / `follow_outer()`: hysteresis radii around the slot, scaled by body size and
    by the nature knob (squared, so the band closes on the closer slot).
  - `_follow()`: walks only outside `outer`, stops inside `inner` (latch `_following`), steps out to
    `player_clearance` when the survivor walks into the capsule, and routes round the survivor's
    clearance circle via a "gate" point instead of straight through it (`_past_gate` latch).
  - `player_clearance(player)` = survivor capsule 0.35 m + pet body radius + 0.3 m margin.
  - `nature_stop_distance()` kept (t_natures and the shared nature reading use it); guard radius,
    attack order, retreat and riding logic untouched.
- `game/scripts/player/player_pets.gd`: a new summon now spawns at its own slot
  (`PetBrain.slot_for`) instead of in a row at `+1.5 + 1.2*i` on x.
- `game/scripts/creatures/creature.gd`: `_apply_pet_passthrough` now also makes a pet ignore the
  other pets' capsules (`_pet_peers_aware`); the survivor's exception is unchanged, enemies still
  collide. Without it two pets whose capsules met inside a slot deadlocked (measured).
- `game/tests/t_petfollow.gd`: new acceptance test, 7 sections.
- `docs/current/creatures-capture-taming.md`: follow behaviour, numbers and code names.

## Before / after (measured, headless)
Base (read from the old `pet_brain.gd`, confirmed by the 6 FAILs of t_petfollow on it): every pet
aimed at the SAME point — `player + player.global_basis.x * 1.6` (1.2 on HEEL) — and stopped once
within `nature_stop_distance` (1.6–2.4 m), so several pets converged on one spot beside the survivor
with no clearance from the survivor's capsule and no per-pet slot.
After (t_petfollow, 3 pets: velociraptor / triceratops / compsognathus, still survivor):

```
settled  velociraptor  slot_d=0.00  player_d=3.72  clear=1.37  (inner 2.24 outer 5.04)
settled  triceratops  slot_d=0.00  player_d=5.16  clear=2.81  (inner 2.72 outer 6.12)
settled  compsognathus slot_d=0.00 player_d=3.36  clear=1.01  (inner 2.12 outer 4.77)
loyal slot=2.60 m vs plain slot=3.72 m (velociraptor)
still 5 s: max pet movement 0.000 m
after a 20 m walk: slot_d 1.99 / 2.70 / 2.04 m; player_d 1.73 / 7.86 / 3.93 m
step aside: 0.15 m -> 1.47 m (clearance 1.37)
```

Sizes: slot distance 3.72 (raptor) < 5.16 (triceratops); compsognathus 3.36. Nature: loyal 2.60 <
3.72. No two pets within r1+r2 (capsules pass through each other, but the slots keep them apart).

## Shots looked at
None. `HEADLESS_ONLY` is set in the job's gate directory: the owner reserved the machine and the
gate explicitly defers `--lab=petslab`. Gate output: `VERIFY HEADLESS-ONLY: visual lab deferred by
owner`, `VERIFY STAGE 2 PASS`. The lab itself (`game/scripts/dev/pets_lab.gd`) is untouched and its
`LAB_ASSERT` is `True`, so it adds no follow check either way.

## Verification
- `verify_job.sh petfollow 1` PASS (3 consecutive runs), `verify_job.sh petfollow 2` PASS.
- Related: `t_tame`, `t_petradial`, `t_natures`, `t_ai`, `t_turnrate` all exit 0 with a PASS line and
  no SCRIPT ERROR.
- `t_petfollow` passes on 5 consecutive direct runs; the one flaky failure found (a pet orbiting the
  gate waypoint on the 20 m walk) was fixed with the `_past_gate` latch before the gate runs above.
- Test fails on base: restoring the base `pet_brain.gd` + `ai.json` gives exit 1 with 6 FAILs.

## Assumptions (all `# ASSUMPTION`)
1. Every number in `ai.json` `follow` (see above) — picked to be measurable, not balanced.
2. Slot fan: right / left / behind for 3 pets (MAX_OUT is 3); a 4th+ would fan to the rear by
   `slot_arc_deg`. Slot distance uses `Creature.body_radius()` (0.12 × real length).
3. The nature's `follow_dist_mult` scales the slot AND (squared) the inner/outer band; HEEL scales
   both by `heel_mult`. This keeps the existing knob working and makes Loyal visibly closer.
4. Survivor capsule radius 0.35 m is a constant in `pet_brain.gd` (`PLAYER_RADIUS`), the same value
   `creature_brain.gd` uses for reach (`SURVIVOR_RADIUS`); the player scene's own `radius = 0.35`.
5. Pets pass through each other's capsules (like they already pass through the survivor's). This
   only removes pet-vs-pet body blocking; pet-vs-wild and pet-vs-structure collision is unchanged.

## What the integrator needs
- Nothing merged or pushed; all changes are in this worktree, inside the job SCOPE.
- If the owner wants pets to body-block each other instead, drop the `_pet_peers_aware` loop in
  `Creature._apply_pet_passthrough` — the follow slots already keep them apart, but expect contact
  separation to nudge pets inside their inner radius (the test tolerates 0.3 m over inner).
- The visual follow behaviour (arc, spacing, how it reads at 1600×900 and 844×390) has NOT been
  looked at; it needs a headed `petslab` run once the owner clears `HEADLESS_ONLY`.
