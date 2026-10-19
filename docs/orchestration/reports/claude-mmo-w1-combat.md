# W1-COMBAT report (claude, branch claude/mmo-w1-combat)

## What shipped

- `game/scripts/combat/melee_query.gd` (new, `MeleeQuery`): one reach rule for every melee contact. A knee-height ray from attacker to target that skips creatures, players, corpses and harvest nodes and stops on structures and terrain. It also checks that the two bodies overlap in height and measures body edges with `surface_gap` and `point_gap`. Player swings, tackle, kick, creature bites and tyrant impact all use it (tyrant impact through `CreatureAttack.apply_for`).
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
- `hunt_lab`: spawns Lv1 raptors, asserts the survivor is alive at 3.2 s, and exits 1 when there is no corpse or the loot never reaches the bag.
- New `combat_rules_lab` and `game/tests/t_combat.gd`.
- Removed 15 stray `.uid` files that the interrupted WIP commit had picked up.

## Acceptance checklist (lines copied from runs on this branch)

| Item | Output |
|---|---|
| combat_rules_lab PASS | `[combatrules] PASS` (exit 0) |
| fence ring blocks, control bites | `[combatrules] ok fence ring 10 s: 0 bites, 0 survivor hits through the wall (9 bite tries at reach, 0 swings started)` / `[combatrules] ok control without fence 10 s: 7 bites (want >= 3)` |
| forced dodge / miss applies 0 statuses | `[t_combat] ok forced dodge: heavy applies 0 statuses, 0 damage (statuses=0)` / `[t_combat] ok forced miss: heavy applies 0 statuses, 0 damage (statuses=0)` |
| live telegraph at HIT frame | `[combatrules] ok velociraptor heavy: 1 live telegraph(s) at the hit frame, 1.03 s after windup` / `[combatrules] ok protoceratops heavy: 1 live telegraph(s) at the hit frame, 1.27 s after windup` |
| stone knife lands >= 0.25 s after swing | `[combatrules] ok stone-knife damage lands 0.282 s after the swing starts (want >= 0.25)` |
| kick mass and contact reach | `[combatrules] ok kick compsognathus moved 3.50 m (want >= 1.5)` / `[combatrules] ok kick triceratops at contact moved 0.00 m, notice 'Too heavy to shove: it barely feels the kick.'` / `[combatrules] ok kick tyrannosaurus at contact moved 0.00 m, notice 'Too heavy to shove: it barely feels the kick.'` |
| 10 landed club hits = -10 durability | `[t_combat] ok 10 landed club hits: durability 61 -> 51` |
| groggy accuracy +-3 % over 1,000 seeded swings | `[t_combat] ok groggy raptor: 722/1000 hits, want 0.848 x 0.85 = 0.721` / `[t_combat] ok groggy survivor: 855/1000 hits, want 0.85` |
| camera trauma | `[combatrules] ok camera trauma 0.60 right after a heavy hit, 0.00 after 1.0 s` |
| hunt_lab alive at shot, corpse + loot | `[hunt_lab] survivor alive=true hp=100 at 3.2 s`, `[item] +3 raptor_meat (loot velociraptor)`, `[hunt_lab] PASS` (exit 0) |
| Hunt.start on a pet | `[t_combat] ok Hunt.start on a pet starts no hunt` |
| t_combat | `[t_combat] PASS` |
| existing suite | `[tests] PASS` (run_all.gd) |
| smoke | `SMOKE PASS` (tools/smoke.sh --no-import) |

## Screenshots inspected

- `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/combat/hunt_lab.png` (Forward+, 1600x900, 3.2 s shot): the survivor stands at 99/100, the plate reads "Velociraptor Lv. 1", and there is no YOU DIED overlay.

## Assumptions

- `hunt.gd`: contact lands at 60 % of the visible swing until W2-PANIM authors clip hit events.
- `hunt.gd`: creature JSON has no mass field, so length x height stands in for body mass (compy 3.6, raptor 14, triceratops 108, T. rex 192). Shove falls off past mass 8, and bodies of mass 60 or more are giants.
- `hunt.gd`: +1 % damage per Melee level (kept from before).
- `hunt_lab.gd`: wild stats do not scale with level yet (W1-AI), so a Lv1 tier-25 raptor still bites for 80 to 140. The lab tops the survivor up whenever a bite would leave him below 40 HP. Every top-up is printed. This lab shows plates; it does not test balance.
- All balance numbers in `combat_tuning.json` are today's values. pc-balance-01 and armor-01 (subtractive armour) still need an owner decision. armor-01 is only centralised (`CreatureAttack.mitigated`), not redesigned.

## Integrator hooks (files I may not edit)

1. pc-hitreact-02, `game/scripts/creatures/creature.gd` (W1-AI). The hit reaction should fire only on a landed hit, once:
   - `func apply_species_on_hit(clip: StringName, target: Node) -> bool:` with body `return CreatureAttack.apply_for(self, clip, target)`
   - in `_on_hit`: `if apply_species_on_hit(clip, target) and target is Player:` before `(target as Player).receive_creature_hit(self, clip)`
2. pc-test-01, `game/scripts/core/main.gd` combattest. The kick probe prints `kick moved=` and passes even when the kick fails. After the `[combattest] kick moved=` print, add:
   `if before.distance_to(c.global_position) < 0.5: push_error("[combattest] FAIL kick did not move the target")`
   (the probe's 1.5 m spawn is at contact range for that species, so the kick is accepted).
3. `game/tests/run_all.gd`: add `t_combat.gd` to the suite if run_all aggregates per-package tests.

## Labs to register

- `combat_rules_lab` (`game/scripts/dev/combat_rules_lab.gd` + `game/scenes/dev/combat_rules_lab.tscn`)

## Failed or left

- `StatusEffects._sync_vitals` sets the survivor's `max_health` to a hard-coded `100.0 * mult`, which overwrites any other base max health. This predates the package and is outside its spec. I left it alone; W2-PLAYER or W2-DATA should store a base value instead.
- pc-misc-01 second half (a 2.03 m survivor in a 1.8 m capsule) belongs to W2-PLAYER. Only the decal half is closed here.
- durability-01: combat wear ships. Repair and death cost remain an owner decision (W2-DATA).
- Telegraph and trauma were not checked in pixels: the lab asserts them headless. Only the hunt_lab acceptance shot was inspected.
