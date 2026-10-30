# dsc-styratactics report

## Shipped
- `game/data/creatures/ai.json`: new archetype block `horned_charger` (styracosaurus, triceratops)
  on the pack_mule template — ring 9, display 2.0 s, straight charge x2.0 with a 4 m / 0.9 s ram
  shove, miss recover 2.0 s, horn swipe (`heavy` / attack_heavy) x2.2 cd 7 s, kick, retreat_frac
  0.25, guard_m 20, hold-heavy fillers, herd defence. All numbers ASSUMPTION (STYRA in Open_Questions).
- `game/scripts/creatures/brains/tactical_brain.gd`: the `heavy` move (point-blank one-shot horn
  swipe) — `attack_available`, `_strike`, `_seq_next`/`_heavy()`, and `hit_damage_mult` mapping the
  attack_heavy clip to `heavy_mult`. ASSUMPTION-tagged.
- `game/tests/t_styraco.gd`: new headless test, 16 checks PASS (display→charge, landed ram shoves
  her along the line, sidestepped charge misses-first and staggers, horn swipe lands heavier than
  the bite, no flee above 25 % HP and flee below, triceratops shares the brain).

## What failed / notes for the next agent
- The charge's impact is an accuracy roll even with `force_accuracy = 1.0` (the roll-draw order);
  the test retries from a fresh charge. The test also re-aggros between tries (a leash break nulls
  `attack_target`) and pins the survivor each frame so she is a stationary target.
- `reach_to` is centre-to-centre 2.4 m for the styraco; spawning the swipe test at exactly 2.4 m
  was floating-point borderline — spawned at 1.8 m instead.
- `_keep_alive` refills the survivor's HP every frame, so HP-comparison assertions are meaningless;
  the test counts `vitals.damaged` signals instead.

## Credits spent
None (no Meshy).

## What the next agent needs
- Run `bash <scratchpad>/dsc/verify_styratactics.sh` for the full gate.
- The horn swipe reuses the attack_heavy clip; if the art thread adds a dedicated swipe clip,
  change `_heavy()`'s play_clip and `hit_damage_mult`'s clip match together.
