# W1-COMBAT report (claude, branch claude/mmo-w1-combat)

## What shipped

- `game/scripts/combat/melee_query.gd` (new, `MeleeQuery`): one reach rule for every melee contact. A knee-height sphere (radius 0.22 m, kept 0.12 m clear of the lower body's feet) swept from attacker to target that skips creatures, players, corpses and harvest nodes and stops on structures and terrain. It also checks that the two bodies overlap in height and measures body edges with `surface_gap` and `point_gap`. Player swings, tackle, kick, creature bites and tyrant impact all use it (tyrant impact through `CreatureAttack.apply_for`).
- `CreatureAttack.apply_for` returns `bool`. Statuses apply only on a landed hit. Wall, dodge and miss all apply nothing.
- `game/data/combat_tuning.json` (new) and `game/scripts/combat/combat_tuning.gd` (new, `CombatTuning`): every hit-chance and damage number moved there unchanged, plus one seedable RNG and the test overrides `force_dodge` and `force_accuracy`.
- Hit chance is accuracy times the status `accuracy_mult`, against dodge plus the status `evasion_add`. The new `StatusEffects.evasion_add()` supplies that term. This applies to survivor swings, creature bites and stone shots.
- Survivor melee: damage now lands at the swing's hit fraction (60 % of the scaled swing) instead of on the button press. Before applying damage it re-checks reach, the frontal arc and a clear line.
- Weapons lose 1 durability per landed hit, from both melee and ranged. A broken weapon fights as bare hands.
- Tackle and kick: reach is measured surface to surface, so a kick at contact range on a T. rex is accepted. The kick shove scales with a mass proxy (length x height). Giants are refused with the notice "Too heavy to shove".
- Telegraph: a ring now lasts until the attacker's actual `attack_hit`, plus 0.1 s. The textureless Decal is gone. The deafened status hides the ring but still leaves the roll dodge window.
- `IsoCamera` trauma shake runs on h/v offsets. It triggers when the survivor is hit, harder on heavy hits, and on the survivor's own heavy swings.
- `Hunt.start` rejects pets. A ranged shot with a blocked line of sight shows "No clear shot" (throttled to once every 3 s). Stone shots fly a gravity arc. Nets follow the 30 % rule: the Net hex is hidden above 30 % health.
- AoE and traps now measure to the body edge (siege burst, ground snare).
- `hunt_lab`: a pack of two raptors and three protoceratops rebased to level-1 stats (see Assumptions). It asserts the survivor is alive at 3.2 s with no guard or top-up, and exits 1 when there is no corpse or the loot never reaches the bag.
- `game/scripts/combat/combat_tactics.gd` (new, `CombatTactics`): tackle, kick, mass proxy and the reach gate, moved out of `hunt.gd`. `Hunt.use_tackle/use_kick` stay as one-line delegates and the cooldowns stay on Hunt because `hunt_hud.gd` reads them. `hunt.gd` is now 367 lines, down from 444.
- New `combat_rules_lab` and `game/tests/t_combat.gd`.
- Removed 15 stray `.uid` files that the interrupted WIP commit had picked up.

## Review round 1 fixes

| Finding | Fix | Check that would have caught it |
|---|---|---|
| blocker: knee ray slipped through the 0.4 m corner slot (fence lab 3/5 FAIL) | `MeleeQuery.blocker` sweeps a 0.22 m sphere (`cast_motion` + `get_rest_info`, skipping bodies as before) | `t_combat` `_test_corner_slot` rebuilds the reviewer's probe geometry. With the radius forced to 0.02 m it printed `[t_combat] FAIL corner slot: raptor->survivor blocked by <null>`; at 0.22 m it prints `ok`. combat_rules_lab then passed 5 of 5 runs in a row (below). |
| blocker: hunt_lab survivor immortal (`_lab_guard`), Lv1 cosmetic | Guard removed. Each lab animal gets a duplicated def with hp/attack/defense divided by `ProgressionScaling.level_multiplier(tier)`, so `stat_value` really is level 1. The pack is two raptors, not three. | A negative run with `_starter_level` disabled printed `[hunt_lab] survivor alive=false hp=0 at 3.2 s` / `[hunt_lab] FAIL survivor dead at the 3.2 s acceptance shot` and exit 1, so the assertion can fail. |
| minor: combattest kick hook fires on a working kick | Hook 2 now waits out the tackle lock first (below), and notes the existing `World.runtime` crash | integrator hook only (main.gd) |
| minor: lab bout counters wrong | `Hunt` emits `swing_started` (in `begin_swing`) and `hit_landed(target)` (in `land_hit`); the lab counts those | control bout now reads `{ "bites": 6, "hits": 14, "reach_tries": 8, "swings": 14 }` (was `swings: 0`) |
| minor: swing timer runs while paused | `create_timer(hit_delay(w), false)` | `[t_combat] ok swing waits out a pause: hp 612 paused, 611 after` |
| minor: ranged skill scaling hard-coded | `ranged.damage_per_ranged_level` (0.01) in combat_tuning.json | inspect `stone_projectile.gd` impact |
| minor: hunt.gd grew 150 lines | tackle/kick extracted to `CombatTactics` | `t_combat` kick-push rows now call `CombatTactics.kick_push` |
| minor: melee blocked silently | `_auto_attack` says "Something is in the way." through the same 3 s throttle as "No clear shot" (`Hunt.say_throttled`) | `[t_combat] ok melee blocked by the fence says so ('Something is in the way.')` |
| minor: tyrant and `_nearest_creature` half of pc-hitreact-02 / pc-bug-01 | hooks 4 and 5 below (files owned by W1-AI / protected) | integrator hooks |

combat_rules_lab, five runs in a row after the fix (each exit 0):

```
run 1 [combatrules] ok fence ring 10 s: 0 bites, 0 survivor hits through the wall (9 bite tries at reach, 0 swings started) | control 6 bites | [combatrules] PASS
run 2 ... 0 bites, 0 survivor hits (9 bite tries at reach, 0 swings started) | control 7 bites | [combatrules] PASS
run 3 ... 0 bites, 0 survivor hits (8 bite tries at reach, 0 swings started) | control 10 bites | [combatrules] PASS
run 4 ... 0 bites, 0 survivor hits (7 bite tries at reach, 0 swings started) | control 8 bites | [combatrules] PASS
run 5 ... 0 bites, 0 survivor hits (7 bite tries at reach, 0 swings started) | control 6 bites | [combatrules] PASS
```

hunt_lab, survivor HP at the 3.2 s beat, no guard: three starter raptors gave 12, 62, 74, 9, 14 (alive every time, but one crit from death); two raptors gave 81, 48, 79, 82, 50 (all `[hunt_lab] PASS`, exit 0). I kept two.

The corner slot itself is a real 0.4 m gap where a ring row and a column fail to meet in `BuildGrid` fence placement. Melee no longer leaks through it. A stone shot can still pass, but no body is narrow enough to. Filed for W1-BUILD below.

## Acceptance checklist (lines copied from runs on this branch)

| Item | Output |
|---|---|
| combat_rules_lab PASS | `[combatrules] PASS` (exit 0), 5 of 5 consecutive runs |
| fence ring blocks, control bites | `[combatrules] ok fence ring 10 s: 0 bites, 0 survivor hits through the wall (7 bite tries at reach, 0 swings started)` / `[combatrules] ok control without fence 10 s: 6 bites (want >= 3)` |
| forced dodge / miss applies 0 statuses | `[t_combat] ok forced dodge: heavy applies 0 statuses, 0 damage (statuses=0)` / `[t_combat] ok forced miss: heavy applies 0 statuses, 0 damage (statuses=0)` |
| live telegraph at HIT frame | `[combatrules] ok velociraptor heavy: 1 live telegraph(s) at the hit frame, 1.02 s after windup` / `[combatrules] ok protoceratops heavy: 1 live telegraph(s) at the hit frame, 1.28 s after windup` |
| stone knife lands >= 0.25 s after swing | `[combatrules] ok stone-knife damage lands 0.282 s after the swing starts (want >= 0.25)` |
| kick mass and contact reach | `[combatrules] ok kick compsognathus moved 3.50 m (want >= 1.5)` / `[combatrules] ok kick triceratops at contact moved 0.00 m, notice 'Too heavy to shove: it barely feels the kick.'` / `[combatrules] ok kick tyrannosaurus at contact moved 0.00 m, notice 'Too heavy to shove: it barely feels the kick.'` |
| 10 landed club hits = -10 durability | `[t_combat] ok 10 landed club hits: durability 61 -> 51` |
| groggy accuracy +-3 % over 1,000 seeded swings | `[t_combat] ok groggy raptor: 751/1000 hits, want 0.879 x 0.85 = 0.747` / `[t_combat] ok groggy survivor: 855/1000 hits, want 0.85` |
| camera trauma | `[combatrules] ok camera trauma 0.60 right after a heavy hit, 0.00 after 1.0 s` |
| hunt_lab alive at shot, corpse + loot | `[hunt_lab] survivor alive=true hp=50 at 3.2 s` (no guard), `[item] +3 raptor_meat (loot velociraptor)`, `[hunt_lab] PASS` (exit 0) |
| Hunt.start on a pet | `[t_combat] ok Hunt.start on a pet starts no hunt` |
| t_combat | `[t_combat] PASS` |
| existing suite | `[tests] PASS` (run_all.gd) |
| smoke | `SMOKE PASS` (tools/smoke.sh --no-import) |

## Screenshots inspected

- `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/combat/hunt_lab.png` (round 0; superseded: that run had the immortality guard).
- `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/combat/hunt_lab_v2.png` (Forward+, 1600x900, 3.2 s shot, no guard): survivor bar 33 / 100, target plate "Velociraptor Lv. 1" at 108 / 233 (starter stats), a -21 float, no YOU DIED overlay. The log line for that run: `[hunt_lab] survivor alive=true hp=33 at 3.2 s`.

## Assumptions

- `hunt.gd`: contact lands at 60 % of the visible swing until W2-PANIM authors clip hit events.
- `combat_tactics.gd` (moved from hunt.gd): creature JSON has no mass field, so length x height stands in for body mass (compy 3.6, raptor 14, triceratops 108, T. rex 192). Shove falls off past mass 8, and bodies of mass 60 or more are giants.
- `hunt.gd`: +1 % damage per Melee level (kept from before).
- `hunt_lab.gd`: wild stats do not scale with level yet (creature.gd is W1-AI's). The lab treats species JSON stats as the animal at its tier level and divides hp, attack and defense by `ProgressionScaling.level_multiplier(tier)` for level 1 (raptor 640 hp / 95 atk becomes 219 / 33, protoceratops /2.52). It does this on a duplicated def, never the shared one. Remove it when W1-AI scales wild stats by level; that is a dependency to record for W1-AI.
- `hunt_lab.gd`: the raptor pack is two, not three (HP numbers above). This changes the scene, not the rule.
- `melee_query.gd`: the sweep radius is 0.22 m and stays 0.12 m above the lower body's feet, so a flat floor never counts as a wall. Very short bodies get a thinner sphere, down to 0.02 m.
- All balance numbers in `combat_tuning.json` are today's values. pc-balance-01 and armor-01 (subtractive armour) still need an owner decision. armor-01 is only centralised (`CreatureAttack.mitigated`), not redesigned.

## Integrator hooks (files I may not edit)

1. pc-hitreact-02, `game/scripts/creatures/creature.gd` (W1-AI). The hit reaction should fire only on a landed hit, once:
   - `func apply_species_on_hit(clip: StringName, target: Node) -> bool:` with body `return CreatureAttack.apply_for(self, clip, target)`
   - in `_on_hit`: `if apply_species_on_hit(clip, target) and target is Player:` before `(target as Player).receive_creature_hit(self, clip)`
2. pc-test-01, `game/scripts/core/main.gd` combattest. Today the probe calls `use_kick` 0.3 s after `use_tackle`, but the tackle sets `_tactic_lock` 0.55 s and the attack clip marks the player busy, so `_can_start_tactic` refuses the kick and it moves 0 m. Add `player.hunt.auto = false` right after `player.hunt.start(c)`, so an auto swing does not take the gap. Then, between the `[combattest] tackle groggy=` print and `var before`, insert:
   `while player.hunt._tactic_lock > 0.0 or player.anim._busy: await get_tree().process_frame`
   After the `[combattest] kick moved=` print:
   `if before.distance_to(c.global_position) < 0.5: push_error("[combattest] FAIL kick did not move the target")`
   Separately, `--combat-test` already crashes on this branch, before my diff: `Cannot call method add_child on a null value` at main.gd:111 (`World.runtime` is null). The integrator needs to load an island (or use the lab host) first. I could not run the probe because of this.
3. `game/tests/run_all.gd`: add `t_combat.gd` to the suite if run_all aggregates per-package tests.
4. pc-hitreact-02, `game/scripts/creatures/brains/tyrant_brain.gd` (`_impact`, W1-AI). Replace the last two lines with:
   `if CreatureAttack.apply_for(creature, windup_clip, locked_target) and locked_target is Player: (locked_target as Player).receive_creature_hit(creature, windup_clip)`
5. pc-bug-01, `game/scripts/player/player.gd` `_nearest_creature` (protected). Change the skip test to `if c == null or c.health.dead or c.is_pet:`, so F picks the nearest wild animal instead of picking the pet and then doing nothing, because `Hunt.start` refuses pets.

## Labs to register

- `combat_rules_lab` (`game/scripts/dev/combat_rules_lab.gd` + `game/scenes/dev/combat_rules_lab.tscn`)

## Failed or left

- For W1-BUILD: a closed `BuildGrid` fence ring leaves a 0.4 m slot where a row (rot 0) and a column (rot 1) meet. In the lab ring the slot is at the row z=16.5 and the column x=10.5, which starts at z=17. Melee is now blocked there, but projectiles can still pass.
- Ranged LOS still uses a zero-width ray (`Hunt.fire_ranged`), which is fine for a projectile. The projectile can pass the same corner slot.

- `StatusEffects._sync_vitals` sets the survivor's `max_health` to a hard-coded `100.0 * mult`, which overwrites any other base max health. This predates the package and is outside its spec. I left it alone; W2-PLAYER or W2-DATA should store a base value instead.
- pc-misc-01 second half (a 2.03 m survivor in a 1.8 m capsule) belongs to W2-PLAYER. Only the decal half is closed here.
- durability-01: combat wear ships. Repair and death cost remain an owner decision (W2-DATA).
- Telegraph and trauma were not checked in pixels: the lab asserts them headless. Only the hunt_lab acceptance shot was inspected.
