# Enemy AI template: class profiles, sequences, cooldowns

How a wild creature fights, as the build runs it today. The deinonychus (`pack_flanker`) is the
first and so far only class on it. Its profile is the template for the other classes.
Code: `game/scripts/creatures/brains/tactical_brain.gd` (`TacticalBrain`), data:
`game/data/creatures/ai.json` → `archetypes.<archetype>.tactics`, test: `game/tests/t_tactical.gd`.

## Who gets it
`Creature._make_brain` gives `TacticalBrain` to any non-pet whose archetype row has a `tactics`
block (`TacticalBrain.has_tactics`). Pets keep `PetBrain`. The T. rex keeps `TyrantBrain`. Every
other species keeps `RaptorPackBrain` or `CreatureBrain` until its class gets a profile. The
shared rules in `CreatureBrain._pre_think` still run first: leash, sleep, walking home, LOD
freeze.

## States
`approach` → `circle` (strafing at the stand-off ring) → a **sequence** → its finisher (`pounce`,
`charge`, `lunge` leap-in → `combo`/`attack`) → one back-off (`hop`), or `hold` when a back-off is
not allowed. The fillers are `hold`, `circle`, `feint`, `hop` and `dodge`. `retreat` happens
below `retreat_frac` HP. `lurk` (shown as `brain_state`) is the ambush idle.
Full-rate thinking runs in every one of these states (`_full_rate`).

## Profile format (`tactics`, every number an ASSUMPTION)
| Key | Deinonychus | Meaning |
|---|---|---|
| `sequences` | 7 rows | `{name, steps[], weight}`; the last step is the finisher |
| `point_blank` | `[combo, bite]` | at contact, after `contact_after_s` 1.0 s of circling |
| `ring_m`, `circle_min_s`/`max_s` | 6.5 m, 0.5–1.0 s | stand-off ring and filler beat length |
| `bite_cd` / `combo_cd` / `pounce_cd` / `charge_cd` / `hop_cd` | 3.5 / 10 / 12 / 5 / 3.5 s | each move's own cooldown, committed when the move is picked |
| `pounce_telegraph_s`, `pounce_mult`, `pounce_min_m`/`max_m` | 0.8 s, 2.5×, 4–11.5 m | pounce windup with a ground ring, damage, range |
| `pounce_overshoot_chance`, `_m`, `pounce_miss_recover_s` | 0.25, 3 m, 1.5 s | sail past the prey; a miss leaves a longer punish window |
| `combo_mults` | 1.0 / 1.3 / 1.8 | damage of each `bite_combo` hit |
| `strafe_m`, `strafe_s` | 2.5 m, 0.42 s | the powerful strafe (dodge step) |
| `hop_m`, `leap_back_m`, `leap_in_max_m`, `leap_height_per_m` | 3.5, 5, 6 m, 0.2 | leap lengths (the profile's, not the body's); arc height rises with distance |
| `max_retreat_m` | 12 m | no back-leap ends farther from the prey than this |
| `w_hold` / `w_strafe` / `w_feint` / `w_hop` | 0.8 / 0.3 / 0.1 / 0.1 | filler weights; hold ×2 while the prey is not advancing |
| `max_basic_streak`, `max_basic_share` | 2, 0.15 | anti-spam: basics in a row; the share the test allows |
| `retreat_frac`, `wide_ring_mult`, `wide_circle_s` | 0.4, 1.6, 4 s | back off when hurt, then circle wider |
| `ambush`, `cover_m`, `ambush_radius_m`, `back_radius_m`, `ambush_pounce_max_m` | true, 14, 6, 10, 10 m | lurk at the tree nearest home and open with the pounce |

## Rules the brain enforces
- **Offence comes from movement.** A sequence is picked by weight × the nature's
  `tactic_w_<finisher>`, and only when its finisher is off cooldown and affordable. Steps:
  `backstep` (a hop_back, at most one per sequence), `strafe_left`/`strafe_right` (the dodge
  step), then `pounce`, `charge` (a run into a bite) or `combo` (a leap-in into `bite_combo`).
  A pounce step that is out of range turns into a charge.
- **The basic bite is a last resort.** It fires only at point blank or during a chase. There is
  always a non-attack beat between two basics, and at most `max_basic_streak` basics come before
  a beat or a special.
- **Energy.** Specials go through `Creature.try_special` (`ai.json energy.special_cost_frac`:
  pounce 0.3 and bite_combo 0.35 of the pool). Dashes, charges and lunges need `can_sprint()`.
  `energy.sprint_states` drain the pool.
- **Back-offs are leaps, never walks.** There is ONE after an attack. Two back-jumps never come
  in a row without a strafe, attack, pounce or chase between them. Back-jumps have `hop_cd` and
  are capped by `max_retreat_m`.
- **Prey that walks away** (more than 1 m/s outward) is chased at a full run, or pounced when the
  pounce reaches its predicted position. It never holds or backs off while the prey leaves.
- **Hit times are data.** The `bite_combo` hits come from `anim_events.json` `hit_fracs`, and its
  tell ring from `tell_fracs[0]`. The pounce hit comes from `pounce.hit_frac`, and leaps move
  only inside their `airborne` fracs. The roll's i-frames (RollRules) decide dodges in
  `CreatureAttack`.

## Clip set (`CreatureClips`)
Required (`CONTRACT`): idle, walk, run, attack_primary, attack_heavy, hit_react, knockdown, death,
alert, feed. Optional (`OPTIONAL`, loaded when the GLB exists): sleep, tail_swipe, bite_combo,
hop_back, leap_back, pounce, dodge_left, dodge_right, strafe_left, strafe_right, walk_back.
Fallbacks: a leap without its clip retimes attack_heavy over the profile's `*_s`. A dodge
without its clip plays the strafe loop. Locomotion picks a clip by velocity against facing
(`CreatureAnim.set_move_velocity`): walk_back when dot < -0.5, a strafe when |side| > 0.7, each
stride-matched, otherwise walk/run. The same applies to ridden mounts.

## Natures (`natures.json`, default 1.0)
| Knob | Aggressive | Timid | Brave |
|---|---|---|---|
| `tactic_cooldown_mult` | 0.7 | | |
| `tactic_feint_mult` | 0.5 | 1.5 | |
| `tactic_standoff_mult` | | 1.3 | |
| `tactic_hold_mult` | 1.5 | | 1.5 |
| `tactic_backoff_mult` | | 2.0 | |
| `tactic_overshoot_mult` | 1.6 | | |
| `tactic_w_charge` / `_combo` / `_pounce` | 2.0 / 1.5 / – | 0.4 / – / 1.5 | – / 1.5 / – |
| `retreat_threshold_mult` (shared) | | 1.8 | 0.5 |

## Player side
- A hit stuns her for exactly the hurt clip's length (`PlayerSim.hurt_stun_seconds`): no
  movement, no swings. Then walk/run takes over (`PlayerAnim.end_hurt`).
  `HIT_STUN_IMMUNE_S` 0.8 s follows, during which hits damage but cannot re-stun.
- Basic swing cooldown = max(1 / attack_rate, `player_melee.basic_cooldown_s` 0.8 s), on the
  client and the server (`act.attack`, `ms` like `act.roll`).
- Tackle and Kick have their own cooldowns (8 s and 6 s) and stagger the target
  (`stagger_s` 0.8 and 0.5 s). They can cut the auto-attack swing short.

## Server
`act.attack` enforces the basic cooldown. Creature AI, creature cooldowns and the stun rule are
client-only: creature hits on a player are not validated server-side yet. When they are, they
call `IntentHandlers.rolls_dodge`.

## Adding a new class
1. Decide the archetype's finishers and fillers from its PRD row (e.g. charger: line-up + charge;
   club tail: side-on tail swipe). Don't invent a mechanic the PRD lacks; mark it `# ASSUMPTION`.
2. Add `tactics` to `ai.json archetypes.<archetype>`: `sequences`, `point_blank`, every
   `<move>_cd`, ring, leap lengths, filler weights, `max_basic_streak`/`share`.
3. A finisher that `TacticalBrain` lacks (stomp, tail swipe, spit) needs a `_terminal_ready`
   case, a `_seq_next` step and a state function. Add its energy cost to `special_cost_frac`.
4. List the clips it needs. Missing optional clips fall back as above; ask the art thread for
   the rest and give each its `anim_events.json` timing (`hit_fracs`, `tell_fracs`, `airborne`).
5. Add nature weights (`tactic_w_<finisher>`) where a nature should lean.
6. Copy `t_tactical`'s `_test_fight` for the species: no move inside its cooldown, sequences
   run in order, basics ≤ share, a beat between basics, back-jumps never adjacent, distance ≤
   `max_retreat_m`, energy gate, retreat. Then run t_ai, t_combat, t_natures, t_canim and
   `tools/smoke.sh`.
7. Watch it in the creature lab:
   `Godot --path game -- --lab=creature_lab --species=<id>` (F3 prints every move;
   `--seq=DIR` saves frames).
