# claude-dodgetext: "Dodged" / "Blocked" combat text, aggro ring debug-only

Branch `claude/mmo-dodgetext` (from `origin/claude/mmo-overhaul`). Owner ask, 2026-10-28: a dodge
"damage number" ("Dodged" / "Blocked") for players and enemies; the aggro-range circle only in debug mode.

## What shipped

- **One avoidance hook: `CombatAvoid.avoided(defender, attacker, how)`** in
  `game/scripts/combat/combat_avoid.gd` (`how` = `&"dodge"` or `&"block"`). Every place that decides
  an attack is avoided now calls it, and nothing else:
  - `Player.roll_dodge` (roll i-frames; it replaces the old `notice("Dodged")` HUD line),
  - `CreatureAttack._deal_damage`: survivor miss / telegraph dodge (print only before; now shows text),
    and creature-on-creature misses,
  - `Hunt.land_hit`: a survivor swing the creature dodges,
  - `StoneProjectile`: a thrown stone the victim dodges.
- Survivor: `HuntHud.avoid_on_player(text)` floats the text where her damage numbers rise, light grey,
  17 px (hits are 22 px). `HudEventState.add_float` gained an optional `px`.
- Creatures: the plate float for kind `dodge` now reads "Dodged" (was "DODGE"); new kind `block` reads
  "Blocked"; both light grey 14 px.
- Aggro ring (`Creature._update_aggro_ring`) shows only while `Game.debug_overlay` is on (F3, labs
  default it on). `targetui_lab` turns the overlay on around its aggro-ring check.

## For claude/mmo-slowlevels (Defense XP)

Put Defense XP for avoided hits in `CombatAvoid.avoided`. Today the roll still pays its XP in
`Player.roll_dodge` (only when the hit would have landed, `lands`); that was left alone. If XP should
only pay for hits that would have landed, add a `lands` argument to the hook.

## Not done / assumptions

- **There is no block mechanic in the game yet.** "Blocked" is wired (hook, both float paths, tested by
  calling the hook directly), but nothing calls it with `&"block"` until a block exists.
- Creatures' backstep/strafe moves are movement only; their real avoidance is the dodge-chance miss,
  which is covered. The server-side swing result `{"kind": "dodge"}` (intent_handlers) is not routed
  to the hook; the local `Hunt.land_hit` path is.
- No italics (the HUD draws with one font); smaller + grey instead.

## Tests

- New `game/tests/t_dodgetext.gd`: i-frame bite deals 0 and floats "Dodged" over the survivor; a block
  floats "Blocked"; smaller than a damage number; a dodged swing deals 0 and floats "Dodged" over the
  plate; creature "Blocked"; aggro ring hidden with debug off, shown with it on, hidden again.
- Screenshot: `docs/orchestration/reports/dodgetext/dodged.png`.
- `tools/all_tests.sh`: 125/128 under heavy machine load (~39 Godot processes from other agents). Fails: t_buildspeed (island build 2.6 s, then 5.3 s on rerun, vs 2.5 s budget), t_eyetrails (ribbon script 2.2 ms, then 3.8 ms, vs 2 ms), t_petfollow (passed on rerun). All are timing budgets on code this branch does not touch; rerun them on an idle machine.
- `tools/smoke.sh --no-import`: SMOKE PASS. `t_dodgetext` PASS.

Credits spent: none.
